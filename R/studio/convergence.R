# Resolution studies compose normal runs and Integrator Lab comparisons.
studio_convergence_requests = function(request, integrator, timesteps) {
  request = studio_validate_request(request)
  if (!is.character(integrator) || length(integrator) != 1L || is.na(integrator))
    stop("Choose one integrator for a convergence study.")
  if (!is.numeric(timesteps) || !is.null(dim(timesteps)) || length(timesteps) < 2L ||
      any(!is.finite(timesteps)) || any(timesteps <= 0) || anyDuplicated(timesteps))
    stop("Supply at least two distinct positive finite timesteps.")
  requests = lapply(sort(timesteps, decreasing = TRUE), function(h) {
    args = unclass(request); args$integrator = integrator; args$timestep = h
    do.call(simulation_request, args)
  })
  steps = vapply(requests, function(r) round(r$duration / r$timestep), numeric(1))
  if (anyDuplicated(steps)) stop("Timesteps must specify distinct actual step counts.")
  requests
}

# A closed-form circular Kepler orbit, including uniform barycentre motion.
# Only accept circular initial conditions to roundoff; do not approximate an ellipse.
studio_circular_reference = function(request, time, gravitational_constant = G) {
  if (!identical(request$system, "two_body"))
    stop("The analytic reference currently supports circular two-body initial conditions only.")
  p = request$parameters
  r = p$positions[2, ] - p$positions[1, ]
  v = p$velocities[2, ] - p$velocities[1, ]
  radius = sqrt(sum(r^2)); speed2 = sum(v^2)
  gm = gravitational_constant * sum(p$masses)
  circular = c(sum(r * v) / (radius * sqrt(speed2)), speed2 * radius / gm - 1)
  if (any(!is.finite(circular)) || any(abs(circular) > 100 * .Machine$double.eps))
    stop("Analytic circular reference is not applicable: require tangential circular Kepler initial velocity.")
  omega = sqrt(gm / radius^3)
  phase = omega * time
  relative_r = outer(cos(phase), r) + outer(sin(phase) / omega, v)
  relative_v = -outer(omega * sin(phase), r) + outer(cos(phase), v)
  centre = colSums(p$masses * p$positions) / sum(p$masses)
  velocity = colSums(p$masses * p$velocities) / sum(p$masses)
  fractions = c(-p$masses[2], p$masses[1]) / sum(p$masses)
  positions = velocities = array(0, c(length(time), 2, 2))
  for (body in 1:2) {
    positions[, body, ] = matrix(centre, length(time), 2, byrow = TRUE) +
      outer(time, velocity) + fractions[body] * relative_r
    velocities[, body, ] = matrix(velocity, length(time), 2, byrow = TRUE) + fractions[body] * relative_v
  }
  # Preserve the supplied initial states exactly through coordinate recomposition.
  for (i in which(time == 0)) {
    positions[i, , ] = p$positions; velocities[i, , ] = p$velocities
  }
  list(time = time, positions = positions, velocities = velocities,
    model = studio_run_model(request, gravitational_constant))
}

studio_convergence_reference_choice = function(reference, reference_run, estimate_order) {
  if (!is.character(reference) || length(reference) != 1L || is.na(reference) ||
      !reference %in% c("analytic", "finest", "numerical"))
    stop("Explicitly choose reference = 'analytic', 'finest', or 'numerical'.")
  if (!is.logical(estimate_order) || length(estimate_order) != 1L || is.na(estimate_order))
    stop("estimate_order must be TRUE or FALSE.")
  if (reference == "numerical" && is.null(reference_run)) stop("Select a saved numerical reference_run.")
  if (reference != "numerical" && !is.null(reference_run)) stop("reference_run applies only to a numerical reference.")
  invisible(TRUE)
}

# All validation precedes execution/history writes. A selected reference is
# reused, or archived with the same scientific ID if supplied from elsewhere.
studio_prepare_convergence = function(request, integrator, timesteps, reference,
    reference_run, estimate_order, directory) {
  studio_convergence_reference_choice(reference, reference_run, estimate_order)
  requests = studio_convergence_requests(request, integrator, timesteps)
  if (reference == "analytic") studio_circular_reference(requests[[1]], 0)
  reference_path = NULL
  if (reference == "numerical") {
    result = if (inherits(reference_run, "simulation_result")) studio_validate_result(reference_run) else
      studio_load_result(reference_run)
    studio_check_comparison_requests(list(requests[[1]], result$request))
    if (!isTRUE(all.equal(result$model, studio_run_model(requests[[1]], G), tolerance = 0)))
      stop("Numerical reference model/constants do not match the current study engine.")
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    if (is.character(reference_run) &&
        identical(normalizePath(dirname(reference_run)), normalizePath(directory))) {
      reference_path = normalizePath(reference_run)
    } else reference_path = studio_save_history(result, directory)
  }
  list(requests = requests, reference_path = reference_path)
}

# Estimates describe the measured observable. They are never constrained by theory.
estimate_convergence_order = function(timesteps, errors) {
  if (!is.numeric(timesteps) || !is.numeric(errors) || length(timesteps) != length(errors) ||
      !is.null(dim(timesteps)) || !is.null(dim(errors)) || any(!is.finite(timesteps)) ||
      any(timesteps <= 0) || anyDuplicated(timesteps)) stop("Use distinct positive finite timesteps and equally sized numeric errors.")
  order = order(timesteps, decreasing = TRUE)
  h = timesteps[order]; e = errors[order]
  included = is.finite(e) & e > 0
  slope = intercept = r_squared = NA_real_
  if (sum(included) >= 2L) {
    x = log(h[included]); y = log(e[included])
    dx = x - mean(x); dy = y - mean(y)
    if (sum(dx^2) > 0) {
      slope = sum(dx * dy) / sum(dx^2)
      intercept = mean(y) - slope * mean(x)
      if (sum(dy^2) > 0) r_squared = 1 - sum((y - intercept - slope * x)^2) / sum(dy^2)
    }
  }
  local = data.frame(coarse_timestep = utils::head(h, -1), fine_timestep = tail(h, -1),
    order = rep(NA_real_, max(0L, length(h) - 1L)))
  if (length(h) > 1L) {
    valid = utils::head(included, -1) & tail(included, -1) &
      (log(utils::head(h, -1)) - log(tail(h, -1)) > 0)
    local$order[valid] = (log(utils::head(e, -1)[valid]) - log(tail(e, -1)[valid])) /
      (log(utils::head(h, -1)[valid]) - log(tail(h, -1)[valid]))
  }
  list(order = slope, log_intercept = intercept, r_squared = r_squared,
    points = sum(included), excluded_points = sum(!included),
    minimum_timestep = if (any(included)) min(h[included]) else NA_real_,
    maximum_timestep = if (any(included)) max(h[included]) else NA_real_,
    samples = data.frame(timestep = h, error = e, included = included,
      reason = ifelse(!is.finite(e), "nonfinite/unavailable", ifelse(e <= 0, "nonpositive", "included"))),
    local = local)
}

studio_convergence_study = function(paths, reference, reference_run = NULL, estimate_order = TRUE) {
  studio_convergence_reference_choice(reference, reference_run, estimate_order)
  if (!is.character(paths) || length(paths) < 2L || anyNA(paths) || anyDuplicated(paths))
    stop("A study needs at least two distinct saved runs.")
  paths = normalizePath(paths, mustWork = TRUE)
  records = lapply(paths, studio_load_history)
  requests = studio_check_comparison_requests(lapply(records, function(r) r$request))
  methods = vapply(requests, function(r) r$integrator, character(1))
  counts = vapply(requests, function(r) round(r$duration / r$timestep), numeric(1))
  if (length(unique(methods)) != 1L || anyDuplicated(counts))
    stop("A convergence study needs one integrator and distinct actual step counts.")
  index = order(counts)
  paths = paths[index]; requests = requests[index]; counts = counts[index]
  baseline = requests[[1]]
  all_paths = paths
  reference_path = tail(paths, 1)
  if (reference == "numerical") {
    if (!is.character(reference_run) || length(reference_run) != 1L || is.na(reference_run))
      stop("For saved-run analysis, reference_run must be a completed history record path.")
    reference_path = normalizePath(reference_run, mustWork = TRUE)
    studio_load_result(reference_path) # A selected reference must already be complete.
    if (!reference_path %in% all_paths) all_paths = c(all_paths, reference_path)
  }
  comparison = studio_compare_runs(all_paths, match(reference_path, all_paths))
  indices = match(paths, comparison$members$path)
  metrics = comparison$metrics[indices, , drop = FALSE]
  rownames(metrics) = NULL
  # Actual h may differ by roundoff from the requested value under existing validation.
  metrics$requested_timestep = metrics$timestep
  metrics$timestep = baseline$duration / counts
  numerical_reference = comparison$results[[match(reference_path, comparison$members$path)]]
  known = Filter(Negate(is.null), comparison$results)
  gravity = if (length(known)) known[[1]]$provenance$G else G
  if (reference == "analytic") studio_circular_reference(baseline, 0, gravity)
  metrics$is_reference = reference != "analytic" & paths == reference_path
  state_metrics = c("final_position_error", "final_velocity_error", "max_position_error", "max_velocity_error")
  for (name in state_metrics) metrics[[name]] = NA_real_
  # Preserve cost and conservation metrics, but do not expose Lab's union-grid
  # state differences as convergence errors: the sampling rules differ.
  metrics[c("final_position_difference", "final_velocity_difference", "max_position_difference", "max_velocity_difference")] = NULL
  errors = setNames(vector("list", length(paths)), metrics$run_id)
  for (i in seq_along(paths)) {
    result = comparison$results[[indices[i]]]
    if (is.null(result)) next
    target = if (reference == "analytic") studio_circular_reference(result$request, result$time, gravity) else numerical_reference
    if (is.null(target)) next
    delta = studio_state_difference(result, target, time = result$time)
    names(delta) = c("time", "position_error", "velocity_error")
    errors[[i]] = delta
    metrics$final_position_error[i] = tail(delta$position_error, 1)
    metrics$final_velocity_error[i] = tail(delta$velocity_error, 1)
    metrics$max_position_error[i] = max(delta$position_error)
    metrics$max_velocity_error[i] = max(delta$velocity_error)
  }
  conservation = c(energy_max_absolute_drift = "J", energy_max_relative_drift = "1",
    angular_momentum_max_absolute_drift = "kg m^2/s", angular_momentum_max_relative_drift = "1",
    centre_of_mass_max_drift = "m", jacobi_max_relative_drift = "1", specific_energy_max_relative_drift = "1")
  length_unit = if (baseline$system == "restricted_three_body") "normalized" else "m"
  speed_unit = if (baseline$system == "restricted_three_body") "normalized" else "m/s"
  metric_registry = data.frame(metric = c(state_metrics, names(conservation)),
    kind = c(rep(if (reference == "analytic") "analytic_error" else "numerical_reference_difference", 4), rep("conservation_drift", length(conservation))),
    units = c(length_unit, speed_unit, length_unit, speed_unit, unname(conservation)))
  estimates = if (estimate_order) setNames(lapply(metric_registry$metric, function(metric) {
    values = metrics[[metric]]
    values[metrics$status != "completed" | is.na(metrics$trajectory_valid) | !metrics$trajectory_valid] = NA_real_
    if (metric %in% state_metrics) values[metrics$is_reference] = NA_real_
    estimate_convergence_order(metrics$timestep, values)
  }), metric_registry$metric) else list()
  estimate_table = data.frame(metric = character(), order = numeric(), points = integer(), r_squared = numeric())
  if (length(estimates)) estimate_table = do.call(rbind, lapply(names(estimates), function(metric) {
    e = estimates[[metric]]
    data.frame(metric = metric, order = e$order, points = e$points, r_squared = e$r_squared)
  }))
  reference_id = if (reference == "analytic") NULL else comparison$reference_run_id
  comparison$convergence = list(schema_version = 1L, reference = reference,
    reference_run_id = reference_id, study_run_ids = metrics$run_id, estimate_order = estimate_order)
  structure(list(schema_version = 1L, id = comparison$id, timestamp = comparison$timestamp,
    integrator = methods[1], theoretical_order = studio_integrators()[[methods[1]]]$order,
    reference = list(type = reference, exact = reference == "analytic", run_id = reference_id,
      status = if (reference == "analytic") "available" else comparison$reference_status,
      description = if (reference == "analytic") "Closed-form circular two-body orbit, evaluated in floating point." else
        "Numerical reference; differences are not errors against an exact solution."),
    metrics = metrics, metric_registry = metric_registry, errors = errors,
    estimates = estimates, estimate_table = estimate_table, comparison = comparison,
    definitions = list(sampling = "Evaluate at each candidate's stored times; analytic state evaluated directly, numerical reference interpolated linearly without extrapolation.",
      state = "Maximum Euclidean difference across integrated bodies; position and velocity remain separate, in native units.",
      conservation = "Conservation errors are drift from initial invariants, independent of the chosen state reference.",
      order = "Least-squares slope of log(error) versus log(actual timestep); adjacent ratios are also reported. Excludes failed/invalid, nonpositive and nonfinite errors and the numerical reference itself for state metrics.",
      limitations = "Sampled trajectory maxima can miss between-sample peaks. Numerical reference error, interpolation, roundoff and non-asymptotic timesteps can distort order estimates. Theory is metadata, not a fit constraint.")),
    class = "convergence_study")
}

run_convergence_study = function(request, integrator, timesteps, reference,
    reference_run = NULL, estimate_order = TRUE, directory = ".studio/history") {
  studio_require_json()
  setup = studio_prepare_convergence(request, integrator, timesteps, reference, reference_run, estimate_order, directory)
  paths = vapply(setup$requests, function(r) {
    failure = NULL
    result = tryCatch(run_simulation(r), error = function(e) { failure <<- conditionMessage(e); NULL })
    if (is.null(result)) studio_save_failure(r, failure, directory) else studio_save_history(result, directory)
  }, character(1))
  study = studio_convergence_study(unname(paths), reference, setup$reference_path, estimate_order)
  study$path = studio_save_convergence_study(study)
  study
}

studio_start_convergence_study = function(request, integrator, timesteps, reference,
    reference_run = NULL, estimate_order = TRUE, directory = ".studio/history", root = NULL) {
  setup = studio_prepare_convergence(request, integrator, timesteps, reference, reference_run, estimate_order, directory)
  job = studio_start_job(setup$requests, directory, root)
  tryCatch({
    study = studio_convergence_study(job$paths, reference, setup$reference_path, estimate_order)
    job$convergence_path = studio_save_convergence_study(study)
    job
  }, error = function(e) {
    studio_cancel_job(job, "Convergence study setup failed.")
    stop(e)
  })
}

studio_save_convergence_study = function(study) {
  if (!inherits(study, "convergence_study")) stop("Expected a convergence_study.")
  studio_save_comparison(study$comparison)
}

studio_load_convergence_study = function(path) {
  comparison = studio_load_comparison(path)
  spec = comparison$convergence
  if (!is.list(spec) || !identical(spec$schema_version, 1L)) stop("No supported convergence specification in this comparison.")
  # Ordinary history JSON encodes NULL list fields as empty objects.
  if (is.list(spec$reference_run_id) && !length(spec$reference_run_id)) spec$reference_run_id = NULL
  ids = unlist(spec$study_run_ids, use.names = FALSE)
  if (!is.character(ids) || length(ids) < 2L || anyNA(ids) || anyDuplicated(ids) ||
      any(!ids %in% comparison$members$run_id)) stop("Invalid convergence study members.")
  reference_path = NULL
  if (identical(spec$reference, "numerical")) {
    if (!studio_valid_id(spec$reference_run_id) || !spec$reference_run_id %in% comparison$members$run_id)
      stop("Missing selected numerical reference.")
    reference_path = comparison$members$path[match(spec$reference_run_id, comparison$members$run_id)]
  }
  study = studio_convergence_study(comparison$members$path[match(ids, comparison$members$run_id)],
    spec$reference, reference_path, spec$estimate_order)
  if (!identical(study$reference$run_id, spec$reference_run_id) ||
      !setequal(comparison$members$run_id, c(ids, spec$reference_run_id)))
    stop("Convergence reference or member specification does not match the linked runs.")
  study$id = study$comparison$id = comparison$id
  study$timestamp = study$comparison$timestamp = comparison$timestamp
  study$path = path
  study
}

studio_plot_convergence = function(study, metric = "final_position_error", log_log = TRUE, show_fit = TRUE) {
  if (!inherits(study, "convergence_study") || !metric %in% study$metric_registry$metric)
    stop("Choose a metric from this convergence study's registry.")
  if (!is.logical(log_log) || length(log_log) != 1L || is.na(log_log) ||
      !is.logical(show_fit) || length(show_fit) != 1L || is.na(show_fit)) stop("Plot switches must be TRUE or FALSE.")
  h = study$metrics$timestep; error = study$metrics[[metric]]
  included = study$metrics$status == "completed" & !is.na(study$metrics$trajectory_valid) &
    study$metrics$trajectory_valid & is.finite(error) & if (log_log) error > 0 else error >= 0
  if (metric %in% c("final_position_error", "final_velocity_error", "max_position_error", "max_velocity_error"))
    included = included & !study$metrics$is_reference
  if (!any(included)) {
    graphics::plot.new(); graphics::text(0.5, 0.5, "No eligible finite errors for this metric/reference.")
    return(invisible(NULL))
  }
  row = study$metric_registry[study$metric_registry$metric == metric, ]
  graphics::plot(h[included], error[included], log = if (log_log) "xy" else "", type = "b", pch = 19,
    xlab = "Actual timestep (system time units)", ylab = paste0(metric, " [", row$units, "]"),
    main = paste(study$integrator, "|", study$reference$type, "reference"))
  fit = study$estimates[[metric]]
  if (show_fit && log_log && !is.null(fit) && is.finite(fit$order)) {
    grid = range(h[included])
    graphics::lines(grid, exp(fit$log_intercept + fit$order * log(grid)), lty = 2, col = "steelblue")
    graphics::legend("topleft", legend = sprintf("Empirical p = %.3g (%d points); theoretical method order = %g",
      fit$order, fit$points, study$theoretical_order), bty = "n", cex = 0.8)
  }
  invisible(data.frame(timestep = h, error = error, included = included))
}
