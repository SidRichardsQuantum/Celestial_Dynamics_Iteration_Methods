# Nearby-trajectory finite-time analysis. No dependency on Shiny or plotting.
cd_sensitivity_norm = function(x) {
  if (any(!is.finite(x))) stop("Nonfinite separation; shorten the renormalisation interval or timestep.")
  largest = max(abs(x))
  if (largest == 0) return(0)
  value = largest * sqrt(sum((x / largest)^2))
  if (!is.finite(value)) stop("Separation overflow; shorten the renormalisation interval.")
  value
}

cd_sensitivity_problem = function(experiment, total_time = NULL) {
  if (inherits(experiment, "simulation_request")) {
    request = experiment
    if (!is.null(total_time)) request$duration = total_time
    problem = simulation_dynamics(request)
  } else {
    required = c("model", "state", "integrator", "duration", "timestep")
    if (!is.list(experiment) || !setequal(names(experiment), required) || length(experiment) != 5L)
      stop("experiment must be a simulation_request or a simulation_dynamics problem list.")
    problem = experiment
    if (!is.null(total_time)) problem$duration = total_time
  }
  problem$model = cd_validate_model(problem$model)
  cd_validate_state(problem$state, problem$model, cd_model_definitions()[[problem$model$id]])
  cd_model_scalar(problem$duration, "total_time")
  cd_model_scalar(problem$timestep, "timestep")
  problem
}

cd_sensitivity_components = function(state) {
  shape = dim(state$positions)
  unlist(lapply(c("position", "velocity"), function(kind)
    unlist(lapply(seq_len(shape[2]), function(axis)
      paste0(kind, "[", seq_len(shape[1]), ",", axis, "]")), use.names = FALSE)), use.names = FALSE)
}

# Direction is expressed in scaled phase-space coordinates, not physical units.
run_lyapunov_analysis = function(experiment, epsilon = 1e-7, direction = NULL,
    component = NULL, renormalisation_interval = NULL, total_time = NULL,
    position_scale = 1, velocity_scale = 1) {
  cd_model_scalar(epsilon, "epsilon")
  cd_model_scalar(position_scale, "position_scale")
  cd_model_scalar(velocity_scale, "velocity_scale")
  problem = cd_sensitivity_problem(experiment, total_time)
  duration = problem$duration; dt = problem$timestep
  steps = duration / dt
  if (!is.finite(steps) || steps < 1 || steps > 100000 ||
      abs(steps - round(steps)) > 1e-9 * max(1, steps))
    stop("total_time / timestep must be an integer from 1 to 100000.")
  steps = round(steps); dt = duration / steps
  if (is.null(renormalisation_interval)) renormalisation_interval = min(10, steps) * dt
  cd_model_scalar(renormalisation_interval, "renormalisation_interval")
  interval_steps = renormalisation_interval / dt
  if (!is.finite(interval_steps) || interval_steps < 1 || interval_steps > steps ||
      abs(interval_steps - round(interval_steps)) > 1e-9 * max(1, interval_steps))
    stop("renormalisation_interval must be an integer multiple of timestep, no longer than total_time.")
  interval_steps = round(interval_steps)
  state = problem$state; shape = dim(state$positions); size = length(state$positions)
  if ((steps + 1) * size > 2000000 || shape[1] > 256 ||
      steps * shape[1] * (shape[1] - 1) / 2 > 10000000)
    stop("Sensitivity analysis exceeds the step, state storage or pair-step budget.")
  labels = cd_sensitivity_components(state)
  scales = rep(c(position_scale, velocity_scale), each = size)
  pack = function(state) c(state$positions, state$velocities)
  unpack = function(x) list(positions = matrix(x[seq_len(size)], shape[1], shape[2]),
    velocities = matrix(x[size + seq_len(size)], shape[1], shape[2]))
  if (!is.null(direction) && !is.null(component)) stop("Choose direction or component, not both.")
  if (is.null(direction)) {
    if (is.null(component)) component = labels[1]
    if (!is.character(component) || length(component) != 1L || is.na(component) || !component %in% labels)
      stop("component must be one of: ", paste(labels, collapse = ", "))
    direction = as.numeric(labels == component)
  }
  if (!is.numeric(direction) || is.complex(direction) || !is.null(dim(direction)) ||
      length(direction) != length(labels) || any(!is.finite(direction)) || !any(direction != 0))
    stop("direction must be a finite nonzero vector with one entry per phase-space component.")
  # First rescale by the largest entry so even very large directions normalize safely.
  direction = direction / max(abs(direction))
  direction = direction / cd_sensitivity_norm(direction)
  perturb = function(base, unit_direction) {
    offset = (epsilon * unit_direction) * scales
    other = base + offset
    actual = (other - base) / scales
    distance = cd_sensitivity_norm(actual)
    if (distance == 0 || cd_sensitivity_norm(actual / epsilon - unit_direction) > 0.01)
      stop("epsilon is not accurately representable at this state and scale (over 1% perturbation error); increase epsilon or revise scales.")
    list(state = unpack(other), separation = distance)
  }
  reset = perturb(pack(state), direction)
  initial_perturbed = reset$state; initial_separation = reset$separation
  other = initial_perturbed
  separation = numeric(steps + 1); separation[1] = initial_separation
  growth = numeric(steps + 1)
  base_q = base_v = other_q = other_v = array(0, c(steps + 1, shape))
  base_q[1, , ] = state$positions; base_v[1, , ] = state$velocities
  other_q[1, , ] = other$positions; other_v[1, , ] = other$velocities
  starts = seq(0, steps - 1, by = interval_steps)
  history = vector("list", length(starts)); restart_states = vector("list", length(starts))
  accumulated = 0
  for (segment in seq_along(starts)) {
    start = starts[segment]; end = min(start + interval_steps, steps)
    segment_time = (end - start) * dt
    solve = function(s) integrate_dynamics(problem$model, s, problem$integrator,
      segment_time, dt, start_time = start * dt)
    # A failure is explicit: never substitute a floor or invent an exponent.
    trajectories = tryCatch(list(base = solve(state), perturbed = solve(other)),
      error = function(e) stop("Sensitivity interval starting at t=", start * dt, ": ",
        conditionMessage(e), " Try a smaller timestep or renormalisation interval.", call. = FALSE))
    b = trajectories$base; p = trajectories$perturbed
    rows = (start + 2):(end + 1); local_rows = 2:length(b$time)
    base_q[rows, , ] = b$positions[local_rows, , ]; base_v[rows, , ] = b$velocities[local_rows, , ]
    other_q[rows, , ] = p$positions[local_rows, , ]; other_v[rows, , ] = p$velocities[local_rows, , ]
    start_distance = reset$separation
    for (j in seq_along(rows)) {
      k = local_rows[j]
      delta = c((p$positions[k, , ] - b$positions[k, , ]) / position_scale,
        (p$velocities[k, , ] - b$velocities[k, , ]) / velocity_scale)
      distance = cd_sensitivity_norm(delta)
      if (distance == 0) stop("Nearby trajectories became indistinguishable at t=", b$time[k],
        "; increase epsilon or shorten the renormalisation interval.")
      separation[rows[j]] = distance
      growth[rows[j]] = accumulated + log(distance) - log(start_distance)
    }
    increment = log(distance) - log(start_distance)
    accumulated = accumulated + increment
    state = unpack(c(b$positions[length(b$time), , ], b$velocities[length(b$time), , ]))
    did_reset = end < steps
    after = NA_real_
    if (did_reset) {
      reset = perturb(pack(state), delta / distance)
      other = reset$state; after = reset$separation
      restart_states[[segment]] = other
    }
    history[[segment]] = data.frame(start_time = start * dt, end_time = end * dt,
      start_step = start, end_step = end, start_separation = start_distance,
      end_separation = distance, log_growth = increment, cumulative_log_growth = accumulated,
      renormalised = did_reset, reset_separation = after)
  }
  time = seq(0, duration, length.out = steps + 1)
  series = data.frame(time = time, separation = separation,
    log_separation = log(separation), log_separation_growth = growth,
    cumulative_log_separation = log(initial_separation) + growth,
    finite_time_exponent = c(NA_real_, growth[-1] / time[-1]))
  structure(list(experiment = experiment, problem = problem, epsilon = epsilon,
    direction = setNames(direction, labels), initial_separation = initial_separation,
    series = series, finite_time_exponent = accumulated / duration,
    renormalisation_history = do.call(rbind, history), restart_states = restart_states,
    base = list(time = time, positions = base_q, velocities = base_v, initial_state = problem$state),
    perturbed = list(time = time, positions = other_q, velocities = other_v, initial_state = initial_perturbed),
    metadata = list(algorithm = "Two nearby trajectories with periodic renormalisation",
      version = 1L, estimate = "Finite-time directional estimate targeting the maximum Lyapunov exponent",
      asymptotic = FALSE, maximized_over_directions = FALSE,
      norm = "Euclidean norm of (delta position / position_scale, delta velocity / velocity_scale)",
      position_scale = position_scale, velocity_scale = velocity_scale,
      components = labels, integrator = problem$integrator, timestep = dt,
      total_time = duration, renormalisation_interval = interval_steps * dt,
      frame = cd_model_definitions()[[problem$model$id]]$frame,
      units = cd_model_definitions()[[problem$model$id]]$units,
      exponent_units = "inverse model time unit", transient_discarded = 0,
      trajectory_sampling = "Pre-reset endpoints; perturbed trajectory restarts are stored separately",
      limitations = c("Depends on direction, scales, epsilon, timestep, interval and duration.",
        "No guarantee of dominant-direction alignment or an infinitesimal perturbation.",
        "Not a true asymptotic exponent or a chaos classification."))),
    class = "lyapunov_analysis")
}
