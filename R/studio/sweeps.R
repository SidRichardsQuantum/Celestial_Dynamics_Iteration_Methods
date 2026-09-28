# Bounded Cartesian experiments. All members use the ordinary request and runner.
sweep_parameters = function(experiment) {
  experiment = studio_validate_request(experiment)
  p = experiment$parameters
  rows = list()
  add = function(parameter, label, value, field, body = NA_integer_, coordinate = NA_integer_,
                 mode = "replace", target = parameter) {
    rows[[length(rows) + 1L]] <<- data.frame(parameter = parameter, label = label,
      value = value, field = field, body = body, coordinate = coordinate, mode = mode, target = target)
  }
  add("timestep", "Timestep (must divide duration)", experiment$timestep, "timestep")
  if (!is.null(p$masses)) {
    add("mass_ratio", "Mass ratio m2/m1 (m1 fixed)", p$masses[2] / p$masses[1],
      "mass_ratio", target = "mass[1]|mass[2]")
    for (body in seq_along(p$masses)) add(paste0("mass[", body, "]"), paste("Mass", body),
      p$masses[body], "masses", body)
  } else if (experiment$system == "restricted_three_body") {
    add("mass_ratio", "Primary mass ratio m2/m1 (normalized total mass fixed)",
      p$mu / (1 - p$mu), "mass_ratio", target = "mu")
    add("mu", "CR3BP secondary / total mass", p$mu, "mu")
  } else {
    for (field in c("primary_mass", "primary_radius")) add(field, gsub("_", " ", field), p[[field]], field)
  }
  state = simulation_dynamics(experiment)$state
  for (kind in c("position", "velocity")) {
    field = if (kind == "position") "positions" else "velocities"
    for (axis in seq_len(ncol(state[[field]]))) for (body in seq_len(nrow(state[[field]]))) {
      key = paste0(kind, "[", body, ",", axis, "]")
      add(key, paste(kind, "body", body, "coordinate", axis), state[[field]][body, axis], field, body, axis)
      add(paste0(kind, "_offset[", body, ",", axis, "]"),
        paste(kind, "offset for body", body, "coordinate", axis), 0, field, body, axis, "offset", key)
    }
  }
  if (experiment$system == "restricted_three_body") {
    add("initial_x", "CR3BP initial x", p$state0[1], "positions", 1L, 1L, target = "position[1,1]")
    add("initial_y", "CR3BP initial y", p$state0[2], "positions", 1L, 2L, target = "position[1,2]")
  }
  do.call(rbind, rows)
}

sweep_metrics = function(experiment) {
  experiment = studio_validate_request(experiment)
  system = experiment$system
  keys = if (system == "restricted_three_body") c("jacobi_drift", "jacobi_relative_drift") else
    if (system == "sitnikov") c("specific_energy_drift", "specific_energy_relative_drift") else
      c("energy_drift", "energy_relative_drift", "angular_momentum_drift", "angular_momentum_relative_drift")
  units = if (system == "restricted_three_body") c("normalized", "1") else
    if (system == "sitnikov") c("m^2/s^2", "1") else c("J", "1", "kg m^2/s", "1")
  length_unit = if (system == "restricted_three_body") "normalized length" else "m"
  time_unit = if (system == "restricted_three_body") "normalized time" else "s"
  data.frame(metric = c(keys, "minimum_separation", "escape_time", "final_position_error", "final_velocity_error", "finite_time_lyapunov"),
    label = c(paste("Maximum absolute", gsub("_", " ", keys)), "Minimum sampled pair separation",
      "First sampled radius crossing time", "Final position error against reference",
      "Final velocity error against reference", "Finite-time directional Lyapunov estimate"),
    units = c(units, length_unit, time_unit, length_unit, paste0(length_unit, "/", time_unit), paste0("1/", time_unit)))
}

studio_sweep_set_parameter = function(request, descriptor, value) {
  field = descriptor$field
  if (field == "timestep") request$timestep = value else if (field == "mass_ratio") {
    if (value <= 0) stop("mass_ratio must be positive.")
    if (request$system == "restricted_three_body") request$parameters$mu = value / (1 + value) else
      request$parameters$masses[2] = request$parameters$masses[1] * value
  } else if (field == "masses") request$parameters$masses[descriptor$body] = value else
    if (field %in% c("positions", "velocities")) {
      body = descriptor$body; axis = descriptor$coordinate
      if (request$system == "restricted_three_body") {
        index = axis + if (field == "velocities") 3L else 0L
        if (descriptor$mode == "offset") value = value + request$parameters$state0[index]
        request$parameters$state0[index] = value
      } else if (request$system == "sitnikov") {
        name = if (field == "positions") "z0" else "vz0"
        if (descriptor$mode == "offset") value = value + request$parameters[[name]]
        request$parameters[[name]] = value
      } else {
        if (descriptor$mode == "offset") value = value + request$parameters[[field]][body, axis]
        request$parameters[[field]][body, axis] = value
      }
    } else request$parameters[[field]] = value
  request
}

prepare_parameter_sweep = function(experiment, parameters, metrics = "minimum_separation", metric_options = list()) {
  experiment = studio_validate_request(experiment)
  registry = sweep_parameters(experiment)
  if (!is.list(parameters) || !length(parameters) %in% 1:2 || is.null(names(parameters)) ||
      anyNA(names(parameters)) || anyDuplicated(names(parameters)) || any(!names(parameters) %in% registry$parameter))
    stop("parameters must be a named list of one or two supported sweep parameters.")
  for (values in parameters) if (!is.numeric(values) || is.complex(values) || !is.null(dim(values)) ||
      !length(values) || any(!is.finite(values)) || anyDuplicated(values))
    stop("Each parameter needs distinct finite real numeric values.")
  # Bound the Cartesian product before allocating it or constructing any requests.
  if (prod(lengths(parameters)) > 256) stop("Sweep limit: at most 256 grid points.")
  descriptors = registry[match(names(parameters), registry$parameter), , drop = FALSE]
  targets = strsplit(descriptors$target, "|", fixed = TRUE)
  if (length(targets) == 2 && length(intersect(targets[[1]], targets[[2]])))
    stop("Sweep parameters overlap or depend on the same state/mass component.")
  metric_registry = sweep_metrics(experiment)
  if (!is.character(metrics) || !length(metrics) || anyNA(metrics) || anyDuplicated(metrics) ||
      any(!metrics %in% metric_registry$metric)) stop("Select distinct metrics available for this system; see sweep_metrics().")
  allowed_options = c("escape_radius", "escape_body", "escape_origin", "reference", "lyapunov")
  if (!is.list(metric_options) || (length(metric_options) && (is.null(names(metric_options)) ||
      anyNA(names(metric_options)) || anyDuplicated(names(metric_options)) ||
      any(!names(metric_options) %in% allowed_options)))) stop("Unsupported or duplicate metric_options.")
  if ("escape_time" %in% metrics) {
    cd_model_scalar(metric_options$escape_radius, "escape_radius")
    body = metric_options$escape_body
    count = if (is.null(experiment$parameters$masses)) 1 else length(experiment$parameters$masses)
    if (is.null(body)) body = count
    if (!is.numeric(body) || is.complex(body) || length(body) != 1L || !is.finite(body) ||
        body != floor(body) || !body %in% seq_len(count)) stop("escape_body must identify an integrated body.")
    dimensions = ncol(simulation_dynamics(experiment)$state$positions)
    origin = metric_options$escape_origin
    if (is.null(origin)) origin = rep(0, dimensions)
    if (!is.numeric(origin) || is.complex(origin) || !is.null(dim(origin)) ||
        length(origin) != dimensions || any(!is.finite(origin))) stop("escape_origin must match the integrated coordinate dimensions.")
    metric_options$escape_body = body; metric_options$escape_origin = origin
  }
  if (any(c("final_position_error", "final_velocity_error") %in% metrics)) {
    reference = metric_options$reference
    if (is.character(reference) && length(reference) == 1L && !is.na(reference) && reference == "analytic_circular") {
      if (experiment$system != "two_body") stop("analytic_circular requires a two_body experiment.")
    } else if (inherits(reference, "simulation_result")) {
      metric_options$reference = studio_validate_result(reference)
    } else stop("Final-state error needs reference = 'analytic_circular' or a completed simulation_result.")
  }
  if ("finite_time_lyapunov" %in% metrics) {
    options = metric_options$lyapunov
    allowed = c("epsilon", "direction", "component", "renormalisation_interval", "position_scale", "velocity_scale")
    if (!is.list(options) || is.null(names(options)) || anyNA(names(options)) || anyDuplicated(names(options)) ||
        any(!names(options) %in% allowed) ||
        !all(c("epsilon", "renormalisation_interval", "position_scale", "velocity_scale") %in% names(options)))
      stop("lyapunov options require epsilon, renormalisation_interval, position_scale and velocity_scale; direction or component is optional.")
    for (name in c("epsilon", "renormalisation_interval", "position_scale", "velocity_scale")) cd_model_scalar(options[[name]], name)
  }
  grid = do.call(expand.grid, c(parameters, list(KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)))
  requests = lapply(seq_len(nrow(grid)), function(i) {
    request = experiment
    for (j in seq_along(parameters)) request = studio_sweep_set_parameter(request, descriptors[j, ], grid[[j]][i])
    tryCatch(studio_validate_request(request), error = function(e)
      stop("Invalid sweep point ", i, ": ", conditionMessage(e), call. = FALSE))
  })
  multiplier = if ("finite_time_lyapunov" %in% metrics) 3 else 1
  steps = vapply(requests, function(r) round(r$duration / r$timestep), numeric(1))
  bodies = if (is.null(experiment$parameters$masses)) 3 else length(experiment$parameters$masses)
  dimensions = studio_catalog()[[experiment$system]]$dimensions
  budget = c(runs = nrow(grid), integration_steps = sum(steps) * multiplier,
    position_values = sum(steps + 1) * bodies * dimensions * multiplier,
    pair_steps = sum(steps) * bodies * (bodies - 1) / 2 * multiplier)
  limits = c(runs = 256, integration_steps = 500000, position_values = 4000000, pair_steps = 20000000)
  if (any(budget > limits)) stop("Sweep limit exceeded: ", paste(names(budget)[budget > limits], collapse = ", "),
    ". Reduce grid points, duration or resolution.")
  structure(list(experiment = experiment, parameters = parameters, grid = grid, requests = requests,
    metrics = metrics, metric_options = metric_options, budget = budget, limits = limits,
    parameter_registry = descriptors,
    metric_registry = metric_registry[match(metrics, metric_registry$metric), , drop = FALSE]), class = "parameter_sweep_plan")
}

studio_sweep_metric = function(result, metric, options) {
  if (metric %in% c("final_position_error", "final_velocity_error")) {
    reference = options$reference
    if (identical(reference, "analytic_circular")) reference = studio_circular_reference(result$request,
      tail(result$time, 1), result$provenance$G) else {
      studio_check_comparison_requests(list(result$request, reference$request))
      if (!isTRUE(all.equal(result$model, reference$model, tolerance = 0))) stop("Reference model/constants differ.")
    }
    field = if (metric == "final_position_error") "positions" else "velocities"
    bodies = which(result$model$body_roles != "prescribed_primary")
    delta = result[[field]][length(result$time), bodies, , drop = FALSE] -
      reference[[field]][length(reference$time), bodies, , drop = FALSE]
    delta = matrix(delta, length(bodies))
    return(list(value = max(apply(delta, 1, cd_sensitivity_norm)), status = "completed", message = NA_character_))
  }
  if (metric == "finite_time_lyapunov") {
    analysis = do.call(run_lyapunov_analysis, c(list(experiment = result$request), options$lyapunov))
    return(list(value = analysis$finite_time_exponent, status = "completed", message = NA_character_))
  }
  if (metric == "escape_time") {
    q = if (result$request$system == "sitnikov") matrix(result$positions[, 3, 3], ncol = 1) else
      matrix(result$positions[, options$escape_body, ], nrow = length(result$time))
    distances = apply(sweep(q, 2, options$escape_origin, "-"), 1, cd_sensitivity_norm)
    crossing = which(distances >= options$escape_radius)
    return(list(value = if (length(crossing)) result$time[crossing[1]] else NA_real_,
      status = if (length(crossing)) "completed" else "not_reached",
      message = if (length(crossing)) NA_character_ else "No sampled radius crossing within the integration window."))
  }
  column = if (metric == "minimum_separation") "minimum_pairwise_separation" else metric
  values = result$diagnostics[[column]]
  if (!length(values) || any(!is.finite(values)))
    return(list(value = NA_real_, status = "unavailable", message = "Diagnostic is unavailable or has an undefined/nonfinite reference."))
  list(value = if (metric == "minimum_separation") min(values) else max(abs(values)),
    status = "completed", message = NA_character_)
}

studio_sweep_report = function(plan) {
  count = nrow(plan$grid)
  ids = vapply(seq_len(count), function(i) studio_run_id(), character(1))
  metrics = data.frame(point = seq_len(count))
  for (metric in plan$metrics) metrics[[metric]] = rep(NA_real_, count)
  structure(c(unclass(plan), list(schema_version = 1L, id = paste0("sweep-", studio_run_id()),
    timestamp = studio_run_timestamp(), provenance = studio_run_provenance(),
    runs = data.frame(point = seq_len(count), run_id = ids, path = NA_character_, status = "queued", metric_status = "pending"),
    scalar_metrics = metrics, metric_status = data.frame(point = integer(), metric = character(), status = character(), message = character()),
    failures = data.frame(point = integer(), run_id = character(), stage = character(), metric = character(), error_class = character(), message = character()),
    results = setNames(vector("list", count), ids),
    definitions = list(escape_time = "First stored sample at or beyond a fixed radius about the specified fixed origin, in the native frame; no crossing is NA (not_reached), not infinity. No physical unbinding claim.",
      final_error = "Maximum Euclidean endpoint error over integrated bodies, against a compatible numerical run or analytic circular two-body reference. Position and velocity have separate units.",
      minimum_separation = "Minimum of the existing sampled pair-separation diagnostic, including prescribed primaries for CR3BP/Sitnikov.",
      drift = "Maximum absolute diagnostic drift over stored samples. Relative drift with a zero/near-zero reference is unavailable.",
      lyapunov = "Directional finite-time estimate with periodic resets; no chaos classification.",
      ordering = "Cartesian grid in supplied value order; first parameter varies fastest."))), class = "parameter_sweep")
}

studio_sweep_checkpoint = function(report, path) {
  if (is.null(path)) return(invisible(NULL))
  temporary = tempfile("sweep-", tmpdir = dirname(path))
  on.exit(unlink(temporary))
  saveRDS(report, temporary)
  if (!file.rename(temporary, path)) stop("Could not write sweep checkpoint.")
  invisible(NULL)
}

studio_sweep_initialize = function(report, store_history, directory) {
  ready = FALSE
  on.exit(if (!ready) {
    for (path in report$runs$path[!is.na(report$runs$path)])
      try(studio_job_finish_unpublished(path, "failed", "setup failed", "Sweep setup did not complete."), silent = TRUE)
  })
  if (store_history) {
    studio_require_json()
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    directory = normalizePath(directory, mustWork = TRUE)
    for (i in seq_len(nrow(report$grid))) {
      id = report$runs$run_id[i]
      path = file.path(directory, paste0(id, ".json"))
      event = studio_stage_event("queued")
      studio_write_record(list(schema_version = 4L, id = id, run_id = id, status = "queued", stage = "queued",
        favorite = FALSE, tags = character(), preset = "custom", timestamp = event$timestamp,
        request = unclass(report$requests[[i]]), lifecycle = list(event)), path)
      report$runs$path[i] = path
    }
  }
  ready = TRUE
  report
}

studio_execute_sweep = function(report, store_history, checkpoint = NULL) {
  failure = function(i, stage, message, error_class = "error", metric = NA_character_) {
    report$failures <<- rbind(report$failures, data.frame(point = i, run_id = report$runs$run_id[i],
      stage = stage, metric = metric, error_class = error_class, message = message))
  }
  for (i in seq_len(nrow(report$grid))) {
    report$runs$status[i] = "running"
    studio_sweep_checkpoint(report, checkpoint)
    stage = "validating"
    result = tryCatch(run_simulation(report$requests[[i]], function(value) {
      stage <<- value
      if (store_history) studio_job_update(report$runs$path[i], "running", value)
    }), error = function(e) {
      failure(i, stage, conditionMessage(e), class(e)[1]); NULL
    })
    if (is.null(result)) {
      report$runs$status[i] = "failed"; report$runs$metric_status[i] = "not_run"
      if (store_history) studio_job_update(report$runs$path[i], "failed", stage, tail(report$failures$message, 1))
    } else {
      result$id = report$runs$run_id[i]
      report$runs$status[i] = "completed"
      stored = FALSE
      if (store_history) stored = tryCatch({
        studio_publish_result(result, report$runs$path[i], "custom"); TRUE
      }, error = function(e) {
        failure(i, "history", conditionMessage(e), class(e)[1])
        studio_job_update(report$runs$path[i], "failed", "saving artifacts", conditionMessage(e)); FALSE
      })
      if (!stored) report$results[[i]] = result
      studio_sweep_checkpoint(report, checkpoint)
      statuses = character()
      for (metric in report$metrics) {
        scalar = tryCatch(studio_sweep_metric(result, metric, report$metric_options), error = function(e) {
          failure(i, "metric", conditionMessage(e), class(e)[1], metric)
          list(value = NA_real_, status = "failed", message = conditionMessage(e))
        })
        if (scalar$status == "unavailable") failure(i, "metric", scalar$message, "unavailable", metric)
        report$scalar_metrics[[metric]][i] = scalar$value
        statuses = c(statuses, scalar$status)
        report$metric_status = rbind(report$metric_status, data.frame(point = i, metric = metric,
          status = scalar$status, message = scalar$message))
      }
      report$runs$metric_status[i] = if (all(statuses %in% c("completed", "not_reached"))) "completed" else "partial"
    }
    studio_sweep_checkpoint(report, checkpoint)
  }
  report
}

run_parameter_sweep = function(experiment, parameters, metrics = "minimum_separation", metric_options = list(),
                               store_history = FALSE, directory = ".studio/history") {
  if (!is.logical(store_history) || length(store_history) != 1L || is.na(store_history)) stop("store_history must be TRUE or FALSE.")
  plan = prepare_parameter_sweep(experiment, parameters, metrics, metric_options)
  report = studio_sweep_initialize(studio_sweep_report(plan), store_history, directory)
  studio_execute_sweep(report, store_history)
}

sweep_run = function(sweep, point) {
  if (!inherits(sweep, "parameter_sweep") || !is.numeric(point) || length(point) != 1L ||
      !is.finite(point) || !point %in% seq_len(nrow(sweep$grid))) stop("Select a valid sweep point number.")
  if (sweep$runs$status[point] != "completed") stop("Selected sweep run is not completed.")
  result = sweep$results[[point]]
  if (is.null(result)) result = studio_load_result(sweep$runs$path[point])
  if (!identical(result$id, sweep$runs$run_id[point])) stop("Sweep run identity mismatch.")
  result
}

# One owned worker, sequential execution, atomic checkpoints for partial results.
studio_start_sweep = function(plan, store_history = TRUE, directory = ".studio/history", root = NULL) {
  if (!inherits(plan, "parameter_sweep_plan")) stop("Expected a prepared parameter sweep.")
  if (!requireNamespace("callr", quietly = TRUE)) stop("Install callr for background sweeps.")
  # Revalidate a caller-edited plan before creating history or starting work.
  plan = prepare_parameter_sweep(plan$experiment, plan$parameters, plan$metrics, plan$metric_options)
  if (!is.logical(store_history) || length(store_history) != 1L || is.na(store_history)) stop("store_history must be TRUE or FALSE.")
  report = studio_sweep_initialize(studio_sweep_report(plan), store_history, directory)
  work = tempfile("sweep-job-"); dir.create(work)
  checkpoint = file.path(work, "report.rds")
  studio_sweep_checkpoint(report, checkpoint)
  process = tryCatch(callr::r_bg(function(checkpoint, store_history, root) {
    if (is.null(root)) worker = get("studio_execute_sweep", envir = asNamespace("CelestialDynamicsIterationMethods")) else {
      source(file.path(root, "R/load.R"), local = .GlobalEnv)
      assign(".cd_project_root", root, envir = .GlobalEnv)
      cd_load_studio(); worker = studio_execute_sweep
    }
    worker(readRDS(checkpoint), store_history, checkpoint)
    invisible(NULL)
  }, args = list(checkpoint = checkpoint, store_history = store_history, root = root),
    supervise = TRUE, user_profile = FALSE), error = function(e) {
      for (path in report$runs$path[!is.na(report$runs$path)])
        studio_job_finish_unpublished(path, "failed", "launch failed", conditionMessage(e))
      stop(e)
    })
  list(process = process, checkpoint = checkpoint)
}

studio_poll_sweep = function(job, cancel = FALSE) {
  if (cancel && job$process$is_alive()) {
    job$process$kill(); job$process$wait(5000)
    if (job$process$is_alive()) stop("Sweep worker has not stopped yet.")
  }
  alive = job$process$is_alive()
  report = readRDS(job$checkpoint)
  if (!alive) {
    terminal = if (cancel) "cancelled" else "failed"
    reason = if (cancel) "Sweep cancelled by user/session." else tryCatch({
      job$process$get_result(); "Worker exited before publishing this point."
    }, error = function(e) conditionMessage(e))
    for (i in seq_len(nrow(report$grid))) {
      path = report$runs$path[i]
      # A trajectory may have been published just before the worker was stopped.
      if (!is.na(path)) {
        studio_job_finish_unpublished(path, terminal, terminal, reason)
        record = studio_load_history(path)
        if (record$status == "completed") report$runs$status[i] = "completed"
      }
      if (report$runs$status[i] %in% c("queued", "running")) {
        report$runs$status[i] = terminal
        report$runs$metric_status[i] = "not_run"
        report$failures = rbind(report$failures, data.frame(point = i, run_id = report$runs$run_id[i],
          stage = "worker", metric = NA_character_, error_class = terminal, message = reason))
      } else if (report$runs$status[i] == "completed" && report$runs$metric_status[i] == "pending") {
        report$runs$metric_status[i] = terminal
        report$failures = rbind(report$failures, data.frame(point = i, run_id = report$runs$run_id[i],
          stage = "metric", metric = NA_character_, error_class = terminal, message = reason))
      }
    }
    studio_sweep_checkpoint(report, job$checkpoint)
  }
  list(alive = alive, report = report)
}
