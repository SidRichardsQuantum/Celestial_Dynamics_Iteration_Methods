if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")

# Pure nondimensional rotating-frame physics, independent of Studio/plotting.
cr3bp_validate_mu = function(mu) {
  if (!is.numeric(mu) || is.complex(mu) || length(mu) != 1L ||
      !is.null(dim(mu)) || !is.finite(mu) || mu <= 0 || mu > 0.5)
    stop("mu must be a finite scalar in (0, 0.5].")
  invisible(mu)
}

cr3bp_mass_parameters = function() {
  c(earth_moon = M_MOON / (M_EARTH + M_MOON),
    sun_earth = M_EARTH / (M_SUN + M_EARTH))
}

cd_cr3bp_rows = function(values, columns) {
  if (!is.numeric(values) || is.complex(values) || any(!is.finite(values)))
    stop("CR3BP coordinates must be finite real numbers.")
  if (is.null(dim(values))) values = matrix(values, nrow = 1)
  if (!is.matrix(values) || ncol(values) != columns || nrow(values) < 1L)
    stop("Expected a coordinate vector or matrix with ", columns, " columns.")
  values
}

# Singular samples return NA internally so diagnostic validity reports survive.
# Subtract the stored secondary coordinate (1-mu) as a unit: x-1+mu can
# leave a roundoff residue even when x is exactly the primary's coordinate.
cd_cr3bp_potential = function(positions, mu) {
  r1 = sqrt((positions[, 1] + mu)^2 + positions[, 2]^2 + positions[, 3]^2)
  r2 = sqrt((positions[, 1] - (1 - mu))^2 + positions[, 2]^2 + positions[, 3]^2)
  r1[r1 == 0] = r2[r2 == 0] = NA_real_
  (positions[, 1]^2 + positions[, 2]^2) / 2 + (1 - mu) / r1 + mu / r2
}

cr3bp_potential = function(position, mu) {
  cr3bp_validate_mu(mu)
  value = cd_cr3bp_potential(cd_cr3bp_rows(position, 3L), mu)
  if (any(!is.finite(value))) stop("Singular or nonfinite CR3BP potential; check primary overlap.")
  value
}

cr3bp_jacobi = function(state, mu) {
  cr3bp_validate_mu(mu)
  states = cd_cr3bp_rows(state, 6L)
  value = 2 * cr3bp_potential(states[, 1:3, drop = FALSE], mu) - rowSums(states[, 4:6, drop = FALSE]^2)
  if (any(!is.finite(value))) stop("Nonfinite Jacobi constant; state magnitude exceeds numerical range.")
  value
}

cd_cr3bp_acceleration = function(time, positions, velocities, parameters) {
  mu = parameters$mu
  x = positions[1, 1]; y = positions[1, 2]; z = positions[1, 3]
  vx = velocities[1, 1]; vy = velocities[1, 2]
  r1 = sqrt((x + mu)^2 + y^2 + z^2)
  r2 = sqrt((x - (1 - mu))^2 + y^2 + z^2)
  if (r1 <= 0 || r2 <= 0) stop("Test particle overlaps a primary.")
  matrix(c(2 * vy + x - (1 - mu) * (x + mu) / r1^3 - mu * (x - (1 - mu)) / r2^3,
    -2 * vx + y - (1 - mu) * y / r1^3 - mu * y / r2^3,
    -(1 - mu) * z / r1^3 - mu * z / r2^3), 1, 3)
}

cr3bp_potential_gradient = function(position, mu) {
  cr3bp_validate_mu(mu)
  positions = cd_cr3bp_rows(position, 3L)
  cr3bp_potential(positions, mu) # Reject singular/nonfinite inputs explicitly.
  gradient = matrix(0, nrow(positions), 3)
  for (i in seq_len(nrow(positions))) gradient[i, ] = cd_cr3bp_acceleration(
    0, positions[i, , drop = FALSE], matrix(0, 1, 3), list(mu = mu))
  if (any(!is.finite(gradient))) stop("Nonfinite potential gradient.")
  if (is.null(dim(position))) as.numeric(gradient) else gradient
}

cr3bp_lagrange_points = function(mu) {
  cr3bp_validate_mu(mu)
  equation = function(x) {
    d1 = x + mu; d2 = x - (1 - mu)
    x - (1 - mu) * d1 / abs(d1)^3 - mu * d2 / abs(d2)^3
  }
  # Bracket each continuous interval separately, away from its singular ends.
  # The gap scales with the small-primary Hill distance rather than a fixed .01.
  gap = min(1e-6, mu^(1 / 3) / 100)
  left = -mu; right = 1 - mu
  if (right + gap == right || right - gap == right)
    stop("mu is too small to resolve collinear equilibria in double precision.")
  root = function(bounds) stats::uniroot(equation, bounds,
    tol = 4 * .Machine$double.eps, maxiter = 1000L, check.conv = TRUE)$root
  list(L1 = c(root(c(left + gap, right - gap)), 0),
    L2 = c(root(c(right + gap, 2)), 0),
    L3 = c(root(c(-2, left - gap)), 0),
    L4 = c(0.5 - mu, sqrt(3) / 2), L5 = c(0.5 - mu, -sqrt(3) / 2))
}

cr3bp_initial_state = function(mu, point = "L4", position_offset = c(0.001, 0, 0),
    velocity = c(0, 0, 0)) {
  if (!is.character(point) || length(point) != 1L || is.na(point) ||
      !point %in% paste0("L", 1:5)) stop("Choose a point L1 through L5.")
  offset = cd_cr3bp_rows(position_offset, 3L)
  speed = cd_cr3bp_rows(velocity, 3L)
  if (nrow(offset) != 1L || nrow(speed) != 1L) stop("Supply one offset and one velocity.")
  position = c(cr3bp_lagrange_points(mu)[[point]], 0) + as.numeric(offset)
  cr3bp_potential(position, mu)
  c(as.numeric(position), as.numeric(speed))
}
