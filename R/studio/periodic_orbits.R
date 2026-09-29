# Opt-in Shiny module. Kept out of cd_load_studio and the core job/runner paths.
studio_start_periodic_orbit = function(arguments, root = cd_project_root()) {
  if (!requireNamespace("callr", quietly = TRUE)) stop("Install callr for background analysis.")
  callr::r_bg(function(root, arguments) {
    setwd(root)
    source(file.path(root, "R", "load.R"))
    cd_load_periodic_orbits()
    do.call(shoot_periodic_orbit, arguments)
  }, args = list(root = root, arguments = arguments), supervise = TRUE)
}

studio_periodic_ui = function(id) {
  ns = shiny::NS(id)
  shiny::tagList(
    shiny::h3("Experimental periodic-orbit correction"),
    shiny::helpText("Start with the Figure-eight catalogue preset. This local shooting analysis uses the composer initial state and RK4. Choose a candidate period and free components; all return components are checked. Results are local numerical corrections, with no claim of new orbit discovery."),
    shiny::uiOutput(ns("settings")),
    shiny::checkboxInput(ns("vary_period"), "Correct period (bounded)", TRUE),
    shiny::numericInput(ns("steps"), "RK4 steps per candidate period", 1000, min = 4, max = 100000),
    shiny::numericInput(ns("tolerance"), "Scaled residual tolerance", 1e-7, min = 0),
    shiny::numericInput(ns("max_iterations"), "Maximum correction iterations", 20, min = 0, max = 100),
    shiny::tags$details(shiny::tags$summary("Numerical safeguards"),
      shiny::numericInput(ns("jacobian_step"), "Finite-difference increment (scaled)", 1e-5),
      shiny::numericInput(ns("damping"), "Damping", 1e-8),
      shiny::numericInput(ns("trust_radius"), "Maximum scaled correction length", 0.1),
      shiny::numericInput(ns("max_backtracks"), "Maximum step halvings", 12, min = 0, max = 30),
      shiny::numericInput(ns("max_evaluations"), "Maximum integrations", 1000, min = 2, max = 10000)),
    shiny::actionButton(ns("run"), "Correct candidate orbit", class = "btn-primary"),
    shiny::actionButton(ns("cancel"), "Cancel correction"),
    shiny::tags$div(role = "status", `aria-live` = "polite", shiny::textOutput(ns("status"))),
    shiny::helpText("Hold suitable components fixed to constrain phase and other symmetries. Convergence requires closure at the chosen resolution and twice as many steps. This does not certify exact periodicity, stability, or minimal period. Close encounters and unstable trajectories may prevent correction. Results retain the inputs used at launch."),
    shiny::verbatimTextOutput(ns("details")),
    shiny::downloadButton(ns("download"), "Full analysis RDS"),
    shiny::downloadButton(ns("history_csv"), "Correction history CSV"),
    shiny::plotOutput(ns("residual_plot"), height = "300px"),
    shiny::plotOutput(ns("trajectory_plot"), height = "420px"),
    shiny::h4("Corrected initial state (model units)"), shiny::tableOutput(ns("state")),
    shiny::h4("Correction trials (including rejected steps)"),
    shiny::tags$div(style = "overflow-x:auto", shiny::tableOutput(ns("history"))))
}

studio_periodic_server = function(id, configuration, configuration_validation) {
  shiny::moduleServer(id, function(input, output, session) {
    report = shiny::reactiveVal(NULL)
    process = shiny::reactiveVal(NULL)
    status = shiny::reactiveVal("Ready. Experimental analysis runs separately from simulations.")
    output$settings = shiny::renderUI({
      problem = simulation_dynamics(configuration())
      components = periodic_orbit_components(problem$state)
      # Preserve double precision when populating dimensional period/scales.
      number = function(id, label, value) {
        control = shiny::numericInput(session$ns(id), label, value)
        control$children[[2]]$attribs$value = sprintf("%.17g", value)
        control
      }
      shiny::tagList(
        shiny::selectInput(session$ns("free"), "Free initial components [body, coordinate]",
          components, selected = components[startsWith(components, "velocity")], multiple = TRUE),
        number("period", "Candidate period (model time units)", problem$duration),
        number("period_min", "Minimum period", problem$duration * 0.5),
        number("period_max", "Maximum period", problem$duration * 1.5),
        number("position_scale", "Position scale (model length units)", max(1, abs(problem$state$positions))),
        number("velocity_scale", "Velocity scale (model velocity units)", max(1, abs(problem$state$velocities))))
    })
    shiny::observeEvent(input$run, {
      if (!is.null(process())) return()
      report(NULL)
      tryCatch({
        validation = configuration_validation()
        if (!validation$valid) stop(paste(unlist(validation$errors), collapse = " "))
        problem = simulation_dynamics(validation$requests[[1]])
        free = input$free
        if (is.null(free)) free = character()
        args = list(model = problem$model, state = problem$state, period = input$period,
          free_components = free, vary_period = isTRUE(input$vary_period),
          period_bounds = c(input$period_min, input$period_max), steps = input$steps,
          position_scale = input$position_scale, velocity_scale = input$velocity_scale,
          tolerance = input$tolerance, max_iterations = input$max_iterations,
          jacobian_step = input$jacobian_step, damping = input$damping,
          trust_radius = input$trust_radius, max_backtracks = input$max_backtracks,
          max_evaluations = input$max_evaluations)
        process(studio_start_periodic_orbit(args))
        status("Correcting in a background process. History will appear when the search finishes.")
      }, error = function(e) status(paste("Correction failed:", conditionMessage(e))))
    })
    poll = function() {
      worker = process()
      if (is.null(worker) || worker$is_alive()) return(invisible(NULL))
      process(NULL)
      tryCatch({
        result = worker$get_result()
        report(result)
        status(paste(result$status, result$message, sep = ": "))
      }, error = function(e) status(paste("Correction failed:", conditionMessage(e))))
      invisible(NULL)
    }
    shiny::observe({
      shiny::req(process()); shiny::invalidateLater(250, session); poll()
    })
    shiny::observeEvent(input$cancel, {
      if (!is.null(process())) {
        process()$kill(); process(NULL); status("Correction cancelled.")
      }
    })
    session$onSessionEnded(function() {
      shiny::isolate({ if (!is.null(process())) process()$kill() })
    })
    output$status = shiny::renderText(status())
    output$details = shiny::renderText({
      r = report(); shiny::req(r)
      sprintf("Status: %s\nPeriod estimate: %.12g\nScaled return residual: %.6g\nHalf-timestep residual: %.6g\nTolerance: %.6g; iterations: %d; integrations: %d\nPosition scale: %.6g; velocity scale: %.6g; RK4 steps: %d\nFree: %s; period corrected: %s",
        r$status, r$period, r$residual_norm, r$verification$residual_norm, r$settings$tolerance,
        r$iterations, r$evaluations, r$settings$position_scale, r$settings$velocity_scale,
        r$settings$steps, paste(r$settings$free_components, collapse = ", "), r$settings$vary_period)
    })
    output$residual_plot = shiny::renderPlot({
      r = report(); shiny::req(r)
      h = r$history[r$history$accepted & is.finite(r$history$residual_norm), ]
      shiny::req(nrow(h) > 0)
      values = log10(pmax(h$residual_norm, .Machine$double.xmin))
      graphics::plot(h$iteration, values, type = "b", xlab = "Accepted correction iteration",
        ylab = "log10(scaled return residual)", ylim = range(c(values, log10(r$settings$tolerance))))
      graphics::abline(h = log10(r$settings$tolerance), lty = 2, col = "red")
    })
    output$trajectory_plot = shiny::renderPlot({
      r = report(); shiny::req(r, r$trajectory)
      q = r$trajectory$positions / r$settings$position_scale
      one = dim(q)[3] == 1
      x = if (one) r$trajectory$time else q[, , 1]
      y = if (one) q[, , 1] else q[, , 2]
      graphics::plot(range(x), range(y), type = "n",
        xlab = if (one) "Time" else "Coordinate 1 / position scale",
        ylab = if (one) "Position / position scale" else "Coordinate 2 / position scale",
        main = paste("Last accepted trajectory:", r$status))
      for (body in seq_len(dim(q)[2])) graphics::lines(
        if (one) r$trajectory$time else q[, body, 1],
        if (one) q[, body, 1] else q[, body, 2], col = body + 1)
    })
    output$state = shiny::renderTable({
      r = report(); shiny::req(r)
      data.frame(component = periodic_orbit_components(r$initial_state),
        initial = format(c(r$initial_state$positions, r$initial_state$velocities), digits = 12),
        corrected = format(c(r$corrected_state$positions, r$corrected_state$velocities), digits = 12))
    })
    output$history = shiny::renderTable({
      r = report(); shiny::req(r)
      h = r$history
      for (name in names(h)) if (is.numeric(h[[name]])) h[[name]] = format(h[[name]], digits = 6)
      h
    })
    output$download = shiny::downloadHandler("periodic-orbit.rds", function(file) {
      shiny::req(report()); saveRDS(report(), file)
    })
    output$history_csv = shiny::downloadHandler("periodic-orbit-history.csv", function(file) {
      shiny::req(report()); utils::write.csv(report()$history, file, row.names = FALSE)
    })
    invisible(list(report = report, status = status))
  })
}
