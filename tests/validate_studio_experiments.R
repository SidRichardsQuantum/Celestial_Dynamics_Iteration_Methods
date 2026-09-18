if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
local({
  directory = tempfile("experiments-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  request = studio_preset("circular_two_body")
  request$duration = request$timestep * 20
  stages = character()
  result = run_simulation(request, function(stage) stages <<- c(stages, stage))
  stopifnot(identical(stages, c("validating", "integrating", "computing diagnostics")))
  path = studio_save_history(result, directory, "circular_two_body")
  record = studio_load_history(path)
  restored = studio_load_result(path)
  stopifnot(isTRUE(all.equal(restored, result, tolerance = 0)),
    isTRUE(all.equal(record$request, request, tolerance = 0)),
    file.exists(studio_artifact_path(path, "preview")),
    identical(studio_gallery_metadata(record), studio_gallery_metadata(record)))
  # Typed JSON must never instantiate executable/namespace/S4 objects.
  unsafe_path = studio_save_history(result, directory)
  artifact = studio_artifact_path(unsafe_path, "result")
  connection = gzfile(artifact, "wt")
  writeLines('{"type":"namespace","value":{"name":"base"}}', connection)
  close(connection)
  stopifnot(inherits(tryCatch(studio_load_result(unsafe_path), error = identity), "error"))
  studio_set_favorite(path, TRUE)
  stopifnot(studio_load_history(path)$favorite)
  studio_set_favorite(path, FALSE)
  stopifnot(!studio_load_history(path)$favorite)
  refined = request
  refined$timestep = refined$timestep / 2
  second = run_simulation(refined)
  table = studio_comparison(list(A = result, B = second))
  stopifnot(table$steps[2] == 40,
    table$max_change_energy_relative_drift[1] == result$diagnostic_summary$energy_relative_drift$max_absolute_change,
    table$runtime_seconds[2] == second$runtime_seconds)
  incompatible = second
  incompatible$request$parameters$masses[1] = incompatible$request$parameters$masses[1] * 1.001
  error = tryCatch(studio_comparison(list(result, incompatible)), error = identity)
  stopifnot(inherits(error, "error"), grepl("Incompatible", conditionMessage(error)))
  failed = studio_save_failure(request, "Body collision or overlapping positions.", directory)
  failure = studio_load_history(failed)
  stopifnot(failure$status == "failed", grepl("collision", failure$error),
    isTRUE(all.equal(failure$request, request, tolerance = 0)))
  # Old metadata-only files remain loadable; no rerun masquerades as old data.
  legacy = jsonlite::read_json(path)
  legacy$schema_version = 1L
  legacy$artifacts = legacy$id = legacy$status = legacy$favorite = NULL
  old = file.path(directory, "legacy.json")
  jsonlite::write_json(legacy, old, auto_unbox = TRUE, digits = I(17))
  stopifnot(studio_load_history(old)$status == "completed",
    !studio_load_history(old)$favorite,
    inherits(tryCatch(studio_load_result(old), error = identity), "error"))
  studio_set_favorite(old, TRUE)
  stopifnot(studio_load_history(old)$favorite)
  # Every system's typed arrays/raw solver output survive persistence.
  for (id in c("figure_eight", "rotating_square", "sun_jupiter_particle", "sitnikov")) {
    request = studio_preset(id)
    request$duration = request$timestep * 5
    result = run_simulation(request)
    saved = studio_save_history(result, directory)
    stopifnot(isTRUE(all.equal(studio_load_result(saved), result, tolerance = 0)))
  }
})
cat("Experiment artifacts, exact reuse, favorites, metadata, comparisons, failures and legacy checks passed.\n")
