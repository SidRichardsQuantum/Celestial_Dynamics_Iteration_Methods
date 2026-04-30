source("celestial_systems/n_body/n_body_helpers.R")

velocity_verlet_n_body = function(T, N, masses, positions, velocities,
                                  body_names = NULL) {
  n_body_validate_inputs(T, N, masses, positions, velocities)

  dt = T / N
  body_count = length(masses)
  dimensions = ncol(positions)
  position_history = array(0, dim = c(N + 1, body_count, dimensions))
  velocity_history = array(0, dim = c(N + 1, body_count, dimensions))
  position_history[1, , ] = positions
  velocity_history[1, , ] = velocities

  current_positions = positions
  current_velocities = velocities

  for (step in 1:N) {
    accelerations = n_body_accelerations(current_positions, masses)
    next_positions = current_positions +
      dt * current_velocities + 0.5 * dt^2 * accelerations
    next_accelerations = n_body_accelerations(next_positions, masses)
    current_velocities = current_velocities +
      0.5 * dt * (accelerations + next_accelerations)
    current_positions = next_positions

    position_history[step + 1, , ] = current_positions
    velocity_history[step + 1, , ] = current_velocities
  }

  result = n_body_result(position_history, velocity_history, masses, dt,
                         "Velocity Verlet", body_names)
  print_n_body_summary("Velocity Verlet", T, N, dt, masses, result)
  result
}
