if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
local({
  fail = function(expr) stopifnot(inherits(tryCatch(force(expr), error = identity), "error"))
  # Endpoints captured before the shared-engine migration. The direct primary
  # subtraction fixes exact-collision detection, allowing only roundoff changes.
  baseline = dget(cd_path("tests/fixtures/cr3bp_before_model.R"))
  for (name in names(baseline)) {
    request = studio_preset(name); request$duration = 8 * request$timestep
    result = run_simulation(request)
    actual = result$raw$states[9, ]
    expected = baseline[[name]]
    # These states are nondimensional. Bound each component's absolute error:
    # all.equal's default relative scale uses only unequal entries, so tiny
    # velocities can turn platform roundoff into a spurious baseline failure.
    stopifnot(identical(names(actual), names(expected)), all(is.finite(actual)))
    error = max(abs(actual - expected))
    if (error > 1e-13)
      stop(sprintf("CR3BP baseline %s: maximum absolute error %.17g exceeds 1e-13.", name, error))
  }
  ratios = cr3bp_mass_parameters()
  stopifnot(is.null(names(cr3bp_initial_state(ratios["earth_moon"]))))
  stopifnot(abs(ratios["earth_moon"] - 0.01215) < 1e-5,
    abs(ratios["sun_earth"] - 3.003e-6) < 1e-9)
  for (mu in c(1e-12, 1e-8, ratios, 0.1, 0.499999, 0.5)) {
    points = cr3bp_lagrange_points(mu)
    stopifnot(identical(names(points), paste0("L", 1:5)),
      points$L3[1] < -mu, points$L1[1] > -mu, points$L1[1] < 1 - mu,
      points$L2[1] > 1 - mu,
      identical(points$L4, c(0.5 - mu, sqrt(3) / 2)),
      identical(points$L5, c(0.5 - mu, -sqrt(3) / 2)))
    for (point in names(points)) {
      equilibrium = cr3bp_initial_state(mu, point, c(0, 0, 0))
      stopifnot(max(abs(cr3bp_derivative(equilibrium, mu))) < 2e-12)
      if (point %in% c("L4", "L5"))
        stopifnot(abs(cr3bp_jacobi(equilibrium, mu) - (3 - mu + mu^2)) < 2e-15)
    }
  }
  stopifnot(abs(cr3bp_lagrange_points(0.5)$L1[1]) < 1e-15)
  # Potential finite differences independently test centrifugal/gravity signs,
  # while arbitrary nonzero velocity tests both Coriolis signs and vertical force.
  mu = unname(ratios["earth_moon"])
  q = c(0.31, -0.27, 0.14); v = c(0.08, -0.12, 0.03)
  h = 1e-6
  gradient = vapply(1:3, function(i) {
    plus = minus = q; plus[i] = plus[i] + h; minus[i] = minus[i] - h
    (cr3bp_potential(plus, mu) - cr3bp_potential(minus, mu)) / (2 * h)
  }, numeric(1))
  stopifnot(max(abs(gradient - cr3bp_potential_gradient(q, mu))) < 1e-8)
  derivative = cr3bp_derivative(c(q, v), mu)
  stopifnot(identical(derivative[1:3], v),
    max(abs(derivative[4:6] - gradient - c(2 * v[2], -2 * v[1], 0))) < 1e-8,
    abs(2 * sum(gradient * v) - 2 * sum(v * derivative[4:6])) < 1e-8)
  # An equilibrium stays at rest; a displaced, spatial trajectory conserves
  # Jacobi to a convergent numerical error rather than being projected onto C.
  state = cr3bp_initial_state(mu, "L4", c(0, 0, 0))
  equilibrium = cr3bp_runge_kutta(2, 200, mu, state)
  stopifnot(max(abs(sweep(equilibrium$states, 2, state))) < 1e-13)
  state = cr3bp_initial_state(mu, "L4", c(0.04, -0.02, 0.02), c(0.01, 0.02, -0.01))
  runs = lapply(c(50, 100, 200), function(n) cr3bp_runge_kutta(5, n, mu, state))
  drift = vapply(runs, function(r) {
    c = cr3bp_jacobi(r$states, mu); max(abs(c - c[1]))
  }, numeric(1))
  stopifnot(all(diff(drift) < 0), drift[1] / drift[3] > 100, drift[3] < 1e-8)
  request = simulation_request("restricted_three_body", "RK4", list(mu = mu, state0 = state), 5, 5 / 200)
  result = run_simulation(request)
  direct = cr3bp_jacobi(result$raw$states, mu)
  stopifnot(max(abs(result$diagnostics$jacobi - direct)) < 1e-14,
    max(abs(result$diagnostics$jacobi_drift - (direct - direct[1]))) < 1e-14,
    !"energy" %in% names(result$diagnostics))
  zero_state = c(q, sqrt(2 * cr3bp_potential(q, mu)), 0, 0)
  zero = run_simulation(simulation_request("restricted_three_body", "RK4",
    list(mu = mu, state0 = zero_state), 0.01, 0.001))
  stopifnot(all(is.na(zero$diagnostics$jacobi_relative_drift)),
    all(is.finite(zero$diagnostics$jacobi_drift)))
  equal = run_simulation(simulation_request("restricted_three_body", "RK4",
    list(mu = 0.5, state0 = cr3bp_initial_state(0.5, "L1", c(0, 0, 0))), 1, 0.01))
  stopifnot(all(is.finite(equal$diagnostics$jacobi)), max(abs(equal$diagnostics$jacobi_drift)) < 1e-14)
  display = studio_display_state(result, "native")
  stopifnot(all(display$positions[, 1, 1] == -mu), all(display$positions[, 2, 1] == 1 - mu))
  path = tempfile(fileext = ".pdf"); on.exit(unlink(path), add = TRUE)
  grDevices::pdf(path)
  studio_plot_trajectories(result, frame = "native")
  studio_plot_diagnostic(result, "jacobi_drift")
  grDevices::dev.off()
  stopifnot(file.info(path)$size > 0)
  for (name in c("earth_moon_l1", "earth_moon_l2", "earth_moon_l3", "sun_earth_l1", "sun_earth_trojan")) {
    r = run_simulation(studio_preset(name))
    stopifnot(r$request$system == "restricted_three_body",
      all(is.finite(r$positions)), max(abs(r$diagnostics$jacobi_drift)) < 1e-9)
  }
  for (bad in list(0, -0.1, 0.6, NA_real_, Inf, c(0.1, 0.2), "0.1")) {
    fail(cr3bp_lagrange_points(bad)); fail(cr3bp_potential(q, bad))
    fail(cr3bp_runge_kutta(1, 10, bad, state))
  }
  fail(cr3bp_potential(c(-mu, 0, 0), mu))
  fail(cr3bp_derivative(c(1 - mu, 0, 0, 0, 0, 0), mu))
  fail(cr3bp_jacobi(rep(0, 5), mu))
  fail(cr3bp_initial_state(mu, "L6"))
  fail(cr3bp_initial_state(mu, "L1", c(0, NA, 0)))
  fail(cr3bp_runge_kutta(1, 10.5, mu, state))
  cat("CR3BP spatial-orbit Jacobi drift (50/100/200 steps):", format(drift, digits = 4), "\n")
})
cat("CR3BP equations, equilibria, Jacobi invariance, presets, plotting and validation passed.\n")
