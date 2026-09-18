if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()
if (requireNamespace("callr", quietly = TRUE) && requireNamespace("jsonlite", quietly = TRUE)) local({
  directory = tempfile("background-")
  jobs = list()
  on.exit({
    for (job in jobs) try(studio_cancel_job(job), silent = TRUE)
    unlink(directory, recursive = TRUE)
  })
  short = studio_preset("circular_two_body")
  short$duration = 10 * short$timestep
  job = studio_start_job(list(short), directory, cd_project_root())
  jobs[[length(jobs) + 1L]] = job
  stopifnot(job$process$get_pid() != Sys.getpid())
  job$process$wait(15000)
  snapshot = studio_poll_job(job)
  stopifnot(!snapshot$alive, snapshot$records[[1]]$status == "completed")
  result = studio_load_result(job$paths[1])
  baseline = run_simulation(short)
  stopifnot(identical(result$positions, baseline$positions),
    identical(result$diagnostics, baseline$diagnostics),
    identical(result$request, short))
  stages = vapply(snapshot$records[[1]]$lifecycle, function(x) x$stage, character(1))
  stopifnot(identical(stages, c("queued", "validating", "integrating",
    "computing diagnostics", "saving artifacts", "completed")))
  studio_cancel_job(job)
  stopifnot(studio_load_history(job$paths[1])$status == "completed")
  # Cancel during integration: keep earlier completion, cancel active and queued.
  long = studio_preset("pythagorean")
  job = studio_start_job(list(short, long, short), directory, cd_project_root())
  jobs[[length(jobs) + 1L]] = job
  deadline = Sys.time() + 20
  repeat {
    snapshot = studio_poll_job(job)
    if (snapshot$records[[2]]$stage == "integrating" || Sys.time() > deadline) break
    Sys.sleep(0.05)
  }
  stopifnot(snapshot$records[[1]]$status == "completed", snapshot$alive,
    snapshot$records[[2]]$stage == "integrating")
  # Model an unpublished partial artifact left behind by a stopped writer.
  partial = sub("\\.json$", "", job$paths[2])
  dir.create(partial)
  writeLines("partial", file.path(partial, "result.json.gz"))
  studio_cancel_job(job)
  stopifnot(!job$process$is_alive(), !dir.exists(partial))
  records = studio_poll_job(job)$records
  stopifnot(identical(vapply(records, function(r) r$status, character(1)) |> unname(),
    c("completed", "cancelled", "cancelled")),
    isTRUE(all.equal(records[[2]]$request, long, tolerance = 0)), nzchar(records[[2]]$error))
  # A crash removes only unpublished artifacts of this batch, preserving a
  # completed result, unrelated files, original requests and the crash reason.
  job = studio_start_job(list(short, long, short), directory, cd_project_root())
  jobs[[length(jobs) + 1L]] = job
  deadline = Sys.time() + 20
  repeat {
    snapshot = studio_poll_job(job)
    if (snapshot$records[[2]]$stage == "integrating" || Sys.time() > deadline) break
    Sys.sleep(0.05)
  }
  stopifnot(snapshot$records[[1]]$status == "completed", snapshot$alive,
    snapshot$records[[2]]$stage == "integrating")
  completed_files = c(job$paths[1], studio_artifact_path(job$paths[1], "result"),
    studio_artifact_path(job$paths[1], "preview"))
  completed_hashes = tools::md5sum(completed_files)
  partial = sub("\\.json$", "", job$paths[2])
  dir.create(partial)
  writeLines("unfinished result", file.path(partial, "result.json.gz"))
  writeLines("unfinished preview", file.path(partial, "preview.png"))
  unrelated = file.path(directory, "unrelated.txt")
  writeLines("keep", unrelated)
  job$process$kill()
  job$process$wait(5000)
  crashed = studio_poll_job(job)$records
  stopifnot(identical(unname(vapply(crashed, function(r) r$status, character(1))),
      c("completed", "failed", "failed")),
    !dir.exists(partial), file.exists(unrelated), nzchar(crashed[[2]]$error),
    isTRUE(all.equal(crashed[[2]]$request, long, tolerance = 0)),
    identical(tools::md5sum(completed_files), completed_hashes))
  # Polling again is idempotent; neither metadata nor finished artifacts change.
  stopifnot(identical(studio_poll_job(job)$records, crashed),
    identical(tools::md5sum(completed_files), completed_hashes))
  # Simulate process-creation failure without relying on host permission errors.
  local({
    original = get("r_bg", envir = asNamespace("callr"))
    on.exit(assignInNamespace("r_bg", original, ns = "callr"))
    failure = structure(list(message = "Test launch failure: process creation denied", call = NULL),
      class = c("studio_test_launch_error", "error", "condition"))
    assignInNamespace("r_bg", function(...) stop(failure), ns = "callr")
    failure_directory = file.path(directory, "launch-failure")
    error = tryCatch(studio_start_job(list(short, long), failure_directory, cd_project_root()),
      error = identity)
    failed = studio_history(failure_directory)
    stopifnot(inherits(error, "studio_test_launch_error"), length(failed) == 2L,
      identical(conditionMessage(error), failure$message),
      all(vapply(failed, function(r) r$status == "failed" && r$stage == "launch failed" &&
        identical(r$error, failure$message), logical(1))))
    expected = list(short, long)
    for (request in expected) stopifnot(any(vapply(failed, function(r) {
      isTRUE(all.equal(r$request, request, tolerance = 0))
    }, logical(1))))
  })
  # Real numerical failure travels through the worker, and another batch can run.
  bad = simulation_request("restricted_three_body", "RK4",
    list(mu = 0.1, state0 = c(0.5, 0, 0, 0, 0, 0)), 1e200, 1e200)
  job = studio_start_job(list(bad, short), directory, cd_project_root())
  jobs[[length(jobs) + 1L]] = job
  job$process$wait(15000)
  records = studio_poll_job(job)$records
  stopifnot(records[[1]]$status == "failed", nzchar(records[[1]]$error),
    records[[2]]$status == "completed")
  cat("Background execution, lifecycle, cancellation, completion races and worker failures passed.\n")
}) else cat("Background tests skipped: install callr and jsonlite.\n")
