source("constants.R")

figure_8_initial_conditions = function(distance_real = AU, body_mass = M_EARTH) {
  if (!is.finite(distance_real) || distance_real <= 0) {
    stop("distance_real must be a positive finite value.")
  }
  if (!is.finite(body_mass) || body_mass <= 0) {
    stop("body_mass must be a positive finite value.")
  }

  # Standard dimensionless equal-mass figure-8 solution, with G = 1 and m = 1.
  a = 0.97000436
  b = 0.24308753
  dimensionless_period = 6.32591398

  position_scale = distance_real / (2 * sqrt(a^2 + b^2))
  time_scale = sqrt(position_scale^3 / (G * body_mass))
  velocity_scale = position_scale / time_scale

  return(list(
    period = dimensionless_period * time_scale,
    positions = list(
      c(-a, b) * position_scale,
      c(a, -b) * position_scale,
      c(0, 0) * position_scale
    ),
    velocities = list(
      c(0.466203685, 0.43236573) * velocity_scale,
      c(0.466203685, 0.43236573) * velocity_scale,
      c(-0.93240737, -0.86473146) * velocity_scale
    ),
    position_scale = position_scale,
    velocity_scale = velocity_scale,
    time_scale = time_scale
  ))
}
