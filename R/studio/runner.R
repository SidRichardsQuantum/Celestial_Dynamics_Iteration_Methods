# Thin adapters: original solver functions and return values remain unchanged.
simulation_dynamics = function(request, gravitational_constant = G) {
  request = studio_validate_request(request)
  p = request$parameters
  if (request$system %in% c("two_body", "three_body", "n_body")) {
    model = dynamical_model("newtonian_gravity", list(masses = p$masses, G = gravitational_constant))
    state = list(positions = p$positions, velocities = p$velocities)
  } else if (request$system == "restricted_three_body") {
    model = dynamical_model("cr3bp_rotating", list(mu = p$mu))
    state = list(positions = matrix(p$state0[1:3], 1, 3), velocities = matrix(p$state0[4:6], 1, 3))
  } else if (request$system == "sitnikov") {
    model = dynamical_model("sitnikov_circular", list(primary_mass = p$primary_mass,
      primary_radius = p$primary_radius, G = gravitational_constant))
    state = list(positions = matrix(p$z0, 1, 1), velocities = matrix(p$vz0, 1, 1))
  } else stop("No dynamical model adapter for this system.")
  list(model = model, state = state, integrator = request$integrator,
    duration = request$duration, timestep = request$timestep)
}

studio_legacy_arguments = function(request) {
  p = request$parameters
  args = list(T = request$duration, N = round(request$duration / request$timestep))
  for (i in seq_along(p$masses)) {
    body = letters[i]
    args[[paste0("m_", body)]] = p$masses[i]
    for (axis in 1:2) {
      suffix = paste0(body, c("x", "y")[axis], "0")
      args[[paste0("r_", suffix)]] = p$positions[i, axis]
      args[[paste0("v_", suffix)]] = p$velocities[i, axis]
    }
  }
  args
}

studio_normalize_legacy = function(raw, request) {
  p = request$parameters
  positions = velocities = array(0, c(length(raw$x_a), length(p$masses), 2))
  for (i in seq_along(p$masses)) {
    for (axis in 1:2) {
      suffix = paste0(c("x", "y")[axis], "_", letters[i])
      positions[, i, axis] = raw[[suffix]]
      velocities[, i, axis] = raw[[paste0("v", suffix)]]
    }
  }
  list(positions = positions, velocities = velocities, masses = p$masses,
       body_names = paste("Body", seq_along(p$masses)), raw = raw)
}

studio_solve_two_body = function(request) {
  method = two_body_method_registry()[[request$integrator]]$func
  studio_normalize_legacy(do.call(method, studio_legacy_arguments(request)), request)
}

studio_solve_three_body = function(request) {
  studio_normalize_legacy(do.call(runge_kutta_three_body,
                                   studio_legacy_arguments(request)), request)
}

studio_solve_n_body = function(request) {
  method = switch(request$integrator, RK4 = runge_kutta_n_body,
                  Verlet = velocity_verlet_n_body)
  raw = do.call(method, c(list(T = request$duration,
                              N = round(request$duration / request$timestep)), request$parameters))
  list(positions = raw$positions, velocities = raw$velocities,
       masses = raw$masses, body_names = raw$body_names, raw = raw)
}

studio_solve_cr3bp = function(request) {
  raw = do.call(cr3bp_runge_kutta, c(list(T = request$duration,
                 N = round(request$duration / request$timestep)), request$parameters[c("mu", "state0")]))
  list(positions = array(raw$states[, 1:3], c(length(raw$t), 1, 3)),
       velocities = array(raw$states[, 4:6], c(length(raw$t), 1, 3)),
       masses = NULL, body_names = "Test particle", raw = raw)
}

studio_solve_sitnikov = function(request) {
  p = request$parameters
  raw = do.call(sitnikov_runge_kutta, c(list(T = request$duration,
                 N = round(request$duration / request$timestep)), p))
  positions = velocities = array(0, c(length(raw$t), 3, 3))
  positions[, 1, ] = raw$primary_a
  positions[, 2, ] = raw$primary_b
  positions[, 3, ] = raw$third
  omega = sqrt(G * p$primary_mass / (4 * p$primary_radius^3))
  for (i in 1:2) {
    velocities[, i, 1] = -omega * positions[, i, 2]
    velocities[, i, 2] = omega * positions[, i, 1]
  }
  velocities[, 3, 3] = raw$vz
  list(positions = positions, velocities = velocities, masses = NULL,
       body_names = c("Primary 1", "Primary 2", "Test particle"), raw = raw)
}

run_simulation = function(request, progress = function(stage) invisible(NULL)) {
  progress("validating")
  request = studio_validate_request(request)
  spec = studio_catalog()[[request$system]]
  id = studio_run_id()
  started_at = studio_run_timestamp()
  progress("integrating")
  start = proc.time()[["elapsed"]]
  invisible(capture.output(trajectory <- spec$adapter(request)))
  elapsed = proc.time()[["elapsed"]] - start
  if (any(!is.finite(trajectory$positions)) || any(!is.finite(trajectory$velocities))) {
    stop("Solver produced non-finite states; shorten the timestep or check for collisions.")
  }
  result = structure(c(list(request = request,
    time = seq(0, request$duration, length.out = dim(trajectory$positions)[1]),
    units = spec$units, runtime_seconds = elapsed,
    provenance = studio_run_provenance()), trajectory),
    class = "simulation_result")
  progress("computing diagnostics")
  result$model = studio_run_model(request, result$provenance$G)
  # All current adapters complete exactly N fixed steps. Force/RHS evaluations
  # are not instrumented; do not infer counts from the integrator's name.
  result$solver_statistics = list(step_count = round(request$duration / request$timestep),
                                  force_evaluation_count = NA_real_)
  report = simulation_diagnostics(result)
  result$diagnostics = report$series
  result$diagnostic_registry = report$registry
  result$diagnostic_summary = studio_diagnostic_summary(result$diagnostics)
  result$schema_version = 2L
  result$id = id
  result$timestamp = studio_run_timestamp()
  result$timestamps = list(started_at = started_at, completed_at = result$timestamp)
  result$lineage = list(parent_run_id = NULL)
  studio_validate_result(result)
  result
}

compare_integrators = function(request, integrators, settings = list()) {
  requests = studio_integrator_requests(request, integrators, settings)
  setNames(lapply(requests, run_simulation), integrators)
}
