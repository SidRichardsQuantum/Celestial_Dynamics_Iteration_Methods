if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()

(function() {
  near = function(actual, expected, tolerance = 1e-10) {
    stopifnot(isTRUE(all.equal(actual, expected, tolerance = tolerance, check.attributes = FALSE)))
  }
  expect_error = function(expr) stopifnot(inherits(tryCatch(force(expr), error = identity), "error"))
  request = studio_preset("circular_two_body")
  request$timestep = request$duration / 1000
  result = run_simulation(request)
  report = simulation_diagnostics(result)
  d = report$series
  m = result$masses
  energy = -G * prod(m) / (2 * AU)
  angular = prod(m) / sum(m) * sqrt(G * sum(m) * AU)
  near(d$energy[1], energy)
  near(d$angular_momentum[1], angular)
  stopifnot(max(abs(d$energy_relative_drift)) < 1e-9,
    max(abs(d$angular_momentum_relative_drift)) < 1e-9,
    max(abs(d$minimum_pairwise_separation / AU - 1)) < 1e-8,
    identical(d$minimum_pairwise_separation, d$maximum_pairwise_separation),
    max(d$centre_of_mass_drift) / AU < 1e-12,
    all(is.na(d$momentum_relative_drift)), report$validity$valid,
    !report$flags$collision, is.na(report$flags$near_collision),
    report$performance$step_count == 1000, report$performance$runtime_seconds >= 0,
    is.na(report$performance$force_evaluation_count),
    identical(studio_diagnostics(result), d),
    identical(report$registry, result$diagnostic_registry),
    identical(report$registry$metric, names(d)[-1]))
  near(d$energy_drift, d$energy - d$energy[1], 0)
  near(d$energy_relative_drift, d$energy_drift / abs(d$energy[1]), 0)
  row = report$summary[report$summary$metric == "energy_relative_drift", ]
  near(row$final, tail(d$energy_relative_drift, 1), 0)
  near(row$maximum, max(d$energy_relative_drift), 0)
  near(row$max_absolute, max(abs(d$energy_relative_drift)), 0)
  stopifnot(row$kind == "relative_error", row$units == "1", row$finite_samples == 1001)

  elliptic = run_simulation(studio_preset("eccentric_two_body"))
  ed = simulation_diagnostics(elliptic)$series
  near(ed$energy[1], energy)
  near(ed$angular_momentum[1], angular * sqrt(1 - 0.6^2))
  stopifnot(max(abs(ed$eccentricity - 0.6)) < 1e-7,
    max(abs(ed$energy_relative_drift)) < 1e-7,
    abs(min(ed$minimum_pairwise_separation) / AU - 0.4) < 1e-7,
    abs(max(ed$maximum_pairwise_separation) / AU - 1.6) < 1e-7)

  figure = run_simulation(studio_preset("figure_eight"))
  fd = simulation_diagnostics(figure)$series
  pscale = sum(figure$masses * sqrt(rowSums(figure$velocities[1, , ]^2)))
  lscale = sum(abs(figure$masses * figure$positions[1, , 1] * figure$velocities[1, , 2]) +
               abs(figure$masses * figure$positions[1, , 2] * figure$velocities[1, , 1]))
  stopifnot(max(abs(fd$energy_relative_drift)) < 1e-7,
    max(fd$momentum_drift) / pscale < 1e-12,
    max(abs(fd$angular_momentum_drift)) / lscale < 1e-8,
    all(is.na(fd$angular_momentum_relative_drift)),
    max(fd$centre_of_mass_drift) / AU < 1e-12,
    min(fd$minimum_pairwise_separation) > 0,
    all(fd$maximum_pairwise_separation >= fd$minimum_pairwise_separation))
  near(fd$minimum_pairwise_separation[1], min(stats::dist(figure$positions[1, , ])))
  near(fd$maximum_pairwise_separation[1], max(stats::dist(figure$positions[1, , ])))

  # Galilean boost and translation: a moving barycentre is not numerical drift.
  moving = result
  boost = c(20, -30)
  offset = c(2, -3) * AU
  for (axis in 1:2) {
    moving$positions[, , axis] = moving$positions[, , axis] + offset[axis] + result$time * boost[axis]
    moving$velocities[, , axis] = moving$velocities[, , axis] + boost[axis]
  }
  md = simulation_diagnostics(moving)$series
  near(md$centre_of_mass_x, offset[1] + result$time * boost[1])
  near(md$centre_of_mass_velocity_y, rep(boost[2], length(result$time)))
  stopifnot(max(md$centre_of_mass_drift) < 1e-3,
    max(md$momentum_relative_drift) < 1e-12)
  perturbed = moving
  last = length(result$time)
  perturbed$positions[last, , 1] = perturbed$positions[last, , 1] + 1000
  stopifnot(abs(tail(simulation_diagnostics(perturbed)$series$centre_of_mass_drift, 1) - 1000) < 1e-3)

  # Vector drift must detect direction changes even when norm(P) is unchanged.
  turning = result
  turning$velocities[] = 0
  turning$velocities[1, , 1] = 1
  turning$velocities[-1, , 2] = 1
  td = simulation_diagnostics(turning)$series
  near(td$momentum_relative_drift[-1], rep(sqrt(2), last - 1))

  # Cancellation safety is relative to physical scale, not a unit-dependent epsilon.
  stopifnot(all(is.na(studio_relative_series(c(0, 1)))),
    all(is.na(studio_relative_series(c(1e-16, 1), scale = 1))),
    all(is.na(studio_relative_series(c(NA_real_, 1)))),
    all(is.na(studio_relative_series(c(Inf, 1)))))
  near(studio_relative_series(c(1e-100, 2e-100)), c(0, 1))
  parabolic = result
  parabolic$velocities = parabolic$velocities * sqrt(2)
  pd = simulation_diagnostics(parabolic)$series
  stopifnot(all(is.na(pd$energy_relative_drift)), is.na(pd$semi_major_axis[1]), is.finite(pd$energy[1]))

  # Report bad states without losing the valid samples or substituting last finite for final.
  bad = result
  bad$positions[last, 1, 1] = NaN
  bad$velocities[last, 2, 2] = Inf
  bd = simulation_diagnostics(bad)
  stopifnot(!bd$validity$valid, bd$validity$nan_count == 1L, bd$validity$inf_count == 1L,
    tail(bd$series$state_finite, 1) == 0,
    is.na(bd$summary$final[bd$summary$metric == "energy"]),
    bd$summary$finite_samples[bd$summary$metric == "energy"] == last - 1)
  bad$time[2] = bad$time[1]
  stopifnot(!simulation_diagnostics(bad)$validity$time_valid, nrow(simulation_diagnostics(bad)$series) == 0)
  bad = result
  bad$velocities = matrix(0, 2, 2)
  stopifnot(!simulation_diagnostics(bad)$validity$shape_valid)
  bad = result
  bad$masses[1] = -1
  stopifnot(!simulation_diagnostics(bad)$validity$masses_valid, !"energy" %in% names(simulation_diagnostics(bad)$series))

  collision = result
  collision$positions[last, 2, ] = collision$positions[last, 1, ]
  cd = simulation_diagnostics(collision)
  stopifnot(cd$flags$collision, !cd$validity$valid, tail(cd$series$minimum_pairwise_separation, 1) == 0,
    is.na(tail(cd$series$energy, 1)))
  stopifnot(simulation_diagnostics(result, near_collision_distance = 2 * AU)$flags$near_collision,
    !simulation_diagnostics(result, near_collision_distance = 0.1 * AU)$flags$near_collision,
    simulation_diagnostics(result, collision_distance = 2 * AU)$flags$collision)
  expect_error(simulation_diagnostics(result, near_collision_distance = -1))
  expect_error(simulation_diagnostics(result, collision_distance = 2, near_collision_distance = 1))

  mu = 0.1
  restricted = run_simulation(simulation_request("restricted_three_body", "RK4",
    list(mu = mu, state0 = c(0.5 - mu, sqrt(3) / 2, 0, 0, 0, 0)), 1, 0.01))
  rd = simulation_diagnostics(restricted)
  near(rd$series$jacobi, rep(3 - mu + mu^2, 101))
  near(rd$series$minimum_pairwise_separation, rep(1, 101))
  stopifnot(!any(c("energy", "momentum_x", "centre_of_mass_x") %in% names(rd$series)))
  restricted$positions[101, 1, ] = c(-mu, 0, 0)
  stopifnot(simulation_diagnostics(restricted)$flags$collision)
  sitnikov_request = studio_preset("sitnikov")
  sitnikov_request$duration = sitnikov_request$timestep * 100
  sd = simulation_diagnostics(run_simulation(sitnikov_request))
  stopifnot("specific_energy" %in% names(sd$series), !"energy" %in% names(sd$series),
    max(abs(sd$series$specific_energy_relative_drift)) < 1e-7)

  # Recorded constants take precedence over today's global G; unknown forces get no invariants.
  changed = result
  changed$model$constants$G = G * 2
  expected = sum(m * rowSums(result$velocities[1, , ]^2)) / 2 - 2 * G * prod(m) / AU
  near(simulation_diagnostics(changed)$series$energy[1], expected)
  changed$model$force = "softened_gravity"
  stopifnot(!"energy" %in% names(simulation_diagnostics(changed)$series),
    !is.null(simulation_diagnostics(changed)$unavailable$invariants))
  changed$request$system = "unknown"
  stopifnot(!"specific_energy" %in% names(simulation_diagnostics(changed)$series))
  historical = result
  historical$solver_statistics = NULL
  historical$diagnostic_registry = NULL
  historical$diagnostics = historical$diagnostics[c("time", studio_catalog()$two_body$diagnostics)]
  historical$diagnostic_summary = studio_diagnostic_summary(historical$diagnostics)
  studio_validate_result(historical)
  stopifnot(is.na(simulation_diagnostics(historical)$performance$step_count))
  recorded = result
  recorded$solver_statistics$force_evaluation_count = 4000
  stopifnot(simulation_diagnostics(recorded)$performance$force_evaluation_count == 4000)
  # Public diagnostics also accept one-sample normalized arrays.
  single = result
  single$time = single$time[1]
  single$positions = single$positions[1, , , drop = FALSE]
  single$velocities = single$velocities[1, , , drop = FALSE]
  stopifnot(nrow(simulation_diagnostics(single)$series) == 1)
  cat(sprintf("Diagnostics: circular max relative energy error %.3g; elliptic %.3g; figure-eight %.3g.\n",
    max(abs(d$energy_relative_drift)), max(abs(ed$energy_relative_drift)), max(abs(fd$energy_relative_drift))))
})()
cat("Structured diagnostics, model applicability, drift, validity and collision checks passed.\n")
