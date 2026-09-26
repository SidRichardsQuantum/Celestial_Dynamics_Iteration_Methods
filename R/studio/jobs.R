# Separate R processes keep solver calls off Shiny's event loop. Only this
# controller owns process handles; the worker sees passive history requests.
studio_stage_event = function(stage) {
  list(stage = stage, timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC"))
}

studio_job_update = function(path, status, stage, error = NULL) {
  record = studio_load_history(path)
  if (record$status %in% c("completed", "failed", "cancelled")) return(invisible(record))
  record$status = status
  record$stage = stage
  if (!is.null(error)) record$error = error
  record$lifecycle[[length(record$lifecycle) + 1L]] = studio_stage_event(stage)
  studio_write_record(record, path)
  invisible(record)
}

studio_job_worker = function(paths) {
  for (path in paths) {
    record = studio_load_history(path)
    if (record$status != "queued") next
    stage = "validating"
    tryCatch({
      result = run_simulation(record$request, function(value) {
        stage <<- value
        studio_job_update(path, "running", value)
      })
      result$id = record$run_id
      stage = "saving artifacts"
      studio_job_update(path, "running", stage)
      studio_publish_result(result, path, record$preset)
    }, error = function(e) {
      studio_job_update(path, "failed", paste("failed during", stage), conditionMessage(e))
    })
  }
  invisible(NULL)
}

studio_start_job = function(requests, directory = ".studio/history", root = NULL) {
  if (!requireNamespace("callr", quietly = TRUE)) {
    stop("Background runs require callr: install.packages('callr').")
  }
  if (!length(requests)) stop("Choose at least one request.")
  requests = lapply(requests, studio_validate_request)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  directory = normalizePath(directory, mustWork = TRUE)
  if (!is.null(root)) root = normalizePath(root, mustWork = TRUE)
  paths = character()
  process = NULL
  ready = FALSE
  launch_error = "Could not launch the background worker."
  on.exit(if (!ready) {
    if (!is.null(process) && process$is_alive()) process$kill()
    for (path in paths) studio_job_update(path, "failed", "launch failed", launch_error)
  }, add = TRUE)
  presets = studio_presets()
  for (request in requests) {
    id = studio_run_id()
    path = file.path(directory, paste0(id, ".json"))
    event = studio_stage_event("queued")
    studio_write_record(list(schema_version = 4L, id = id, run_id = id, status = "queued", stage = "queued",
      favorite = FALSE, tags = character(), preset = studio_preset_identity(request, presets), timestamp = event$timestamp,
      request = unclass(request), lifecycle = list(event)), path)
    paths = c(paths, path)
  }
  log_directory = file.path(directory, ".jobs", tools::file_path_sans_ext(basename(paths[1])))
  dir.create(log_directory, recursive = TRUE, showWarnings = FALSE)
  process = tryCatch(callr::r_bg(function(paths, root) {
    if (is.null(root)) {
      worker = get("studio_job_worker", envir = asNamespace("CelestialDynamicsIterationMethods"))
    } else {
      source(file.path(root, "R/load.R"), local = .GlobalEnv)
      assign(".cd_project_root", root, envir = .GlobalEnv)
      cd_load_studio()
      worker = studio_job_worker
    }
    worker(paths)
  }, args = list(paths = paths, root = root), supervise = TRUE,
     stdout = file.path(log_directory, "stdout.log"),
     stderr = file.path(log_directory, "stderr.log"), user_profile = FALSE),
    error = function(e) {
      launch_error <<- conditionMessage(e)
      stop(e)
    })
  ready = TRUE
  list(process = process, paths = paths, log_directory = log_directory)
}

# Call only after the owned worker has stopped. Completed/terminal records and
# their artifacts are untouched, including a completion that won the race.
studio_job_finish_unpublished = function(path, status, stage, error) {
  record = studio_load_history(path)
  if (!record$status %in% c("queued", "running")) return(invisible(record))
  partial = file.path(dirname(path), tools::file_path_sans_ext(basename(path)))
  unlink(partial, recursive = TRUE)
  studio_job_update(path, status, stage, error)
}

studio_poll_job = function(job) {
  alive = job$process$is_alive()
  if (!alive) {
    error = tryCatch({ job$process$get_result(); "Worker exited before completing the run." },
                     error = function(e) conditionMessage(e))
    for (path in job$paths) studio_job_finish_unpublished(path, "failed", "worker exited", error)
  }
  list(alive = alive, records = setNames(lapply(job$paths, studio_load_history), job$paths))
}

studio_cancel_job = function(job, reason = "Cancelled by user.") {
  # Stop and reap before writing terminal metadata. A result that won the race
  # and was atomically published remains completed, never relabelled cancelled.
  if (job$process$is_alive()) {
    job$process$kill()
    job$process$wait(timeout = 5000)
    if (job$process$is_alive()) stop("Worker has not stopped; cancellation is not yet confirmed.")
  }
  for (path in job$paths) {
    studio_job_finish_unpublished(path, "cancelled", "cancelled", reason)
  }
  invisible(studio_poll_job(job))
}
