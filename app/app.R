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
    if (is.numeric(table[[name]]) && !name %in% c("steps")) {
      table[[name]] = format(table[[name]], digits = 6, scientific = TRUE, trim = TRUE)
    }
  }
  table
}

ui = fluidPage(
  tags$head(tags$script(HTML("$(document).on('shiny:connected', function() {
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
      actionButton("run", "Run simulation / comparison", class = "btn-primary"),
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
          helpText("SI invariants: energy in J, angular momentum in kg m²/s, momentum in kg m/s. Orbital semi-major axis is in m; eccentricity and relative drift are dimensionless. CR3BP Jacobi uses normalized units; Sitnikov specific energy uses m²/s². Relative drift is undefined for a zero initial invariant."),
          plotOutput("phase", height = "350px")),
        tabPanel("Animation", helpText("Playback covers the full run in 20 seconds at 1x and stops at the end. Fit a body, zoom, or follow it using the camera controls. For Trojan libration, choose the rotating frame and fit Test particle; the primaries may then lie off-screen."),
          uiOutput("animation")),
        tabPanel("Parameters & export", verbatimTextOutput("exact"),
          downloadButton("request_download", "Request JSON"),
          downloadButton("trajectory_download", "Trajectory CSV"),
          downloadButton("diagnostics_download", "Diagnostics CSV"))
      )),
      tabPanel("Comparison",
        helpText("Same physical problem and duration required. Runtime measures only a single solver call. Undefined relative drift remains NA."),
        tags$div(style = "overflow-x:auto", tableOutput("comparison_table")),
        uiOutput("comparison_metric_control"),
        plotOutput("comparison_orbit", height = "480px"),
        plotOutput("comparison_diagnostic", height = "400px"))
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
      if (field$type == "number") {
        preciseNumericInput(paste0("parameter_", name), field$label, value = value)
      } else {
        textAreaInput(paste0("parameter_", name), paste0(field$label, " (JSON)"),
          value = as.character(jsonlite::toJSON(value, digits = I(17), matrix = "rowmajor")),
          rows = if (field$type == "matrix") 3 else 2, width = "100%")
      }
    })
    tagList(p(spec$description), helpText(spec$units),
      selectInput("integrators", "Integrator(s); select several to compare",
                  choices = spec$integrators, selected = config$integrator, multiple = TRUE),
      helpText(paste(vapply(studio_integrators()[spec$integrators], function(m) {
        paste0(m$name, ": order ", m$order, ", ",
          if (m$adaptive) "adaptive" else "fixed step", ", ",
          if (m$symplectic) "symplectic" else "non-symplectic")
      }, character(1)), collapse = "; ")),
      controls,
      preciseNumericInput("duration", "Duration (system time units)", config$duration),
      preciseNumericInput("timestep", "Timestep (duration must be an integer multiple)", config$timestep),
      helpText("Up to 100,000 steps, 256 massive bodies, 2 million position values and 10 million pair-steps per run. Close encounters may require a much smaller timestep."))
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
      stages = vapply(snapshot$records, function(r) paste(r$request$integrator, r$stage), character(1))
      status(paste("Background batch:", paste(stages, collapse = " | ")))
    } else {
      active_job(NULL)
      session$sendCustomMessage("studioBusy", FALSE)
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
      base = configuration()
      spec = catalog[[base$system]]
      if (!length(input$integrators)) stop("Select at least one integrator.")
      parameters = lapply(names(spec$parameters), function(name) {
        field = spec$parameters[[name]]
        value = input[[paste0("parameter_", name)]]
        if (field$type != "number") {
          value = jsonlite::fromJSON(value, simplifyVector = TRUE)
        }
        value
      }) |> setNames(names(spec$parameters))
      request = simulation_request(base$system, input$integrators[1], parameters,
                                   input$duration, input$timestep)
      # Validate every comparison before spending time on the first one.
      requests = lapply(input$integrators, function(method) {
        args = unclass(request)
        args$integrator = method
        do.call(simulation_request, args)
      })
      job = studio_start_job(requests, history_directory, root = cd_project_root())
      active_job(job)
      session$sendCustomMessage("studioBusy", TRUE)
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
  observeEvent(input$compare_saved, {
    tryCatch({
      results = setNames(lapply(picked(), studio_load_result),
        vapply(history_records()[picked()], function(r) paste(r$id, r$request$integrator), character(1)))
      studio_comparison(results)
      compared(results)
      updateTabsetPanel(session, "workspace", selected = "Comparison")
    }, error = function(e) { compared(NULL); showNotification(conditionMessage(e), type = "error") })
  })
  output$comparison_table = renderTable({ req(compared()); scientific_table(studio_comparison(compared())) }, digits = 8)
  output$comparison_metric_control = renderUI({
    req(compared())
    selectInput("comparison_metric", "Conserved quantity or drift", names(compared()[[1]]$diagnostics)[-1],
      selected = grep("relative_drift", names(compared()[[1]]$diagnostics), value = TRUE)[1])
  })
  output$comparison_orbit = renderPlot({
    req(compared())
    studio_plot_trajectories(compared(), if (compared()[[1]]$request$system == "sitnikov") c(1L, 3L) else c(1L, 2L))
  })
  output$comparison_diagnostic = renderPlot({
    req(compared(), input$comparison_metric)
    studio_plot_diagnostic(compared(), input$comparison_metric)
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
  output$diagnostic_control = renderUI({
    req(runs())
    selectInput("metric", "Diagnostic", catalog[[selected()$request$system]]$diagnostics)
  })
  output$diagnostic = renderPlot({
    req(runs(), input$metric)
    req(input$metric %in% names(selected()$diagnostics))
    studio_plot_diagnostic(runs(), input$metric)
  })
  output$summary = renderTable({
    req(runs())
    scientific_table(do.call(rbind, lapply(runs(), function(r) {
      data.frame(integrator = r$request$integrator, runtime_seconds = r$runtime_seconds,
        metric = names(r$diagnostic_summary),
        initial = vapply(r$diagnostic_summary, function(x) x$initial, numeric(1)),
        final = vapply(r$diagnostic_summary, function(x) x$final, numeric(1)),
        max_absolute_change = vapply(r$diagnostic_summary, function(x) x$max_absolute_change, numeric(1)))
    })))
  }, digits = 8)
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
    utils::write.csv(selected()$diagnostics, file, row.names = FALSE)
  })
}

shinyApp(ui, server)
