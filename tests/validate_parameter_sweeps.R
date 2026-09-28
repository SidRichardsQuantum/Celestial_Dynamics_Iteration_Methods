if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
local({
  expect_error = function(expr, pattern = NULL) {
    e = tryCatch(force(expr), error = identity)
    stopifnot(inherits(e, "error"))
    if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(e), fixed = TRUE))
  }
  near = function(x, y, tolerance = 1e-10) stopifnot(isTRUE(all.equal(x, y, tolerance = tolerance)))
  base = studio_preset("circular_two_body"); base$duration = 8 * base$timestep
  original = base
  plan = prepare_parameter_sweep(base, list(timestep = base$timestep / c(1, 2, 4)),
    c("energy_relative_drift", "angular_momentum_relative_drift", "final_position_error"),
    list(reference = "analytic_circular"))
  stopifnot(nrow(plan$grid) == 3, plan$budget["integration_steps"] == 56, identical(base, original))
  report = run_parameter_sweep(base, plan$parameters, plan$metrics, plan$metric_options)
  stopifnot(all(report$runs$status == "completed"), !anyDuplicated(report$runs$run_id),
    all(is.na(report$runs$path)), !nrow(report$failures))
  for (i in 1:3) {
    run = sweep_run(report, i)
    stopifnot(identical(run$id, report$runs$run_id[i]), identical(run$request, plan$requests[[i]]))
    near(report$scalar_metrics$energy_relative_drift[i], max(abs(run$diagnostics$energy_relative_drift)))
  }
  stopifnot(report$scalar_metrics$final_position_error[3] < report$scalar_metrics$final_position_error[1] / 100)
  repeat_report = run_parameter_sweep(base, plan$parameters, plan$metrics, plan$metric_options)
  near(repeat_report$scalar_metrics, report$scalar_metrics, 0)
  stopifnot(!any(repeat_report$runs$run_id %in% report$runs$run_id))
  parameters = list("position_offset[2,1]" = c(-1000, 0, 1000), "velocity_offset[2,2]" = c(-1, 1))
  grid = prepare_parameter_sweep(base, parameters)
  stopifnot(identical(grid$grid[[1]], rep(parameters[[1]], 2)), identical(grid$grid[[2]], rep(c(-1, 1), each = 3)))
  for (i in seq_len(6)) {
    expected = base
    expected$parameters$positions[2, 1] = base$parameters$positions[2, 1] + grid$grid[[1]][i]
    expected$parameters$velocities[2, 2] = base$parameters$velocities[2, 2] + grid$grid[[2]][i]
    stopifnot(identical(grid$requests[[i]], expected))
  }
  ratio = prepare_parameter_sweep(base, list(mass_ratio = c(0.1, 0.2)))
  for (i in 1:2) {
    stopifnot(ratio$requests[[i]]$parameters$masses[1] == base$parameters$masses[1],
      ratio$requests[[i]]$parameters$masses[2] == base$parameters$masses[1] * c(0.1, 0.2)[i],
      identical(ratio$requests[[i]]$parameters$positions, base$parameters$positions),
      identical(ratio$requests[[i]]$parameters$velocities, base$parameters$velocities))
  }
  cr = studio_preset("earth_moon_trojan"); cr$duration = 0.1
  two = run_parameter_sweep(cr, list(initial_x = c(0.49, 0.51), initial_y = c(0.85, 0.87)),
    c("jacobi_relative_drift", "minimum_separation"))
  for (i in seq_len(4)) near(two$requests[[i]]$parameters$state0[1:2], as.numeric(two$grid[i, ]))
  mu = prepare_parameter_sweep(cr, list(mass_ratio = c(0.1, 1)))
  near(mu$requests[[1]]$parameters$mu, 0.1 / 1.1)
  near(mu$requests[[2]]$parameters$mu, 0.5)
  vertical = studio_preset("sitnikov"); vertical$duration = 4 * vertical$timestep
  sitnikov = run_parameter_sweep(vertical,
    list("position_offset[1,1]" = c(-1000, 1000), "velocity_offset[1,1]" = c(-1, 1)),
    c("specific_energy_relative_drift", "escape_time"), list(escape_radius = 1e30))
  stopifnot(all(sitnikov$runs$status == "completed"), all(sitnikov$runs$metric_status == "completed"),
    all(is.na(sitnikov$scalar_metrics$escape_time)))
  for (i in 1:4) {
    near(sitnikov$requests[[i]]$parameters$z0, vertical$parameters$z0 + sitnikov$grid[[1]][i])
    near(sitnikov$requests[[i]]$parameters$vz0, vertical$parameters$vz0 + sitnikov$grid[[2]][i])
  }
  many = studio_preset("rotating_square"); many$duration = 4 * many$timestep
  multi = prepare_parameter_sweep(many, list(mass_ratio = c(0.9, 1), "mass[3]" = many$parameters$masses[3] * c(0.9, 1)))
  stopifnot(nrow(multi$grid) == 4,
    multi$requests[[1]]$parameters$masses[3] == 0.9 * many$parameters$masses[3])
  expect_error(prepare_parameter_sweep(cr, list(initial_x = c(0.49, 0.5), "position_offset[1,1]" = c(0, 1))), "overlap")
  expect_error(prepare_parameter_sweep(base, list(mass_ratio = c(1, 2), "mass[1]" = c(1, 2))), "overlap")
  # Numeric references require matching physics. Metric errors do not discard runs.
  reference = sweep_run(report, 3)
  numerical = run_parameter_sweep(base, list(timestep = base$timestep), "final_position_error", list(reference = reference))
  stopifnot(is.finite(numerical$scalar_metrics$final_position_error))
  incompatible = run_parameter_sweep(base, list("position_offset[2,1]" = 1000),
    c("minimum_separation", "final_position_error"), list(reference = reference))
  stopifnot(incompatible$runs$status == "completed", incompatible$runs$metric_status == "partial",
    is.finite(incompatible$scalar_metrics$minimum_separation), is.na(incompatible$scalar_metrics$final_position_error),
    incompatible$failures$stage == "metric")
  # Known threshold semantics: already outside -> zero; no crossing -> NA, not failure.
  escaping = run_parameter_sweep(cr, list(initial_x = c(0.49, 0.5)), "escape_time", list(escape_radius = 0.1))
  stopifnot(all(escaping$scalar_metrics$escape_time == 0))
  bounded = run_parameter_sweep(cr, list(initial_x = 0.5), "escape_time", list(escape_radius = 1e10))
  stopifnot(is.na(bounded$scalar_metrics$escape_time), bounded$metric_status$status == "not_reached", !nrow(bounded$failures))
  # One explicitly constructed crossing at the first time step in a weak gravity system.
  drift = simulation_request("two_body", "Euler", list(masses = c(1, 1),
    positions = rbind(c(-100, 0), c(0, 0)), velocities = rbind(c(0, 0), c(2, 0))), 2, 1)
  crossing = run_parameter_sweep(drift, list("velocity[2,1]" = 2), "escape_time", list(escape_radius = 1, escape_body = 2))
  stopifnot(crossing$scalar_metrics$escape_time == 1)
  # Relative angular momentum is undefined for the initial zero-angular-momentum state.
  undefined = run_parameter_sweep(drift, list(timestep = 1), "angular_momentum_relative_drift")
  stopifnot(undefined$metric_status$status == "unavailable", is.na(undefined$scalar_metrics$angular_momentum_relative_drift))
  options = list(epsilon = 1e-7, component = "position[1,1]", renormalisation_interval = 0.05, position_scale = 1, velocity_scale = 1)
  lyap = run_parameter_sweep(cr, list(initial_x = c(0.49, 0.5)), "finite_time_lyapunov", list(lyapunov = options))
  stopifnot(lyap$budget["integration_steps"] == 60)
  for (i in 1:2) near(lyap$scalar_metrics$finite_time_lyapunov[i],
    do.call(run_lyapunov_analysis, c(list(experiment = lyap$requests[[i]]), options))$finite_time_exponent)
  # A numerical failure at one grid point leaves other runs intact and inspectable.
  failed = run_parameter_sweep(cr, list("velocity[1,1]" = c(0, 1e308)), "minimum_separation")
  stopifnot(identical(failed$runs$status, c("completed", "failed")),
    failed$failures$point == 2, nzchar(failed$failures$message), is.na(failed$scalar_metrics$minimum_separation[2]))
  expect_error(sweep_run(failed, 2))
  for (parameters in list(list(), list(bad = 1), list(timestep = c(1, 1)), list(timestep = NA_real_),
      list(timestep = 1i), list(timestep = numeric()), list(timestep = 1:257),
      list("position_offset[1,1]" = 1:17, "velocity_offset[1,1]" = 1:17),
      list(timestep = base$duration / 1.5))) expect_error(prepare_parameter_sweep(base, parameters))
  large = base; large$timestep = large$duration / 100000
  expect_error(prepare_parameter_sweep(large, list("position_offset[2,1]" = 1:6)), "Sweep limit")
  expect_error(prepare_parameter_sweep(cr, list(initial_x = 0.5), "energy_relative_drift"))
  expect_error(prepare_parameter_sweep(cr, list(initial_x = 0.5), "escape_time"))
  expect_error(prepare_parameter_sweep(base, list(timestep = base$timestep), "final_position_error"))
  expect_error(prepare_parameter_sweep(cr, list(initial_x = 0.5), "finite_time_lyapunov"))
  expect_error(studio_sweep_values("linear", from = 0, to = 1, count = 1e9))
  expect_error(studio_sweep_values("values", text = "system('x')"))
  expect_error(studio_sweep_values("log", from = -1, to = 2, count = 3))
  near(studio_sweep_values("linear", from = 0, to = 1, count = 3), c(0, 0.5, 1))
  near(studio_sweep_values("log", from = 1, to = 100, count = 3), c(1, 10, 100))
  near(studio_sweep_values("values", text = "3, 1, 2"), c(3, 1, 2))
  stopifnot(studio_sweep_point(two, 0.51, 0.85) == 2)
  path = tempfile(fileext = ".pdf"); grDevices::pdf(path)
  studio_plot_sweep(report); studio_plot_sweep(two); studio_plot_sweep(undefined)
  singleton = run_parameter_sweep(cr, list(initial_x = 0.5, initial_y = c(0.85, 0.87)))
  studio_plot_sweep(singleton); grDevices::dev.off()
  stopifnot(file.info(path)$size > 1000); unlink(path)
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    directory = tempfile("sweep-history-"); on.exit(unlink(directory, recursive = TRUE), add = TRUE)
    stored = run_parameter_sweep(cr, list("velocity[1,1]" = c(0, 1e308)), store_history = TRUE, directory = directory)
    stopifnot(all(file.exists(stored$runs$path)), all(vapply(stored$results, is.null, logical(1))))
    for (i in 1:2) stopifnot(studio_load_history(stored$runs$path[i])$run_id == stored$runs$run_id[i])
    stopifnot(identical(sweep_run(stored, 1)$id, stored$runs$run_id[1]))
    saved = tempfile(); saveRDS(stored, saved)
    stopifnot(identical(readRDS(saved), stored)); unlink(saved)
    if (requireNamespace("callr", quietly = TRUE)) {
      job = studio_start_sweep(prepare_parameter_sweep(cr, list(initial_x = c(0.49, 0.5))), TRUE, directory, cd_project_root())
      job$process$wait(30000)
      snapshot = studio_poll_sweep(job)
      stopifnot(!snapshot$alive, all(snapshot$report$runs$status == "completed"))
      cancel_plan = prepare_parameter_sweep(base, list(timestep = base$duration / c(4, 100000)))
      job = studio_start_sweep(cancel_plan, TRUE, directory, cd_project_root())
      deadline = Sys.time() + 30
      repeat {
        snapshot = studio_poll_sweep(job)
        if (snapshot$report$runs$status[1] == "completed" || !snapshot$alive || Sys.time() > deadline) break
        Sys.sleep(0.05)
      }
      snapshot = studio_poll_sweep(job, cancel = TRUE)
      stopifnot(!snapshot$alive, snapshot$report$runs$status[1] == "completed",
        snapshot$report$runs$status[2] == "cancelled", file.exists(snapshot$report$runs$path[1]),
        inherits(sweep_run(snapshot$report, 1), "simulation_result"))
    }
  }
})
cat("Parameter sweep grids, metrics, failures, budgets, persistence, plots and cancellation passed.\n")
