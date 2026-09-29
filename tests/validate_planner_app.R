if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_experiment_planning()
cd_source("R/studio/experiment_planner.R")
if (all(vapply(c("shiny", "jsonlite", "callr"), requireNamespace, logical(1), quietly = TRUE))) local({
  json = paste(readLines(cd_path("examples/planning/figure_eight_plan.json")), collapse = "\n")
  calls = 0L; received = NULL
  callback = function(plan, requests) { calls <<- calls + 1L; received <<- requests }
  shiny::testServer(studio_plan_server,
    args = list(on_confirm = callback, provider = mock_experiment_provider(json)), {
    session$setInputs(prompt = "Compare figure-eight methods", json = '{"schema_version":1}', validate = 1)
    stopifnot(review()$status == "needs_clarification", is.null(review()$requests),
      grepl("Clarification required", status()), calls == 0)
    session$setInputs(approve = TRUE, confirm = 1)
    stopifnot(calls == 0, grepl("Review and approve", status()))
    session$setInputs(json = json, validate = 2)
    stopifnot(review()$status == "ready", nzchar(output$preview),
      grepl("energy_relative_drift", output$details), calls == 0)
    session$setInputs(approve = FALSE)
    session$setInputs(approve = TRUE, confirm = 2)
    stopifnot(calls == 1, identical(names(received), c("Verlet", "RK4")),
      grepl("normal Run button", status()), is.null(approved_json()))
    # Confirmation is single use, and edits invalidate a previous approval.
    session$setInputs(confirm = 3)
    stopifnot(calls == 1)
    session$setInputs(validate = 3, approve = FALSE)
    session$setInputs(approve = TRUE)
    session$setInputs(json = sub('"value": 20', '"value": 10', json, fixed = TRUE), confirm = 4)
    stopifnot(calls == 1, is.null(review()), is.null(approved_json()))
    session$setInputs(validate = 4)
    stopifnot(review()$status == "ready")
    session$setInputs(approve = FALSE)
    session$setInputs(approve = TRUE)
    session$setInputs(prompt = "A different experiment", confirm = 5)
    stopifnot(calls == 1, is.null(review()))
    session$setInputs(generate = 1)
    stopifnot(review()$status == "ready", calls == 1, is.null(approved_json()))
    session$setInputs(json = '{"schema_version":1,"code":"stop(1)"}', validate = 5)
    stopifnot(review()$status == "invalid", grepl("Invalid plan", status()), calls == 1)
  })
  shiny::testServer(studio_plan_server, args = list(on_confirm = callback), {
    session$setInputs(prompt = "test", generate = 1)
    stopifnot(grepl("No provider configured", status()), calls == 1)
    session$setInputs(json = json, validate = 1)
    stopifnot(review()$status == "ready")
  })
  old = Sys.getenv(c("CELESTIAL_STUDIO_PLANNING", "CELESTIAL_STUDIO_HISTORY"), unset = NA_character_)
  old_provider = getOption("celestial.experiment_provider")
  directory = tempfile("planner-app-")
  on.exit({
    for (name in names(old)) if (is.na(old[[name]])) Sys.unsetenv(name) else do.call(Sys.setenv, setNames(list(old[[name]]), name))
    options(celestial.experiment_provider = old_provider)
    unlink(directory, recursive = TRUE)
  })
  Sys.setenv(CELESTIAL_STUDIO_HISTORY = directory)
  Sys.unsetenv("CELESTIAL_STUDIO_PLANNING")
  # A configured provider must never be invoked while the feature is disabled.
  options(celestial.experiment_provider = function(...) stop("Provider should not be invoked"))
  disabled = new.env(parent = globalenv()); sys.source(cd_path("app/app.R"), disabled)
  stopifnot(!disabled$planning_enabled, !grepl("Optional experiment planner", as.character(disabled$ui), fixed = TRUE))
  Sys.setenv(CELESTIAL_STUDIO_PLANNING = "1")
  enabled = new.env(parent = globalenv()); sys.source(cd_path("app/app.R"), enabled)
  stopifnot(enabled$planning_enabled, grepl("Optional experiment planner", as.character(enabled$ui), fixed = TRUE))
  shiny::testServer(enabled$server, {
    session$setInputs(`planner-prompt` = "Use this explicit plan", `planner-json` = json, `planner-validate` = 1)
    stopifnot(is.null(active_job()), length(history_records()) == 0)
    session$setInputs(`planner-approve` = TRUE)
    session$setInputs(`planner-confirm` = 1)
    stopifnot(configuration()$system == "n_body", identical(planned_selection()$integrators, c("Verlet", "RK4")),
      identical(configuration()$parameters, studio_preset("figure_eight")$parameters),
      is.null(active_job()), length(history_records()) == 0,
      grepl("Confirmed plan loaded", status()),
      grepl('value="Verlet" selected', output$settings$html, fixed = TRUE),
      grepl('value="RK4" selected', output$settings$html, fixed = TRUE))
  })
  cat("Optional planner UI: clarification, confirmation, stale edits, disabled mode and composer handoff passed.\n")
}) else cat("Optional planner app checks skipped: install shiny, jsonlite and callr.\n")
