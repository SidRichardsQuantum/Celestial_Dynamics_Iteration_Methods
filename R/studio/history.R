studio_require_json = function() {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("JSON history requires optional package jsonlite: install.packages('jsonlite').")
  }
}

studio_request_json = function(request) {
  studio_require_json()
  jsonlite::toJSON(unclass(studio_validate_request(request)), auto_unbox = TRUE,
                   matrix = "rowmajor", digits = I(17), pretty = TRUE)
}

studio_request_from_list = function(value) {
  if (!is.list(value)) stop("Invalid request object.")
  # Restore JSON row arrays to R matrices, without evaluating input as R code.
  spec = studio_catalog()[[value$system]]
  if (is.null(spec)) stop("Unknown simulation system.")
  for (name in names(spec$parameters)) {
    field = spec$parameters[[name]]
    item = value$parameters[[name]]
    if (is.list(item) && field$type == "matrix") {
      widths = lengths(item)
      if (!length(widths) || any(widths != widths[1])) stop("Ragged matrix: ", name)
      item = do.call(rbind, lapply(item, unlist, use.names = FALSE))
    } else if (is.list(item) && field$type %in% c("vector", "labels")) {
      item = unlist(item, use.names = FALSE)
    }
    value$parameters[[name]] = item
  }
  do.call(simulation_request, value)
}

studio_request_from_json = function(text) {
  studio_require_json()
  studio_request_from_list(jsonlite::fromJSON(text, simplifyVector = FALSE))
}

# Metadata is authoritative; large scientific artifacts live beside each record.
studio_write_record = function(record, path) {
  if (inherits(record$request, "simulation_request")) record$request = unclass(record$request)
  temporary = tempfile("pending-", tmpdir = dirname(path), fileext = ".tmp")
  on.exit(unlink(temporary), add = TRUE)
  jsonlite::write_json(record, temporary, auto_unbox = TRUE, matrix = "rowmajor",
                       digits = I(17), pretty = TRUE, na = "null")
  if (!file.rename(temporary, path)) stop("Could not publish history record.")
  path
}

studio_save_history = function(result, directory = ".studio/history", preset = NULL) {
  studio_require_json()
  if (!inherits(result, "simulation_result")) stop("Expected a simulation_result.")
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  id = basename(tempfile("run-", tmpdir = directory))
  studio_publish_result(result, file.path(directory, paste0(id, ".json")), preset)
}

# The worker publishes to its existing queued record, preserving the run ID.
studio_publish_result = function(result, path, preset = NULL) {
  directory = dirname(path)
  id = tools::file_path_sans_ext(basename(path))
  previous = if (file.exists(path)) studio_load_history(path) else NULL
  artifacts = file.path(directory, id)
  dir.create(artifacts)
  published = FALSE
  on.exit(if (!published) unlink(artifacts, recursive = TRUE), add = TRUE)
  # Typed JSON preserves array dimensions and NA values without executable R data.
  connection = gzfile(file.path(artifacts, "result.json.gz"), "wt")
  tryCatch(writeLines(jsonlite::serializeJSON(result, digits = 17), connection),
           finally = close(connection))
  grDevices::png(file.path(artifacts, "preview.png"), width = 640, height = 420)
  tryCatch(studio_plot_trajectories(result,
    axes = if (result$request$system == "sitnikov") c(1L, 3L) else c(1L, 2L)),
    finally = grDevices::dev.off())
  record = list(schema_version = if (is.null(previous)) 2L else 3L,
                id = id, status = "completed", stage = "completed",
                favorite = if (is.null(previous)) FALSE else previous$favorite,
                preset = preset, timestamp = result$timestamp,
                request = unclass(studio_validate_request(result$request)),
                provenance = result$provenance, runtime_seconds = result$runtime_seconds,
                diagnostic_summary = result$diagnostic_summary,
                warnings = studio_accuracy_warnings(result),
                artifacts = list(result = paste0(id, "/result.json.gz"),
                                 preview = paste0(id, "/preview.png")))
  if (!is.null(previous)) {
    record$submitted_at = previous$timestamp
    record$lifecycle = previous$lifecycle
    record$lifecycle[[length(record$lifecycle) + 1L]] = studio_stage_event("completed")
  }
  path = studio_write_record(record, path)
  published = TRUE
  path
}

studio_save_failure = function(request, error, directory = ".studio/history", preset = NULL,
                              stage = "integrating") {
  studio_require_json()
  request = studio_validate_request(request)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  id = basename(tempfile("run-", tmpdir = directory))
  studio_write_record(list(schema_version = 2L, id = id, status = "failed",
    favorite = FALSE, preset = preset, request = unclass(request),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
    error = as.character(error), failed_stage = stage),
    file.path(directory, paste0(id, ".json")))
}

studio_set_favorite = function(path, favorite) {
  studio_load_history(path) # Validate before updating, preserving unknown fields.
  if (!is.logical(favorite) || length(favorite) != 1L || is.na(favorite)) {
    stop("favorite must be TRUE or FALSE.")
  }
  record = jsonlite::read_json(path, simplifyVector = FALSE)
  record$favorite = favorite
  studio_write_record(record, path)
}

studio_artifact_path = function(path, kind) {
  record = studio_load_history(path)
  relative = record$artifacts[[kind]]
  if (is.null(relative)) return(NULL)
  root = normalizePath(dirname(path), mustWork = TRUE)
  target = normalizePath(file.path(root, relative), mustWork = TRUE)
  if (!startsWith(target, paste0(root, .Platform$file.sep))) stop("Invalid artifact path.")
  target
}

studio_load_result = function(path) {
  record = studio_load_history(path)
  if (record$status != "completed") stop("Only completed runs can be viewed or compared.")
  artifact = studio_artifact_path(path, "result")
  if (is.null(artifact)) stop("This legacy record has no saved trajectory. Reuse its request to create a new run.")
  connection = gzfile(artifact, "rt")
  on.exit(close(connection))
  text = paste(readLines(connection, warn = FALSE), collapse = "\n")
  # Restrict typed JSON to passive scientific data before unpacking. jsonlite's
  # general decoder also supports namespaces, S4 objects and function types.
  validate_node = function(node) {
    if (!is.list(node) || !is.character(node$type) || length(node$type) != 1L ||
        !node$type %in% c("NULL", "list", "double", "numeric", "integer", "logical", "character")) {
      stop("Unsupported scientific artifact type.")
    }
    if (node$type == "list") lapply(node$value, validate_node)
    if (length(node$attributes)) {
      if (!all(names(node$attributes) %in% c("names", "dim", "dimnames", "class", "row.names"))) {
        stop("Unsupported scientific artifact attributes.")
      }
      lapply(node$attributes, validate_node)
      classes = node$attributes$class$value
      if (length(classes) && !all(unlist(classes) %in%
          c("simulation_result", "simulation_request", "data.frame", "matrix", "array"))) {
        stop("Unsupported scientific artifact class.")
      }
    }
    invisible(TRUE)
  }
  validate_node(jsonlite::fromJSON(text, simplifyVector = FALSE))
  result = jsonlite::unserializeJSON(text)
  if (!inherits(result, "simulation_result") ||
      !isTRUE(all.equal(result$request, record$request, tolerance = 0))) {
    stop("Scientific artifact does not match its history request.")
  }
  result
}

studio_history_timestamp = function(timestamp) {
  message = "History timestamp must be a valid UTC timestamp (YYYY-MM-DDTHH:MM:SS[.ffffff]Z)."
  if (!is.character(timestamp) || length(timestamp) != 1L || is.na(timestamp) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-5][0-9](\\.[0-9]{1,6})?Z$", timestamp)) {
    stop(message)
  }
  parsed = as.POSIXct(strptime(timestamp, "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
  if (is.na(parsed) || format(parsed, "%Y-%m-%dT%H:%M:%S", tz = "UTC") != substr(timestamp, 1, 19)) {
    stop(message)
  }
  as.numeric(parsed)
}

studio_load_history = function(path) {
  studio_require_json()
  record = jsonlite::read_json(path, simplifyVector = FALSE)
  if (!record$schema_version %in% c(1L, 2L, 3L)) stop("Unsupported history schema version.")
  studio_history_timestamp(record$timestamp)
  record$request = studio_request_from_list(record$request)
  if (is.null(record$id)) record$id = tools::file_path_sans_ext(basename(path))
  if (is.null(record$status)) record$status = "completed"
  if (!record$status %in% c("queued", "running", "completed", "failed", "cancelled")) stop("Invalid history status.")
  record$favorite = isTRUE(record$favorite)
  record
}

studio_history = function(directory = ".studio/history") {
  files = list.files(directory, pattern = "\\.json$", full.names = TRUE)
  records = lapply(files, function(path) {
    tryCatch(studio_load_history(path), error = function(e) {
      warning("Skipping invalid history file ", basename(path), ": ", conditionMessage(e))
      NULL
    })
  })
  records = setNames(records, files)
  records = Filter(Negate(is.null), records)
  if (length(records)) records = records[order(vapply(records, function(x) {
    studio_history_timestamp(x$timestamp)
  }, numeric(1)), decreasing = TRUE)]
  records
}

studio_export_trajectory = function(result, path) {
  coordinates = c("x", "y", "z")[seq_len(dim(result$positions)[3])]
  rows = lapply(seq_len(dim(result$positions)[2]), function(body) {
    data = data.frame(time = result$time, body = result$body_names[body])
    for (axis in seq_along(coordinates)) {
      data[[coordinates[axis]]] = result$positions[, body, axis]
      data[[paste0("v", coordinates[axis])]] = result$velocities[, body, axis]
    }
    data
  })
  utils::write.csv(do.call(rbind, rows), path, row.names = FALSE)
  invisible(path)
}
