if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
if (all(vapply(c("shiny", "jsonlite", "callr"), requireNamespace, logical(1), quietly = TRUE))) local({
  directory = tempfile("sensitivity-app-")
  previous = Sys.getenv("CELESTIAL_STUDIO_HISTORY", unset = NA_character_)
  Sys.setenv(CELESTIAL_STUDIO_HISTORY = directory)
  on.exit({
    if (is.na(previous)) Sys.unsetenv("CELESTIAL_STUDIO_HISTORY") else
      Sys.setenv(CELESTIAL_STUDIO_HISTORY = previous)
    unlink(directory, recursive = TRUE)
  })
  app_environment = new.env(parent = globalenv())
  sys.source(cd_path("app/app.R"), envir = app_environment)
  shiny::testServer(app_environment$server, {
    finish = function() {
      deadline = Sys.time() + 30
      while (!is.null(sensitivity_process()) && Sys.time() < deadline) {
        sensitivity_process()$wait(100)
        poll_sensitivity(); session$flushReact()
      }
      stopifnot(is.null(sensitivity_process()))
    }
    initial = studio_preset("earth_moon_trojan")
    session$setInputs(system = initial$system, preset = "custom")
    session$setInputs(integrators = "RK4", parameter_mu = initial$parameters$mu,
      parameter_state0 = as.character(jsonlite::toJSON(initial$parameters$state0, digits = NA)),
      parameter_primary_names = '["Earth","Moon"]', duration = 0.12, timestep = 0.01,
      sensitivity_epsilon = 1e-7, sensitivity_component = "position[1,1]",
      sensitivity_time = 0.12, sensitivity_interval = 0.05,
      sensitivity_position_scale = 1, sensitivity_velocity_scale = 1, run_sensitivity = 1)
    stopifnot(!is.null(sensitivity_process()))
    finish()
    stopifnot(inherits(sensitivity_report(), "lyapunov_analysis"),
      grepl("Completed", sensitivity_status()),
      grepl("Finite-time Lyapunov estimate", output$sensitivity_details$html, fixed = TRUE),
      nzchar(output$sensitivity_separation$src), nzchar(output$sensitivity_log$src),
      nzchar(output$sensitivity_trajectories$src), nrow(sensitivity_report()$renormalisation_history) == 3)
    session$setInputs(sensitivity_epsilon = 0, run_sensitivity = 2)
    finish()
    stopifnot(is.null(sensitivity_report()), grepl("epsilon", sensitivity_status()))
    session$setInputs(sensitivity_epsilon = 1e-7, run_sensitivity = 3)
    session$setInputs(cancel_sensitivity = 1)
    stopifnot(is.null(sensitivity_process()), grepl("cancelled", sensitivity_status()))
  })
  cat("Studio sensitivity background analysis, plots, errors and cancellation passed.\n")
}) else cat("Optional sensitivity app checks skipped: install shiny, jsonlite and callr.\n")
