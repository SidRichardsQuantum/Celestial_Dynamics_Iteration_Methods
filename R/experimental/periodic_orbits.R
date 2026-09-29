# Experimental single shooting. Depends only on the public dynamics interface.
# No simulation runner dispatch, persistence, or model definitions are modified.
periodic_orbit_components = function(state) {
  if (!is.list(state) || !is.matrix(state$positions) || !is.matrix(state$velocities) ||
      !identical(dim(state$positions), dim(state$velocities)))
    stop("state needs matching positions and velocities matrices.")
  unlist(lapply(c("position", "velocity"), function(kind)
    unlist(lapply(seq_len(ncol(state$positions)), function(axis)
      paste0(kind, "[", seq_len(nrow(state$positions)), ",", axis, "]")), use.names = FALSE)),
    use.names = FALSE)
}

cd_shooting_norm = function(x) {
  if (any(!is.finite(x))) stop("Nonfinite shooting residual or correction.")
  largest = max(abs(x))
  value = if (largest == 0) 0 else largest * sqrt(sum((x / largest)^2))
  if (!is.finite(value)) stop("Shooting norm overflow.")
  value
}

shoot_periodic_orbit = function(model, state, period, free_components = character(),
    vary_period = FALSE, period_bounds = period * c(0.5, 1.5), steps = 1000L,
    position_scale = 1, velocity_scale = 1, tolerance = 1e-7,
    max_iterations = 20L, jacobian_step = 1e-5, damping = 1e-8,
    trust_radius = 0.1, max_backtracks = 12L, max_evaluations = 1000L) {
  model = cd_validate_model(model)
  cd_validate_state(state, model, cd_model_definitions()[[model$id]])
  for (name in c("period", "position_scale", "velocity_scale", "tolerance",
      "jacobian_step", "damping", "trust_radius")) cd_model_scalar(get(name), name)
  integer_control = function(x, name, low, high) {
    cd_model_scalar(x, name, positive = FALSE)
    if (x != round(x) || x < low || x > high) stop(name, " must be an integer from ", low, " to ", high, ".")
  }
  integer_control(steps, "steps", 4, 100000)
  integer_control(max_iterations, "max_iterations", 0, 100)
  integer_control(max_backtracks, "max_backtracks", 0, 30)
  integer_control(max_evaluations, "max_evaluations", 2, 10000)
  if (!is.logical(vary_period) || length(vary_period) != 1 || is.na(vary_period))
    stop("vary_period must be TRUE or FALSE.")
  if (!is.numeric(period_bounds) || is.complex(period_bounds) || length(period_bounds) != 2 ||
      !is.null(dim(period_bounds)) || any(!is.finite(period_bounds)) ||
      period_bounds[1] <= 0 || period_bounds[1] >= period_bounds[2] ||
      period < period_bounds[1] || period > period_bounds[2])
    stop("period_bounds must be increasing, positive and contain period.")
  labels = periodic_orbit_components(state)
  if (!is.character(free_components) || anyNA(free_components) || anyDuplicated(free_components) ||
      any(!free_components %in% labels)) stop("free_components must be unique names from periodic_orbit_components(state).")
  if (!length(free_components) && !vary_period) stop("Select free components or vary_period.")
  shape = dim(state$positions); size = length(state$positions)
  if ((2 * steps + 1) * size > 2000000 || shape[1] > 256 ||
      2 * steps * shape[1] * (shape[1] - 1) / 2 > 10000000)
    stop("Shooting exceeds the trajectory storage or pair-step budget.")
  scales = rep(c(position_scale, velocity_scale), each = size)
  original = c(state$positions, state$velocities)
  free = match(free_components, labels)
  unpack = function(x) list(positions = matrix(x[seq_len(size)], shape[1], shape[2]),
    velocities = matrix(x[size + seq_len(size)], shape[1], shape[2]))
  # Optimize scaled offsets from the supplied state; held entries are copied exactly.
  parameters = setNames(rep(0, length(free) + as.integer(vary_period)),
    c(free_components, if (vary_period) "period"))
  decode = function(z) {
    x = original
    x[free] = original[free] + z[seq_along(free)] * scales[free]
    list(state = unpack(x), period = if (vary_period) unname(period * (1 + z[length(z)])) else period)
  }
  evaluations = 0L
  evaluate = function(z, count = steps) {
    if (evaluations >= max_evaluations) return(list(ok = FALSE, message = "Integration evaluation budget exhausted.", budget = TRUE))
    candidate = decode(z)
    if (!is.finite(candidate$period) || candidate$period < period_bounds[1] || candidate$period > period_bounds[2])
      return(list(ok = FALSE, message = "Candidate outside period bounds.", budget = FALSE))
    evaluations <<- evaluations + 1L
    tryCatch({
      trajectory = integrate_dynamics(model, candidate$state, "RK4", candidate$period, candidate$period / count)
      end = length(trajectory$time)
      residual = setNames(c(trajectory$positions[end, , ], trajectory$velocities[end, , ]) -
        c(candidate$state$positions, candidate$state$velocities), labels)
      scaled = residual / scales
      list(ok = TRUE, trajectory = trajectory, residual = residual, scaled = scaled,
        norm = cd_shooting_norm(scaled), raw_norm = cd_shooting_norm(residual), message = "", budget = FALSE)
    }, error = function(e) list(ok = FALSE, message = conditionMessage(e), budget = FALSE))
  }
  history = list(); iterates = list()
  record = function(iteration, attempt, z, value, accepted, alpha = 0, step_norm = 0,
      rank = NA_integer_, condition = NA_real_) {
    history[[length(history) + 1L]] <<- data.frame(iteration = iteration, attempt = attempt,
      accepted = accepted, residual_norm = if (value$ok) value$norm else NA_real_,
      raw_residual_norm = if (value$ok) value$raw_norm else NA_real_, period = decode(z)$period,
      step_norm = step_norm, damping = damping, step_fraction = alpha,
      jacobian_rank = rank, jacobian_condition = condition, evaluations = evaluations,
      message = value$message)
    iterates[[length(iterates) + 1L]] <<- list(parameters = z, state = decode(z)$state,
      residual = if (value$ok) value$residual else NULL)
  }
  current = evaluate(parameters)
  record(0L, 0L, parameters, current, current$ok)
  status = if (current$ok) "max_iterations" else "integration_failed"
  message = if (current$ok) "Maximum correction iterations reached." else current$message
  iterations = 0L
  for (iteration in seq_len(max_iterations)) {
    if (!current$ok || current$norm <= tolerance) break
    iterations = iteration
    jacobian = matrix(0, length(labels), length(parameters))
    error = NULL
    for (j in seq_along(parameters)) {
      h = jacobian_step * max(1, abs(parameters[j]))
      plus = minus = parameters; plus[j] = plus[j] + h; minus[j] = minus[j] - h
      physical = function(z) {
        value = decode(z)
        if (j <= length(free)) c(value$state$positions, value$state$velocities)[free[j]] / scales[free[j]] else value$period / period
      }
      represented = (physical(plus) - physical(minus)) / (2 * h)
      if (!is.finite(represented) || abs(represented - 1) > 0.01) {
        error = "Finite-difference perturbation is not accurately representable; revise scales or jacobian_step."
        status = "jacobian_failed"; break
      }
      a = evaluate(plus); b = evaluate(minus)
      if (isTRUE(a$budget) || isTRUE(b$budget)) {
        error = "Integration evaluation budget exhausted."; status = "evaluation_limit"; break
      }
      # One-sided derivatives permit correction from a period boundary or near a collision.
      if (a$ok && b$ok) jacobian[, j] = (a$scaled - b$scaled) / (plus[j] - minus[j]) else
      if (a$ok) jacobian[, j] = (a$scaled - current$scaled) / (plus[j] - parameters[j]) else
      if (b$ok) jacobian[, j] = (current$scaled - b$scaled) / (parameters[j] - minus[j]) else {
        error = paste("Jacobian evaluation failed:", a$message, b$message)
        status = "jacobian_failed"; break
      }
    }
    if (!is.null(error)) { message = error; break }
    # Levenberg regularized Gauss-Newton using base R's LAPACK SVD. Avoid J'J.
    correction = tryCatch({
      decomposition = svd(jacobian)
      d = decomposition$d
      cutoff = max(d) * 1e-10
      keep = d > cutoff
      rank = sum(keep)
      condition = if (rank < length(parameters)) Inf else max(d) / min(d)
      weights = numeric(length(d))
      weights[keep] = 1 / (d[keep] + damping / d[keep])
      delta = -as.vector(decomposition$v %*% (weights * as.vector(crossprod(decomposition$u, current$scaled))))
      norm = cd_shooting_norm(delta)
      if (norm > trust_radius) delta = delta * (trust_radius / norm)
      list(delta = delta, rank = rank, condition = condition)
    }, error = identity)
    if (inherits(correction, "error")) {
      status = "jacobian_failed"; message = conditionMessage(correction); break
    }
    accepted = FALSE
    for (attempt in 0:max_backtracks) {
      alpha = 2^(-attempt)
      candidate = parameters + alpha * correction$delta
      trial = evaluate(candidate)
      accepted = trial$ok && trial$norm < current$norm
      record(iteration, attempt, candidate, trial, accepted, alpha,
        cd_shooting_norm(candidate - parameters), correction$rank, correction$condition)
      if (accepted) { parameters = candidate; current = trial; break }
      if (isTRUE(trial$budget)) break
    }
    if (!accepted) {
      status = if (isTRUE(trial$budget)) "evaluation_limit" else "stalled"
      message = if (isTRUE(trial$budget)) trial$message else "No decreasing step found within damping, trust and backtracking safeguards."
      break
    }
  }
  numerical_converged = current$ok && current$norm <= tolerance
  refinement = list(ok = FALSE, norm = NA_real_, message = "Not attempted: shooting tolerance not reached.")
  if (numerical_converged) {
    refinement = evaluate(parameters, 2 * steps)
    status = if (!refinement$ok) {
      if (isTRUE(refinement$budget)) "evaluation_limit" else "verification_failed"
    } else if (refinement$norm <= tolerance) "converged" else "discretization_limit"
    message = switch(status,
      converged = "Full return residual meets tolerance on both integration grids.",
      discretization_limit = "Shooting grid meets tolerance; half-timestep check does not. Increase steps.",
      refinement$message)
  }
  corrected = decode(parameters)
  structure(list(status = status, message = message, converged = identical(status, "converged"),
    numerical_converged = numerical_converged, iterations = iterations, evaluations = evaluations,
    initial_state = state, initial_period = period, corrected_state = corrected$state,
    period = corrected$period, residual = if (current$ok) current$residual else setNames(rep(NA_real_, length(labels)), labels),
    residual_norm = if (current$ok) current$norm else NA_real_,
    raw_residual_norm = if (current$ok) current$raw_norm else NA_real_,
    trajectory = if (current$ok) current$trajectory else NULL,
    history = do.call(rbind, history), iterates = iterates,
    verification = list(status = if (refinement$ok) "completed" else "unavailable",
      residual_norm = if (refinement$ok) refinement$norm else NA_real_,
      residual = refinement$residual, message = refinement$message, steps = 2 * steps),
    model = model, settings = list(free_components = free_components, vary_period = vary_period,
      period_bounds = period_bounds, steps = steps, position_scale = position_scale,
      velocity_scale = velocity_scale, tolerance = tolerance, max_iterations = max_iterations,
      jacobian_step = jacobian_step, damping = damping, trust_radius = trust_radius,
      max_backtracks = max_backtracks, max_evaluations = max_evaluations),
    metadata = list(experimental = TRUE, algorithm = "Damped SVD Gauss-Newton single shooting",
      integrator = "RK4", residual = "All position and velocity components; Euclidean norm after scaling",
      limitations = c("Local correction only; no claim of discovery, stability, uniqueness or exact periodicity.",
        "Autonomous phase, translation and other symmetries can make the Jacobian rank deficient; hold suitable components fixed.",
        "No phase condition, continuation, collision regularization or multiple shooting.",
        "Finite differences and fixed-step integration limit attainable accuracy; refinement is a check, not an error bound.",
        "Equilibria and repeated traversals also have zero return residual; minimal period is not determined."))),
    class = "periodic_orbit_search")
}
