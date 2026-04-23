source("constants.R")

choreography_initial_conditions = function(name = "butterfly_i",
                                           outer_separation_real = AU,
                                           body_mass = M_EARTH) {
  if (!is.finite(outer_separation_real) || outer_separation_real <= 0) {
    stop("outer_separation_real must be a positive finite value.")
  }
  if (!is.finite(body_mass) || body_mass <= 0) {
    stop("body_mass must be a positive finite value.")
  }

  catalog = list(
    butterfly_i = list(
      label = "Butterfly I",
      p1 = 0.306893,
      p2 = 0.125507,
      period = 6.234671
    )
  )

  if (!name %in% names(catalog)) {
    stop(sprintf("Unknown choreography '%s'.", name))
  }

  orbit = catalog[[name]]
  position_scale = outer_separation_real / 2
  time_scale = sqrt(position_scale^3 / (G * body_mass))
  velocity_scale = position_scale / time_scale

  return(list(
    label = orbit$label,
    period = orbit$period * time_scale,
    positions = list(
      c(-1, 0) * position_scale,
      c(0, 0) * position_scale,
      c(1, 0) * position_scale
    ),
    velocities = list(
      c(orbit$p1, orbit$p2) * velocity_scale,
      c(-2 * orbit$p1, -2 * orbit$p2) * velocity_scale,
      c(orbit$p1, orbit$p2) * velocity_scale
    ),
    position_scale = position_scale,
    velocity_scale = velocity_scale,
    time_scale = time_scale,
    source = "Hudomal periodic three-body initial-condition catalog"
  ))
}
