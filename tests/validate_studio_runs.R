if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()

(function() {
  expect_error = function(expr, pattern) {
    error = tryCatch({ force(expr); NULL }, error = identity)
    stopifnot(inherits(error, "error"))
    if (!missing(pattern)) stopifnot(grepl(pattern, conditionMessage(error), fixed = TRUE))
  }
  request = studio_preset("circular_two_body")
  request$duration = 5 * request$timestep
  set.seed(123)
  rng = .Random.seed
  result = run_simulation(request)
  stopifnot(identical(rng, .Random.seed), inherits(result, "simulation_result"),
    identical(studio_validate_result(result), result), result$schema_version == 2L,
    identical(result$request, request), identical(result$model$constants$G, G),
    result$provenance$package_version == read.dcf(cd_path("DESCRIPTION"))[1, "Version"],
    length(result$provenance$source_fingerprint) > 0,
    identical(result$timestamps$completed_at, result$timestamp),
    is.null(result$lineage$parent_run_id), !any(c("tags", "favorite", "preset") %in% names(result)))
  stopifnot(nrow(summary(result)) == 1L, summary(result)$run_id == result$id,
    summary(result)$steps == 5, identical(summary(result), studio_run_summary(result)),
    any(grepl(result$id, capture.output(print(result)), fixed = TRUE)))
  rerun = studio_rerun(result)
  stopifnot(result$id != rerun$id, rerun$lineage$parent_run_id == result$id,
    identical(result$request, rerun$request), identical(result$positions, rerun$positions),
    identical(result$velocities, rerun$velocities), identical(result$diagnostics, rerun$diagnostics),
    nrow(studio_comparison(list(result, rerun))) == 2L)
  changed = result
  changed$provenance$package_version = "99.0.0"
  expect_error(studio_rerun(changed), "Engine identity")
  stopifnot(suppressWarnings(studio_rerun(changed, allow_engine_change = TRUE))$lineage$parent_run_id == result$id)
  changed = result
  changed$provenance$source_fingerprint[1] = paste(rep("0", 32), collapse = "")
  expect_error(studio_rerun(changed), "Engine identity")
  changed = result
  changed$provenance$G = changed$provenance$G * 2
  changed$model$constants$G = changed$provenance$G
  expect_error(studio_rerun(changed, allow_engine_change = TRUE), "gravitational constant")

  bad_cases = list(
    function(r) { r$schema_version = 99L; r },
    function(r) { r$id = "../outside"; r },
    function(r) { r$lineage$parent_run_id = r$id; r },
    function(r) { r$time[2] = r$time[1]; r },
    function(r) { r$time = r$time[-1]; r },
    function(r) { r$positions[2, 1, 1] = Inf; r },
    function(r) { r$positions[1, 1, 1] = 123; r },
    function(r) { r$velocities = r$velocities[, , 1]; r },
    function(r) { r$body_names = c("same", "same"); r },
    function(r) { r$masses = NULL; r },
    function(r) { r$diagnostics$time[2] = 1; r },
    function(r) { r$diagnostics$energy = NULL; r },
    function(r) { r$diagnostic_summary$energy$initial = 0; r },
    function(r) { r$runtime_seconds = -1; r },
    function(r) { r$timestamps$started_at = "2099-01-01T00:00:00Z"; r },
    function(r) { r$timestamp = "yesterday"; r },
    function(r) { r$model$frame = "unknown"; r },
    function(r) { r$provenance$package_version = NULL; r },
    function(r) { r$provenance$source_fingerprint = "not a checksum"; r },
    function(r) { r$raw = list(); r },
    function(r) { r$raw$callback = function() NULL; r },
    function(r) { r$provenance$session = new.env(); r },
    function(r) { r$tags = "presentation"; r },
    function(r) { r$favorite = TRUE; r }
  )
  for (mutate in bad_cases) expect_error(studio_validate_result(mutate(result)))
  expect_error(studio_validate_result(list()), "simulation_result")

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    cat("Run JSON/history checks skipped: install jsonlite.\n")
    return(invisible(NULL))
  }
  directory = tempfile("scientific-runs-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  stopifnot(identical(studio_result_from_json(studio_result_json(result)), result))
  special = result
  special$diagnostics$optional_metric = c(0, NA_real_, NaN, Inf, -Inf, 1)
  special$diagnostic_summary = studio_diagnostic_summary(special$diagnostics)
  stopifnot(identical(studio_result_from_json(studio_result_json(special)), special))
  for (mutate in bad_cases) expect_error(studio_result_from_json(jsonlite::serializeJSON(mutate(result))))
  expect_error(studio_result_from_json('{"type":"namespace","value":{"name":"base"}}'))
  expect_error(studio_result_from_json("not JSON"))

  first = studio_save_history(result, directory, tags = c("baseline", "comparison"), favorite = TRUE)
  second = studio_save_history(result, directory)
  stopifnot(first != second, identical(studio_load_result(first), result),
    identical(studio_load_result(second), result),
    studio_load_history(first)$schema_version == 4L,
    studio_load_history(first)$run_id == result$id,
    studio_load_history(second)$run_id == result$id,
    identical(studio_load_history(first)$tags, c("baseline", "comparison")),
    studio_load_history(first)$favorite)
  checksum = tools::md5sum(studio_artifact_path(first, "result"))
  studio_set_tags(first, "reviewed")
  studio_set_favorite(first, FALSE)
  stopifnot(identical(studio_load_history(first)$tags, "reviewed"),
    !studio_load_history(first)$favorite, identical(studio_load_result(first), result),
    identical(tools::md5sum(studio_artifact_path(first, "result")), checksum))
  for (tags in list(1, c("duplicate", "duplicate"), "", NA_character_)) {
    expect_error(studio_set_tags(first, tags), "tags")
  }
  csv1 = file.path(directory, "before.csv")
  csv2 = file.path(directory, "after.csv")
  studio_export_trajectory(result, csv1)
  studio_export_trajectory(studio_load_result(first), csv2)
  stopifnot(identical(readLines(csv1), readLines(csv2)))

  # Test genuine old layouts: remove all fields added by the run model.
  legacy = result
  legacy[c("schema_version", "id", "model", "timestamps", "lineage")] = NULL
  legacy$provenance = result$provenance[c("studio_schema", "R", "G", "engine")]
  legacy$provenance$studio_schema = 1L
  for (schema in 1:3) {
    path = file.path(directory, paste0("legacy-", schema, ".json"))
    record = list(schema_version = schema, timestamp = legacy$timestamp,
      request = unclass(legacy$request), provenance = legacy$provenance,
      diagnostic_summary = legacy$diagnostic_summary, runtime_seconds = legacy$runtime_seconds)
    if (schema > 1) {
      artifact = file.path(directory, paste0("legacy-", schema, ".json.gz"))
      connection = gzfile(artifact, "wt")
      writeLines(jsonlite::serializeJSON(legacy, digits = 17), connection)
      close(connection)
      record$artifacts = list(result = basename(artifact))
    }
    jsonlite::write_json(record, path, auto_unbox = TRUE, digits = I(17))
    before = readLines(path)
    restored = studio_load_history(path)
    stopifnot(restored$status == "completed", !restored$favorite, !length(restored$tags))
    if (schema == 1) {
      expect_error(studio_load_result(path), "no saved trajectory")
    } else {
      old = studio_load_result(path)
      stopifnot(old$id == paste0("legacy-", schema), old$schema_version == 2L,
        is.null(old$timestamps$started_at), old$timestamp == legacy$timestamp,
        identical(old$positions, legacy$positions), identical(old$diagnostics, legacy$diagnostics),
        identical(studio_load_result(path), old), is.null(old$provenance$source_fingerprint))
      expect_error(studio_rerun(old), "Engine identity")
      stopifnot(suppressWarnings(studio_rerun(old, allow_engine_change = TRUE))$lineage$parent_run_id == old$id)
    }
    stopifnot(identical(before, readLines(path)))
  }
  # Historical requests are readable even when current execution caps reject them.
  old_request = request
  old_request$duration = 100001 * old_request$timestep
  record$request = unclass(old_request)
  historical_path = file.path(directory, "over-budget.json")
  jsonlite::write_json(record, historical_path, auto_unbox = TRUE, digits = I(17))
  historical = studio_load_history(historical_path)
  expect_error(run_simulation(historical$request), "100000")

  record = jsonlite::read_json(first)
  record$run_id = "wrong-run"
  studio_write_record(record, second)
  expect_error(studio_load_result(second), "run identity")
  for (version in list(NULL, 99L, c(1, 2))) {
    record$schema_version = version
    studio_write_record(record, second)
    expect_error(studio_load_history(second), "schema version")
  }
  # All adapters must satisfy the same contract, including restricted body roles.
  for (name in c("figure_eight", "rotating_square", "sun_jupiter_particle", "sitnikov")) {
    r = studio_preset(name)
    r$duration = 5 * r$timestep
    output = run_simulation(r)
    stopifnot(identical(studio_result_from_json(studio_result_json(output)), output),
      identical(studio_load_result(studio_save_history(output, directory)), output),
      length(output$model$body_roles) == dim(output$positions)[2])
    bad = output
    bad$raw = list()
    expect_error(studio_validate_result(bad), "Raw solver output")
  }
})()
cat("Scientific run contracts, identity, provenance, reruns, JSON, metadata and schema migration passed.\n")
