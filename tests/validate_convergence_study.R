if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
local({
  directory = tempfile("convergence-study-")
  jobs = list()
  on.exit({
    for (job in jobs) try(studio_cancel_job(job), silent = TRUE)
    unlink(directory, recursive = TRUE)
  })
  expect_error = function(expr, pattern = NULL) {
    e = tryCatch(force(expr), error = identity)
    stopifnot(inherits(e, "error"))
    if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(e), fixed = TRUE))
  }
  request = studio_preset("circular_two_body")
  period = request$duration
  request$duration = period / 4
  timesteps = request$duration / c(20, 40, 80, 160)
  requests = studio_convergence_requests(request, "RK4", rev(timesteps))
  stopifnot(identical(vapply(requests, function(r) r$timestep, numeric(1)), timesteps),
    all(vapply(requests, function(r) identical(r$parameters, request$parameters), logical(1))))
  for (bad in list(1, c(1, 1), c(0, 1), c(NA_real_, 1), c(Inf, 1), c(-1, 1)))
    expect_error(studio_convergence_requests(request, "RK4", bad))
  expect_error(studio_convergence_requests(request, "RK4", request$duration / c(20, 20 + 1e-12)))
  expect_error(run_convergence_study(request, "RK4", timesteps, reference = "implicit", directory = directory))
  expect_error(run_convergence_study(studio_preset("eccentric_two_body"), "RK4", timesteps,
    reference = "analytic", directory = directory), "circular")
  expect_error(run_convergence_study(request, "RK4", timesteps, reference = "numerical", directory = directory), "reference_run")
  stopifnot(!dir.exists(directory))

  # The analytic reference includes barycentre motion and either rotation sense.
  analytic = studio_circular_reference(request, c(0, period / 4, period))
  initial_r = request$parameters$positions[2, ] - request$parameters$positions[1, ]
  quarter_r = analytic$positions[2, 2, ] - analytic$positions[2, 1, ]
  stopifnot(max(abs(quarter_r - c(-initial_r[2], initial_r[1]))) / AU < 1e-14,
    max(abs(analytic$positions[3, , ] - request$parameters$positions)) / AU < 1e-14,
    identical(unname(analytic$velocities[1, , ]), unname(request$parameters$velocities)))
  moving = request
  moving$parameters$positions = sweep(moving$parameters$positions, 2, c(2, 3) * AU, "+")
  moving$parameters$velocities = sweep(-moving$parameters$velocities, 2, c(10, -20), "+")
  translated = studio_circular_reference(moving, c(0, period / 4))
  centre = colSums(translated$positions[2, , ] * moving$parameters$masses) / sum(moving$parameters$masses)
  stopifnot(max(abs(centre - (c(2, 3) * AU + period / 4 * c(10, -20)))) / AU < 1e-14)

  measured = numeric()
  studies = list()
  for (method in c("Euler", "Midpoint", "Heun", "RK4", "Verlet")) {
    study = run_convergence_study(request, method, timesteps, reference = "analytic", directory = directory)
    studies[[method]] = study
    errors = study$metrics$final_position_error
    p = study$estimates$final_position_error$order
    measured[method] = p
    theory = studio_integrators()[[method]]$order
    stopifnot(inherits(study, "convergence_study"), study$reference$exact,
      is.null(study$reference$run_id), all(study$metrics$status == "completed"),
      identical(study$metrics$step_count, c(20, 40, 80, 160)), all(diff(errors) < 0),
      abs(p - theory) < 0.25, identical(study$theoretical_order, theory),
      study$estimates$final_position_error$points == 4,
      all(is.finite(study$metrics$energy_max_relative_drift)),
      all(is.finite(study$metrics$angular_momentum_max_absolute_drift)),
      all(study$metrics$runtime_seconds >= 0), all(is.na(study$metrics$force_evaluation_count)))
    stopifnot(identical(studio_load_convergence_study(study$path)$metrics, study$metrics))
  }
  # Observed conservation slopes need not equal theoretical state order.
  rk = studies$RK4
  stopifnot(rk$estimates$energy_max_relative_drift$order > 4.5,
    rk$theoretical_order == 4)
  paths = rk$comparison$members$path
  finest = studio_convergence_study(paths, reference = "finest")
  stopifnot(!finest$reference$exact, finest$reference$status == "completed",
    identical(finest$metrics$is_reference, c(FALSE, FALSE, FALSE, TRUE)),
    tail(finest$metrics$final_position_error, 1) == 0,
    finest$estimates$final_position_error$points == 3,
    finest$estimates$energy_max_relative_drift$points == 4)
  finest_path = studio_save_convergence_study(finest)
  stopifnot(identical(studio_load_convergence_study(finest_path)$reference, finest$reference))
  # A selected reference is compatible but never certified exact, even if finer.
  ref_request = request; ref_request$timestep = request$duration / 640
  selected_result = run_simulation(ref_request)
  selected = run_convergence_study(request, "RK4", timesteps, reference = "numerical",
    reference_run = selected_result, directory = directory)
  stopifnot(!selected$reference$exact, selected$reference$run_id == selected_result$id,
    nrow(selected$comparison$members) == 5, nrow(selected$metrics) == 4,
    !any(selected$metrics$is_reference), selected$estimates$final_position_error$points == 4,
    identical(studio_load_convergence_study(selected$path)$metrics, selected$metrics))
  last = selected$errors[[1]]
  stopifnot(identical(summary(selected), selected$metrics),
    identical(selected$reference$integrator, selected_result$request$integrator),
    identical(selected$reference$timestep, selected_result$request$timestep),
    any(grepl("Numerical reference", capture.output(print(selected)), fixed = TRUE)),
    is.null(rk$reference$integrator), is.null(rk$reference$timestep))
  stopifnot(identical(last$time, selected$comparison$results[[1]]$time),
    nrow(last) == 21, tail(last$position_error, 1) == selected$metrics$final_position_error[1])
  no_fit = studio_convergence_study(paths, reference = "finest", estimate_order = FALSE)
  stopifnot(length(no_fit$estimates) == 0, nrow(no_fit$estimate_table) == 0)
  incompatible = ref_request; incompatible$duration = incompatible$duration * 2
  incompatible_result = run_simulation(incompatible)
  before = length(studio_history(directory))
  expect_error(run_convergence_study(request, "RK4", timesteps, reference = "numerical",
    reference_run = incompatible_result, directory = directory), "Incompatible")
  stopifnot(length(studio_history(directory)) == before)

  # Slopes are measured: increasing errors give negative slopes; zeros/NA are excluded.
  fit = estimate_convergence_order(c(0.4, 0.2, 0.1), 3 * c(0.4, 0.2, 0.1)^2.5)
  stopifnot(abs(fit$order - 2.5) < 1e-14, all(abs(fit$local$order - 2.5) < 1e-14))
  stopifnot(estimate_convergence_order(c(1, 0.5), c(1, 2))$order == -1,
    estimate_convergence_order(c(1, 0.5, 0.25), c(1, 0, NA_real_))$points == 1,
    is.na(estimate_convergence_order(c(1, 0.5, 0.25), c(1, 0, NA_real_))$order),
    is.na(estimate_convergence_order(c(1, 0.5), c(Inf, NaN))$order))
  expect_error(estimate_convergence_order(c(1, 1), c(1, 2)))

  # A failed finest run is not replaced by another numerical baseline.
  failed_request = request; failed_request$timestep = request$duration / 320
  failed_path = studio_save_failure(failed_request, "Synthetic solver failure", directory)
  partial = studio_convergence_study(c(paths[1], failed_path), reference = "finest")
  stopifnot(partial$reference$status == "failed", all(is.na(partial$metrics$final_position_error)),
    is.na(partial$estimates$final_position_error$order), is.na(partial$metrics$runtime_seconds[2]))
  # A genuinely singular RK4 run is retained by the synchronous study.
  collision = simulation_request("two_body", "RK4", list(masses = c(1, 1),
    positions = rbind(c(-1, 0), c(1, 0)), velocities = rbind(c(1, 0), c(-1, 0))), 2, 2)
  failed_study = run_convergence_study(collision, "RK4", c(2, 1), reference = "finest", directory = directory)
  stopifnot(failed_study$metrics$status[1] == "failed", nzchar(failed_study$metrics$error[1]))

  plot = tempfile(fileext = ".png")
  grDevices::png(plot, width = 1000, height = 600)
  studio_plot_convergence(rk, log_log = FALSE)
  plotted = studio_plot_convergence(finest)
  stopifnot(!tail(plotted$included, 1))
  studio_plot_convergence(no_fit)
  studio_plot_convergence(partial)
  studio_plot_convergence(rk, "jacobi_max_relative_drift")
  grDevices::dev.off(); stopifnot(file.info(plot)$size > 0); unlink(plot)

  # Study analysis settings survive through the normal comparison manifest.
  manifest = jsonlite::read_json(rk$path, simplifyVector = FALSE)
  manifest$convergence$reference_run_id = "wrong-id"
  bad_path = file.path(dirname(rk$path), "bad-study.json")
  studio_write_record(manifest, bad_path)
  expect_error(studio_load_convergence_study(bad_path), "specification")
  unlink(bad_path)
  if (requireNamespace("callr", quietly = TRUE)) {
    short = request; short$duration = 10 * short$timestep
    job = studio_start_convergence_study(short, "RK4", short$duration / c(10, 20),
      reference = "analytic", directory = directory, root = cd_project_root())
    jobs[[length(jobs) + 1L]] = job
    stopifnot(file.exists(job$convergence_path))
    job$process$wait(20000)
    stopifnot(!studio_poll_job(job)$alive)
    restored = studio_load_convergence_study(job$convergence_path)
    stopifnot(all(restored$metrics$status == "completed"), restored$reference$type == "analytic")
    job = studio_start_convergence_study(request, "RK4", request$duration / c(50000, 100000),
      reference = "finest", directory = directory, root = cd_project_root())
    jobs[[length(jobs) + 1L]] = job
    studio_cancel_job(job)
    cancelled = studio_load_convergence_study(job$convergence_path)
    stopifnot(any(cancelled$metrics$status == "cancelled"),
      all(cancelled$metrics$status %in% c("completed", "cancelled")))
  }
  cat("Measured circular-orbit final-position orders:", paste(names(measured), round(measured, 3), collapse = "; "), "\n")
})
cat("Convergence study references, analytic solution, estimates, history, plots, failures and background checks passed.\n")
