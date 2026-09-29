# Optional review UI only. Providers cannot access the composer or run controls.
studio_plan_ui = function(id) {
  ns = shiny::NS(id)
  shiny::tagList(
    shiny::h3("Optional experiment planner"),
    shiny::helpText("Describe an experiment to the configured provider, or paste plan JSON. The provider proposes settings only. Review explicit units, backend, integrators and initial conditions before loading the composer. Only the normal Run button invokes the numerical engine."),
    shiny::textAreaInput(ns("prompt"), "Experiment description", rows = 3),
    shiny::actionButton(ns("generate"), "Request a plan"),
    shiny::helpText("No provider is bundled. Without a host-configured adapter, JSON review and all normal Studio workflows remain available. A provider receives only your submitted description and the public planning schema."),
    shiny::textAreaInput(ns("json"), "Experiment-plan JSON (editable)", rows = 12),
    shiny::actionButton(ns("validate"), "Validate and review"),
    shiny::textOutput(ns("status")),
    shiny::tableOutput(ns("issues")),
    shiny::h4("Resolved numerical requests"), shiny::tableOutput(ns("preview")),
    shiny::verbatimTextOutput(ns("details")),
    shiny::uiOutput(ns("approval")))
}

studio_plan_server = function(id, on_confirm, provider = NULL) {
  if (!is.function(on_confirm)) stop("on_confirm must be a trusted application callback.")
  shiny::moduleServer(id, function(input, output, session) {
    review = shiny::reactiveVal(NULL)
    reviewed_json = shiny::reactiveVal(NULL)
    reviewed_prompt = shiny::reactiveVal(NULL)
    approved_json = shiny::reactiveVal(NULL)
    status = shiny::reactiveVal("No plan reviewed. Nothing will run automatically.")
    clear_approval = function() {
      approved_json(NULL)
      shiny::updateCheckboxInput(session, "approve", value = FALSE)
    }
    set_review = function(result, json) {
      clear_approval()
      review(result); reviewed_json(json); reviewed_prompt(input$prompt)
      status(switch(result$status,
        ready = "Ready for review. Confirm the exact settings before loading the composer.",
        needs_clarification = "Clarification required: fill the listed fields, then validate again. Nothing can be loaded yet.",
        provider_error = "Provider failed. No plan was prepared.",
        "Invalid plan. Correct the listed errors and validate again."))
    }
    shiny::observeEvent(list(input$json, input$prompt), {
      if (!identical(input$json, reviewed_json()) || !identical(input$prompt, reviewed_prompt())) {
        review(NULL); clear_approval()
        status("Inputs changed. Validate and review the current plan before confirming.")
      }
    }, ignoreInit = TRUE, priority = 100)
    shiny::observeEvent(input$generate, {
      review(NULL); clear_approval()
      if (!is.function(provider)) {
        status("No provider configured. Paste plan JSON or use the normal composer.")
        return()
      }
      tryCatch({
        result = plan_experiment(input$prompt, provider)
        json = if (is.null(result$plan)) "" else as.character(jsonlite::toJSON(result$plan,
          auto_unbox = TRUE, null = "null", digits = I(17), pretty = TRUE))
        set_review(result, json)
        shiny::updateTextAreaInput(session, "json", value = json)
      }, error = function(e) status(paste("Planning failed:", conditionMessage(e))))
    })
    shiny::observeEvent(input$validate, set_review(parse_experiment_plan(input$json), input$json))
    shiny::observeEvent(input$approve, {
      if (isTRUE(input$approve) && identical(review()$status, "ready") &&
          identical(input$json, reviewed_json()) && identical(input$prompt, reviewed_prompt()))
        approved_json(reviewed_json()) else approved_json(NULL)
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$confirm, {
      tryCatch({
        if (!isTRUE(input$approve) || is.null(approved_json()) ||
            !identical(input$json, approved_json()) || !identical(input$prompt, reviewed_prompt()))
          stop("Review and approve the current plan before loading it.")
        # Decode and validate again; a stale UI status is not authorization.
        checked = parse_experiment_plan(input$json)
        if (!identical(checked$status, "ready")) stop("The plan is no longer ready. Validate again.")
        requests = experiment_plan_requests(checked$plan)
        on_confirm(checked$plan, requests)
        clear_approval()
        status("Confirmed plan loaded into the composer. Use its normal Run button to execute the existing engine.")
      }, error = function(e) status(conditionMessage(e)))
    })
    output$status = shiny::renderText(status())
    output$issues = shiny::renderTable({
      r = review(); shiny::req(r)
      rbind(r$errors, r$clarifications)
    })
    output$preview = shiny::renderTable({
      r = review(); shiny::req(r, r$preview)
      preview = r$preview
      for (name in c("duration", "timestep")) preview[[name]] = format(preview[[name]], digits = 17)
      preview
    })
    output$details = shiny::renderText({
      r = review(); shiny::req(r, r$requests)
      # Render as escaped text, never HTML or executable instructions.
      paste("Requested plots:", paste(unlist(r$plan$plots), collapse = ", "),
        "\nExact resolved initial conditions and requests:\n",
        as.character(jsonlite::toJSON(lapply(r$requests, unclass), auto_unbox = TRUE,
          matrix = "rowmajor", digits = I(17), pretty = TRUE)))
    })
    output$approval = shiny::renderUI({
      shiny::req(identical(review()$status, "ready"))
      shiny::tagList(
        shiny::checkboxInput(session$ns("approve"), "I reviewed the units, initial conditions, methods and run sizes.", FALSE),
        shiny::actionButton(session$ns("confirm"), "Confirm and load into composer"))
    })
    invisible(list(review = review, status = status))
  })
}
