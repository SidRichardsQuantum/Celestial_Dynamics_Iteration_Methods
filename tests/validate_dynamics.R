if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
local({
  expect_error = function(expr) stopifnot(inherits(tryCatch(force(expr), error = identity), "error"))
  close = function(x, y) stopifnot(isTRUE(all.equal(x, y, tolerance = 1e-13)))
  # Frozen endpoint values from eight pre-refactor steps, encoded exactly in hex.
  # These prevent both the shared solver and its legacy wrapper drifting together.
  baseline = dget(cd_path("tests/fixtures/n_body_before_model.R"))
  for (name in names(baseline)) for (method in names(baseline[[name]])) {
    request = studio_preset(name)
    request$duration = 8 * request$timestep; request$integrator = method
    result = run_simulation(request)
    old = baseline[[name]][[method]]
    close(result$positions[9, , ], old$positions)
    close(result$velocities[9, , ], old$velocities)
    close(result$raw$energy_ratio, old$energy_ratio)
  }
  # Every catalogue preset and every currently supported integrator remains
  # available. The new interface reproduces integrated (not prescribed) states.
  count = 0L
  for (preset in studio_presets()) for (method in studio_catalog()[[preset$request$system]]$integrators) {
    request = preset$request; request$integrator = method
    request$duration = 8 * request$timestep
    legacy = run_simulation(request)
    problem = simulation_dynamics(request)
    trajectory = do.call(integrate_dynamics, problem)
    q = legacy$positions; v = legacy$velocities
    if (request$system == "sitnikov") {
      q = array(q[, 3, 3], dim(trajectory$positions))
      v = array(v[, 3, 3], dim(trajectory$velocities))
    }
    close(trajectory$positions, q); close(trajectory$velocities, v)
    stopifnot(identical(trajectory$model, problem$model))
    count = count + 1L
  }
  # Independently known Newtonian accelerations and mass-weighted momentum balance.
  model = dynamical_model("newtonian_gravity", list(masses = c(2, 3), G = 1))
  state = list(positions = rbind(c(0, 0), c(2, 0)), velocities = matrix(0, 2, 2))
  derivative = dynamics_derivative(model, 0, state)
  stopifnot(identical(derivative$positions, state$velocities))
  close(derivative$velocities, rbind(c(0.75, 0), c(-0.5, 0)))
  close(colSums(derivative$velocities * c(2, 3)), c(0, 0))
  # Explicit G belongs to the model and is independent of the global constant.
  twice = model; twice$parameters$G = 2
  close(dynamics_derivative(twice, 0, state)$velocities, 2 * derivative$velocities)
  three_dimensional = lapply(state, function(x) cbind(x, 0))
  close(dynamics_derivative(model, 0, three_dimensional)$velocities,
    cbind(derivative$velocities, 0))

  softened = dynamical_model("softened_gravity", list(masses = c(2, 3), G = 1, softening = 0.5))
  expected = rbind(c(6 / 4.25^1.5, 0), c(-4 / 4.25^1.5, 0))
  close(dynamics_derivative(softened, 0, state)$velocities, expected)
  overlap = state; overlap$positions[,] = 0
  expect_error(dynamics_derivative(model, 0, overlap))
  close(dynamics_derivative(softened, 0, overlap)$velocities, matrix(0, 2, 2))
  for (method in c("Euler", "Midpoint", "Heun", "RK4", "Verlet")) {
    result = integrate_dynamics(softened, state, method, 0.1, 0.01)
    stopifnot(all(is.finite(result$positions)), identical(dim(result$positions), c(11L, 2L, 2L)))
  }
  restricted = simulation_dynamics(studio_preset("earth_moon_trojan"))
  restricted$integrator = "Verlet"
  expect_error(do.call(integrate_dynamics, restricted))

  # Plain descriptors/configurations survive normal R and JSON serialization.
  tmp = tempfile(); on.exit(unlink(tmp))
  problem = simulation_dynamics(studio_preset("rotating_square"))
  problem$duration = 8 * problem$timestep
  saveRDS(problem, tmp)
  stopifnot(identical(readRDS(tmp), problem))
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    decoded = jsonlite::fromJSON(jsonlite::toJSON(problem, auto_unbox = TRUE, digits = NA))
    close(do.call(integrate_dynamics, decoded)$positions, do.call(integrate_dynamics, problem)$positions)
  }
  for (id in list("missing", NA_character_, c("newtonian_gravity", "softened_gravity")))
    expect_error(dynamical_model(id))
  for (parameters in list(list(), list(masses = c(1, -1)), list(masses = c(1, NA)),
      list(masses = c(1, 2), G = 0), list(masses = c(1, 2), unknown = 1),
      list(masses = c(1, 2), masses = c(2, 3)))) expect_error(dynamical_model("newtonian_gravity", parameters))
  expect_error(dynamical_model("softened_gravity", list(masses = c(1, 2), softening = -1)))
  expect_error(dynamical_model("cr3bp_rotating", list(mu = 0.6)))
  bad = model; bad$version = 2; expect_error(dynamics_derivative(bad, 0, state))
  bad = model; bad$parameters$G = NULL; expect_error(dynamics_derivative(bad, 0, state))
  bad = state; bad$positions[1, 1] = Inf; expect_error(dynamics_derivative(model, 0, bad))
  bad = state; bad$velocities = matrix(0, 3, 2); expect_error(dynamics_derivative(model, 0, bad))
  expect_error(dynamics_derivative(model, NA_real_, state))
  expect_error(dynamics_derivative(model, 1 + 1i, state))
  expect_error(integrate_dynamics(model, state, "bad", 1, 0.1))
  expect_error(integrate_dynamics(model, state, "RK4", 1, 0.3))
  expect_error(integrate_dynamics(model, state, "RK4", -1, 0.1))
  expect_error(integrate_dynamics(model, state, "RK4", 1, 0))

  # A test-only nonautonomous model demonstrates the definition extension point
  # and catches using the wrong time at RK stages without changing the solver.
  scope = new.env(parent = environment(integrate_dynamics))
  scope$cd_model_definitions = function() {
    definitions = cd_model_definitions()
    definitions$uniform_time_force = list(defaults = list(), required = character(),
      validate = function(p) invisible(TRUE), shape = function(p) list(bodies = 1L, dimensions = 1L),
      acceleration = function(time, positions, velocities, parameters) matrix(time, 1, 1),
      velocity_independent = TRUE)
    definitions
  }
  for (name in c("dynamical_model", "cd_validate_model", "integrate_dynamics")) {
    fn = get(name); environment(fn) = scope; scope[[name]] = fn
  }
  custom = scope$dynamical_model("uniform_time_force")
  initial = list(positions = matrix(0, 1, 1), velocities = matrix(0, 1, 1))
  result = scope$integrate_dynamics(custom, initial, "RK4", 2, 0.2)
  close(as.numeric(result$positions), result$time^3 / 6)
  close(as.numeric(result$velocities), result$time^2 / 2)
  cat(count, "catalogue/method combinations agree with the dynamical interface.\n")
})
cat("Model validation, serialization, force laws, shared integrators and legacy baselines passed.\n")
