# Launch from the checkout: Rscript -e 'shiny::runApp("app")'
if (!requireNamespace("shiny", quietly = TRUE) ||
    !requireNamespace("jsonlite", quietly = TRUE) ||
    !requireNamespace("callr", quietly = TRUE)) {
  stop("Install optional UI dependencies: install.packages(c('shiny', 'jsonlite', 'callr'))")
}
# Shiny changes its working directory to app/ before sourcing this file.
if (!file.exists("R/load.R")) {
  source("../R/load.R")
} else {
  source("R/load.R")
}
cd_load_studio()
library(shiny)

catalog = studio_catalog()
presets = studio_presets()
history_directory = Sys.getenv("CELESTIAL_STUDIO_HISTORY", cd_path(".studio", "history"))

# Shiny's default scalar formatting can round a saved double before submission.
preciseNumericInput = function(inputId, label, value) {
  control = numericInput(inputId, label, value)
  control$children[[2]]$attribs$value = sprintf("%.17g", value)
  control
}

scientific_table = function(table) {
  for (name in names(table)) {
    if (is.numeric(table[[name]]) && !name %in% c("steps", "step_count", "force_evaluation_count")) {
      table[[name]] = format(table[[name]], digits = 6, scientific = TRUE, trim = TRUE)
    }
  }
  table
}

ui = fluidPage(
  tags$head(tags$script(src = "composer.js"), tags$script(HTML("$(document).on('shiny:connected', function() {
    Shiny.addCustomMessageHandler('studioBusy', function(busy) {
      document.getElementById('run').disabled = busy;
    });
  });")), tags$style(HTML("
    body { background: #10151d; color: #e2e9f2; font-size: 15px; }
    .container-fluid { max-width: 1680px; margin: auto; }
    .well, .run-card { background: #19222e; border: 1px solid #344254; border-radius: 10px; }
    .well { padding: 22px; } h2, h3, h4 { font-weight: 600; }
    .tab-content { padding-top: 20px; } .help-block { color: #afbdcf; }
    textarea, pre { font-family: monospace; font-variant-numeric: tabular-nums; }
    .form-control, .selectize-input, .selectize-input.full, .selectize-dropdown,
    pre { background: #101923; color: #e2e9f2; border-color: #465970; }
    .selectize-input input { color: #e2e9f2; }
    .selectize-dropdown .active { background: #344254; color: white; }
    .btn-default { background: #253345; color: #e2e9f2; border-color: #465970; }
    .btn-primary { background: #216f80; border-color: #4197a8; }
    a { color: #85cbd9; } .nav-tabs>li.active>a, .nav-tabs>li.active>a:focus,
    .nav-tabs>li.active>a:hover { background: #253345; color: white; border-color: #465970; }
    .nav>li>a:hover { background: #253345; } .table-striped>tbody>tr:nth-of-type(odd) { background: #19222e; }
    .gallery { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }
    .run-card { padding: 16px; min-width: 0; overflow-wrap: anywhere; }
    .run-card.selected { border: 2px solid #85cbd9; } .run-card.failed { border-color: #cc817a; }
    .run-card img { width: 100%; border-radius: 6px; margin: 10px 0; }
    .run-card p { font-variant-numeric: tabular-nums; font-size: 13px; }
    .run-card .btn { margin: 3px; } .run-card small { color: #afbdcf; }
    #status { padding: 12px; margin-bottom: 12px; background: #19222e; border-left: 3px solid #85cbd9; }
    .modal-content { background: #19222e; } .table { font-variant-numeric: tabular-nums; }
    :focus-visible { outline: 2px solid #85cbd9; outline-offset: 3px; }
    .field-error { color: #ffb6ae; margin: 5px 0 12px; }
    .body-editor { margin-bottom: 12px; }
    .body-table { overflow-x: auto; margin-bottom: 12px; }
    .body-editor table { width: 100%; }
    .body-editor th, .body-editor td { padding: 4px; }
    .body-editor input { width: 200px; font: 13px monospace; }
    .body-editor th { white-space: nowrap; }
    .body-editor tbody th { position: sticky; left: 0; background: #19222e; }
    [aria-invalid='true'] { border-color: #ffb6ae !important; }
    .body-editor summary { cursor: pointer; margin: 12px 0; }
  "))),
  titlePanel("Celestial Dynamics Studio"),
  p("Explore numerical gravity with reproducible initial conditions and the repository's existing solvers."),
  sidebarLayout(
    sidebarPanel(width = 4,
      h3("Simulation composer"),
      selectInput("system", "Simulation", choices = setNames(names(catalog),
        gsub("_", " ", names(catalog)))),
      uiOutput("preset_control"),
      uiOutput("preset_description"),
      uiOutput("settings"),
      uiOutput("configuration_feedback"),
      actionButton("run", "Run simulation / comparison", class = "btn-primary", disabled = "disabled"),
      uiOutput("job_controls"),
      hr(), h4("Run history"),
      selectInput("history", "Previous run", choices = character()),
      actionButton("reload", "Reload configuration"),
      helpText("Reuse restores saved inputs. New runs retain scientific artifacts in local history.")
    ),
    mainPanel(width = 8,
      tags$div(role = "status", `aria-live` = "polite", textOutput("status")),
      tabsetPanel(id = "workspace", selected = "Gallery",
        tabPanel("Catalogue", textInput("catalogue_search", "Find a preset"), uiOutput("catalogue_cards")),
        tabPanel("Gallery",
          h3("Experiment gallery"),
          fluidRow(column(6, selectInput("scope", "Show", c("All" = "all",
            setNames(names(catalog), gsub("_", " ", names(catalog))),
            "Favorites" = "favorites", "Failed" = "failed",
            "Queued / running" = "active", "Cancelled" = "cancelled"))),
            column(6, textInput("search", "Search preset, integrator or run ID"))),
          actionButton("compare_saved", "Compare selected runs", class = "btn-primary"),
          actionButton("clear_selection", "Clear selection"),
          actionButton("refresh", "Refresh history"),
          textOutput("selection_count"),
          selectInput("page_size", "Runs per page", c(6, 12, 24, 48), selected = 12),
          uiOutput("gallery_pager"), uiOutput("gallery")),
        tabPanel("Viewer", uiOutput("viewer_details"),
      uiOutput("accuracy_notice"),
      uiOutput("result_control"), uiOutput("view_controls"),
      tabsetPanel(
        tabPanel("Trajectories",
          plotOutput("orbit", height = "520px"),
          uiOutput("spatial_controls"), plotOutput("spatial", height = "450px")),
        tabPanel("Diagnostics", uiOutput("diagnostic_control"),
          plotOutput("diagnostic", height = "440px"), tableOutput("summary"),
          uiOutput("diagnostic_details"),
          plotOutput("phase", height = "350px")),
        tabPanel("Animation", helpText("Playback covers the full run in 20 seconds at 1x and stops at the end. Fit a body, zoom, or follow it using the camera controls. For Trojan libration, choose the rotating frame and fit Test particle; the primaries may then lie off-screen."),
          uiOutput("animation")),
        tabPanel("Parameters & export", verbatimTextOutput("exact"),
          downloadButton("request_download", "Request JSON"),
          downloadButton("trajectory_download", "Trajectory CSV"),
          downloadButton("diagnostics_download", "Diagnostics CSV"))
      )),
      tabPanel("Integrator Lab", value = "Comparison",
        helpText("Choose a catalogue preset or reuse a history run, select two or more integrators in the composer, then Run. Physical inputs and duration are shared. Each run is saved in normal history."),
        selectInput("saved_comparison", "Saved comparisons", choices = character()),
        actionButton("load_comparison", "Load comparison"),
        actionButton("save_comparison", "Save comparison"),
        downloadButton("comparison_download", "Metrics CSV"),
        uiOutput("comparison_reference_control"),
        uiOutput("comparison_members"),
        helpText("Accuracy, conservation and cost are separate measurements. Conservation columns use relative drift when defined, otherwise absolute drift. Runtime is one solver call. NA means unavailable. Position and velocity differences use native units and linear interpolation on the union of stored times; the chosen reference is not an exact solution."),
        tags$div(style = "overflow-x:auto", tableOutput("comparison_table")),
        tags$details(tags$summary("State differences, absolute drifts and failures"),
          tags$div(style = "overflow-x:auto", tableOutput("comparison_detail_table"))),
        plotOutput("comparison_orbit", height = "480px"),
        plotOutput("comparison_energy", height = "320px"),
        plotOutput("comparison_angular", height = "320px"),
        checkboxInput("comparison_side_by_side", "Show trajectories side by side", FALSE),
        conditionalPanel("input.comparison_side_by_side === true",
          plotOutput("comparison_panels", height = "400px")),
        uiOutput("comparison_metric_control"),
        plotOutput("comparison_diagnostic", height = "400px")),
      tabPanel("Convergence", value = "Convergence",
        helpText("Use a catalogue preset or reuse an experiment in the composer. This study keeps its physical inputs and duration fixed while changing the selected integrator's timestep."),
        uiOutput("convergence_settings"),
        selectInput("convergence_reference", "Reference solution", c("Choose a reference" = "",
          "Analytic circular two-body orbit" = "analytic", "Finest study run (numerical)" = "finest",
          "Selected saved run (numerical)" = "numerical")),
        conditionalPanel("input.convergence_reference === 'numerical'",
          selectInput("convergence_reference_run", "Saved numerical reference", choices = character())),
        checkboxInput("convergence_estimate", "Estimate empirical order", TRUE),
        actionButton("run_convergence", "Run convergence study", class = "btn-primary"),
        helpText("Uses the existing background queue and Cancel unfinished runs control. Numerical references are approximations; their error and interpolation can affect measured slopes."),
        selectInput("saved_convergence", "Saved convergence studies", choices = character()),
        actionButton("load_convergence", "Load study"),
        actionButton("convergence_to_lab", "Open runs in Integrator Lab"),
        downloadButton("convergence_download", "Study CSV"),
        uiOutput("convergence_details"), uiOutput("convergence_metric_control"),
        tags$div(style = "overflow-x:auto", tableOutput("convergence_table")),
        tableOutput("convergence_order_table"),
        plotOutput("convergence_linear", height = "330px"),
        plotOutput("convergence_log", height = "380px"))
      )
    )
  )
)

server = function(input, output, session) {
  configuration = reactiveVal(studio_preset("circular_two_body"))
  preset_selection = reactiveVal("custom")
  runs = reactiveVal(NULL)
  viewed_path = reactiveVal(NULL)
  run_paths = reactiveVal(list())
  picked = reactiveVal(character())
  compared = reactiveVal(NULL)
  comparison_report = reactiveVal(NULL)
  comparison_records = reactiveVal(list())
  convergence_report = reactiveVal(NULL)
  active_job = reactiveVal(NULL)
  gallery_page_number = reactiveVal(1L)
  preview_cache = studio_preview_cache()
  preview_paths = new.env(parent = emptyenv())
  preview_endpoint = session$registerDataObj("trajectory-preview", NULL, function(data, request) {
    key = parseQueryString(request$QUERY_STRING)$key
    path = if (is.character(key) && length(key) == 1L) preview_paths[[key]] else NULL
    entry = if (!is.null(path)) preview_cache$get(path) else NULL
    if (is.null(entry) || !identical(entry$key, key)) {
      return(list(status = 404L, headers = list("Content-Type" = "text/plain"), body = "Preview unavailable."))
    }
    list(status = 200L, headers = list("Content-Type" = "image/png",
      "Cache-Control" = "private, max-age=31536000, immutable"), body = entry$bytes)
  })
  preview_url = function(path) {
    artifact = tryCatch(studio_artifact_path(path, "preview"), error = function(e) NULL)
    if (is.null(artifact)) return(NULL)
    entry = preview_cache$get(artifact)
    if (is.null(entry)) return(NULL)
    preview_paths[[entry$key]] = artifact
    paste0(preview_endpoint, "&key=", entry$key)
  }
  status = reactiveVal("Choose a preset or edit the initial conditions, then run.")
  history_records = reactiveVal(list())
  refresh_history = function() {
    records = withCallingHandlers(studio_history(history_directory), warning = function(w) {
      showNotification(conditionMessage(w), type = "warning")
      invokeRestart("muffleWarning")
    })
    history_records(records)
    labels = vapply(records, function(r) paste(r$timestamp, r$request$system,
                                               r$request$integrator), character(1))
    updateSelectInput(session, "history", choices = setNames(names(records), labels))
    comparisons = suppressWarnings(studio_comparison_history(history_directory))
    comparison_records(comparisons)
    updateSelectInput(session, "saved_comparison", choices = setNames(names(comparisons),
      vapply(comparisons, function(x) paste(x$timestamp, x$label), character(1))))
    studies = Filter(function(x) !is.null(x$convergence), comparisons)
    updateSelectInput(session, "saved_convergence", choices = setNames(names(studies),
      vapply(studies, function(x) paste(x$timestamp, x$label, x$convergence$reference), character(1))))
    complete = Filter(function(r) r$status == "completed" && !is.null(r$artifacts$result), records)
    updateSelectInput(session, "convergence_reference_run", choices = setNames(names(complete),
      vapply(complete, function(r) paste(r$request$system, r$request$integrator,
        "dt", format(r$request$timestep, digits = 6), r$id), character(1))))
  }
  refresh_history()
  output$status = renderText(status())
  output$catalogue_cards = renderUI({
    query = input$catalogue_search
    tagList(lapply(names(catalog), function(system) {
      choices = Filter(function(p) p$request$system == system &&
        (is.null(query) || !nzchar(query) || grepl(tolower(query),
          tolower(paste(p$name, p$description)), fixed = TRUE)), presets)
      if (!length(choices)) return(NULL)
      tagList(h3(gsub("_", " ", system)), tags$div(class = "gallery",
        lapply(names(choices), function(id) {
          p = choices[[id]]
          tags$article(class = "run-card", h4(p$name), tags$p(p$description),
            tags$small(p$source), tags$br(),
            tags$button(type = "button", class = "btn btn-primary", "Use preset",
              onclick = sprintf("Shiny.setInputValue('choose_preset', %s, {priority:'event'})",
                jsonlite::toJSON(id, auto_unbox = TRUE))))
        })))
    }))
  })
  observeEvent(input$choose_preset, {
    req(input$choose_preset %in% names(presets))
    config = presets[[input$choose_preset]]$request
    freezeReactiveValue(input, "preset")
    freezeReactiveValue(input, "system")
    configuration(config)
    preset_selection(input$choose_preset)
    updateSelectInput(session, "system", selected = config$system)
    updateSelectInput(session, "preset", selected = input$choose_preset)
    status(paste("Configured:", presets[[input$choose_preset]]$name))
  })
  output$preset_control = renderUI({
    choices = Filter(function(p) p$request$system == input$system, presets)
    selectInput("preset", "Initial conditions", choices = c("Custom" = "custom",
      setNames(names(choices), vapply(choices, function(p) p$name, character(1)))),
      selected = if (preset_selection() %in% names(choices)) preset_selection() else "custom")
  })
  observeEvent(input$system, {
    if (configuration()$system != input$system) {
      choices = Filter(function(p) p$request$system == input$system, presets)
      preset_selection("custom")
      configuration(choices[[1]]$request)
    }
  })
  observeEvent(input$preset, {
    if (input$preset != "custom" && presets[[input$preset]]$request$system == input$system) {
      configuration(presets[[input$preset]]$request)
    }
  })
  output$preset_description = renderUI({
    req(input$preset, input$preset != "custom")
    helpText(presets[[input$preset]]$description)
  })
  output$settings = renderUI({
    config = configuration()
    spec = catalog[[config$system]]
    controls = lapply(names(spec$parameters), function(name) {
      field = spec$parameters[[name]]
      value = config$parameters[[name]]
      control = if (field$type == "number") {
        preciseNumericInput(paste0("parameter_", name), field$label, value = value)
      } else {
        textAreaInput(paste0("parameter_", name), paste0(field$label, " (JSON)"),
          value = as.character(jsonlite::toJSON(value, digits = I(17), matrix = "rowmajor")),
          rows = if (field$type == "matrix") 3 else 2, width = "100%")
      }
      tagList(control, uiOutput(paste0("error_", name)))
    })
    if (all(c("masses", "positions", "velocities") %in% names(spec$parameters))) {
      # JSON controls remain the canonical Shiny inputs. The table edits the
      # same values, so reuse, presets and the API retain their full precision.
      controls = tags$div(class = "body-editor", `data-system` = config$system,
        tags$div(class = "body-table", tabindex = "0", role = "region",
          `aria-label` = "Body initial conditions; scroll horizontally for all coordinates"),
        if (config$system == "n_body") tags$button(type = "button",
          class = "btn btn-default add-body", "Add body"),
        helpText("One row per body. Scroll horizontally to edit all coordinates. Mass must be positive; bodies must start at different positions."),
        uiOutput("error_masses"), uiOutput("error_positions"), uiOutput("error_velocities"),
        tags$details(tags$summary("Advanced: edit initial conditions as JSON"),
          lapply(seq_along(spec$parameters), function(i) controls[[i]][[1]])))
    }
    tagList(p(spec$description), helpText(spec$units),
      selectInput("integrators", "Integrator(s); select several to compare",
                  choices = spec$integrators, selected = config$integrator, multiple = TRUE),
      uiOutput("error_integrators"),
      helpText(paste(vapply(studio_integrators()[spec$integrators], function(m) {
        paste0(m$name, ": order ", m$order, ", ",
          if (m$adaptive) "adaptive" else "fixed step", ", ",
          if (m$symplectic) "symplectic" else "non-symplectic")
      }, character(1)), collapse = "; ")),
      controls,
      preciseNumericInput("duration", "Duration (system time units)", config$duration),
      uiOutput("error_duration"),
      preciseNumericInput("timestep", "Timestep (duration must be an integer multiple)", config$timestep),
      uiOutput("error_timestep"),
      checkboxInput("individual_timesteps", "Set a different timestep for each integrator", FALSE),
      uiOutput("integrator_settings"), uiOutput("batch_reference_control"),
      if (length(spec$integrators) < 2L) helpText("This model currently has one integrator. Saved runs with different timesteps can still be compared."),
      helpText("Up to 100,000 steps, 256 massive bodies, 2 million position values and 10 million pair-steps per run. Close encounters may require a much smaller timestep."))
  })
  output$integrator_settings = renderUI({
    req(isTRUE(input$individual_timesteps), input$integrators)
    tagList(lapply(input$integrators, function(method)
      preciseNumericInput(paste0("method_timestep_", method), paste(method, "timestep"), input$timestep)))
  })
  output$batch_reference_control = renderUI({
    req(length(input$integrators) >= 2L)
    selectInput("batch_reference", "Reference run for state differences (not an exact solution)", input$integrators)
  })
  configuration_validation = reactive({
    base = configuration()
    spec = catalog[[base$system]]
    errors = list()
    parameters = list()
    for (name in names(spec$parameters)) {
      field = spec$parameters[[name]]
      value = input[[paste0("parameter_", name)]]
      parameters[name] = list(tryCatch({
        if (field$type != "number") value = tryCatch(
          jsonlite::parse_json(value, simplifyVector = TRUE),
          error = function(e) stop("Enter valid JSON."))
        if (field$type == "labels") {
          if (!is.character(value) || !is.null(dim(value)) || anyNA(value) ||
              length(value) != field$length || any(!nzchar(trimws(value))) ||
              any(nchar(value) > 64) || anyDuplicated(value))
            stop("Enter distinct, nonempty labels of at most 64 characters.")
        } else {
          if (!is.numeric(value) || !length(value) || any(!is.finite(value)))
            stop("Enter finite numbers in every field.")
          if (field$type == "number" && length(value) != 1L) stop("Enter one number.")
          if (field$type == "vector" && !is.null(dim(value))) stop("Enter a vector of numbers.")
          if (field$type == "matrix" && !is.matrix(value)) stop("Enter one [x,y] row per body.")
          if (!is.null(field$length) && length(value) != field$length)
            stop("Expected ", field$length, " values.")
          if (field$positive && any(value <= 0)) stop("Values must be greater than zero.")
        }
        value
      }, error = function(e) {
        errors[[name]] <<- paste(field$label, conditionMessage(e))
        NULL
      }))
    }
    if (!is.null(parameters$masses)) {
      bodies = length(parameters$masses)
      required = switch(base$system, two_body = 2L, three_body = 3L, NULL)
      if (bodies < 2 || bodies > 256 || (!is.null(required) && bodies != required))
        errors$masses = if (is.null(required)) "Enter between 2 and 256 bodies." else
          paste("This system requires exactly", required, "bodies.")
      for (name in c("positions", "velocities")) {
        value = parameters[[name]]
        if (!is.null(value) && (!is.matrix(value) || !identical(dim(value), c(as.integer(bodies), 2L))))
          errors[[name]] = paste(name, "must have one [x,y] row per body.")
      }
    }
    for (name in c("duration", "timestep")) {
      tryCatch(studio_positive_scalar(input[[name]], name), error = function(e) {
        errors[[name]] <<- conditionMessage(e)
      })
    }
    steps = NULL
    if (!any(c("duration", "timestep") %in% names(errors))) {
      steps = input$duration / input$timestep
      if (!is.finite(steps) || round(steps) < 1 || round(steps) > 100000 ||
          abs(steps - round(steps)) > 1e-9 * max(1, steps)) {
        errors$timestep = "Duration / timestep must be an integer from 1 to 100,000. Adjust duration or timestep."
      }
    }
    if (!length(input$integrators)) errors$integrators = "Select at least one integrator."
    requests = NULL
    if (!length(errors)) {
      requests = tryCatch({
        request = simulation_request(base$system, input$integrators[1], parameters, input$duration, input$timestep)
        settings = if (isTRUE(input$individual_timesteps)) setNames(lapply(input$integrators, function(method) {
          value = input[[paste0("method_timestep_", method)]]
          studio_positive_scalar(value, paste(method, "timestep"))
          list(timestep = value)
        }), input$integrators) else list()
        studio_integrator_requests(request, input$integrators, settings)
      }, error = function(e) {
        message = conditionMessage(e)
        field = if (grepl("overlapping positions", message, fixed = TRUE)) "positions" else
          if (grepl("overlaps a primary", message, fixed = TRUE)) "state0" else
          if (grepl("mu must", message, fixed = TRUE)) "mu" else
          if (grepl("limit|timestep", message)) "timestep" else "configuration"
        errors[[field]] <<- message
        NULL
      })
    }
    list(errors = errors, steps = steps, requests = requests,
         valid = !length(errors) && length(requests) > 0)
  })
  for (name in unique(c("duration", "timestep", "integrators", unlist(lapply(catalog, function(s) names(s$parameters)))))) {
    local({
      field_name = name
      output[[paste0("error_", field_name)]] = renderUI({
        message = configuration_validation()$errors[[field_name]]
        if (!is.null(message)) tags$p(class = "field-error", message)
      })
    })
  }
  output$configuration_feedback = renderUI({
    validation = configuration_validation()
    tagList(
      if (validation$valid) p(paste("Steps:", paste(vapply(validation$requests,
        function(r) paste(r$integrator, round(r$duration / r$timestep)), character(1)), collapse = " | "))) else
      if (!is.null(validation$steps) && is.finite(validation$steps))
        p(paste("Steps per integrator:", format(validation$steps, digits = 10, big.mark = ","))),
      tags$div(role = "status", `aria-live` = "polite",
        if (validation$valid) p("Configuration ready to run.") else
          tags$p(class = "field-error", paste(c("Fix the highlighted inputs before running.",
            validation$errors$integrators, validation$errors$configuration), collapse = " "))))
  })
  observe({
    session$sendCustomMessage("studioBusy", !configuration_validation()$valid || !is.null(active_job()))
    session$sendCustomMessage("studioValidation", list(fields = names(configuration_validation()$errors)))
  })
  reuse = function(path) {
    record = history_records()[[path]]
    req(record)
    # Changing the system must not let the previous preset overwrite saved inputs.
    freezeReactiveValue(input, "preset")
    freezeReactiveValue(input, "system")
    preset_selection("custom")
    configuration(record$request)
    updateSelectInput(session, "system", selected = record$request$system)
    updateSelectInput(session, "preset", selected = "custom")
    status("Loaded exact previous configuration. Edit a value or press Run to reproduce it.")
  }
  observeEvent(input$reload, reuse(input$history))
  poll_background = function() {
    job = active_job()
    if (is.null(job)) return(invisible(NULL))
    snapshot = studio_poll_job(job)
    previous = history_records()[job$paths]
    if (!identical(previous, snapshot$records)) refresh_history()
    states = vapply(snapshot$records, function(r) r$status, character(1))
    if (snapshot$alive) {
      stages = vapply(snapshot$records, function(r) paste(r$request$integrator, "dt",
        format(r$request$timestep, digits = 5), r$stage), character(1))
      status(paste("Background batch:", paste(stages, collapse = " | ")))
    } else {
      active_job(NULL)
      if (!is.null(job$comparison_path)) {
        show_comparison(studio_load_comparison(job$comparison_path))
        updateTabsetPanel(session, "workspace", selected = "Comparison")
      }
      if (!is.null(job$convergence_path)) {
        convergence_report(studio_load_convergence_study(job$convergence_path))
        updateTabsetPanel(session, "workspace", selected = "Convergence")
      }
      status(paste("Completed batch:", sum(states == "completed"), "completed,",
        sum(states == "failed"), "failed,", sum(states == "cancelled"), "cancelled. View results in the gallery."))
    }
    invisible(snapshot)
  }
  observe({
    req(active_job())
    invalidateLater(400, session)
    isolate(tryCatch(poll_background(), error = function(e) {
      status(paste("Background status error:", conditionMessage(e)))
    }))
  })
  cancel_background = function(reason = "Cancelled by user.") {
    job = active_job()
    if (is.null(job)) return(invisible(NULL))
    studio_cancel_job(job, reason)
    poll_background()
  }
  session$onSessionEnded(function() {
    isolate(tryCatch(cancel_background("Cancelled because the browser session ended."),
                     error = function(e) warning(conditionMessage(e))))
  })
  output$job_controls = renderUI({
    req(active_job())
    tagList(helpText("Running in a separate R process. You can browse history while it runs."),
      actionButton("cancel_run", "Cancel unfinished runs", class = "btn-warning"))
  })
  observeEvent(input$cancel_run, {
    tryCatch(cancel_background(), error = function(e) showNotification(conditionMessage(e), type = "error"))
  })
  observeEvent(input$run, {
    if (!is.null(active_job())) {
      showNotification("This session already has a batch running. Cancel it or wait for completion.")
      return()
    }
    tryCatch({
      status("Validating configuration")
      validation = configuration_validation()
      if (!validation$valid) stop(paste(unlist(validation$errors), collapse = " "))
      requests = validation$requests
      reference = if (length(input$batch_reference) && input$batch_reference %in% names(requests)) input$batch_reference else 1L
      job = if (length(requests) >= 2L) studio_start_comparison(requests, reference,
        history_directory, root = cd_project_root()) else
        studio_start_job(requests, history_directory, root = cd_project_root())
      active_job(job)
      refresh_history()
      gallery_page_number(1L)
      updateTabsetPanel(session, "workspace", selected = "Gallery")
      status("Queued background batch. Browse history or cancel unfinished runs.")
    }, error = function(e) {
      refresh_history()
      status(paste("Run failed:", conditionMessage(e)))
      showNotification(conditionMessage(e), type = "error", duration = NULL)
    })
  })
  observeEvent(input$refresh, refresh_history())
  observeEvent(input$clear_selection, picked(character()))
  output$selection_count = renderText(paste(length(picked()), "runs selected"))
  card_button = function(label, action, path) {
    tags$button(type = "button", class = "btn btn-default btn-sm", label,
      onclick = sprintf("Shiny.setInputValue('gallery_action', {action:%s,path:%s}, {priority:'event'})",
        jsonlite::toJSON(action, auto_unbox = TRUE), jsonlite::toJSON(path, auto_unbox = TRUE)))
  }
  gallery_index = reactive(studio_gallery_index(history_records(), presets))
  gallery_page = reactive({
    studio_gallery_page(gallery_index(),
      scope = if (is.null(input$scope)) "all" else input$scope,
      query = if (is.null(input$search)) "" else input$search,
      page = gallery_page_number(),
      page_size = if (is.null(input$page_size)) 12L else as.integer(input$page_size))
  })
  observeEvent(list(input$scope, input$search, input$page_size), {
    gallery_page_number(1L)
  }, priority = 100)
  observeEvent(input$previous_page, gallery_page_number(max(1L, gallery_page()$page - 1L)))
  observeEvent(input$next_page, gallery_page_number(min(gallery_page()$pages, gallery_page()$page + 1L)))
  output$gallery_pager = renderUI({
    page = gallery_page()
    tagList(p(paste("Showing", page$first, "to", page$last, "of", page$total,
      "runs | Page", page$page, "of", page$pages)),
      actionButton("previous_page", "Previous page", disabled = if (page$page <= 1L) "disabled" else NULL),
      actionButton("next_page", "Next page", disabled = if (page$page >= page$pages) "disabled" else NULL))
  })
  output$gallery = renderUI({
    records = history_records()
    if (!length(records)) return(p("No experiments yet. Choose a preset in the composer and run it."))
    rows = gallery_page()$rows
    cards = lapply(seq_len(nrow(rows)), function(i) {
      m = rows[i, , drop = FALSE]
      path = m$path
      r = records[[path]]
      preview = preview_url(path)
      tags$article(class = paste("run-card", r$status, if (path %in% picked()) "selected"),
        h4(m$title), tags$small(paste(m$id, m$status, r$stage)),
        if (!is.null(preview)) tags$img(src = preview, loading = "lazy", decoding = "async",
          alt = paste("Computed trajectory preview for", m$title)) else
          p(if (r$status %in% c("failed", "cancelled")) r$error else if (r$status %in% c("queued", "running")) paste("Current stage:", r$stage) else if (is.null(r$artifacts$preview)) "Legacy record: reuse to generate scientific artifacts." else "Saved preview is missing or unreadable."),
        p(paste(m$system, m$integrator, "|", m$bodies, if (m$system == "restricted_three_body") "integrated particle (plus 2 prescribed primaries) |" else "bodies |", m$dimensions, "D")),
        p(paste("T =", format(m$duration, digits = 7), "| dt =", format(m$timestep, digits = 7))),
        p(paste("Runtime:", if (is.na(m$runtime_seconds)) "unavailable" else paste(format(m$runtime_seconds, digits = 4), "s"))),
        if (!is.na(m$metric)) p(paste(m$metric, "max |change| =", format(m$max_relative_drift, digits = 4))),
        tags$small(m$timestamp), tags$div(
          card_button("View", "view", path), card_button("Reuse", "reuse", path),
          if (!r$status %in% c("queued", "running")) card_button(if (r$favorite) "Unfavorite" else "Favorite", "favorite", path),
          if (r$status == "completed" && !is.null(r$artifacts$result))
            card_button(if (path %in% picked()) "Deselect" else "Select to compare", "select", path)))
    })
    cards = Filter(Negate(is.null), cards)
    if (!length(cards)) p("No runs match these filters.") else tags$div(class = "gallery", cards)
  })
  observeEvent(input$gallery_action, {
    event = input$gallery_action
    req(event$path %in% names(history_records()))
    tryCatch({
      r = history_records()[[event$path]]
      switch(event$action,
        reuse = reuse(event$path),
        favorite = {
          if (r$status %in% c("queued", "running")) stop("Wait for this run to finish before favoriting it.")
          studio_set_favorite(event$path, !r$favorite); refresh_history()
        },
        select = picked(if (event$path %in% picked()) setdiff(picked(), event$path) else c(picked(), event$path)),
        view = {
          viewed_path(event$path)
          result = tryCatch(studio_load_result(event$path), error = function(e) {
            showNotification(conditionMessage(e), type = "message"); NULL
          })
          run_paths(setNames(list(event$path), r$id))
          runs(if (is.null(result)) NULL else setNames(list(result), r$id))
          updateTabsetPanel(session, "workspace", selected = "Viewer")
        })
    }, error = function(e) showNotification(conditionMessage(e), type = "error"))
  })
  active_path = reactive({
    if (length(runs())) {
      choice = input$selected_run
      if (is.null(choice) || !choice %in% names(runs())) choice = names(runs())[1]
      return(run_paths()[[choice]])
    }
    viewed_path()
  })
  output$viewer_details = renderUI({
    path = active_path()
    req(path)
    r = history_records()[[path]]
    req(r)
    m = studio_gallery_metadata(r, presets)
    method = studio_integrators()[[r$request$integrator]]
    tagList(h3(m$title), p(paste(r$id, r$status, r$timestamp)),
      card_button("Reuse configuration", "reuse", path),
      if (!r$status %in% c("queued", "running")) card_button(if (r$favorite) "Unfavorite" else "Favorite", "favorite", path),
      if (!is.null(r$artifacts$result)) card_button("Select to compare", "select", path),
      h4("System and integration"),
      p(paste(m$system, "|", m$bodies, if (m$system == "restricted_three_body") "integrated particle (plus 2 prescribed primaries) |" else "bodies |", m$dimensions, "dimensions |", catalog[[m$system]]$units)),
      p(paste(m$integrator, "| order", method$order, "| fixed step |", m$steps, "steps")),
      p(paste("dt =", format(m$timestep, digits = 16), "| duration =", format(m$duration, digits = 16))),
      h4("Performance"), p(paste("Solver runtime (seconds):", format(m$runtime_seconds, digits = 8))),
      if (r$status %in% c("failed", "cancelled")) tags$div(role = "alert", class = "alert alert-danger", r$error),
      tags$details(tags$summary("Exact input parameters"), tags$pre(studio_request_json(r$request))),
      downloadButton("saved_request_download", "Export saved request JSON"),
      if (is.null(r$artifacts$result)) p("No trajectory artifacts are stored for this record. Reuse to run again."))
  })
  output$saved_request_download = downloadHandler("request.json", function(file) {
    writeLines(studio_request_json(history_records()[[active_path()]]$request), file)
  })
  show_comparison = function(value) {
    comparison_report(value)
    results = Filter(Negate(is.null), value$results)
    names(results) = vapply(results, function(r) paste(r$request$integrator, r$id), character(1))
    compared(results)
  }
  observeEvent(input$compare_saved, {
    tryCatch({
      show_comparison(studio_compare_runs(picked()))
      updateTabsetPanel(session, "workspace", selected = "Comparison")
    }, error = function(e) { compared(NULL); comparison_report(NULL); showNotification(conditionMessage(e), type = "error") })
  })
  observeEvent(input$save_comparison, {
    req(comparison_report())
    tryCatch({
      path = studio_save_comparison(comparison_report())
      refresh_history()
      updateSelectInput(session, "saved_comparison", selected = path)
      status("Saved comparison links. Every constituent remains an ordinary history run.")
    }, error = function(e) showNotification(conditionMessage(e), type = "error"))
  })
  observeEvent(input$load_comparison, {
    req(input$saved_comparison %in% names(comparison_records()))
    tryCatch(show_comparison(studio_load_comparison(input$saved_comparison)),
      error = function(e) showNotification(conditionMessage(e), type = "error"))
  })
  output$comparison_reference_control = renderUI({
    report = comparison_report(); req(report)
    selectInput("comparison_reference", "Reference run", setNames(report$members$run_id,
      paste(report$members$integrator, "dt", format(report$members$timestep, digits = 6), report$members$status)),
      selected = report$reference_run_id)
  })
  observeEvent(input$comparison_reference, {
    old = comparison_report(); req(old)
    if (input$comparison_reference == old$reference_run_id || !input$comparison_reference %in% old$members$run_id) return()
    tryCatch({
      changed = studio_compare_runs(old$members$path, input$comparison_reference)
      changed$id = old$id; changed$timestamp = old$timestamp
      show_comparison(changed)
    }, error = function(e) showNotification(conditionMessage(e), type = "error"))
  })
  output$comparison_members = renderUI({
    report = comparison_report(); req(report)
    tagList(p(paste("Units:", report$definitions$units)), if (report$reference_status != "completed")
      p("The reference has no completed trajectory; state differences are unavailable."),
      lapply(seq_len(nrow(report$members)), function(i) card_button(
        paste("Open", report$members$integrator[i], report$members$status[i]), "view", report$members$path[i])))
  })
  output$comparison_table = renderTable({
    report = comparison_report(); req(report)
    invariant = switch(report$problem$system, restricted_three_body = "jacobi_max_relative_drift",
      sitnikov = "specific_energy_max_relative_drift", "energy_max_relative_drift")
    if (invariant == "energy_max_relative_drift" && !any(is.finite(report$metrics[[invariant]])))
      invariant = "energy_max_absolute_drift"
    angular = if (any(is.finite(report$metrics$angular_momentum_max_relative_drift)))
      "angular_momentum_max_relative_drift" else "angular_momentum_max_absolute_drift"
    table = scientific_table(report$metrics[c("integrator", "timestep", "status", "runtime_seconds", "step_count",
      "force_evaluation_count", invariant, angular,
      "centre_of_mass_max_drift", "final_position_difference", "max_position_difference")])
    energy_label = switch(invariant, energy_max_relative_drift = "Max relative energy drift",
      energy_max_absolute_drift = "Max energy drift (J)", jacobi_max_relative_drift = "Max relative Jacobi drift",
      specific_energy_max_relative_drift = "Max relative specific-energy drift")
    angular_label = if (angular == "angular_momentum_max_relative_drift") "Max relative angular drift" else "Max angular drift (kg m^2/s)"
    unit = if (report$problem$system == "restricted_three_body") "normalized" else "m"
    names(table) = c("Integrator", "dt", "Status", "Runtime (s)", "Steps", "Force evals",
      energy_label, angular_label, paste0("Max CM drift (", unit, ")"),
      paste0("Final position difference (", unit, ")"), paste0("Max position difference (", unit, ")"))
    table
  }, digits = 8)
  output$comparison_detail_table = renderTable({
    req(comparison_report()); scientific_table(comparison_report()$metrics)
  }, digits = 8)
  output$comparison_download = downloadHandler("comparison.csv", function(file) {
    utils::write.csv(comparison_report()$metrics, file, row.names = FALSE)
  })
  output$comparison_metric_control = renderUI({
    req(compared())
    selectInput("comparison_metric", "Diagnostic", Reduce(intersect, lapply(compared(), function(r) setdiff(names(r$diagnostics), "time"))),
      selected = grep("relative_drift", names(compared()[[1]]$diagnostics), value = TRUE)[1])
  })
  output$comparison_orbit = renderPlot({
    req(comparison_report()); studio_plot_comparison(comparison_report(), "trajectory")
  })
  output$comparison_energy = renderPlot({
    req(comparison_report()); studio_plot_comparison(comparison_report(), "energy")
  })
  output$comparison_angular = renderPlot({
    req(comparison_report()); studio_plot_comparison(comparison_report(), "angular_momentum")
  })
  output$comparison_panels = renderPlot({
    req(comparison_report(), isTRUE(input$comparison_side_by_side))
    studio_plot_comparison(comparison_report(), "side_by_side")
  })
  output$comparison_diagnostic = renderPlot({
    req(compared(), input$comparison_metric)
    studio_plot_diagnostic(compared(), input$comparison_metric)
  })
  output$convergence_settings = renderUI({
    config = configuration()
    tagList(selectInput("convergence_integrator", "Integrator to study",
      catalog[[config$system]]$integrators, selected = config$integrator),
      textInput("convergence_timesteps", "Timesteps (comma-separated; each must divide duration)",
        paste(sprintf("%.17g", config$timestep / c(1, 2, 4, 8)), collapse = ", ")))
  })
  observeEvent(input$run_convergence, {
    if (!is.null(active_job())) {
      showNotification("Wait for the current batch or cancel it before starting a study.")
      return()
    }
    tryCatch({
      validation = configuration_validation()
      if (!validation$valid) stop(paste(unlist(validation$errors), collapse = " "))
      steps = suppressWarnings(as.numeric(strsplit(trimws(input$convergence_timesteps), "[,[:space:]]+")[[1]]))
      reference_run = if (identical(input$convergence_reference, "numerical")) input$convergence_reference_run else NULL
      job = studio_start_convergence_study(validation$requests[[1]], input$convergence_integrator,
        steps, input$convergence_reference, reference_run,
        estimate_order = isTRUE(input$convergence_estimate), directory = history_directory, root = cd_project_root())
      active_job(job)
      refresh_history()
      status("Queued convergence study. Each resolution will be saved as a normal run.")
    }, error = function(e) {
      status(paste("Convergence study failed:", conditionMessage(e)))
      showNotification(conditionMessage(e), type = "error")
    })
  })
  observeEvent(input$load_convergence, {
    req(input$saved_convergence %in% names(comparison_records()))
    tryCatch(convergence_report(studio_load_convergence_study(input$saved_convergence)),
      error = function(e) showNotification(conditionMessage(e), type = "error"))
  })
  observeEvent(input$convergence_to_lab, {
    req(convergence_report())
    show_comparison(convergence_report()$comparison)
    updateTabsetPanel(session, "workspace", selected = "Comparison")
  })
  output$convergence_details = renderUI({
    study = convergence_report(); req(study)
    tagList(p(paste("Integrator:", study$integrator, "| Theoretical method order:", study$theoretical_order,
      "| Reference:", study$reference$type, "| Reference status:", study$reference$status)),
      p(study$reference$description),
      helpText("Errors use each candidate's stored times. Empirical order is fitted from positive finite errors of valid completed runs; numerical reference self-errors are excluded. Conservation slopes may differ from the method's theoretical state order. Roundoff and coarse timesteps can distort estimates."),
      lapply(seq_len(nrow(study$comparison$members)), function(i) {
        m = study$comparison$members[i, ]
        card_button(paste("Open", m$integrator, "dt", format(m$timestep, digits = 5), m$status), "view", m$path)
      }))
  })
  output$convergence_metric_control = renderUI({
    study = convergence_report(); req(study)
    registry = study$metric_registry
    selectInput("convergence_metric", "Error or conservation observable", setNames(registry$metric,
      paste0(gsub("_", " ", registry$metric, fixed = TRUE), " [", registry$units, "]")),
      selected = "final_position_error")
  })
  output$convergence_table = renderTable({
    req(convergence_report())
    scientific_table(convergence_report()$metrics)
  }, digits = 8)
  output$convergence_order_table = renderTable({
    study = convergence_report(); req(study, input$convergence_metric)
    scientific_table(study$estimate_table[study$estimate_table$metric == input$convergence_metric, ])
  }, digits = 6)
  output$convergence_linear = renderPlot({
    req(convergence_report(), input$convergence_metric)
    studio_plot_convergence(convergence_report(), input$convergence_metric, log_log = FALSE)
  })
  output$convergence_log = renderPlot({
    req(convergence_report(), input$convergence_metric)
    studio_plot_convergence(convergence_report(), input$convergence_metric)
  })
  output$convergence_download = downloadHandler("convergence.csv", function(file) {
    req(convergence_report())
    utils::write.csv(convergence_report()$metrics, file, row.names = FALSE)
  })
  output$result_control = renderUI({
    req(runs())
    selectInput("selected_run", "Run for animation, 3D view and export", names(runs()))
  })
  selected = reactive({
    req(runs())
    choice = input$selected_run
    if (is.null(choice) || !choice %in% names(runs())) choice = names(runs())[1]
    runs()[[choice]]
  })
  output$accuracy_notice = renderUI({
    req(runs())
    messages = unlist(lapply(runs(), studio_accuracy_warnings))
    if (length(messages)) tags$div(class = "alert alert-warning", role = "alert",
      tags$strong("Conservation check: "), lapply(messages, tags$p))
  })
  output$view_controls = renderUI({
    req(runs())
    choices = c("x-y" = "12")
    if (dim(selected()$positions)[3] == 3) choices = c(choices, "x-z" = "13", "y-z" = "23")
    tagList(
      selectInput("axes", "Projection for trajectories and animation", choices,
        selected = if (selected()$request$system == "sitnikov") "13" else "12"),
      if (selected()$request$system == "restricted_three_body")
        selectInput("reference_frame", "Display frame (plots and animation)",
          c("Inertial: orbiting primaries" = "inertial", "Rotating: fixed primaries" = "native"),
          selected = "inertial"))
  })
  axes = reactive({
    code = input$axes
    if (is.null(code)) return(if (selected()$request$system == "sitnikov") c(1L, 3L) else c(1L, 2L))
    if (dim(selected()$positions)[3] == 2) return(c(1L, 2L))
    as.integer(strsplit(code, "")[[1]])
  })
  display_frame = reactive({
    if (selected()$request$system != "restricted_three_body") return("native")
    if (is.null(input$reference_frame)) "inertial" else input$reference_frame
  })
  output$orbit = renderPlot({ req(runs()); studio_plot_trajectories(runs(), axes(), display_frame()) })
  output$spatial_controls = renderUI({
    req("3d" %in% catalog[[selected()$request$system]]$visualisations)
    tagList(sliderInput("azimuth", "3D camera azimuth", -180, 180, 35),
            sliderInput("elevation", "3D camera elevation", -90, 90, 25))
  })
  output$spatial = renderPlot({
    req("3d" %in% catalog[[selected()$request$system]]$visualisations)
    req(!is.null(input$azimuth), !is.null(input$elevation))
    studio_plot_3d(selected(), input$azimuth, input$elevation, display_frame())
  })
  diagnostic_report = reactive({ simulation_diagnostics(selected()) })
  diagnostic_result = reactive({
    r = selected()
    r$diagnostics = diagnostic_report()$series
    r$diagnostic_registry = diagnostic_report()$registry
    r
  })
  output$diagnostic_control = renderUI({
    req(runs())
    registry = diagnostic_report()$registry
    selectInput("metric", "Diagnostic", setNames(registry$metric,
      paste0(gsub("_", " ", registry$metric, fixed = TRUE), " [", registry$units, "]")),
      selected = if (length(input$metric) && input$metric %in% registry$metric) input$metric else registry$metric[1])
  })
  output$diagnostic = renderPlot({
    req(runs(), input$metric)
    req(input$metric %in% names(diagnostic_result()$diagnostics))
    studio_plot_diagnostic(diagnostic_result(), input$metric)
  })
  output$summary = renderTable({
    req(runs(), input$metric)
    summary = diagnostic_report()$summary
    scientific_table(summary[summary$metric == input$metric,
      c("kind", "units", "initial", "final", "minimum", "maximum", "max_absolute", "max_absolute_change")])
  }, digits = 8)
  output$diagnostic_details = renderUI({
    report = diagnostic_report()
    req(input$metric)
    row = report$summary[report$summary$metric == input$metric, ]
    available = function(x) if (is.null(x) || is.na(x)) "unavailable" else format(x, digits = 6)
    tagList(
      p(row$definition),
      p(paste("Runtime:", available(report$performance$runtime_seconds), "s | Steps:",
        available(report$performance$step_count), "| Force evaluations:",
        available(report$performance$force_evaluation_count))),
      p(paste("Trajectory valid:", report$validity$valid, "| NaN:", report$validity$nan_count,
        "| Inf:", report$validity$inf_count, "| NA:", report$validity$na_count,
        "| Sampled overlap:", available(report$flags$collision))),
      helpText("Relative errors are undefined for zero or cancelling initial invariants. Centre-of-mass drift measures departure from uniform motion. Extrema use finite samples; final is the last stored value. Near-collision checks require an explicit distance threshold. Encounters between stored samples may be missed."))
  })
  output$phase = renderPlot({
    req("phase_space" %in% catalog[[selected()$request$system]]$visualisations)
    r = selected()
    graphics::plot(r$raw$z, r$raw$vz, type = "l", xlab = "z (m)", ylab = "vz (m/s)", main = "Sitnikov phase space")
  })
  output$animation = renderUI({
    r = selected()
    path = tempfile(fileext = ".html")
    on.exit(unlink(path))
    studio_animation(r, path, axes(), display_frame())
    tags$iframe(srcdoc = paste(readLines(path, warn = FALSE), collapse = "\n"),
                 sandbox = "allow-scripts", width = "100%", height = "750", frameborder = "0")
  })
  output$exact = renderText({
    r = selected()
    paste(studio_request_json(r$request), "\nUnits:", r$units,
          "\nCompleted:", r$timestamp, "\nEngine:", r$provenance$engine)
  })
  output$request_download = downloadHandler("request.json", function(file) {
    writeLines(studio_request_json(selected()$request), file)
  })
  output$trajectory_download = downloadHandler("trajectory.csv", function(file) {
    studio_export_trajectory(selected(), file)
  })
  output$diagnostics_download = downloadHandler("diagnostics.csv", function(file) {
    utils::write.csv(diagnostic_report()$series, file, row.names = FALSE)
  })
}

shinyApp(ui, server)
