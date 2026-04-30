source("constants.R")

rotating_square_four_body_initial_conditions = function(half_side_real = 0.25 * AU,
                                                        body_mass = M_EARTH) {
  positions = rbind(
    c(half_side_real, half_side_real),
    c(-half_side_real, half_side_real),
    c(-half_side_real, -half_side_real),
    c(half_side_real, -half_side_real)
  )

  omega = sqrt(
    G * body_mass / half_side_real^3 *
      (1 / 4 + 1 / (8 * sqrt(2)))
  )

  velocities = cbind(-omega * positions[, 2],
                     omega * positions[, 1])

  list(
    masses = rep(body_mass, 4),
    positions = positions,
    velocities = velocities,
    period = 2 * pi / omega,
    body_names = c("Body A", "Body B", "Body C", "Body D"),
    description = "Equal-mass rotating square central configuration"
  )
}

triangular_central_four_body_initial_conditions = function(radius_real = 0.5 * AU,
                                                           outer_mass = M_EARTH,
                                                           central_mass = M_EARTH) {
  angles = c(0, 2 * pi / 3, 4 * pi / 3)
  outer_positions = cbind(radius_real * cos(angles),
                          radius_real * sin(angles))
  positions = rbind(c(0, 0), outer_positions)

  omega = sqrt(G * (central_mass + outer_mass / sqrt(3)) / radius_real^3)
  velocities = rbind(
    c(0, 0),
    cbind(-omega * outer_positions[, 2],
          omega * outer_positions[, 1])
  )

  list(
    masses = c(central_mass, rep(outer_mass, 3)),
    positions = positions,
    velocities = velocities,
    period = 2 * pi / omega,
    body_names = c("Center", "Outer A", "Outer B", "Outer C"),
    description = "Three equal outer bodies rotating around a central mass"
  )
}
