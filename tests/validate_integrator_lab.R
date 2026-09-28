if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()

local({
  directory = tempfile("integrator-lab-")
  jobs = list()
  on.exit({
    for (job in jobs) try(studio_cancel_job(job), silent = TRUE)
    unlink(directory, recursive = TRUE)
  })
  expect_error = function(expr, text = NULL) {
    error = tryCatch(force(expr), error = identity)
    stopifnot(inherits(error, "error"))
    if (!is.null(text)) stopifnot(grepl(text, conditionMessage(error), fixed = TRUE))
  }
  request = studio_preset("circular_two_body")
  request$duration = request$duration / 4
  request$timestep = request$duration / 100
  settings = list(RK4 = list(timestep = request$timestep / 2))
  requests = studio_comparison_requests(request, c("Euler", "RK4", "Verlet"), settings)
  stopifnot(identical(requests$Euler$parameters, requests$RK4$parameters),
    identical(requests$Euler$parameters, requests$Verlet$parameters),
    requests$RK4$timestep == request$timestep / 2,
    all(vapply(requests, function(r) r$duration == request$duration, logical(1))))
  expect_error(studio_comparison_requests(request, "RK4"), "at least two")
  expect_error(studio_comparison_requests(request, c("RK4", "RK4")), "distinct")
  expect_error(studio_comparison_requests(request, c("RK4", "unknown")))
  expect_error(studio_comparison_requests(request, c("RK4", "Euler"), list(RK4 = list(duration = 2))), "Only timestep")
  expect_error(studio_comparison_requests(request, c("RK4", "Euler"), list(RK4 = list(parameters = list()))))
  expect_error(studio_comparison_requests(request, c("RK4", "Euler"), list(Verlet = list(timestep = 1))))
  expect_error(studio_comparison_requests(request, c("RK4", "Euler"), list(Euler = list(timestep = request$duration / 3.5))))
  bad_requests = requests
  bad_requests$Euler$parameters$masses[1] = bad_requests$Euler$parameters$masses[1] * 2
  expect_error(studio_check_comparison_requests(bad_requests), "Incompatible")

  lab = run_integrator_comparison(request, c("Euler", "RK4", "Verlet"), settings,
    reference = "RK4", directory = directory)
  stopifnot(inherits(lab, "integrator_comparison"), nrow(lab$metrics) == 3,
    length(studio_history(directory)) == 3, length(studio_comparison_history(directory)) == 1,
    all(lab$metrics$status == "completed"), all(lab$metrics$trajectory_valid),
    identical(lab$metrics$step_count, c(100, 200, 100)),
    all(is.na(lab$metrics$force_evaluation_count)),
    all(lab$metrics$runtime_seconds >= 0), lab$reference_status == "completed",
    lab$metrics$max_position_difference[2] == 0,
    lab$metrics$final_velocity_difference[2] == 0,
    lab$metrics$energy_max_relative_drift[1] > lab$metrics$energy_max_relative_drift[2],
    lab$metrics$max_position_difference[1] > lab$metrics$max_position_difference[3],
    !any(grepl("score|best|rank", names(lab$metrics))))
  delta = lab$differences[[1]]
  stopifnot(nrow(delta) >= 201, all(diff(delta$time) > 0),
    delta$position_difference[1] == 0,
    lab$metrics$max_position_difference[1] == max(delta$position_difference),
    lab$metrics$final_position_difference[1] == tail(delta$position_difference, 1))
  a = lab$results[[1]]; b = lab$results[[2]]
  last = sqrt(rowSums((a$positions[101, , ] - b$positions[201, , ])^2))
  stopifnot(abs(max(last) / lab$metrics$final_position_difference[1] - 1) < 1e-14)
  restored = studio_load_comparison(lab$path)
  stopifnot(identical(restored$metrics, lab$metrics), identical(restored$differences, lab$differences),
    identical(restored$id, lab$id), identical(restored$reference_run_id, lab$reference_run_id))
  # A reference change is explicit and never changes the runs themselves.
  switched = studio_compare_runs(lab$members$path, "Euler")
  stopifnot(switched$metrics$max_position_difference[1] == 0,
    switched$metrics$max_position_difference[2] == lab$metrics$max_position_difference[1])
  expect_error(studio_compare_runs(lab$members$path, "missing"), "Reference")
  expect_error(studio_compare_runs(rep(lab$members$path[1], 2)), "distinct")
  duplicate = studio_save_history(lab$results[[1]], directory)
  expect_error(studio_compare_runs(c(lab$members$path[1], duplicate)), "distinct scientific")

  # Exact linear interpolants: test numerical alignment independently of solvers.
  linear = function(times, offset = 0) {
    positions = velocities = array(0, c(length(times), 2, 2))
    positions[, 1, 1] = times * (1 + offset)
    positions[, 2, 2] = 2 * times
    velocities[, 1, 1] = 1 + offset
    velocities[, 2, 2] = 2
    list(time = times, positions = positions, velocities = velocities,
      model = list(body_roles = rep("integrated_massive", 2)))
  }
  exact = studio_state_difference(linear(c(0, 1, 2), 0.25), linear(c(0, 0.5, 1.5, 2)))
  stopifnot(identical(exact$time, c(0, 0.5, 1, 1.5, 2)),
    max(abs(exact$position_difference - 0.25 * exact$time)) < 1e-14,
    all(exact$velocity_difference == 0.25))

  # RK4 hits a singular midpoint. Euler returns a finite (inaccurate) crossing.
  collision = simulation_request("two_body", "RK4", list(masses = c(1, 1),
    positions = rbind(c(-1, 0), c(1, 0)), velocities = rbind(c(1, 0), c(-1, 0))), 2, 2)
  partial = run_integrator_comparison(collision, c("RK4", "Euler"), directory = directory)
  stopifnot(identical(partial$metrics$status, c("failed", "completed")),
    nzchar(partial$metrics$error[1]), is.na(partial$metrics$runtime_seconds[1]),
    all(is.na(partial$metrics$max_position_difference)), partial$reference_status == "failed",
    studio_load_comparison(partial$path)$reference_status == "failed")
  successful_reference = studio_compare_runs(partial$members$path, "Euler")
  stopifnot(successful_reference$metrics$max_position_difference[2] == 0,
    is.na(successful_reference$metrics$max_position_difference[1]))

  # Preserve existing lightweight APIs, including single-method use.
  old = compare_integrators(request, "RK4", settings)
  stopifnot(length(old) == 1, length(old$RK4$time) == 201)
  old_table = studio_comparison(Filter(Negate(is.null), lab$results))
  stopifnot(nrow(old_table) == 3, "max_change_energy_relative_drift" %in% names(old_table))

  # Model-specific diagnostics and zero angular momentum remain explicit.
  figure = studio_preset("figure_eight")
  figure = simulation_request("n_body", "RK4", figure$parameters, 10 * figure$timestep, figure$timestep)
  figure_lab = run_integrator_comparison(figure, c("RK4", "Verlet"), directory = directory)
  stopifnot(all(is.na(figure_lab$metrics$angular_momentum_max_relative_drift)),
    all(is.finite(figure_lab$metrics$angular_momentum_max_absolute_drift)))
  restricted = studio_preset("earth_moon_trojan")
  restricted$duration = 5 * restricted$timestep
  fine = restricted; fine$timestep = fine$timestep / 2
  rpaths = vapply(list(restricted, fine), function(r) studio_save_history(run_simulation(r), directory), character(1))
  restricted_lab = studio_compare_runs(rpaths)
  stopifnot(all(is.na(restricted_lab$metrics$energy_max_relative_drift)),
    all(is.finite(restricted_lab$metrics$jacobi_max_relative_drift)))
  plot = tempfile(fileext = ".png")
  grDevices::png(plot, width = 1200, height = 600)
  for (view in c("trajectory", "energy", "angular_momentum", "side_by_side")) studio_plot_comparison(lab, view)
  studio_plot_comparison(figure_lab, "angular_momentum")
  studio_plot_comparison(restricted_lab, "energy")
  studio_plot_comparison(restricted_lab, "angular_momentum")
  studio_plot_comparison(partial, "trajectory")
  grDevices::dev.off()
  stopifnot(file.info(plot)$size > 0); unlink(plot)

  # Links are relative to history and identify the scientific run, not just filenames.
  manifest = jsonlite::read_json(lab$path, simplifyVector = FALSE)
  bad_path = file.path(dirname(lab$path), "bad.json")
  bad = manifest; bad$members[[1]]$record = "../outside.json"
  studio_write_record(bad, bad_path)
  expect_error(studio_load_comparison(bad_path), "member link")
  bad = manifest; bad$members[[1]]$run_id = "wrong-id"
  studio_write_record(bad, bad_path)
  expect_error(studio_load_comparison(bad_path), "run ID mismatch")
  bad = manifest; bad$members[[1]]$record = "missing.json"
  studio_write_record(bad, bad_path)
  expect_error(studio_load_comparison(bad_path), "missing")
  unlink(bad_path)
  moved = file.path(directory, "relocated")
  dir.create(moved)
  files = list.files(directory, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  files = files[basename(files) != "relocated"]
  stopifnot(all(file.copy(files, moved, recursive = TRUE)))
  portable = studio_load_comparison(file.path(moved, ".comparisons", basename(lab$path)))
  stopifnot(identical(portable$metrics, lab$metrics))

  if (requireNamespace("callr", quietly = TRUE)) {
    short = request; short$duration = 5 * short$timestep
    job = studio_start_comparison(studio_comparison_requests(short, c("RK4", "Verlet")),
      reference = "Verlet", directory = directory, root = cd_project_root())
    jobs[[length(jobs) + 1L]] = job
    stopifnot(file.exists(job$comparison_path))
    job$process$wait(20000)
    snapshot = studio_poll_job(job)
    stopifnot(!snapshot$alive)
    batch = studio_load_comparison(job$comparison_path)
    stopifnot(all(batch$members$status == "completed"), batch$metrics$max_position_difference[2] == 0)
    long = studio_preset("circular_two_body")
    long$timestep = long$duration / 100000
    cancelled_job = studio_start_comparison(studio_comparison_requests(long, c("RK4", "Verlet")),
      directory = directory, root = cd_project_root())
    jobs[[length(jobs) + 1L]] = cancelled_job
    studio_cancel_job(cancelled_job)
    cancelled = studio_load_comparison(cancelled_job$comparison_path)
    stopifnot(all(cancelled$members$status %in% c("completed", "cancelled")),
      any(cancelled$members$status == "cancelled"))
  }
  cat(sprintf("Integrator Lab: Euler / RK4 / Verlet max relative energy errors: %s.\n",
    paste(format(lab$metrics$energy_max_relative_drift, digits = 4), collapse = " / ")))
})
cat("Integrator Lab settings, metrics, references, failures, persistence, plotting and background checks passed.\n")
