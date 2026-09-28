# Integrator Lab builds on ordinary requests, jobs, history records and the
# existing compatibility/table API. Manifests contain links, never trajectories.
studio_integrator_requests = function(request, integrators, settings = list()) {
  request = studio_validate_request(request)
  if (!is.character(integrators) || !length(integrators) || anyNA(integrators) ||
      anyDuplicated(integrators)) stop("Choose distinct available integrators.")
  if (!is.list(settings) || (length(settings) && (is.null(names(settings)) ||
      anyNA(names(settings)) || anyDuplicated(names(settings)) ||
      any(!names(settings) %in% integrators)))) stop("Settings must be named by selected integrator.")
  setNames(lapply(integrators, function(method) {
    values = settings[[method]]
    if (!is.null(values) && (!is.list(values) || (length(values) &&
        (is.null(names(values)) || anyNA(names(values)) || anyDuplicated(names(values)) ||
         any(!names(values) %in% "timestep"))))) {
      stop("Only timestep can vary by integrator; physical parameters and duration are shared.")
    }
    args = unclass(request)
    args$integrator = method
    if (!is.null(values$timestep)) args$timestep = values$timestep
    do.call(simulation_request, args)
  }), integrators)
}

studio_comparison_requests = function(request, integrators, settings = list()) {
  if (length(integrators) < 2L) stop("An Integrator Lab batch needs at least two integrators.")
  studio_integrator_requests(request, integrators, settings)
}

studio_physical_request = function(request) {
  parameters = request$parameters
  parameters$primary_names = NULL
  list(system = request$system, parameters = parameters, duration = request$duration)
}

studio_check_comparison_requests = function(requests, execution = FALSE) {
  if (!is.list(requests) || length(requests) < 2L) stop("Select at least two runs.")
  requests = lapply(requests, studio_validate_request, execution = execution)
  baseline = studio_physical_request(requests[[1]])
  if (!all(vapply(requests, function(r) isTRUE(all.equal(studio_physical_request(r),
      baseline, tolerance = 0)), logical(1)))) {
    stop("Incompatible runs: physical system, initial conditions and duration must match.")
  }
  requests
}

studio_reference_index = function(reference, members) {
  if (is.numeric(reference) && length(reference) == 1L && is.finite(reference) &&
      reference == floor(reference) && reference >= 1 && reference <= nrow(members)) return(as.integer(reference))
  if (is.character(reference) && length(reference) == 1L && !is.na(reference)) {
    matches = which(members$run_id == reference)
    if (!length(matches)) matches = which(members$integrator == reference)
    if (length(matches) == 1L) return(matches)
  }
  stop("Reference must identify one member by index, run ID or unambiguous integrator name.")
}

# At the union knots these are differences of piecewise-linear interpolants.
# Endpoint states are original stored samples; no extrapolation or phase fitting.
studio_state_difference = function(result, reference, time = NULL) {
  if (is.null(time)) time = sort(unique(c(result$time, reference$time)))
  roles = result$model$body_roles
  bodies = which(roles != "prescribed_primary")
  if (!length(bodies)) stop("No integrated bodies available for state comparison.")
  differences = lapply(c("positions", "velocities"), function(field) {
    squared = matrix(0, length(time), length(bodies))
    for (body in seq_along(bodies)) {
      for (axis in seq_len(dim(result[[field]])[3])) {
        a = stats::approx(result$time, result[[field]][, bodies[body], axis],
          xout = time, ties = "ordered", rule = 1)$y
        b = stats::approx(reference$time, reference[[field]][, bodies[body], axis],
          xout = time, ties = "ordered", rule = 1)$y
        squared[, body] = squared[, body] + (a - b)^2
      }
    }
    apply(sqrt(squared), 1, max)
  })
  data.frame(time = time, position_difference = differences[[1]], velocity_difference = differences[[2]])
}

studio_compare_runs = function(paths, reference = 1L) {
  if (!is.character(paths) || length(paths) < 2L || anyNA(paths) || anyDuplicated(paths))
    stop("Select at least two distinct history record paths.")
  paths = normalizePath(paths, mustWork = TRUE)
  if (anyDuplicated(paths)) stop("Comparison members must be distinct history records.")
  records = lapply(paths, studio_load_history)
  requests = studio_check_comparison_requests(lapply(records, function(r) r$request))
  members = do.call(rbind, lapply(seq_along(records), function(i) {
    r = records[[i]]
    data.frame(run_id = r$run_id, record_id = r$id, path = paths[i],
      integrator = r$request$integrator, timestep = r$request$timestep,
      status = r$status, error = if (is.null(r$error)) NA_character_ else r$error)
  }))
  if (anyDuplicated(members$run_id)) stop("Comparison members must have distinct scientific run IDs.")
  ref = studio_reference_index(reference, members)
  results = lapply(seq_along(paths), function(i) {
    if (members$status[i] == "completed") studio_load_result(paths[i]) else NULL
  })
  names(results) = members$run_id
  completed = Filter(Negate(is.null), results)
  # Keep the existing scientific compatibility rules, including units and G.
  if (length(completed) >= 2L) studio_comparison(completed)
  reports = lapply(results, function(r) if (is.null(r)) NULL else simulation_diagnostics(r))
  metrics = members[c("run_id", "integrator", "timestep", "status", "error")]
  for (name in c("runtime_seconds", "step_count", "force_evaluation_count",
      "energy_max_absolute_drift", "energy_max_relative_drift",
      "angular_momentum_max_absolute_drift", "angular_momentum_max_relative_drift",
      "centre_of_mass_max_drift", "jacobi_max_relative_drift", "specific_energy_max_relative_drift",
      "final_position_difference", "final_velocity_difference",
      "max_position_difference", "max_velocity_difference")) metrics[[name]] = NA_real_
  metrics$trajectory_valid = NA
  differences = setNames(vector("list", length(results)), members$run_id)
  maximum = function(report, metric) {
    row = report$summary[report$summary$metric == metric, ]
    if (nrow(row)) row$max_absolute else NA_real_
  }
  for (i in seq_along(results)) {
    if (is.null(results[[i]])) next
    report = reports[[i]]
    for (name in names(report$performance)) metrics[[name]][i] = report$performance[[name]]
    metrics$trajectory_valid[i] = report$validity$valid
    mapping = c(energy_max_absolute_drift = "energy_drift",
      energy_max_relative_drift = "energy_relative_drift",
      angular_momentum_max_absolute_drift = "angular_momentum_drift",
      angular_momentum_max_relative_drift = "angular_momentum_relative_drift",
      centre_of_mass_max_drift = "centre_of_mass_drift",
      jacobi_max_relative_drift = "jacobi_relative_drift",
      specific_energy_max_relative_drift = "specific_energy_relative_drift")
    for (name in names(mapping)) metrics[[name]][i] = maximum(report, mapping[[name]])
    if (!is.null(results[[ref]])) {
      delta = studio_state_difference(results[[i]], results[[ref]])
      differences[[i]] = delta
      metrics$final_position_difference[i] = tail(delta$position_difference, 1)
      metrics$final_velocity_difference[i] = tail(delta$velocity_difference, 1)
      metrics$max_position_difference[i] = max(delta$position_difference)
      metrics$max_velocity_difference[i] = max(delta$velocity_difference)
    }
  }
  structure(list(schema_version = 1L, id = paste0("comparison-", studio_run_id()),
    timestamp = studio_run_timestamp(), problem = studio_physical_request(requests[[1]]),
    reference_run_id = members$run_id[ref], reference_status = members$status[ref],
    members = members, metrics = metrics, differences = differences, results = results,
    diagnostics = reports,
    definitions = list(position_difference = "Maximum over integrated bodies of Euclidean position difference, in native position units.",
      velocity_difference = "Maximum over integrated bodies of Euclidean velocity difference, in native velocity units.",
      alignment = "Piecewise-linear interpolation on the union of each run and reference time grids; no extrapolation.",
      reference = "A comparison run, not an exact solution. Missing/failed references leave all state differences unavailable.",
      units = if (requests[[1]]$system == "restricted_three_body") "normalized position and velocity" else "position: m; velocity: m/s; energy: J; angular momentum: kg m^2/s",
      runtime = "One elapsed solver adapter call per run; excludes comparison analysis and persistence.")),
    class = "integrator_comparison")
}

run_integrator_comparison = function(request, integrators, settings = list(),
    reference = integrators[1], directory = ".studio/history") {
  studio_require_json()
  requests = studio_comparison_requests(request, integrators, settings)
  # Validate reference before creating any history entries.
  ref = studio_reference_index(reference, data.frame(run_id = integrators, integrator = integrators))
  paths = vapply(requests, function(r) {
    failure = NULL
    result = tryCatch(run_simulation(r), error = function(e) { failure <<- conditionMessage(e); NULL })
    if (is.null(result)) studio_save_failure(r, failure, directory) else studio_save_history(result, directory)
  }, character(1))
  comparison = studio_compare_runs(unname(paths), ref)
  comparison$path = studio_save_comparison(comparison)
  comparison
}

# Uses the same background worker and lifecycle/cancellation handling as Studio.
studio_start_comparison = function(requests, reference = 1L,
    directory = ".studio/history", root = NULL) {
  requests = studio_check_comparison_requests(requests, execution = TRUE)
  methods = vapply(requests, function(r) r$integrator, character(1))
  if (anyDuplicated(methods)) stop("Choose at least two distinct integrators for a new batch.")
  ref = studio_reference_index(reference, data.frame(run_id = methods, integrator = methods))
  job = studio_start_job(requests, directory, root)
  tryCatch({
    # Save the links immediately, so partial and cancelled batches remain reloadable.
    comparison = studio_compare_runs(job$paths, ref)
    job$comparison_path = studio_save_comparison(comparison)
    job
  }, error = function(e) {
    studio_cancel_job(job, "Comparison setup failed.")
    stop(e)
  })
}

studio_save_comparison = function(comparison) {
  studio_require_json()
  if (!inherits(comparison, "integrator_comparison") || !studio_valid_id(comparison$id))
    stop("Expected an integrator_comparison.")
  studio_history_timestamp(comparison$timestamp)
  paths = normalizePath(comparison$members$path, mustWork = TRUE)
  roots = unique(dirname(paths))
  if (length(roots) != 1L) stop("Save comparison members in the same history directory.")
  records = lapply(paths, studio_load_history)
  studio_check_comparison_requests(lapply(records, function(r) r$request))
  ids = vapply(records, function(r) r$run_id, character(1))
  if (anyDuplicated(ids) || !identical(unname(ids), comparison$members$run_id) ||
      !comparison$reference_run_id %in% ids) stop("Comparison member identity or reference mismatch.")
  manifest = list(schema_version = 1L, type = "integrator_comparison", id = comparison$id,
    timestamp = comparison$timestamp,
    label = paste(comparison$problem$system, paste(comparison$members$integrator, collapse = " / ")),
    reference_run_id = comparison$reference_run_id,
    members = lapply(seq_along(paths), function(i) list(record = basename(paths[i]), run_id = ids[i])))
  # Convergence studies reuse the member-link manifest, adding analysis settings.
  if (!is.null(comparison$convergence)) manifest$convergence = comparison$convergence
  directory = file.path(roots, ".comparisons")
  dir.create(directory, showWarnings = FALSE)
  studio_write_record(manifest, file.path(directory, paste0(comparison$id, ".json")))
}

studio_read_comparison_manifest = function(path) {
  studio_require_json()
  manifest = jsonlite::read_json(path, simplifyVector = FALSE)
  if (!identical(manifest$type, "integrator_comparison") ||
      !identical(manifest$schema_version, 1L) || !studio_valid_id(manifest$id) ||
      !is.character(manifest$label) || length(manifest$label) != 1L || is.na(manifest$label) ||
      !studio_valid_id(manifest$reference_run_id) || !is.list(manifest$members) ||
      length(manifest$members) < 2L) stop("Invalid comparison manifest.")
  studio_history_timestamp(manifest$timestamp)
  for (member in manifest$members) {
    if (!is.list(member) || !studio_valid_id(member$run_id) ||
        !is.character(member$record) || length(member$record) != 1L || is.na(member$record) ||
        !grepl("^[A-Za-z0-9][A-Za-z0-9_.-]*\\.json$", member$record)) stop("Invalid comparison member link.")
  }
  ids = vapply(manifest$members, function(x) x$run_id, character(1))
  records = vapply(manifest$members, function(x) x$record, character(1))
  if (anyDuplicated(ids) || anyDuplicated(records) || !manifest$reference_run_id %in% ids)
    stop("Duplicate comparison members or missing reference.")
  manifest
}

studio_load_comparison = function(path) {
  manifest = studio_read_comparison_manifest(path)
  path = normalizePath(path, mustWork = TRUE)
  if (basename(dirname(path)) != ".comparisons") stop("Comparison must be inside a history .comparisons directory.")
  root = dirname(dirname(path))
  paths = file.path(root, vapply(manifest$members, function(x) x$record, character(1)))
  if (any(!file.exists(paths))) stop("A linked comparison run is missing from history.")
  resolved = normalizePath(paths, mustWork = TRUE)
  if (any(dirname(resolved) != root)) stop("Comparison link leaves its history directory.")
  comparison = studio_compare_runs(resolved, manifest$reference_run_id)
  expected = vapply(manifest$members, function(x) x$run_id, character(1))
  if (!identical(unname(expected), comparison$members$run_id)) stop("Comparison member run ID mismatch.")
  comparison$id = manifest$id
  comparison$timestamp = manifest$timestamp
  comparison$path = path
  if (!is.null(manifest$convergence)) comparison$convergence = manifest$convergence
  comparison
}

studio_comparison_history = function(directory = ".studio/history") {
  paths = list.files(file.path(directory, ".comparisons"), pattern = "\\.json$", full.names = TRUE)
  manifests = lapply(paths, function(path) tryCatch(studio_read_comparison_manifest(path),
    error = function(e) { warning("Skipping invalid comparison: ", conditionMessage(e)); NULL }))
  Filter(Negate(is.null), setNames(manifests, paths))
}

# Plotting consumes the report; no scientific calculations are in the UI layer.
studio_plot_comparison = function(comparison,
    view = c("trajectory", "energy", "angular_momentum", "side_by_side")) {
  if (!inherits(comparison, "integrator_comparison")) stop("Expected an integrator_comparison.")
  view = match.arg(view)
  available = which(!vapply(comparison$results, is.null, logical(1)))
  if (!length(available)) {
    graphics::plot.new(); graphics::text(0.5, 0.5, "No completed trajectories available.")
    return(invisible(NULL))
  }
  results = comparison$results[available]
  names(results) = vapply(results, function(r) paste0(r$request$integrator,
    " (dt=", format(r$request$timestep, digits = 5), ")"), character(1))
  names(results) = make.unique(names(results))
  for (i in seq_along(results)) {
    report = comparison$diagnostics[[available[i]]]
    results[[i]]$diagnostics = report$series
    results[[i]]$diagnostic_summary = studio_diagnostic_summary(report$series)
    results[[i]]$diagnostic_registry = report$registry
  }
  axes = if (results[[1]]$request$system == "sitnikov") c(1L, 3L) else c(1L, 2L)
  if (view == "trajectory") return(studio_plot_trajectories(results, axes))
  if (view == "side_by_side") {
    columns = min(3L, length(results))
    old = graphics::par(mfrow = c(ceiling(length(results) / columns), columns))
    on.exit(graphics::par(old))
    scale = if (results[[1]]$request$system == "restricted_three_body") 1 else AU
    display = lapply(results, studio_display_state)
    limits = list(
      x = cd_expand_range(unlist(lapply(display, function(r) r$positions[, , axes[1]] / scale))),
      y = cd_expand_range(unlist(lapply(display, function(r) r$positions[, , axes[2]] / scale))))
    for (i in seq_along(results)) {
      studio_plot_trajectories(results[i], axes, limits = limits)
      graphics::mtext(names(results)[i], side = 3, line = 0.3, cex = 0.8)
    }
    return(invisible(NULL))
  }
  base = if (view == "angular_momentum") "angular_momentum" else
    switch(results[[1]]$request$system, restricted_three_body = "jacobi", sitnikov = "specific_energy", "energy")
  relative = paste0(base, "_relative_drift")
  absolute = paste0(base, "_drift")
  if (!all(vapply(results, function(r) absolute %in% names(r$diagnostics), logical(1)))) {
    graphics::plot.new(); graphics::text(0.5, 0.5, "This invariant is not applicable to the selected model.")
    return(invisible(NULL))
  }
  # Use a common absolute scale if any member has an undefined relative reference.
  metric = if (all(vapply(results, function(r) any(is.finite(r$diagnostics[[relative]])), logical(1)))) relative else absolute
  studio_plot_diagnostic(results, metric)
}
