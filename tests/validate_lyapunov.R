if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
local({
  expect_error = function(expr, pattern = NULL) {
    error = tryCatch(force(expr), error = identity)
    stopifnot(inherits(error, "error"))
    if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(error), fixed = TRUE))
  }
  near = function(x, y, tolerance = 1e-8) stopifnot(max(abs(x - y)) < tolerance)
  # Test-only analytic models exercise the real solver and analysis together.
  scope = new.env(parent = environment(run_lyapunov_analysis))
  scope$cd_model_definitions = function() {
    definitions = cd_model_definitions()
    for (id in c("unstable", "oscillator", "free", "time_force")) {
      acceleration = switch(id,
        unstable = function(time, positions, velocities, parameters) positions,
        oscillator = function(time, positions, velocities, parameters) -positions,
        free = function(time, positions, velocities, parameters) positions * 0,
        time_force = function(time, positions, velocities, parameters) matrix(time, 1, 1))
      definitions[[id]] = list(defaults = list(), required = character(),
        validate = function(p) invisible(TRUE), shape = function(p) list(bodies = 1L, dimensions = 1L),
        acceleration = acceleration, velocity_independent = TRUE, frame = "test", units = "normalized")
    }
    definitions
  }
  for (name in c("dynamical_model", "cd_validate_model", "integrate_dynamics",
      "cd_sensitivity_problem", "run_lyapunov_analysis")) {
    fn = get(name); environment(fn) = scope; scope[[name]] = fn
  }
  problem = function(id, duration = 2, timestep = 0.01) list(model = scope$dynamical_model(id),
    state = list(positions = matrix(0, 1, 1), velocities = matrix(0, 1, 1)),
    integrator = "RK4", duration = duration, timestep = timestep)
  analyze = scope$run_lyapunov_analysis
  growing = analyze(problem("unstable"), direction = c(1, 1), renormalisation_interval = 0.3)
  shrinking = analyze(problem("unstable"), direction = c(1, -1), renormalisation_interval = 0.3)
  near(growing$finite_time_exponent, 1)
  near(shrinking$finite_time_exponent, -1)
  near(growing$series$log_separation_growth, growing$series$time)
  stopifnot(is.na(growing$series$finite_time_exponent[1]),
    !growing$metadata$asymptotic, !growing$metadata$maximized_over_directions,
    identical(growing, analyze(problem("unstable"), direction = c(1, 1), renormalisation_interval = 0.3)))
  h = growing$renormalisation_history
  near(tail(h$end_time, 1) - tail(h$start_time, 1), 0.2)
  near(sum(h$log_growth) / 2, growing$finite_time_exponent)
  near(h$reset_separation[h$renormalised], growing$epsilon, 1e-20)
  stopifnot(!tail(h$renormalised, 1), is.na(tail(h$reset_separation, 1)))
  # Neutral rotation and algebraic shear have independently known finite-time growth.
  neutral = analyze(problem("oscillator", 10), direction = c(1, 2), renormalisation_interval = 0.5)
  near(neutral$finite_time_exponent, 0)
  free = analyze(problem("free"), component = "velocity[1,1]", renormalisation_interval = 0.3)
  near(free$finite_time_exponent, log(sqrt(5)) / 2)
  scaled = analyze(problem("free"), component = "velocity[1,1]", renormalisation_interval = 0.3,
    position_scale = 2, velocity_scale = 3)
  near(scaled$finite_time_exponent, log(sqrt(10)) / 2)
  # Growth and decay spanning more than exp(800) never exponentiate cumulative logs.
  for (sign in c(-1, 1)) {
    long = analyze(problem("unstable", 800, 0.1), epsilon = 1e-250,
      direction = c(1, sign), renormalisation_interval = 1)
    near(long$finite_time_exponent, sign, 1e-6)
    stopifnot(all(is.finite(long$series$log_separation_growth)), all(long$series$separation > 0),
      max(long$series$separation) < 1e-249)
  }
  # Absolute stage time must survive every restart (q=t^3/6, v=t^2/2).
  timed = analyze(problem("time_force"), renormalisation_interval = 0.3, epsilon = 1e-5)
  near(as.numeric(timed$base$positions), timed$series$time^3 / 6)
  near(as.numeric(timed$base$velocities), timed$series$time^2 / 2)
  near(timed$finite_time_exponent, 0)
  # No resets: compare against direct integration of the original two trajectories.
  direct_problem = problem("unstable")
  single = analyze(direct_problem, direction = c(1, 1), renormalisation_interval = 2)
  direct_problem$state = single$perturbed$initial_state
  direct = do.call(scope$integrate_dynamics, direct_problem)
  near(as.numeric(direct$positions), as.numeric(single$perturbed$positions), 1e-20)
  near(single$finite_time_exponent, growing$finite_time_exponent)
  # Refining the timestep reduces the known RK4 exponential growth error.
  coarse = analyze(problem("unstable", 2, 0.2), direction = c(1, 1), renormalisation_interval = 0.4)
  fine = analyze(problem("unstable", 2, 0.1), direction = c(1, 1), renormalisation_interval = 0.4)
  stopifnot(abs(fine$finite_time_exponent - 1) < abs(coarse$finite_time_exponent - 1) / 10)
  for (method in c("Euler", "Midpoint", "Heun", "RK4", "Verlet")) {
    inertial = problem("free"); inertial$integrator = method
    result = analyze(inertial, component = "velocity[1,1]", renormalisation_interval = 0.3)
    near(result$finite_time_exponent, log(sqrt(5)) / 2)
  }
  # Epsilon, direction, grids and precision failures are errors, not fake rates.
  for (epsilon in list(0, -1, NA_real_, Inf, numeric(), c(1, 2), "small", 1i))
    expect_error(analyze(problem("free"), epsilon = epsilon))
  for (direction in list(c(0, 0), c(NA, 1), c(1, Inf), 1, c(1, 2, 3), matrix(1, 1, 2)))
    expect_error(analyze(problem("free"), direction = direction))
  for (interval in c(0, -1, 0.015, 3, Inf))
    expect_error(analyze(problem("free"), renormalisation_interval = interval))
  for (total in c(0, -1, 0.005, 0.015, Inf)) expect_error(analyze(problem("free"), total_time = total))
  expect_error(analyze(problem("free"), position_scale = 0))
  expect_error(analyze(problem("free"), velocity_scale = Inf))
  expect_error(analyze(problem("free"), component = "position[2,1]"))
  expect_error(analyze(problem("free"), direction = c(1, 1), component = "position[1,1]"))
  unresolved = problem("free"); unresolved$state$positions[1, 1] = 1e16
  expect_error(analyze(unresolved, epsilon = 1e-10), "representable")
  # Euler with h=1 maps this stable eigenvector exactly to zero.
  collapse = problem("unstable", 2, 1); collapse$integrator = "Euler"
  expect_error(analyze(collapse, direction = c(1, -1)), "indistinguishable")
  overflow = problem("unstable", 1e200, 1e200)
  expect_error(analyze(overflow, direction = c(1, 1)), "Sensitivity interval")
  # Catalogue integration and all supported dimensions; input requests stay unchanged.
  for (name in c("circular_two_body", "figure_eight", "rotating_square", "earth_moon_trojan", "sitnikov")) {
    request = studio_preset(name); request$duration = request$timestep * 12
    original = request; defaults = studio_lyapunov_defaults(request)
    result = run_lyapunov_analysis(request, position_scale = defaults$position_scale,
      velocity_scale = defaults$velocity_scale, renormalisation_interval = request$timestep * 5)
    stopifnot(identical(request, original), is.finite(result$finite_time_exponent))
    trajectory = do.call(integrate_dynamics, simulation_dynamics(request))
    near(as.numeric(result$base$positions) / defaults$position_scale,
      as.numeric(trajectory$positions) / defaults$position_scale)
    path = tempfile(fileext = ".pdf")
    grDevices::pdf(path)
    for (view in c("separation", "log", "trajectories")) studio_plot_lyapunov(result, view)
    grDevices::dev.off()
    stopifnot(file.info(path)$size > 1000); unlink(path)
  }
  saved = tempfile(); saveRDS(growing, saved)
  stopifnot(identical(readRDS(saved), growing)); unlink(saved)
})
cat("Finite-time Lyapunov analytic, precision, renormalisation, model and plot checks passed.\n")
