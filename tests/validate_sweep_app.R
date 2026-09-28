if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
if (all(vapply(c("shiny", "jsonlite", "callr"), requireNamespace, logical(1), quietly = TRUE))) local({
  directory = tempfile("sweep-app-")
  previous = Sys.getenv("CELESTIAL_STUDIO_HISTORY", unset = NA_character_)
  Sys.setenv(CELESTIAL_STUDIO_HISTORY = directory)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("CELESTIAL_STUDIO_HISTORY") else Sys.setenv(CELESTIAL_STUDIO_HISTORY = previous)
    unlink(directory, recursive = TRUE)
  })
  app_environment = new.env(parent = globalenv())
  sys.source(cd_path("app/app.R"), envir = app_environment)
  shiny::testServer(app_environment$server, {
    finish = function() {
      deadline = Sys.time() + 30
      while (!is.null(sweep_job()) && Sys.time() < deadline) {
        sweep_job()$process$wait(100); poll_sweep(); session$flushReact()
      }
      stopifnot(is.null(sweep_job()))
    }
    initial = studio_preset("earth_moon_trojan")
    session$setInputs(system = initial$system, preset = "custom")
    session$setInputs(integrators = "RK4", parameter_mu = initial$parameters$mu,
      parameter_state0 = as.character(jsonlite::toJSON(initial$parameters$state0, digits = NA)),
      parameter_primary_names = '["Earth","Moon"]', duration = 0.1, timestep = 0.01,
      sweep_dimensions = "2", sweep_parameter_a = "initial_x", sweep_parameter_b = "initial_y",
      sweep_a_mode = "linear", sweep_a_from = 0.49, sweep_a_to = 0.51, sweep_a_count = 2,
      sweep_b_mode = "values", sweep_b_values = "0.85, 0.87",
      sweep_metrics = c("minimum_separation", "jacobi_relative_drift"), sweep_store = TRUE)
    stopifnot(!is.null(sweep_plan()$plan), sweep_plan()$plan$budget["runs"] == 4)
    session$setInputs(run_sweep = 1)
    stopifnot(!is.null(sweep_job()))
    finish()
    stopifnot(all(sweep_report()$runs$status == "completed"), nrow(sweep_report()$grid) == 4,
      length(history_records()) == 4, grepl("4 completed", sweep_status(), fixed = TRUE))
    session$setInputs(sweep_output_metric = "jacobi_relative_drift", sweep_point = "2")
    stopifnot(nzchar(output$sweep_plot$src), !is.null(output$sweep_point_details), !is.null(output$sweep_table),
      grepl('id="sweep_output_metric"', output$sweep_metric_control$html, fixed = TRUE))
    session$setInputs(sweep_click = list(x = 0.51, y = 0.85))
    stopifnot(studio_sweep_point(sweep_report(), 0.51, 0.85) == 2)
    session$setInputs(sweep_inspect = 1)
    stopifnot(identical(selected()$id, sweep_report()$runs$run_id[2]),
      identical(active_path(), sweep_report()$runs$path[2]))
    # No-history runs still open in the normal viewer and remain exportable.
    session$setInputs(sweep_dimensions = "1", sweep_store = FALSE, run_sweep = 2)
    finish()
    session$setInputs(sweep_point = "1", sweep_inspect = 2)
    stopifnot(length(history_records()) == 4, all(is.na(sweep_report()$runs$path)),
      ncol(sweep_report()$grid) == 1, identical(selected()$id, sweep_report()$runs$run_id[1]),
      nzchar(output$sweep_plot$src), nzchar(output$exact))
    # Oversized ranges cannot launch or create history.
    session$setInputs(sweep_a_count = 1000000, run_sweep = 3)
    stopifnot(is.null(sweep_job()), is.null(sweep_plan()$plan), length(history_records()) == 4,
      grepl("Sweep rejected", sweep_status(), fixed = TRUE))
    session$setInputs(sweep_a_count = 2, run_sweep = 4)
    session$setInputs(cancel_sweep = 1)
    stopifnot(is.null(sweep_job()), any(sweep_report()$runs$status == "cancelled"))
  })
  cat("Studio sweep ranges, 1D/2D plots, point inspection, budgets and cancellation passed.\n")
}) else cat("Optional sweep app checks skipped: install shiny, jsonlite and callr.\n")
