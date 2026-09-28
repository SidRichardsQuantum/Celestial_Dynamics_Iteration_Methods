# Relative errors use an initial reference and a cancellation-aware scale.
# Undefined references stay NA; absolute quantities and drift remain available.
studio_relative_series = function(values, scale = abs(values[1])) {
  if (!length(values)) return(numeric())
  reference = values[1]
  if (!is.finite(reference) || !is.finite(scale) ||
      abs(reference) <= 100 * .Machine$double.eps * max(abs(scale), .Machine$double.xmin)) {
    return(rep(NA_real_, length(values)))
  }
  (values - reference) / abs(reference)
}

# Does not require a completed/persistable run: useful for inspecting failed or
# externally assembled normalized trajectories. Persistence validation is stricter.
studio_trajectory_checks = function(result) {
  time = result$time
  r = result$positions
  v = result$velocities
  shape = dim(r)
  shape_valid = is.numeric(r) && is.numeric(v) && length(shape) == 3L &&
    identical(shape, dim(v)) && shape[1] == length(time) &&
    shape[2] >= 1L && shape[3] %in% c(2L, 3L)
  time_valid = is.numeric(time) && is.null(dim(time)) && length(time) >= 1L &&
    all(is.finite(time)) && all(diff(time) > 0)
  values = c(if (is.numeric(time)) time, if (is.numeric(r)) r, if (is.numeric(v)) v)
  masses_valid = is.null(result$masses) || (is.numeric(result$masses) &&
    is.null(dim(result$masses)) && shape_valid && length(result$masses) == shape[2] &&
    all(is.finite(result$masses)) && all(result$masses > 0))
  issues = c(if (!shape_valid) "Expected matching time by body by coordinate arrays.",
    if (!time_valid) "Time must be finite and strictly increasing.",
    if (!masses_valid) "Masses must be positive, finite and match the body axis.",
    if (any(!is.finite(values))) "Trajectory contains NA, NaN or Inf.")
  list(valid = !length(issues), shape_valid = shape_valid, time_valid = time_valid,
    masses_valid = masses_valid, na_count = sum(is.na(values) & !is.nan(values)),
    nan_count = sum(is.nan(values)), inf_count = sum(is.infinite(values)), issues = issues)
}

# Structured interface; the legacy data-frame API below delegates here.
simulation_diagnostics = function(result, collision_distance = 0,
                                  near_collision_distance = NULL) {
  if (!is.list(result)) stop("Expected a normalized trajectory/result list.")
  threshold_ok = function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0
  if (!threshold_ok(collision_distance) ||
      (!is.null(near_collision_distance) && (!threshold_ok(near_collision_distance) ||
        near_collision_distance < collision_distance))) {
    stop("Collision thresholds must be finite, nonnegative distances; near must be >= collision.")
  }
  checks = studio_trajectory_checks(result)
  series = data.frame(time = numeric())
  registry = data.frame(metric = character(), kind = character(), units = character(),
                        definition = character())
  add = function(name, values, kind, units, definition) {
    series[[name]] <<- as.numeric(values)
    registry <<- rbind(registry, data.frame(metric = name, kind = kind,
      units = units, definition = definition))
  }
  unavailable = list()
  scalar = function(x, integer = FALSE) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0 ||
        (integer && x != floor(x))) NA_real_ else as.numeric(x)
  }
  statistics = result$solver_statistics
  performance = list(runtime_seconds = scalar(result$runtime_seconds),
    step_count = scalar(statistics$step_count, TRUE),
    force_evaluation_count = scalar(statistics$force_evaluation_count, TRUE))
  if (is.na(performance$force_evaluation_count))
    unavailable$force_evaluation_count = "Solver did not record force/RHS evaluations."
  if (is.na(performance$step_count)) unavailable$step_count = "Solver did not record completed steps."
  if (is.na(performance$runtime_seconds)) unavailable$runtime_seconds = "Solver runtime was not recorded."
  flags = list(collision = NA, near_collision = NA,
    collision_distance = collision_distance, near_collision_distance = near_collision_distance,
    scope = "Stored samples only; encounters between samples may be missed.")
  assumptions = c("Relative drift is signed (q(t)-q(0))/abs(q(0)); no fitted drift rate.",
    "Near-zero references yield NA, using 100 machine eps times the initial physical scale.",
    "Extrema use finite samples; final is the actual last sample, even if non-finite.")
  if (checks$shape_valid && checks$time_valid) {
    time = result$time
    n = length(time)
    bodies = dim(result$positions)[2]
    dimensions = dim(result$positions)[3]
    series = data.frame(time = time)
    system = result$request$system
    p = result$request$parameters
    massive = is.character(system) && length(system) == 1L &&
      system %in% c("two_body", "three_body", "n_body")
    restricted = identical(system, "restricted_three_body")
    sitnikov = identical(system, "sitnikov")
    # Require the supported model, not merely the presence of a mass vector.
    model_ok = massive || restricted || sitnikov
    if (!is.null(result$model)) {
      model_ok = model_ok && identical(result$model$force, "newtonian_point_mass_gravity") &&
        identical(result$model$formulation, system) &&
        identical(result$model$frame, if (restricted) "rotating" else "inertial") &&
        isTRUE(all.equal(result$model, studio_run_model(result$request,
          result$model$constants$G), tolerance = 0))
    }
    gravity = result$model$constants$G
    if (is.null(gravity)) gravity = result$provenance$G
    if (is.null(gravity)) gravity = G
    gravity_ok = is.numeric(gravity) && length(gravity) == 1L && is.finite(gravity) && gravity > 0
    physics_ok = model_ok && (restricted || gravity_ok)
    massive = massive && physics_ok && checks$masses_valid && !is.null(result$masses) &&
      bodies >= 2L && dimensions == 2L
    restricted = restricted && physics_ok && bodies == 1L && dimensions == 3L &&
      is.numeric(p$mu) && length(p$mu) == 1L && is.finite(p$mu) && p$mu > 0 && p$mu <= 0.5
    sitnikov = sitnikov && physics_ok && bodies == 3L && dimensions == 3L &&
      threshold_ok(p$primary_mass) && p$primary_mass > 0 &&
      threshold_ok(p$primary_radius) && p$primary_radius > 0
    if (!(massive || restricted || sitnikov))
      unavailable$invariants = "Unsupported or inconsistent physical model, dimensions or masses."
    if (!massive) unavailable$massive_invariants =
      "Total energy, momentum, angular momentum and centre of mass require the supported closed massive system."
    finite_state = vapply(seq_len(n), function(i)
      all(is.finite(result$positions[i, , ])) && all(is.finite(result$velocities[i, , ])), logical(1))
    distance_min = distance_max = rep(NA_real_, n)
    kinetic = potential = angular = angular_scale = rep(NA_real_, n)
    momentum = centre = centre_velocity = matrix(NA_real_, n, dimensions)
    momentum_scale = NA_real_
    if (massive) pairs = utils::combn(seq_len(bodies), 2)
    for (i in seq_len(n)) {
      r = matrix(result$positions[i, , ], bodies, dimensions)
      v = matrix(result$velocities[i, , ], bodies, dimensions)
      # In CR3BP include both prescribed primaries for separation checks only.
      geometry = if (restricted) rbind(c(-p$mu, 0, 0), c(1 - p$mu, 0, 0), r) else r
      if (all(is.finite(geometry)) && nrow(geometry) >= 2L) {
        distances = as.numeric(stats::dist(geometry))
        distance_min[i] = min(distances)
        distance_max[i] = max(distances)
      }
      if (massive && finite_state[i]) {
        m = result$masses
        kinetic[i] = sum(m * rowSums(v^2)) / 2
        separations = sqrt(colSums((t(r[pairs[1, ], , drop = FALSE]) -
                                   t(r[pairs[2, ], , drop = FALSE]))^2))
        # Singular energy is unavailable; collision flags still report overlap.
        potential[i] = if (any(separations == 0)) NA_real_ else
          -gravity * sum(m[pairs[1, ]] * m[pairs[2, ]] / separations)
        angular[i] = sum(m * (r[, 1] * v[, 2] - r[, 2] * v[, 1]))
        angular_scale[i] = sum(abs(m * r[, 1] * v[, 2]) + abs(m * r[, 2] * v[, 1]))
        momentum[i, ] = colSums(m * v)
        centre[i, ] = colSums(m * r) / sum(m)
        centre_velocity[i, ] = momentum[i, ] / sum(m)
        if (i == 1L) momentum_scale = sum(m * sqrt(rowSums(v^2)))
      }
    }
    invariant = function(name, values, units, definition, scale) {
      add(name, values, "absolute", units, definition)
      add(paste0(name, "_drift"), values - values[1], "absolute_drift", units, "q(t) - q(0)")
      add(paste0(name, "_relative_drift"), studio_relative_series(values, scale),
        "relative_error", "1", "(q(t) - q(0)) / abs(q(0)); NA for a near-zero reference")
    }
    if (massive) {
      energy = kinetic + potential
      invariant("energy", energy, "J", "sum(m*v^2)/2 - G*sum(i<j, m_i*m_j/r_ij)",
        max(kinetic[1], abs(potential[1])))
      invariant("angular_momentum", angular, "kg m^2/s", "sum(m*(x*vy-y*vx)); signed z component about the coordinate origin",
        angular_scale[1])
      for (axis in seq_len(dimensions)) {
        suffix = c("x", "y", "z")[axis]
        add(paste0("momentum_", suffix), momentum[, axis], "absolute", "kg m/s", "sum(m*v), coordinate component")
        add(paste0("momentum_drift_", suffix), momentum[, axis] - momentum[1, axis],
          "absolute_drift", "kg m/s", "P(t) - P(0), coordinate component")
        add(paste0("centre_of_mass_", suffix), centre[, axis], "absolute", "m", "sum(m*r)/sum(m), coordinate component")
        add(paste0("centre_of_mass_velocity_", suffix), centre_velocity[, axis], "absolute", "m/s", "P/sum(m), coordinate component")
      }
      norm = function(x) sqrt(rowSums(x^2))
      pd = norm(sweep(momentum, 2, momentum[1, ]))
      add("momentum_drift", pd, "absolute_drift", "kg m/s", "Euclidean norm of P(t)-P(0)")
      reference = norm(momentum)[1]
      denominator = if (all(is.na(studio_relative_series(c(reference, reference), momentum_scale)))) NA_real_ else reference
      add("momentum_relative_drift", pd / denominator, "relative_error", "1", "norm(P(t)-P(0))/norm(P(0)); NA for a near-zero reference")
      expected = matrix(centre[1, ], n, dimensions, byrow = TRUE) +
        outer(time - time[1], centre_velocity[1, ])
      add("centre_of_mass_drift", norm(centre - expected), "absolute_drift", "m", "norm(R(t)-R(0)-(t-t0)*Vcm(0)); residual from uniform motion")
      add("centre_of_mass_velocity_drift", norm(sweep(centre_velocity, 2, centre_velocity[1, ])),
        "absolute_drift", "m/s", "norm(Vcm(t)-Vcm(0))")
      if (identical(system, "two_body") && bodies == 2L) {
        r = matrix(result$positions[, 2, ] - result$positions[, 1, ], n, dimensions)
        v = matrix(result$velocities[, 2, ] - result$velocities[, 1, ], n, dimensions)
        radius = sqrt(rowSums(r^2))
        radius[radius == 0] = NA_real_
        gm = gravity * sum(result$masses)
        specific = rowSums(v^2) / 2 - gm / radius
        # Parabolic or numerically cancelling energies have no finite a.
        scale = pmax(rowSums(v^2) / 2, gm / radius)
        specific[which(abs(specific) <= 100 * .Machine$double.eps * scale)] = NA_real_
        add("semi_major_axis", -gm / (2 * specific), "absolute", "m", "-G*M/(2*relative specific orbital energy); NA near parabolic")
        evec = ((rowSums(v^2) - gm / radius) * r - rowSums(r * v) * v) / gm
        add("eccentricity", sqrt(rowSums(evec^2)), "absolute", "1", "norm(((v^2-G*M/r)*r-(r dot v)*v)/(G*M))")
      }
    } else if (restricted) {
      r = matrix(result$positions, n, 3)
      v = matrix(result$velocities, n, 3)
      potential_term = 2 * cd_cr3bp_potential(r, p$mu)
      speed2 = rowSums(v^2)
      invariant("jacobi", potential_term - speed2, "normalized", "x^2+y^2+2*((1-mu)/r1+mu/r2)-v^2 in the rotating frame",
        max(abs(potential_term[1]), speed2[1]))
    } else if (sitnikov) {
      z = result$positions[, 3, 3]
      kinetic = result$velocities[, 3, 3]^2 / 2
      potential = -2 * gravity * p$primary_mass / sqrt(p$primary_radius^2 + z^2)
      invariant("specific_energy", kinetic + potential, "m^2/s^2", "vz^2/2 - 2*G*m/sqrt(a^2+z^2); circular Sitnikov only",
        max(kinetic[1], abs(potential[1])))
    }
    length_unit = if (identical(system, "restricted_three_body")) "normalized" else "m"
    scope = if (restricted) "all pairs including the two prescribed primaries" else "all pairs in the stored positions"
    add("minimum_pairwise_separation", distance_min, "absolute", length_unit, paste("Minimum distance at each sample over", scope))
    add("maximum_pairwise_separation", distance_max, "absolute", length_unit, paste("Maximum distance at each sample over", scope))
    add("state_finite", finite_state, "flag", "0/1", "1 if every position and velocity at this sample is finite")
    add("collision", distance_min <= collision_distance, "flag", "0/1", "Minimum sampled pair separation <= collision_distance")
    add("near_collision", if (is.null(near_collision_distance)) rep(NA_real_, n) else
      distance_min <= near_collision_distance, "flag", "0/1", "Minimum sampled pair separation <= near_collision_distance; NA if unset")
    flags$collision = any(as.logical(series$collision))
    flags$near_collision = any(as.logical(series$near_collision))
    flags$pair_scope = scope
    checks$valid = checks$valid && !isTRUE(flags$collision)
    if (isTRUE(flags$collision)) checks$issues = c(checks$issues, "Sampled collision threshold reached.")
  }
  if (is.null(near_collision_distance)) unavailable$near_collision =
    "No physical radii or universal close-encounter distance: supply near_collision_distance in position units."
  diagnostic_values = unlist(series[setdiff(names(series), "time")], use.names = FALSE)
  checks$diagnostic_nan_count = sum(is.nan(diagnostic_values))
  checks$diagnostic_inf_count = sum(is.infinite(diagnostic_values))
  if (checks$diagnostic_nan_count + checks$diagnostic_inf_count > 0) {
    checks$valid = FALSE
    checks$issues = c(checks$issues, "Derived diagnostics contain NaN or Inf.")
  }
  summary = studio_diagnostics_table(series, registry)
  list(version = 1L, series = series, summary = summary, registry = registry,
       performance = performance, validity = checks, flags = flags,
       unavailable = unavailable, assumptions = assumptions)
}

studio_diagnostics_table = function(series, registry) {
  summary = registry
  for (name in c("initial", "final", "minimum", "maximum", "max_absolute", "max_absolute_change", "finite_samples", "nonfinite_samples"))
    summary[[name]] = numeric(nrow(registry))
  for (i in seq_len(nrow(registry))) {
    values = series[[registry$metric[i]]]
    finite = values[is.finite(values)]
    summary$initial[i] = values[1]
    summary$final[i] = tail(values, 1)
    summary$minimum[i] = if (length(finite)) min(finite) else NA_real_
    summary$maximum[i] = if (length(finite)) max(finite) else NA_real_
    summary$max_absolute[i] = if (length(finite)) max(abs(finite)) else NA_real_
    summary$max_absolute_change[i] = if (length(finite) && is.finite(values[1])) max(abs(finite - values[1])) else NA_real_
    summary$finite_samples[i] = length(finite)
    summary$nonfinite_samples[i] = length(values) - length(finite)
  }
  summary
}

studio_diagnostics = function(result) simulation_diagnostics(result)$series

studio_diagnostic_summary = function(diagnostics) {
  lapply(diagnostics[setdiff(names(diagnostics), "time")], function(values) {
    finite = values[is.finite(values)]
    list(initial = values[1], final = tail(values, 1),
         max_absolute_change = if (length(finite)) max(abs(finite - values[1])) else NA_real_)
  })
}

# This flags a demonstrated loss of conservation, not a guarantee of accuracy
# when the threshold passes. Display it beside the run, including animations.
studio_accuracy_warnings = function(result, threshold = 1e-3) {
  columns = intersect(c("energy_relative_drift", "jacobi_relative_drift",
                        "specific_energy_relative_drift"), names(result$diagnostics))
  messages = character()
  for (name in columns) {
    values = result$diagnostics[[name]]
    if (any(is.finite(values)) && max(abs(values), na.rm = TRUE) > threshold) {
      messages = c(messages, sprintf(
        "%s: %s reaches %.3g. This trajectory may be inaccurate; reduce the timestep and check convergence.",
        result$request$integrator, name, max(abs(values), na.rm = TRUE)))
    }
  }
  messages
}
