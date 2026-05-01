source("R/constants.R")

lagrange_initial_conditions = function(side_length_real = AU, body_mass = M_EARTH) {
  if (!is.finite(side_length_real) || side_length_real <= 0) {
    stop("side_length_real must be a positive finite value.")
  }
  if (!is.finite(body_mass) || body_mass <= 0) {
    stop("body_mass must be a positive finite value.")
  }

  radius = side_length_real / sqrt(3)
  total_mass = 3 * body_mass
  angular_velocity = sqrt(G * total_mass / side_length_real^3)

  angles = c(pi / 2, pi / 2 + 2 * pi / 3, pi / 2 + 4 * pi / 3)
  positions = lapply(angles, function(theta) {
    c(radius * cos(theta), radius * sin(theta))
  })
  velocities = lapply(positions, function(position) {
    c(-angular_velocity * position[2], angular_velocity * position[1])
  })

  return(list(
    period = 2 * pi / angular_velocity,
    positions = positions,
    velocities = velocities,
    side_length = side_length_real,
    angular_velocity = angular_velocity
  ))
}
