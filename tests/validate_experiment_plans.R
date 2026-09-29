if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_experiment_planning()
local({
  expect_error = function(expr) stopifnot(inherits(tryCatch(force(expr), error = identity), "error"))
  plan = list(schema_version = 1, kind = "compare", system = "n_body",
    model = "newtonian_gravity", preset = "figure_eight", integrators = c("Verlet", "RK4"),
    duration = list(value = 20, unit = "preset_periods"),
    timestep = list(value = 0.001, unit = "preset_periods"), plots = "energy_relative_drift")
  original = plan
  valid = validate_experiment_plan(plan)
  stopifnot(valid$status == "ready", identical(plan, original),
    identical(names(valid$requests), c("Verlet", "RK4")), all(valid$preview$steps == 20000),
    identical(valid$requests[[1]]$parameters, studio_preset("figure_eight")$parameters),
    identical(experiment_plan_requests(plan), valid$requests))
  # Context comes from actual registries; unavailable IDs cannot be advertised.
  schema = experiment_plan_schema()
  stopifnot(identical(schema$fields$system$values, names(studio_catalog())),
    identical(schema$fields$model$values, names(cd_model_definitions())),
    identical(schema$fields$integrators$values, names(studio_integrators())),
    identical(schema$systems$three_body$integrators, "RK4"),
    identical(schema$systems$n_body$integrators, c("RK4", "Verlet")))
  invalid = function(p, pattern = NULL) {
    r = validate_experiment_plan(p)
    stopifnot(r$status == "invalid", is.null(r$requests), is.null(r$preview))
    if (!is.null(pattern)) stopifnot(any(grepl(pattern, r$errors$message, fixed = TRUE)))
    expect_error(experiment_plan_requests(p))
  }
  change = function(name, value) { p = plan; p[name] = list(value); p }
  for (name in c("kind", "system", "model", "preset", "integrators", "plots")) invalid(change(name, "invented"))
  for (name in c("code", "tools", "shell", "trajectory", "diagnostics", "api_key", "output_path")) invalid(change(name, "untrusted"))
  invalid(change("schema_version", "1")); invalid(change("schema_version", 2))
  invalid(change("system", "three_body"), "incompatible")
  invalid(change("model", "softened_gravity"), "incompatible")
  invalid(change("integrators", c("leapfrog", "RK4")))
  invalid(change("integrators", c("RK4", "RK4")))
  invalid(change("integrators", "RK4"), "at least two")
  invalid(change("kind", "simulate"), "one integrator")
  invalid(change("parameters", list(G = 1)), "unknown")
  invalid(change("parameters", list(masses = c(1, -1, 1))), "positive")
  invalid(change("parameters", list(positions = list(list(1, 2), list(1)))), "rectangular")
  invalid(change("parameters", list(masses = c(1, 1, 1))), "overrides")
  invalid(change("duration", list(value = 20, unit = "years")))
  invalid(change("duration", list(value = "20", unit = "preset_periods")))
  invalid(change("duration", list(value = 20, unit = "preset_periods", code = "bad")))
  invalid(change("timestep", list(value = 0, unit = "preset_periods")))
  invalid(change("timestep", list(value = 0.003, unit = "preset_periods")), "integer")
  invalid(change("timestep", list(value = 1e-8, unit = "preset_periods")), "100000")
  invalid(change("timestep", list(value = 0.001, unit = "model_time")), "100000")
  bad_period = plan; bad_period$preset = "pythagorean"
  invalid(bad_period, "no documented reference period")
  for (missing in c("kind", "system", "model", "preset", "integrators", "duration", "timestep", "plots")) {
    p = plan; p[[missing]] = NULL
    r = validate_experiment_plan(p)
    stopifnot(r$status == "needs_clarification", is.null(r$requests), nrow(r$clarifications) > 0)
    expect_error(experiment_plan_requests(p))
  }
  p = plan; p$timestep$unit = NULL
  stopifnot(validate_experiment_plan(p)$status == "needs_clarification",
    "timestep.unit" %in% validate_experiment_plan(p)$clarifications$field)
  # Explicit custom initial conditions must supply all required values.
  custom = plan; custom["preset"] = list(NULL)
  custom$duration = list(value = 1, unit = "model_time")
  custom$timestep = list(value = 0.01, unit = "model_time")
  stopifnot(validate_experiment_plan(custom)$status == "needs_clarification")
  custom$parameters = list(masses = c(1, 1, 1), positions = list(list(-1, 0), list(1, 0), list(0, 1)),
    velocities = list(list(0, 0), list(0, 0), list(0, 0)))
  stopifnot(validate_experiment_plan(custom)$status == "ready")
  collision = custom; collision$parameters$positions[[2]] = collision$parameters$positions[[1]]
  invalid(collision)
  large = custom; large$parameters$masses = rep(1, 257)
  large$parameters$positions = lapply(1:257, function(i) list(i, 0))
  large$parameters$velocities = lapply(1:257, function(i) list(0, 0))
  invalid(large, "256-body")
  for (value in list(function() 1, quote(stop("bad")), new.env(), structure(list(a = 1), class = "evil")))
    invalid(change("parameters", value), "plain data")
  invalid(change("duration", list(value = Inf, unit = "model_time")), "finite")
  # Conversion produces ordinary requests and only the engine produces trajectories.
  short = plan; short$duration$value = 0.002; short$timestep$value = 0.0001
  requests = experiment_plan_requests(short)
  results = lapply(requests, run_simulation)
  stopifnot(all(vapply(results, inherits, logical(1), "simulation_result")),
    all(vapply(results, function(r) length(r$time) == 21, logical(1))),
    all(vapply(results, function(r) "energy_relative_drift" %in% names(r$diagnostics), logical(1))))
  tampered = plan; class(tampered) = "validated_experiment_plan"
  invalid(tampered, "plain data")
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    json = '{"schema_version":1,"kind":"compare","system":"n_body","model":"newtonian_gravity","preset":"figure_eight","parameters":{},"integrators":["Verlet","RK4"],"duration":{"value":20,"unit":"preset_periods"},"timestep":{"value":0.001,"unit":"preset_periods"},"plots":["energy_relative_drift"]}'
    from_json = parse_experiment_plan(json)
    stopifnot(from_json$status == "ready", identical(from_json$requests, valid$requests))
    mock = mock_experiment_provider(json)
    stopifnot(identical(plan_experiment("Compare the known figure-eight methods.", mock)$requests, valid$requests))
    calls = 0
    provider = function(prompt, schema) {
      calls <<- calls + 1
      stopifnot(identical(prompt, "test"), schema$version == 1, "RK4" %in% schema$fields$integrators$values)
      json
    }
    stopifnot(plan_experiment("test", provider)$status == "ready", calls == 1)
    stopifnot(plan_experiment("test", function(prompt, schema) stop("secret-api-key"))$status == "provider_error")
    stopifnot(!grepl("secret-api-key", paste(capture.output(plan_experiment("test",
      function(prompt, schema) stop("secret-api-key"))), collapse = "")))
    for (bad in c("stop('bad')", "https://example.com/request.json", "/tmp/request.json", "[]", "{}",
        paste0("```json\n", json, "\n```"), paste0(json, json),
        '{"schema_version":1,"schema_version":1}',
        '{"schema_version":1/*comment*/}',
        '{"schema_version":1,}',
        '{"schema_version":1,"duration":{"value":1,"value":2}}',
        '{"schema_version":1,"integrators":"RK4"}',
        '{"schema_version":1,"plots":{}}',
        '{"schema_version":1,"parameters":[]}',
        '{"schema_version":1,"parameters":{"masses":1}}',
        '{"schema_version":1,"duration":{"value":NaN}}',
        '{"schema_version":1,"duration":{"value":1e999}}',
        paste(rep("[", 20), collapse = ""), paste(rep("x", 65537), collapse = "")))
      stopifnot(parse_experiment_plan(bad)$status == "invalid")
    stopifnot(plan_experiment("test", mock_experiment_provider('{"schema_version":1}'))$status == "needs_clarification")
    sentinel = tempfile()
    injection = paste0("writeLines('injected', '", sentinel, "')")
    injected = sub('"preset":"figure_eight"', paste0('"preset":', jsonlite::toJSON(injection, auto_unbox = TRUE)), json, fixed = TRUE)
    stopifnot(parse_experiment_plan(injected)$status == "invalid", !file.exists(sentinel))
    stopifnot(plan_experiment("test", function(prompt, schema) list(code = injection))$status == "invalid")
  }
  expect_error(plan_experiment("", function(...) NULL))
  expect_error(plan_experiment("test", "provider code"))
})
cat("Experiment-plan schema, providers, clarification, malicious inputs, budgets and engine conversion passed.\n")
