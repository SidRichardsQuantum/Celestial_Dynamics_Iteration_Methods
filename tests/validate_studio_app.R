# Optional server smoke test; no browser or exact plot snapshots required.
if (requireNamespace("shiny", quietly = TRUE) && requireNamespace("jsonlite", quietly = TRUE) && requireNamespace("callr", quietly = TRUE)) {
  local({
    directory = tempfile("studio-app-")
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
      finish_batch = function() {
        deadline = Sys.time() + 30
        while (!is.null(active_job()) && Sys.time() < deadline) {
          active_job()$process$wait(100)
          poll_background()
          session$flushReact()
        }
        stopifnot(is.null(active_job()))
      }
      session$setInputs(system = "two_body", preset = "custom")
      initial = studio_preset("circular_two_body")
      session$setInputs(
        integrators = c("RK4", "Verlet"),
        parameter_masses = as.character(jsonlite::toJSON(initial$parameters$masses, digits = NA)),
        parameter_positions = as.character(jsonlite::toJSON(initial$parameters$positions, digits = NA)),
        parameter_velocities = as.character(jsonlite::toJSON(initial$parameters$velocities, digits = NA)),
        duration = initial$timestep * 10, timestep = initial$timestep, run = 1
      )
      stopifnot(!is.null(active_job()))
      finish_batch()
      stopifnot(length(history_records()) == 2,
                grepl("Completed", status()))
      first = names(history_records())[1]
      session$setInputs(gallery_action = list(action = "view", path = first))
      session$setInputs(selected_run = history_records()[[first]]$id, axes = "12", metric = "energy_relative_drift")
      stopifnot(grepl("two_body", output$exact), nzchar(output$animation$html),
                nzchar(output$orbit$src), nzchar(output$diagnostic$src))
      saved = names(history_records())
      session$setInputs(gallery_action = list(action = "favorite", path = saved[1]))
      stopifnot(studio_load_history(saved[1])$favorite)
      session$setInputs(gallery_action = list(action = "select", path = saved[1]))
      session$setInputs(gallery_action = list(action = "select", path = saved[2]))
      session$setInputs(compare_saved = 1)
      stopifnot(length(compared()) == 2, nrow(studio_comparison(compared())) == 2)
      session$setInputs(gallery_action = list(action = "view", path = saved[1]))
      stopifnot(length(runs()) == 1, identical(active_path(), saved[1]),
        isTRUE(all.equal(selected(), studio_load_result(saved[1]), tolerance = 0)))
      session$setInputs(gallery_action = list(action = "reuse", path = saved[1]))
      stopifnot(isTRUE(all.equal(configuration(), studio_load_history(saved[1])$request, tolerance = 0)))
      session$setInputs(system = "sitnikov")
      stopifnot(configuration()$system == "sitnikov")
      session$setInputs(history = names(history_records())[1], reload = 1)
      stopifnot(configuration()$system == "two_body", grepl("Loaded", status()))
      session$setInputs(duration = -1, run = 2)
      stopifnot(grepl("Run failed", status()), length(history_records()) == 2)
      session$setInputs(system = "restricted_three_body", preset = "sun_jupiter_particle")
      initial = studio_preset("sun_jupiter_particle")
      session$setInputs(
        integrators = "RK4", parameter_mu = initial$parameters$mu,
        parameter_state0 = as.character(jsonlite::toJSON(initial$parameters$state0, digits = NA)),
        parameter_primary_names = '["Sun","Jupiter"]',
        duration = initial$timestep * 10, timestep = initial$timestep, run = 3,
        axes = "12", reference_frame = "inertial"
      )
      finish_batch()
      first = names(history_records())[1]
      session$setInputs(gallery_action = list(action = "view", path = first))
      stopifnot(length(runs()) == 1, grepl("Completed", status()),
                grepl("Jupiter", output$animation$html, fixed = TRUE))
      # An actual non-finite solver result is retained by the worker.
      session$setInputs(duration = 1e200, timestep = 1e200, run = 4)
      finish_batch()
      failures = Filter(function(r) r$status == "failed", history_records())
      stopifnot(length(failures) == 1, nzchar(failures[[1]]$error),
        failures[[1]]$request$system == "restricted_three_body")
      # Page navigation and filtering do not clear comparison selections.
      session$setInputs(page_size = "6", search = "Sun-Jupiter")
      stopifnot(length(picked()) == 2, gallery_page()$page == 1L)
      session$setInputs(search = "")
      session$setInputs(reference_frame = "native")
      stopifnot(grepl("rotating frame", output$animation$html, fixed = TRUE),
                nzchar(output$orbit$src))
    })
  })
  cat("Studio Shiny server smoke checks passed.\n")
} else cat("Optional Studio app checks skipped: install shiny, jsonlite and callr to enable.\n")
