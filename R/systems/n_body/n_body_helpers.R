source("R/constants.R")

n_body_validate_inputs = function(T, N, masses, positions, velocities) {
  if (!is.finite(T) || T <= 0) {
    stop("T must be a positive finite value.")
  }
  if (!is.finite(N) || N <= 0 || N != as.integer(N)) {
    stop("N must be a positive integer.")
  }
  if (!is.numeric(masses) || length(masses) < 2 ||
      any(!is.finite(masses)) || any(masses <= 0)) {
    stop("masses must contain at least two positive finite values.")
  }
  if (!is.matrix(positions) || !is.matrix(velocities)) {
    stop("positions and velocities must be matrices.")
  }
  if (!identical(dim(positions), dim(velocities))) {
    stop("positions and velocities must have the same dimensions.")
  }
  if (nrow(positions) != length(masses)) {
    stop("positions and velocities must have one row per body.")
  }
  if (ncol(positions) != 2) {
    stop("Only two-dimensional n-body simulations are currently supported.")
  }
  if (any(!is.finite(positions)) || any(!is.finite(velocities))) {
    stop("Initial positions and velocities must be finite values.")
  }

  n_body_pairwise_distances(positions)
  invisible(TRUE)
}

n_body_pairwise_distances = function(positions) {
  body_count = nrow(positions)
  distances = matrix(0, nrow = body_count, ncol = body_count)

  for (i in 1:(body_count - 1)) {
    for (j in (i + 1):body_count) {
      distance = sqrt(sum((positions[i, ] - positions[j, ])^2))
      if (!is.finite(distance) || distance <= 0) {
        stop("Body collision or overlapping positions.")
      }
      distances[i, j] = distance
      distances[j, i] = distance
    }
  }

  distances
}

n_body_accelerations = function(positions, masses) {
  body_count = length(masses)
  accelerations = matrix(0, nrow = body_count, ncol = ncol(positions))

  for (i in 1:(body_count - 1)) {
    for (j in (i + 1):body_count) {
      displacement = positions[j, ] - positions[i, ]
      distance = sqrt(sum(displacement^2))
      if (!is.finite(distance) || distance <= 0) {
        stop("Body collision or overlapping positions.")
      }

      factor = G * displacement / distance^3
      accelerations[i, ] = accelerations[i, ] + masses[j] * factor
      accelerations[j, ] = accelerations[j, ] - masses[i] * factor
    }
  }

  accelerations
}

n_body_total_energy = function(positions, velocities, masses) {
  body_count = length(masses)
  kinetic = 0.5 * sum(masses * rowSums(velocities^2))
  potential = 0

  for (i in 1:(body_count - 1)) {
    for (j in (i + 1):body_count) {
      distance = sqrt(sum((positions[i, ] - positions[j, ])^2))
      if (!is.finite(distance) || distance <= 0) {
        stop("Body collision or overlapping positions.")
      }
      potential = potential - G * masses[i] * masses[j] / distance
    }
  }

  kinetic + potential
}

n_body_angular_momentum = function(positions, velocities, masses) {
  sum(masses * (positions[, 1] * velocities[, 2] -
                  positions[, 2] * velocities[, 1]))
}

n_body_energy_series = function(result) {
  step_count = dim(result$positions)[1]
  energy = numeric(step_count)

  for (step in 1:step_count) {
    energy[step] = n_body_total_energy(result$positions[step, , ],
                                       result$velocities[step, , ],
                                       result$masses)
  }

  energy
}

n_body_angular_momentum_series = function(result) {
  step_count = dim(result$positions)[1]
  angular_momentum = numeric(step_count)

  for (step in 1:step_count) {
    angular_momentum[step] = n_body_angular_momentum(result$positions[step, , ],
                                                     result$velocities[step, , ],
                                                     result$masses)
  }

  angular_momentum
}

n_body_result = function(positions, velocities, masses, dt, method,
                         body_names = NULL) {
  if (is.null(body_names)) {
    body_names = paste0("body_", seq_along(masses))
  }

  list(
    positions = positions,
    velocities = velocities,
    masses = masses,
    dt = dt,
    method = method,
    body_names = body_names,
    energy_ratio = n_body_total_energy(positions[dim(positions)[1], , ],
                                       velocities[dim(velocities)[1], , ],
                                       masses) /
      n_body_total_energy(positions[1, , ], velocities[1, , ], masses)
  )
}

print_n_body_summary = function(method_name, T, N, dt, masses, result) {
  energy = n_body_energy_series(result)
  angular_momentum = n_body_angular_momentum_series(result)

  cat(sprintf("N-Body System Simulation %s Method Results:\n", method_name))
  cat(sprintf("Bodies: %d\n", length(masses)))
  cat(sprintf("Total simulation time: %.2f years\n", T / YEAR))
  cat(sprintf("Time steps: %d\n", N))
  cat(sprintf("Time step size: %.2f days\n", dt / DAY))
  cat(sprintf("Energy conservation ratio: %.6f\n", tail(energy, 1) / energy[1]))
  cat(sprintf("Angular momentum relative drift: %.6e\n",
              relative_drift(angular_momentum)))
  cat("\n")
}

if (!exists("relative_drift")) {
  relative_drift = function(values) {
    reference = values[1]
    scale = max(abs(reference), .Machine$double.eps)
    max(abs(values - reference)) / scale
  }
}
