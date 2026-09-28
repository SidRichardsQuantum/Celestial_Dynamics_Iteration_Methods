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
        duration = initial$timestep * 10, timestep = initial$timestep,
        individual_timesteps = TRUE, method_timestep_RK4 = initial$timestep,
        method_timestep_Verlet = initial$timestep / 2, batch_reference = "RK4", run = 1
      )
      stopifnot(configuration_validation()$valid, configuration_validation()$steps == 10)
      stopifnot(!is.null(active_job()))
      finish_batch()
      stopifnot(length(history_records()) == 2,
                grepl("Completed", status()))
      stopifnot(inherits(comparison_report(), "integrator_comparison"),
        identical(comparison_report()$metrics$step_count, c(10, 20)),
        comparison_report()$metrics$max_position_difference[1] == 0,
        length(comparison_records()) == 1)
      session$setInputs(individual_timesteps = FALSE)
      first = names(history_records())[1]
      session$setInputs(gallery_action = list(action = "view", path = first))
      session$setInputs(selected_run = history_records()[[first]]$id, axes = "12", metric = "energy_relative_drift")
      stopifnot(grepl("two_body", output$exact), nzchar(output$animation$html),
                nzchar(output$orbit$src), nzchar(output$diagnostic$src))
      session$setInputs(metric = "centre_of_mass_drift")
      stopifnot(nzchar(output$diagnostic$src),
        grepl("centre_of_mass_drift", output$diagnostic_control$html, fixed = TRUE),
        grepl("Force evaluations", output$diagnostic_details$html, fixed = TRUE),
        diagnostic_report()$performance$step_count == round(selected()$request$duration / selected()$request$timestep),
        identical(diagnostic_result()$id, selected()$id))
      saved = names(history_records())
      session$setInputs(gallery_action = list(action = "favorite", path = saved[1]))
      stopifnot(studio_load_history(saved[1])$favorite)
      session$setInputs(gallery_action = list(action = "select", path = saved[1]))
      session$setInputs(gallery_action = list(action = "select", path = saved[2]))
      session$setInputs(compare_saved = 1)
      stopifnot(length(compared()) == 2, nrow(studio_comparison(compared())) == 2)
      reference = comparison_report()$members$run_id[2]
      session$setInputs(comparison_reference = reference, comparison_side_by_side = TRUE)
      stopifnot(comparison_report()$reference_run_id == reference,
        comparison_report()$metrics$max_position_difference[2] == 0,
        nzchar(output$comparison_energy$src), nzchar(output$comparison_angular$src),
        nzchar(output$comparison_panels$src), nzchar(output$comparison_orbit$src))
      session$setInputs(save_comparison = 1)
      saved_comparisons = names(comparison_records())
      stopifnot(length(saved_comparisons) == 2)
      comparison_path = saved_comparisons[vapply(comparison_records(), function(x)
        identical(x$id, comparison_report()$id), logical(1))]
      session$setInputs(saved_comparison = comparison_path, load_comparison = 1)
      stopifnot(comparison_report()$reference_run_id == reference,
        nrow(comparison_report()$metrics) == 2,
        grepl("Open", output$comparison_members$html, fixed = TRUE))
      session$setInputs(gallery_action = list(action = "view", path = saved[1]))
      stopifnot(length(runs()) == 1, identical(active_path(), saved[1]),
        isTRUE(all.equal(selected(), studio_load_result(saved[1]), tolerance = 0)))
      session$setInputs(gallery_action = list(action = "reuse", path = saved[1]))
      stopifnot(isTRUE(all.equal(configuration(), studio_load_history(saved[1])$request, tolerance = 0)))
      # Live validation must reject invalid drafts without launching a worker.
      before = length(history_records())
      session$setInputs(duration = -1)
      stopifnot(!configuration_validation()$valid,
        !is.null(configuration_validation()$errors$duration), is.null(active_job()))
      session$setInputs(duration = initial$timestep * 10.5)
      stopifnot(!is.null(configuration_validation()$errors$timestep))
      session$setInputs(duration = initial$timestep * 100001)
      stopifnot(!is.null(configuration_validation()$errors$timestep))
      session$setInputs(duration = initial$timestep * 10, parameter_masses = "[null,1]")
      stopifnot(!is.null(configuration_validation()$errors$masses))
      session$setInputs(parameter_masses = "bad JSON")
      stopifnot(grepl("valid JSON", configuration_validation()$errors$masses))
      session$setInputs(parameter_masses = "[1,1]", parameter_positions = "[[0,0],[0,0]]")
      stopifnot(!is.null(configuration_validation()$errors$positions))
      session$setInputs(parameter_positions = "[[0,0]]")
      stopifnot(!is.null(configuration_validation()$errors$positions))
      session$setInputs(parameter_masses = as.character(jsonlite::toJSON(initial$parameters$masses, digits = NA)),
        parameter_positions = as.character(jsonlite::toJSON(initial$parameters$positions, digits = NA)))
      stopifnot(configuration_validation()$valid, length(history_records()) == before)
      session$setInputs(system = "n_body", parameter_masses = "[1,1,1]",
        parameter_positions = "[[0,0],[1,0],[0,1]]",
        parameter_velocities = "[[0,0],[0,0],[0,0]]", integrators = "RK4", duration = 10, timestep = 1)
      stopifnot(configuration_validation()$valid,
        length(configuration_validation()$requests[[1]]$parameters$masses) == 3)
      session$setInputs(parameter_masses = "[1,1]", parameter_positions = "[[0,0],[1,0]]",
        parameter_velocities = "[[0,0],[0,0]]")
      stopifnot(configuration_validation()$valid)
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
      session$setInputs(metric = "minimum_pairwise_separation")
      stopifnot(nzchar(output$diagnostic$src),
        !"energy" %in% diagnostic_report()$registry$metric,
        "jacobi" %in% diagnostic_report()$registry$metric)
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
      # A timestep study reuses the same physical composer and background queue.
      session$setInputs(system = "two_body", preset = "circular_two_body")
      initial = studio_preset("circular_two_body")
      duration = initial$duration / 4
      session$setInputs(integrators = "RK4", individual_timesteps = FALSE,
        parameter_masses = as.character(jsonlite::toJSON(initial$parameters$masses, digits = NA)),
        parameter_positions = as.character(jsonlite::toJSON(initial$parameters$positions, digits = NA)),
        parameter_velocities = as.character(jsonlite::toJSON(initial$parameters$velocities, digits = NA)),
        duration = duration, timestep = duration / 80,
        convergence_integrator = "RK4", convergence_reference = "analytic", convergence_estimate = TRUE,
        convergence_timesteps = paste(sprintf("%.17g", duration / c(20, 40, 80)), collapse = ","),
        run_convergence = 1)
      stopifnot(!is.null(active_job()))
      finish_batch()
      study = convergence_report()
      stopifnot(inherits(study, "convergence_study"), study$reference$exact,
        identical(study$metrics$step_count, c(20, 40, 80)), study$theoretical_order == 4)
      session$setInputs(convergence_metric = "final_position_error")
      stopifnot(nzchar(output$convergence_linear$src), nzchar(output$convergence_log$src),
        grepl("Theoretical method order", output$convergence_details$html, fixed = TRUE))
      session$setInputs(saved_convergence = study$path, load_convergence = 1, convergence_to_lab = 1)
      stopifnot(identical(convergence_report()$metrics, study$metrics), length(compared()) == 3)
      reference_path = tail(study$comparison$members$path, 1)
      session$setInputs(convergence_reference = "numerical", convergence_reference_run = reference_path,
        convergence_timesteps = paste(sprintf("%.17g", duration / c(20, 40)), collapse = ","), run_convergence = 2)
      finish_batch()
      stopifnot(!convergence_report()$reference$exact, nrow(convergence_report()$metrics) == 2,
        nrow(convergence_report()$comparison$members) == 3,
        convergence_report()$reference$type == "numerical")
      before = length(history_records())
      session$setInputs(convergence_reference = "", run_convergence = 3)
      stopifnot(is.null(active_job()), length(history_records()) == before,
        grepl("Explicitly choose", status(), fixed = TRUE))
    })
  })
  cat("Studio Shiny server smoke checks passed.\n")
} else cat("Optional Studio app checks skipped: install shiny, jsonlite and callr to enable.\n")
