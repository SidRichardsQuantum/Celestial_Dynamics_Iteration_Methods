# Relative drift is undefined when the initial invariant is zero or cancels
# to roundoff. Absolute invariant series remain available in those cases.
studio_relative_series = function(values, scale = abs(values[1])) {
  if (abs(values[1]) <= 100 * .Machine$double.eps * max(scale, .Machine$double.xmin)) {
    return(rep(NA_real_, length(values)))
  }
  (values - values[1]) / abs(values[1])
}

studio_diagnostics = function(result) {
  system = result$request$system
  p = result$request$parameters
  if (!is.null(result$masses)) {
    energy = n_body_energy_series(result)
    angular = n_body_angular_momentum_series(result)
    momentum = vapply(seq_along(result$time), function(i) {
      colSums(result$velocities[i, , ] * result$masses)
    }, numeric(2))
    r0 = result$positions[1, , ]
    v0 = result$velocities[1, , ]
    kinetic0 = sum(result$masses * rowSums(v0^2)) / 2
    angular_scale = sum(abs(result$masses * r0[, 1] * v0[, 2]) +
                          abs(result$masses * r0[, 2] * v0[, 1]))
    diagnostics = data.frame(time = result$time, energy = energy,
      energy_relative_drift = studio_relative_series(energy, max(kinetic0, abs(energy[1]))),
      angular_momentum = angular,
      angular_momentum_relative_drift = studio_relative_series(angular, angular_scale),
      momentum_x = momentum[1, ], momentum_y = momentum[2, ])
    if (system == "two_body") {
      r = result$positions[, 2, ] - result$positions[, 1, ]
      v = result$velocities[, 2, ] - result$velocities[, 1, ]
      radius = sqrt(rowSums(r^2))
      gm = G * sum(result$masses)
      specific_energy = rowSums(v^2) / 2 - gm / radius
      diagnostics$semi_major_axis = -gm / (2 * specific_energy)
      evec = ((rowSums(v^2) - gm / radius) * r - rowSums(r * v) * v) / gm
      diagnostics$eccentricity = sqrt(rowSums(evec^2))
    }
  } else if (system == "restricted_three_body") {
    s = result$raw$states
    r1 = sqrt((s[, 1] + p$mu)^2 + s[, 2]^2 + s[, 3]^2)
    r2 = sqrt((s[, 1] - 1 + p$mu)^2 + s[, 2]^2 + s[, 3]^2)
    jacobi = s[, 1]^2 + s[, 2]^2 + 2 * ((1 - p$mu) / r1 + p$mu / r2) - rowSums(s[, 4:6]^2)
    diagnostics = data.frame(time = result$time, jacobi = jacobi,
                             jacobi_relative_drift = studio_relative_series(jacobi))
  } else {
    energy = result$raw$vz^2 / 2 - 2 * G * p$primary_mass /
      sqrt(p$primary_radius^2 + result$raw$z^2)
    diagnostics = data.frame(time = result$time, specific_energy = energy,
                             specific_energy_relative_drift = studio_relative_series(energy))
  }
  diagnostics
}

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
