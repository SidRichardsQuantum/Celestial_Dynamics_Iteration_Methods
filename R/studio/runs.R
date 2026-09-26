# A completed scientific run is still a simulation_result. Request parameters,
# trajectory arrays and diagnostic columns retain their existing meanings.
studio_run_id = function() {
  paste0("run-", format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC"), "-",
         Sys.getpid(), "-", basename(tempfile()))
}

studio_valid_id = function(id) {
  is.character(id) && length(id) == 1L && !is.na(id) &&
    grepl("^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$", id)
}

studio_run_timestamp = function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
}

# Captured when sources are loaded/built, not when a later run happens to save.
studio_source_fingerprint = function(root) {
  # R CMD build adds packaging fields to DESCRIPTION. Version is recorded
  # separately; hash R sources so checkout and installed identities agree.
  paths = paste0("R/", sort(list.files(file.path(root, "R"),
    pattern = "\\.R$", recursive = TRUE)))
  setNames(as.character(tools::md5sum(file.path(root, paths))), paths)
}

studio_run_provenance = function() {
  package = "CelestialDynamicsIterationMethods"
  if (isNamespace(environment(run_simulation))) {
    version = as.character(getNamespaceVersion(environment(run_simulation)))
    fingerprint = cd_engine_fingerprint
  } else {
    version = unname(read.dcf(cd_path("DESCRIPTION"))[1, "Version"])
    fingerprint = get(".cd_engine_fingerprint", envir = .GlobalEnv)
  }
  list(studio_schema = 2L, package = package, package_version = version,
       engine = paste(package, version), R = R.version.string,
       platform = R.version$platform, G = G, source_fingerprint = fingerprint)
}

studio_run_model = function(request, gravitational_constant) {
  system = request$system
  restricted = system == "restricted_three_body"
  massive = !is.null(request$parameters$masses)
  list(version = 1L, force = "newtonian_point_mass_gravity",
       formulation = system,
       frame = if (restricted) "rotating" else "inertial",
       units = if (restricted) list(position = "normalized", velocity = "normalized",
         time = "normalized", mass = "normalized") else
         list(position = "m", velocity = "m/s", time = "s", mass = "kg"),
       constants = if (restricted) list() else list(G = gravitational_constant),
       body_roles = if (massive) rep("integrated_massive", length(request$parameters$masses)) else
         if (restricted) "integrated_test_particle" else
           c("prescribed_primary", "prescribed_primary", "integrated_test_particle"))
}

# Reject process handles, reactive closures and arbitrary R objects at every
# nesting level, including extensions in raw output or provenance.
studio_validate_passive = function(value, depth = 0L) {
  if (depth > 64L || !typeof(value) %in%
      c("NULL", "list", "double", "integer", "logical", "character")) {
    stop("Scientific runs must contain passive data only.")
  }
  attributes = attributes(value)
  if (length(attributes)) {
    if (!all(names(attributes) %in% c("names", "dim", "dimnames", "class", "row.names")) ||
        !all(attributes$class %in% c("simulation_result", "simulation_request",
                                    "data.frame", "matrix", "array"))) {
      stop("Unsupported scientific data attributes or class.")
    }
    lapply(attributes, studio_validate_passive, depth = depth + 1L)
  }
  if (is.list(value)) lapply(value, studio_validate_passive, depth = depth + 1L)
  invisible(TRUE)
}

# Add missing schema-1 metadata without recomputing or replacing scientific data.
# A historical file supplies its record ID so repeated reads have stable identity.
studio_upgrade_result = function(result, legacy_id = NULL) {
  if (!is.list(result) || !inherits(result, "simulation_result")) stop("Expected a simulation_result.")
  version = result$schema_version
  if (is.null(version)) version = 1L
  if (!is.numeric(version) || length(version) != 1L || is.na(version) ||
      !version %in% c(1L, 2L)) stop("Unsupported simulation result schema version.")
  if (version == 1L) {
    result$schema_version = 2L
    result$id = if (is.null(legacy_id)) studio_run_id() else legacy_id
    result$lineage = list(parent_run_id = NULL)
    result$timestamps = list(started_at = NULL, completed_at = result$timestamp)
    result$model = studio_run_model(result$request, result$provenance$G)
    result$provenance$package = "CelestialDynamicsIterationMethods"
    engine = result$provenance$engine
    result$provenance$package_version = if (is.character(engine) && length(engine) == 1L &&
      !is.na(engine) && grepl("^CelestialDynamicsIterationMethods [0-9]+\\.[0-9]+", engine))
        sub("^CelestialDynamicsIterationMethods ", "", engine) else NA_character_
    # Unknown start time, platform and source identity remain unknown.
  }
  result
}

studio_validate_result = function(result) {
  studio_validate_passive(result)
  result = studio_upgrade_result(result)
  required = c("id", "schema_version", "request", "time", "positions", "velocities",
    "masses", "body_names", "units", "raw", "diagnostics", "diagnostic_summary",
    "runtime_seconds", "timestamp", "timestamps", "provenance", "model", "lineage")
  if (anyDuplicated(names(result)) || !all(required %in% names(result))) stop("Incomplete simulation_result.")
  if (any(c("favorite", "tags", "preset") %in% names(result))) {
    stop("Favorites, tags and preset labels belong in history metadata, not scientific results.")
  }
  if (!studio_valid_id(result$id)) stop("Invalid scientific run ID.")
  parent = result$lineage$parent_run_id
  if (!is.list(result$lineage) || !"parent_run_id" %in% names(result$lineage) ||
      (!is.null(parent) && (!studio_valid_id(parent) || identical(parent, result$id)))) {
    stop("Invalid run lineage.")
  }
  request = studio_validate_request(result$request, execution = FALSE)
  if (!isTRUE(all.equal(request, result$request, tolerance = 0))) stop("Run request must contain resolved defaults.")
  n = length(result$time)
  shape = dim(result$positions)
  spec = studio_catalog()[[request$system]]
  bodies = if (!is.null(request$parameters$masses)) length(request$parameters$masses) else
    if (request$system == "sitnikov") 3L else 1L
  expected = c(n, bodies, spec$dimensions)
  if (!is.numeric(result$positions) || !is.numeric(result$velocities) ||
      !identical(as.integer(shape), as.integer(expected)) ||
      !identical(dim(result$velocities), shape) ||
      any(!is.finite(result$positions)) || any(!is.finite(result$velocities))) {
    stop("Trajectory must contain finite, matching time by body by coordinate arrays.")
  }
  if (!is.numeric(result$time) || !is.null(dim(result$time)) || n < 2L ||
      any(!is.finite(result$time)) || any(diff(result$time) <= 0) ||
      n - 1 != round(request$duration / request$timestep) ||
      !isTRUE(all.equal(result$time, seq(0, request$duration, length.out = n), tolerance = 1e-12))) {
    stop("Time grid does not match the fixed-step request.")
  }
  if (!is.character(result$body_names) || length(result$body_names) != bodies ||
      anyNA(result$body_names) || any(!nzchar(result$body_names)) || anyDuplicated(result$body_names)) {
    stop("Run body names must be distinct nonempty labels.")
  }
  if (!isTRUE(all.equal(result$masses, request$parameters$masses, tolerance = 0))) stop("Run masses do not match its request.")
  p = request$parameters
  if (!is.null(p$masses)) {
    if (!isTRUE(all.equal(unname(result$positions[1, , ]), unname(p$positions), tolerance = 0)) ||
        !isTRUE(all.equal(unname(result$velocities[1, , ]), unname(p$velocities), tolerance = 0))) {
      stop("Trajectory initial conditions do not match its request.")
    }
  } else if (request$system == "restricted_three_body") {
    if (!isTRUE(all.equal(unname(c(result$positions[1, 1, ], result$velocities[1, 1, ])),
                         unname(p$state0), tolerance = 0))) stop("Particle initial conditions do not match its request.")
  } else if (result$positions[1, 3, 3] != p$z0 || result$velocities[1, 3, 3] != p$vz0) {
    stop("Sitnikov initial conditions do not match its request.")
  }
  diagnostics = result$diagnostics
  if (!is.data.frame(diagnostics) || anyDuplicated(names(diagnostics)) || nrow(diagnostics) != n ||
      !all(c("time", spec$diagnostics) %in% names(diagnostics)) ||
      !all(vapply(diagnostics, is.numeric, logical(1))) ||
      !isTRUE(all.equal(diagnostics$time, result$time, tolerance = 0))) {
    stop("Diagnostics must be numeric series aligned with the trajectory time grid.")
  }
  if (!isTRUE(all.equal(result$diagnostic_summary, studio_diagnostic_summary(diagnostics), tolerance = 0))) {
    stop("Diagnostic summary does not match the saved diagnostic series.")
  }
  if (!is.numeric(result$runtime_seconds) || length(result$runtime_seconds) != 1L ||
      !is.finite(result$runtime_seconds) || result$runtime_seconds < 0) stop("Invalid solver runtime.")
  if (!is.character(result$units) || length(result$units) != 1L || is.na(result$units) ||
      !nzchar(result$units) || !is.list(result$raw)) stop("Missing units or raw solver output.")
  # Existing plots still consume raw states. Verify that this compatibility
  # representation cannot disagree with the normalized scientific arrays.
  same = function(a, b) isTRUE(all.equal(unname(a), unname(b), tolerance = 0))
  raw = result$raw
  raw_matches = switch(request$system,
    n_body = same(raw$positions, result$positions) && same(raw$velocities, result$velocities) &&
      same(raw$masses, result$masses),
    restricted_three_body = is.matrix(raw$states) &&
      identical(dim(raw$states), c(as.integer(n), 6L)) &&
      identical(colnames(raw$states), c("x", "y", "z", "vx", "vy", "vz")) &&
      same(raw$t, result$time) && same(raw$mu, p$mu) &&
      same(raw$states[, 1:3], result$positions[, 1, ]) &&
      same(raw$states[, 4:6], result$velocities[, 1, ]),
    sitnikov = same(raw$t, result$time) && same(raw$primary_a, result$positions[, 1, ]) &&
      same(raw$primary_b, result$positions[, 2, ]) && same(raw$third, result$positions[, 3, ]) &&
      same(raw$z, result$positions[, 3, 3]) && same(raw$vz, result$velocities[, 3, 3]),
    all(vapply(seq_len(bodies), function(i) {
      all(vapply(1:2, function(axis) {
        suffix = paste0(c("x", "y")[axis], "_", letters[i])
        same(raw[[suffix]], result$positions[, i, axis]) &&
          same(raw[[paste0("v", suffix)]], result$velocities[, i, axis])
      }, logical(1)))
    }, logical(1))))
  if (!raw_matches) stop("Raw solver output does not match the normalized trajectory.")
  provenance = result$provenance
  if (!is.list(provenance) || !identical(provenance$package, "CelestialDynamicsIterationMethods") ||
      !is.character(provenance$package_version) || length(provenance$package_version) != 1L ||
      !is.character(provenance$R) || length(provenance$R) != 1L || is.na(provenance$R) ||
      !is.character(provenance$engine) || length(provenance$engine) != 1L || is.na(provenance$engine)) {
    stop("Incomplete run provenance.")
  }
  studio_positive_scalar(provenance$G, "Recorded gravitational constant")
  fingerprint = provenance$source_fingerprint
  if (!is.null(fingerprint) && (!is.character(fingerprint) || !length(fingerprint) ||
      anyNA(fingerprint) || is.null(names(fingerprint)) || anyDuplicated(names(fingerprint)) ||
      any(!nzchar(names(fingerprint))) || any(!grepl("^[a-f0-9]{32}$", fingerprint)))) {
    stop("Invalid source fingerprint.")
  }
  if (!isTRUE(all.equal(result$model, studio_run_model(request, provenance$G), tolerance = 0))) {
    stop("Unsupported or inconsistent run model configuration.")
  }
  completed = studio_history_timestamp(result$timestamp)
  if (!is.list(result$timestamps) || !all(c("started_at", "completed_at") %in% names(result$timestamps)) ||
      !identical(result$timestamps$completed_at, result$timestamp)) stop("Invalid run timestamps.")
  if (!is.null(result$timestamps$started_at) &&
      studio_history_timestamp(result$timestamps$started_at) > completed) stop("Run starts after completion.")
  invisible(result)
}

studio_run_summary = function(result) {
  result = studio_validate_result(result)
  data.frame(run_id = result$id, system = result$request$system,
    integrator = result$request$integrator, bodies = dim(result$positions)[2],
    dimensions = dim(result$positions)[3], steps = length(result$time) - 1L,
    duration = result$request$duration, timestep = result$request$timestep,
    runtime_seconds = result$runtime_seconds, completed_at = result$timestamp,
    package_version = result$provenance$package_version, schema_version = result$schema_version)
}

print.simulation_result = function(x, ...) {
  row = studio_run_summary(x)
  cat("Simulation run ", row$run_id, "\n", row$system, " / ", row$integrator,
      ": ", row$bodies, " bodies, ", row$steps, " steps\n",
      "Duration: ", format(row$duration), "; timestep: ", format(row$timestep),
      "; solver runtime: ", format(row$runtime_seconds), " s\n", sep = "")
  invisible(x)
}

summary.simulation_result = function(object, ...) studio_run_summary(object)

studio_rerun = function(result, progress = function(stage) invisible(NULL),
                        allow_engine_change = FALSE) {
  result = studio_validate_result(result)
  if (!is.logical(allow_engine_change) || length(allow_engine_change) != 1L ||
      is.na(allow_engine_change)) stop("allow_engine_change must be TRUE or FALSE.")
  current = studio_run_provenance()
  if (result$request$system != "restricted_three_body" && result$provenance$G != current$G) {
    stop("Recorded gravitational constant differs from this engine; exact rerun is unavailable.")
  }
  same_engine = identical(result$provenance$package_version, current$package_version) &&
    !is.null(result$provenance$source_fingerprint) &&
    identical(result$provenance$source_fingerprint, current$source_fingerprint)
  if (!same_engine) {
    if (!allow_engine_change) stop("Engine identity differs or is unknown. Set allow_engine_change = TRUE to run with the current engine.")
    warning("Rerunning with a changed or previously unidentified engine; numerical equivalence is not guaranteed.")
  }
  rerun = run_simulation(result$request, progress)
  rerun$lineage$parent_run_id = result$id
  rerun
}
