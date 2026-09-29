if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
cd_load_periodic_orbits()
cd_source("R/studio/periodic_orbits.R")
if (all(vapply(c("shiny", "jsonlite", "callr"), requireNamespace, logical(1), quietly = TRUE))) local({
  request = studio_preset("figure_eight")
  state = simulation_dynamics(request)$state
  configuration = shiny::reactiveVal(request)
  validation = shiny::reactiveVal(list(valid = TRUE, requests = list(request)))
  stopifnot(grepl("Experimental periodic-orbit correction", as.character(studio_periodic_ui("test")), fixed = TRUE))
  shiny::testServer(studio_periodic_server,
    args = list(configuration = configuration, configuration_validation = validation), {
    finish = function() {
      deadline = Sys.time() + 60
      while (!is.null(process()) && Sys.time() < deadline) {
        process()$wait(100); poll(); session$flushReact()
      }
      stopifnot(is.null(process()))
    }
    session$setInputs(free = periodic_orbit_components(state)[7:12],
      period = request$duration * 1.0001, period_min = request$duration * 0.5,
      period_max = request$duration * 1.5, vary_period = TRUE, steps = 1000,
      position_scale = max(abs(state$positions)), velocity_scale = max(abs(state$velocities)),
      tolerance = 1e-7, max_iterations = 20, jacobian_step = 1e-5,
      damping = 1e-8, trust_radius = 0.1, max_backtracks = 12, max_evaluations = 1000, run = 1)
    stopifnot(!is.null(process()))
    finish()
    stopifnot(report()$converged, grepl("converged", status()),
      grepl("Period estimate", output$details), nzchar(output$residual_plot$src),
      nzchar(output$trajectory_plot$src), nzchar(output$state), nzchar(output$history))
    # Editing the composer never mutates the already completed result.
    saved = report()
    configuration(studio_preset("circular_two_body")); session$flushReact()
    stopifnot(identical(saved, report()))
    session$setInputs(steps = 400, run = 2)
    finish()
    stopifnot(!report()$converged, report()$status == "discretization_limit",
      grepl("discretization_limit", status()), nzchar(output$history))
    session$setInputs(tolerance = 0, run = 3)
    finish()
    stopifnot(is.null(report()), grepl("tolerance", status()))
    session$setInputs(tolerance = 1e-7, run = 4)
    stopifnot(!is.null(process()))
    session$setInputs(cancel = 1)
    stopifnot(is.null(process()), grepl("cancelled", status()))
    validation(list(valid = FALSE, errors = list(state = "Invalid composer state")))
    session$setInputs(run = 5)
    stopifnot(is.null(process()), grepl("Invalid composer state", status()))
  })
  cat("Studio periodic-orbit background correction, refinement failures, outputs and cancellation passed.\n")
}) else cat("Optional periodic-orbit app checks skipped: install shiny, jsonlite and callr.\n")
