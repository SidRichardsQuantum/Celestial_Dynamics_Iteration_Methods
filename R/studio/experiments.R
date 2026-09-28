# Experiment management contains no integration or invariant calculations.
studio_preset_identity = function(request, presets = studio_presets()) {
  matches = names(Filter(function(p) {
    identical(p$request$system, request$system) &&
      isTRUE(all.equal(p$request$parameters, request$parameters, tolerance = 0))
  }, presets))
  if (length(matches)) matches[1] else "custom"
}

studio_gallery_metadata = function(record, presets = studio_presets()) {
  request = record$request
  preset = record$preset
  if (is.null(preset)) preset = studio_preset_identity(request, presets)
  label = if (preset %in% names(presets)) presets[[preset]]$name else "Custom configuration"
  metric = intersect(c("energy_relative_drift", "jacobi_relative_drift",
                       "specific_energy_relative_drift"), names(record$diagnostic_summary))
  value = if (length(metric)) record$diagnostic_summary[[metric[1]]]$max_absolute_change else NULL
  data.frame(id = record$id, run_id = if (is.null(record$run_id)) record$id else record$run_id,
    title = label, preset = preset, system = request$system,
    integrator = request$integrator, duration = request$duration, timestep = request$timestep,
    bodies = if (!is.null(request$parameters$masses)) length(request$parameters$masses) else
      if (request$system == "sitnikov") 3L else 1L,
    dimensions = studio_catalog()[[request$system]]$dimensions,
    steps = round(request$duration / request$timestep),
    runtime_seconds = if (is.null(record$runtime_seconds)) NA_real_ else record$runtime_seconds,
    metric = if (length(metric)) metric[1] else NA_character_,
    max_relative_drift = if (is.null(value)) NA_real_ else value,
    timestamp = record$timestamp, status = record$status, favorite = isTRUE(record$favorite))
}

studio_comparison = function(results) {
  if (length(results) < 2L || !all(vapply(results, inherits, logical(1), "simulation_result"))) {
    stop("Select at least two completed runs with saved trajectories.")
  }
  physical = function(result) {
    # Display labels are not part of the physical problem.
    c(studio_physical_request(result$request),
      list(units = result$units, G = result$provenance$G))
  }
  baseline = physical(results[[1]])
  compatible = vapply(results, function(r) isTRUE(all.equal(physical(r), baseline,
                                                           tolerance = 0)), logical(1))
  if (!all(compatible)) {
    stop("Incompatible runs: system, physical initial conditions, constants, units and duration must match. Integrator and timestep may differ.")
  }
  results = lapply(results, studio_validate_result)
  labels = names(results)
  if (is.null(labels)) labels = paste("Run", seq_along(results))
  metrics = Reduce(intersect, lapply(results, function(r) names(r$diagnostic_summary)))
  rows = lapply(seq_along(results), function(i) {
    r = results[[i]]
    row = data.frame(run = labels[i], run_id = r$id, integrator = r$request$integrator,
      timestep = r$request$timestep, steps = length(r$time) - 1L,
      runtime_seconds = r$runtime_seconds)
    for (metric in metrics) {
      row[[paste0("max_change_", metric)]] = r$diagnostic_summary[[metric]]$max_absolute_change
    }
    row
  })
  do.call(rbind, rows)
}
