source("constants.R")

euler_collinear_initial_conditions = function(outer_separation_real = AU,
                                             body_mass = M_EARTH) {
  if (!is.finite(outer_separation_real) || outer_separation_real <= 0) {
    stop("outer_separation_real must be a positive finite value.")
  }
  if (!is.finite(body_mass) || body_mass <= 0) {
    stop("body_mass must be a positive finite value.")
  }

  radius = outer_separation_real / 2
  angular_velocity = sqrt(5 * G * body_mass / (4 * radius^3))

  positions = list(
    c(-radius, 0),
    c(0, 0),
    c(radius, 0)
  )
  velocities = lapply(positions, function(position) {
    c(-angular_velocity * position[2], angular_velocity * position[1])
  })

  return(list(
    period = 2 * pi / angular_velocity,
    positions = positions,
    velocities = velocities,
    outer_separation = outer_separation_real,
    angular_velocity = angular_velocity
  ))
}
