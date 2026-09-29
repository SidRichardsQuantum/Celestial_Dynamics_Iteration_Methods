# Optional data-only planning boundary. No provider SDK, integration or execution.
experiment_plan_schema = function() {
  catalog = studio_catalog(); presets = studio_presets()
  # Only these catalogue durations are documented reference orbital periods.
  periodic = intersect(c("figure_eight", "circular_two_body", "eccentric_two_body",
    "earth_moon_binary", "equal_mass_binary", "lagrange_triangle"), names(presets))
  systems = lapply(names(catalog), function(id) {
    spec = catalog[[id]]
    exemplar = Filter(function(p) identical(p$request$system, id), presets)[[1]]$request
    list(model = simulation_dynamics(exemplar)$model$id, integrators = spec$integrators,
      parameters = lapply(spec$parameters, function(p) unclass(p)),
      plots = c("trajectory", spec$diagnostics), units = spec$units)
  })
  names(systems) = names(catalog)
  list(format = "Celestial Dynamics typed experiment-plan schema", version = 1L,
    fields = list(
      schema_version = list(type = "integer", required = TRUE, value = 1L),
      kind = list(type = "string", values = c("simulate", "compare"), essential = TRUE),
      system = list(type = "string", values = names(catalog), essential = TRUE),
      model = list(type = "string", values = names(cd_model_definitions()), essential = TRUE),
      preset = list(type = "string or null (custom initial conditions)", values = names(presets), essential = TRUE),
      parameters = list(type = "object", default = "empty object", fields = "system parameter schema; overrides preset values"),
      integrators = list(type = "string array", values = names(studio_integrators()), unique = TRUE,
        min_items = 1L, max_items = length(studio_integrators()), essential = TRUE),
      duration = list(type = "time object", fields = c("value", "unit"), essential = TRUE),
      timestep = list(type = "time object", fields = c("value", "unit"), essential = TRUE),
      plots = list(type = "string array", values = unique(unlist(lapply(systems, `[[`, "plots"))),
        unique = TRUE, essential = TRUE)),
    time_object = list(value = "positive finite number", unit = c("model_time", "preset_periods")),
    systems = systems,
    presets = lapply(presets, function(p) list(system = p$request$system, description = p$description)),
    reference_periods = setNames(lapply(periodic, function(id) presets[[id]]$request$duration), periodic),
    policy = list(additional_fields = FALSE, unresolved = "Omit or use null for essential values; ask user. Null preset explicitly means custom.",
      parameters = "Only registered parameter names and numeric shapes; no expressions. Empty arrays/objects are distinct JSON types.",
      units = "No inferred units. Reference periods require an unchanged named preset. SI catalogue times are seconds.",
      aliases = "Use canonical IDs only. Leapfrog is not an ID; Verlet is the available velocity-Verlet method, requiring explicit user review.",
      compatibility = "A preset can use another backend only for the same model with compatible parameters, explicitly specified by system.",
      confirmation = "Every ready plan must be reviewed in the UI before loading; planning never executes a simulation.",
      limits = "100000 steps, 256 bodies, 2000000 position values, 10000000 pair-steps per run; <=500000 total steps.",
      forbidden = "No code, commands, paths, credentials, trajectories, generated diagnostics or provider-selected tools."))
}

cd_plan_object = function(x, path) {
  if (!is.list(x) || is.object(x) || is.null(names(x)) || anyNA(names(x)) ||
      any(!nzchar(names(x))) || anyDuplicated(names(x))) stop(path, " must be an object with unique fields.")
}

cd_plan_fields = function(x, allowed, path) {
  cd_plan_object(x, path)
  if (any(!names(x) %in% allowed)) stop(path, " contains unknown fields: ", paste(setdiff(names(x), allowed), collapse = ", "))
}

# Check plain R data before traversing it. No S3 coercion, calls, environments,
# functions, formulas, matrix attributes or deserialization of provider objects.
cd_plan_data = function(x, depth = 0L) {
  if (depth > 12L) stop("Plan nesting exceeds 12 levels.")
  if (is.object(x) || !typeof(x) %in% c("NULL", "list", "character", "integer", "double", "logical") ||
      !is.null(dim(x)) || any(!names(attributes(x)) %in% "names")) stop("Plans must contain plain data only.")
  if (!is.null(names(x)) && (anyNA(names(x)) || any(nchar(names(x)) > 64) ||
      any(!nzchar(names(x))) || anyDuplicated(names(x)))) stop("Object fields must be unique nonempty names of at most 64 characters.")
  if (is.list(x)) {
    if (length(x) > 4096) stop("Plan array is too large.")
    for (item in x) cd_plan_data(item, depth + 1L)
  } else if (!is.null(x)) {
    if (length(x) > 4096 || anyNA(x)) stop("Plan values are missing or too large.")
    if (is.numeric(x) && any(!is.finite(x))) stop("Plan numbers must be finite.")
    if (is.character(x) && any(nchar(x, type = "bytes") > 256)) stop("Plan strings exceed 256 bytes.")
  }
  invisible(TRUE)
}

cd_plan_strings = function(x, path, allowed, empty = FALSE) {
  if (is.list(x) && is.null(names(x)) && all(vapply(x, function(v)
      is.character(v) && length(v) == 1L && is.null(names(v)), logical(1))))
    x = unlist(x, use.names = FALSE)
  if (is.null(x) && empty) x = character()
  if (!is.character(x) || !is.null(names(x)) || (!empty && !length(x)) ||
      anyDuplicated(x) || any(!x %in% allowed)) stop(path, " must be an array of distinct supported IDs.")
  x
}

cd_plan_parameter = function(x, spec, path, json = FALSE) {
  number = function(value) is.numeric(value) && length(value) == 1L && is.null(names(value))
  array = function(value) is.list(value) && is.null(names(value)) && length(value) > 0
  if (spec$type == "number") {
    if (!number(x)) stop(path, " must be a number.")
  } else if (spec$type == "matrix") {
    if (!array(x) || !all(vapply(x, array, logical(1))) ||
        length(unique(lengths(x))) != 1L ||
        !all(vapply(unlist(x, recursive = FALSE), number, logical(1)))) stop(path, " must be a rectangular array of numeric row arrays.")
    x = do.call(rbind, lapply(x, unlist, use.names = FALSE))
  } else {
    check = if (spec$type == "labels") function(v) is.character(v) && length(v) == 1L && is.null(names(v)) else number
    if (json && !is.list(x)) stop(path, " must be a JSON array.")
    if (is.atomic(x) && is.null(names(x))) x = as.list(x)
    if (!array(x) || !all(vapply(x, check, logical(1)))) stop(path, " has the wrong array element type.")
    x = unlist(x, use.names = FALSE)
  }
  if (!is.null(spec$length) && length(x) != spec$length) stop(path, " has incorrect length.")
  if (isTRUE(spec$positive) && any(x <= 0)) stop(path, " must be positive.")
  x
}

cd_plan_failure = function(message, status = "invalid") {
  list(status = status, errors = data.frame(field = "plan", message = message),
    clarifications = data.frame(field = character(), message = character()),
    plan = NULL, requests = NULL, preview = NULL)
}

validate_experiment_plan = function(plan) {
  tryCatch(cd_validate_experiment_plan(plan), error = function(e) cd_plan_failure(conditionMessage(e)))
}

cd_validate_experiment_plan = function(plan, json = FALSE) {
  if (as.numeric(utils::object.size(plan)) > 262144) stop("Plan exceeds the 256 KiB data limit.")
  cd_plan_data(plan)
  schema = experiment_plan_schema()
  cd_plan_fields(plan, names(schema$fields), "plan")
  if (!is.numeric(plan$schema_version) || length(plan$schema_version) != 1L ||
      !is.null(names(plan$schema_version)) || plan$schema_version != 1)
    stop("schema_version must be the number 1.")
  missing = list()
  ask = function(field, message) missing[[length(missing) + 1L]] <<- data.frame(field = field, message = message)
  scalar_id = function(name, values) {
    value = plan[[name]]
    if (is.null(value)) { ask(name, paste("Choose", name, "explicitly.")); return(NULL) }
    if (!is.character(value) || length(value) != 1L || !is.null(names(value)) || !value %in% values)
      stop(name, " must be a supported ID.")
    value
  }
  kind = scalar_id("kind", c("simulate", "compare"))
  system = scalar_id("system", names(schema$systems))
  model = scalar_id("model", schema$fields$model$values)
  preset = plan$preset
  if (!"preset" %in% names(plan)) ask("preset", "Choose a named preset or null for custom initial conditions.") else
    if (!is.null(preset) && (!is.character(preset) || length(preset) != 1L || !preset %in% names(schema$presets)))
      stop("preset must be an existing preset ID or null for custom initial conditions.")
  methods = NULL; plots = NULL
  if (is.null(plan$integrators)) ask("integrators", "Choose the integrator IDs to run.") else
    methods = cd_plan_strings(plan$integrators, "integrators", schema$fields$integrators$values)
  if (is.null(plan$plots)) ask("plots", "Choose plot IDs or an empty array for no plots.") else
    plots = cd_plan_strings(plan$plots, "plots", schema$fields$plots$values, empty = TRUE)
  if (!is.null(kind) && !is.null(methods) &&
      ((kind == "simulate" && length(methods) != 1L) || (kind == "compare" && length(methods) < 2L)))
    stop("simulate requires one integrator; compare requires at least two.")
  if (!is.null(system)) {
    spec = schema$systems[[system]]
    if (!is.null(model) && model != spec$model) stop("model is incompatible with system.")
    if (any(!methods %in% spec$integrators)) stop("integrators are incompatible with system; choose a supported backend explicitly.")
    if (any(!plots %in% spec$plots)) stop("plots are incompatible with system diagnostics.")
  }
  parameters = setNames(list(), character())
  if ("parameters" %in% names(plan)) {
    allowed = if (is.null(system)) unique(unlist(lapply(schema$systems, function(s) names(s$parameters)))) else names(spec$parameters)
    cd_plan_fields(plan$parameters, allowed, "parameters")
    for (name in names(plan$parameters)) {
      value = plan$parameters[[name]]
      field = if (!is.null(system)) spec$parameters[[name]] else
        Filter(function(s) name %in% names(s$parameters), schema$systems)[[1]]$parameters[[name]]
      if (is.null(value)) ask(paste0("parameters.", name), "Supply an explicit parameter value or remove this override.") else
        parameters[[name]] = cd_plan_parameter(value, field, paste0("parameters.", name), json)
    }
  }
  if (!is.null(preset)) {
    base = studio_preset(preset)
    if (!is.null(system) && schema$systems[[base$system]]$model != spec$model)
      stop("Preset and selected system use different physical models.")
    parameters = utils::modifyList(base$parameters, parameters)
  }
  if (!is.null(system)) {
    if (any(!names(parameters) %in% names(spec$parameters))) stop("Preset parameters are incompatible with system.")
    for (name in names(spec$parameters)) {
      if (is.null(parameters[[name]]) && isTRUE(spec$parameters[[name]]$required))
        ask(paste0("parameters.", name), paste("Supply required", name, "or choose a preset."))
    }
  }
  time_value = function(name) {
    value = plan[[name]]
    if (is.null(value)) { ask(name, "Supply a positive value and explicit time unit."); return(NULL) }
    cd_plan_fields(value, c("value", "unit"), name)
    if (is.null(value$value)) ask(paste0(name, ".value"), "Supply a positive time value.") else
      if (!is.numeric(value$value) || length(value$value) != 1L || !is.null(names(value$value)) || value$value <= 0)
        stop(name, ".value must be a positive finite number.")
    if (is.null(value$unit)) { ask(paste0(name, ".unit"), "Choose model_time or preset_periods; units are never inferred."); return(NULL) }
    if (!is.character(value$unit) || length(value$unit) != 1L || !value$unit %in% schema$time_object$unit)
      stop(name, ".unit must be model_time or preset_periods.")
    factor = 1
    if (value$unit == "preset_periods") {
      if (is.null(preset)) { ask(name, "Choose a preset with a documented reference period, or use model_time."); return(NULL) }
      if (!preset %in% names(schema$reference_periods)) stop("This preset has no documented reference period; use model_time.")
      if (length(plan$parameters)) stop("preset_periods cannot be used with parameter overrides; specify model_time explicitly.")
      factor = schema$reference_periods[[preset]]
    }
    if (is.null(value$value)) return(NULL)
    resolved = value$value * factor
    if (!is.finite(resolved)) stop(name, " overflows model time units.")
    resolved
  }
  duration = time_value("duration"); timestep = time_value("timestep")
  if (length(missing)) return(list(status = "needs_clarification",
    errors = data.frame(field = character(), message = character()), clarifications = unique(do.call(rbind, missing)),
    plan = plan, requests = NULL, preview = NULL))
  # This is the sole conversion boundary. Existing validators enforce shape,
  # collision, compatibility and execution budgets. No integration occurs here.
  requests = setNames(lapply(methods, function(method)
    simulation_request(system, method, parameters, duration, timestep)), methods)
  if (sum(vapply(requests, function(r) round(r$duration / r$timestep), numeric(1))) > 500000)
    stop("Plan exceeds the 500000 total-step limit.")
  # Resolve model through the real adapter, rather than trusting the proposed ID.
  if (any(vapply(requests, function(r) simulation_dynamics(r)$model$id != model, logical(1))))
    stop("Resolved numerical model does not match the proposed model.")
  preview = data.frame(system = system, model = model, integrator = methods,
    duration = duration, timestep = timestep, steps = round(duration / timestep),
    units = schema$systems[[system]]$units)
  list(status = "ready", errors = data.frame(field = character(), message = character()),
    clarifications = data.frame(field = character(), message = character()),
    plan = plan, requests = requests, preview = preview)
}

parse_experiment_plan = function(text) {
  tryCatch({
    if (!is.character(text) || length(text) != 1L || is.na(text) ||
        nchar(text, type = "bytes") > 65536) stop("Provider output must be one JSON string of at most 64 KiB.")
    if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install optional jsonlite to decode experiment-plan JSON.")
    # Bound JSON nesting before decoding. Quotes/escapes are tracked as JSON
    # lexical data; this is never an R parser and never a filename or URL loader.
    depth = 0L; quoted = FALSE; escaped = FALSE
    for (ch in strsplit(text, "", fixed = TRUE)[[1]]) {
      if (quoted) {
        if (escaped) escaped = FALSE else if (ch == "\\") escaped = TRUE else if (ch == '"') quoted = FALSE
      } else if (ch == '"') quoted = TRUE else if (ch %in% c("{", "[")) {
        depth = depth + 1L
        if (depth > 12L) stop("Plan nesting exceeds 12 levels.")
      } else if (ch %in% c("}", "]")) depth = depth - 1L
    }
    # parse_json permits comments in some jsonlite versions; enforce strict
    # JSON syntax first, then retain object/array types and duplicate keys.
    if (!isTRUE(jsonlite::validate(text))) stop("Malformed JSON; supply a single JSON object without comments, prose or code fences.")
    value = tryCatch(jsonlite::parse_json(text, simplifyVector = FALSE),
      error = function(e) stop("Malformed JSON; supply a single JSON object without prose or code fences."))
    cd_plan_object(value, "plan")
    for (name in c("integrators", "plots")) {
      if (!is.null(value[[name]]) && (!is.list(value[[name]]) || !is.null(names(value[[name]]))))
        stop(name, " must be a JSON array, not a scalar or object.")
    }
    cd_validate_experiment_plan(value, json = TRUE)
  }, error = function(e) cd_plan_failure(conditionMessage(e)))
}

# Host-supplied adapter is trusted application code; its output is untrusted JSON.
# Providers receive no filesystem, shell, solver callbacks or application secrets.
plan_experiment = function(prompt, provider) {
  if (!is.character(prompt) || length(prompt) != 1L || is.na(prompt) ||
      !nzchar(trimws(prompt)) || nchar(prompt, type = "bytes") > 8000)
    stop("prompt must be nonempty text of at most 8000 bytes.")
  if (!is.function(provider)) stop("provider must be an explicitly supplied adapter function(prompt, schema).")
  schema = experiment_plan_schema()
  response = tryCatch(provider(prompt = prompt, schema = schema), error = identity)
  if (inherits(response, "error")) return(cd_plan_failure("Provider failed; no experiment was prepared.", "provider_error"))
  parse_experiment_plan(response)
}

mock_experiment_provider = function(response) {
  if (!is.character(response) || length(response) != 1L || is.na(response)) stop("Mock response must be one JSON string.")
  force(response)
  function(prompt, schema) response
}

experiment_plan_requests = function(plan) {
  # A class or previous validation flag is never proof of validity.
  result = validate_experiment_plan(plan)
  if (!identical(result$status, "ready")) stop("Plan is not ready: ",
    paste(c(result$errors$message, result$clarifications$message), collapse = " "))
  result$requests
}
