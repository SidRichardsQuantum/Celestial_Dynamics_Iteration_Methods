if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/systems/n_body/n_body_helpers.R")

velocity_verlet_n_body = function(T, N, masses, positions, velocities,
                                  body_names = NULL) {
  n_body_validate_inputs(T, N, masses, positions, velocities)

  dt = T / N
  trajectory = integrate_dynamics(
    dynamical_model("newtonian_gravity", list(masses = masses, G = G)),
    list(positions = positions, velocities = velocities), "Verlet", T, dt)
  position_history = trajectory$positions
  velocity_history = trajectory$velocities

  result = n_body_result(position_history, velocity_history, masses, dt,
                         "Velocity Verlet", body_names)
  print_n_body_summary("Velocity Verlet", T, N, dt, masses, result)
  result
}
