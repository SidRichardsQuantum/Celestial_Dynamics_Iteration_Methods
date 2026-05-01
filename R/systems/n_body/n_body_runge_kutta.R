source("R/systems/n_body/n_body_helpers.R")

runge_kutta_n_body = function(T, N, masses, positions, velocities,
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
    k1_r = current_velocities
    k1_v = n_body_accelerations(current_positions, masses)

    k2_r = current_velocities + 0.5 * dt * k1_v
    k2_v = n_body_accelerations(current_positions + 0.5 * dt * k1_r, masses)

    k3_r = current_velocities + 0.5 * dt * k2_v
    k3_v = n_body_accelerations(current_positions + 0.5 * dt * k2_r, masses)

    k4_r = current_velocities + dt * k3_v
    k4_v = n_body_accelerations(current_positions + dt * k3_r, masses)

    current_positions = current_positions +
      (dt / 6) * (k1_r + 2 * k2_r + 2 * k3_r + k4_r)
    current_velocities = current_velocities +
      (dt / 6) * (k1_v + 2 * k2_v + 2 * k3_v + k4_v)

    position_history[step + 1, , ] = current_positions
    velocity_history[step + 1, , ] = current_velocities
  }

  result = n_body_result(position_history, velocity_history, masses, dt,
                         "Runge-Kutta", body_names)
  print_n_body_summary("Runge-Kutta", T, N, dt, masses, result)
  result
}
