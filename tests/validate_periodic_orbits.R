if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_periodic_orbits()
cd_source("R/systems/three_body/figure_8_initial_conditions.R")
local({
  expect_error = function(expr) stopifnot(inherits(tryCatch(force(expr), error = identity), "error"))
  seed = figure_8_initial_conditions()
  state = list(positions = do.call(rbind, seed$positions) / seed$position_scale,
    velocities = do.call(rbind, seed$velocities) / seed$velocity_scale)
  model = dynamical_model("newtonian_gravity", list(masses = rep(1, 3), G = 1))
  period = seed$period / seed$time_scale
  components = periodic_orbit_components(state)
  stopifnot(identical(components[c(1, 4, 7, 12)],
    c("position[1,1]", "position[1,2]", "velocity[1,1]", "velocity[3,2]")))
  perturbed = state; perturbed$velocities[1, 1] = perturbed$velocities[1, 1] + 1e-4
  original = perturbed
  solve = function(...) shoot_periodic_orbit(model, perturbed, period, components[7:12], ...)
  variable = shoot_periodic_orbit(model, perturbed, period * 1.0001, components[7:12], vary_period = TRUE)
  fixed = solve()
  for (result in list(variable, fixed)) {
    stopifnot(result$converged, result$status == "converged", result$iterations >= 1,
      result$residual_norm <= 1e-7, result$verification$residual_norm <= 1e-7,
      abs(result$period - period) < 1e-5,
      identical(result$corrected_state$positions, state$positions),
      identical(perturbed, original), identical(result$initial_state, original),
      all(diff(result$history$residual_norm[result$history$accepted]) < 0),
      length(result$iterates) == nrow(result$history),
      identical(result$trajectory$initial_state, result$corrected_state))
    end = length(result$trajectory$time)
    direct = c(result$trajectory$positions[end, , ], result$trajectory$velocities[end, , ]) -
      c(result$corrected_state$positions, result$corrected_state$velocities)
    stopifnot(max(abs(direct - result$residual)) == 0,
      abs(sqrt(sum(direct^2)) - result$residual_norm) < 1e-15)
  }
  stopifnot(identical(fixed$period, period))
  # Reintegrate independently: closure has a finite discretisation floor.
  verified = integrate_dynamics(model, variable$corrected_state, "RK4", variable$period, variable$period / 2000)
  error = c(verified$positions[2001, , ], verified$velocities[2001, , ]) -
    c(variable$corrected_state$positions, variable$corrected_state$velocities)
  stopifnot(abs(sqrt(sum(error^2)) - variable$verification$residual_norm) < 1e-15)
  coarse = solve(steps = 400, vary_period = TRUE)
  stopifnot(coarse$numerical_converged, !coarse$converged, coarse$status == "discretization_limit",
    coarse$verification$residual_norm > 1e-7)
  limited = solve(steps = 100, max_iterations = 0)
  stopifnot(!limited$converged, limited$status == "max_iterations", limited$iterations == 0,
    identical(limited$corrected_state, perturbed), nrow(limited$history) == 1)
  budget = solve(steps = 100, max_evaluations = 2)
  stopifnot(budget$status == "evaluation_limit", budget$evaluations == 2, !budget$converged)
  unresolved = solve(steps = 100, jacobian_step = 1e-300)
  stopifnot(unresolved$status == "jacobian_failed", !unresolved$converged,
    grepl("representable", unresolved$message), identical(unresolved$corrected_state, perturbed))
  trust = solve(steps = 100, max_iterations = 1, trust_radius = 1e-6)
  stopifnot(!trust$converged, all(trust$history$step_norm <= 1e-6 * (1 + 1e-12)))
  stalled = solve(steps = 100, damping = 1e300, max_backtracks = 2)
  stopifnot(stalled$status == "stalled", !stalled$converged,
    nrow(stalled$history) == 4, all(!stalled$history$accepted[-1]),
    identical(stalled$corrected_state, perturbed))
  collision = state; collision$positions[2, ] = collision$positions[1, ]
  failed = shoot_periodic_orbit(model, collision, period, components[7:12], steps = 100)
  stopifnot(failed$status == "integration_failed", !failed$converged,
    is.null(failed$trajectory), is.na(failed$residual_norm), grepl("collision", failed$message))
  # A second known periodic solution: circular equal-mass two-body orbit.
  circular = list(positions = rbind(c(-0.5, 0), c(0.5, 0)),
    velocities = rbind(c(0, -sqrt(0.5)), c(0, sqrt(0.5))))
  circular_model = dynamical_model("newtonian_gravity", list(masses = c(1, 1), G = 1))
  exact_period = 2 * pi / sqrt(2)
  orbit = shoot_periodic_orbit(circular_model, circular, exact_period * 1.0001,
    vary_period = TRUE, steps = 500)
  stopifnot(orbit$converged, identical(orbit$corrected_state, circular),
    abs(orbit$period - exact_period) < 1e-6)
  unchecked = shoot_periodic_orbit(circular_model, circular, exact_period * 1.0001,
    vary_period = TRUE, steps = 500, max_evaluations = 4)
  stopifnot(unchecked$numerical_converged, !unchecked$converged,
    unchecked$status == "evaluation_limit", is.na(unchecked$verification$residual_norm))
  # More unknowns than residuals: rank deficiency is handled without a singular solve.
  symmetric = shoot_periodic_orbit(circular_model, circular, exact_period * 1.0001,
    periodic_orbit_components(circular), vary_period = TRUE, steps = 500, max_iterations = 1)
  stopifnot(all(is.infinite(symmetric$history$jacobian_condition[-1])),
    all(symmetric$history$jacobian_rank[-1] < 9), is.finite(symmetric$residual_norm))
  # Bounds permit one-sided differencing and never permit a zero-period solution.
  bounded = shoot_periodic_orbit(circular_model, circular, exact_period * 1.0001,
    vary_period = TRUE, steps = 500, period_bounds = c(exact_period * 0.99, exact_period * 1.0001))
  stopifnot(bounded$converged, bounded$period >= bounded$settings$period_bounds[1],
    bounded$period <= bounded$settings$period_bounds[2])
  # Unit changes preserve the scaled objective and correction.
  unit_state = circular
  unit_state$positions = circular$positions * 10
  unit_state$velocities = circular$velocities * 10
  unit_model = dynamical_model("newtonian_gravity", list(masses = c(1, 1), G = 1000))
  scaled = shoot_periodic_orbit(unit_model, unit_state, exact_period * 1.0001,
    vary_period = TRUE, steps = 500, position_scale = 10, velocity_scale = 10)
  stopifnot(scaled$converged, abs(scaled$period - orbit$period) < 1e-12,
    abs(scaled$residual_norm - orbit$residual_norm) < 1e-12)
  for (control in c("period", "position_scale", "velocity_scale", "tolerance", "jacobian_step", "damping", "trust_radius")) {
    args = list(model = model, state = state, period = period, free_components = components[7:12])
    for (value in list(0, NA_real_, Inf, "invalid", 1i)) {
      args[[control]] = value; expect_error(do.call(shoot_periodic_orbit, args))
    }
  }
  expect_error(solve(steps = 3)); expect_error(solve(steps = 1.5))
  expect_error(solve(max_iterations = -1)); expect_error(solve(max_backtracks = 31))
  expect_error(solve(max_evaluations = 1)); expect_error(solve(vary_period = NA))
  expect_error(solve(period_bounds = c(0, period)))
  expect_error(shoot_periodic_orbit(model, state, period))
  for (free in list("bogus", c(components[1], components[1]), NA_character_, 1))
    expect_error(shoot_periodic_orbit(model, state, period, free))
  cat(sprintf("Figure-eight: initial %.4g, shooting %.4g, refined %.4g, period %.10f (%d iterations).\n",
    variable$history$residual_norm[1], variable$residual_norm, variable$verification$residual_norm,
    variable$period, variable$iterations))
  cat(sprintf("Coarse figure-eight: shooting %.4g, refined %.4g, status %s.\n",
    coarse$residual_norm, coarse$verification$residual_norm, coarse$status))
})
cat("Experimental periodic-orbit correction, known solutions, safeguards and failure checks passed.\n")
