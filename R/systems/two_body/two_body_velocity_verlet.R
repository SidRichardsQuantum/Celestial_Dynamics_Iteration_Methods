# Pair of massive bodies interacting in 2D
# Velocity Verlet method for Two-Body System
source("R/systems/two_body/two_body_helpers.R")

velocity_verlet_two_body = function(T, N, m_a, m_b, r_ax0, r_ay0, r_bx0, r_by0, v_ax0, v_ay0, v_bx0, v_by0) {
  two_body_validate_inputs(T, N, m_a, m_b,
                           r_ax0, r_ay0, r_bx0, r_by0,
                           v_ax0, v_ay0, v_bx0, v_by0)

  # Calculate time step
  dt = T / N

  # Initialize position vectors
  r_a = c(r_ax0, r_ay0)
  r_b = c(r_bx0, r_by0)

  # Initialize velocity vectors
  v_a = c(v_ax0, v_ay0)
  v_b = c(v_bx0, v_by0)

  # Initialize arrays for plotting and diagnostics
  x_a = c(r_ax0)
  y_a = c(r_ay0)
  x_b = c(r_bx0)
  y_b = c(r_by0)
  vx_a = c(v_ax0)
  vy_a = c(v_ay0)
  vx_b = c(v_bx0)
  vy_b = c(v_by0)

  initial_separation = sqrt(sum((r_a - r_b)^2))
  E_0 = two_body_total_energy(r_a, r_b, v_a, v_b, m_a, m_b)

  # Numerical integration using velocity Verlet.
  for (i in 1:N) {
    accelerations = two_body_accelerations(r_a, r_b, m_a, m_b)
    a_a = accelerations$a_a
    a_b = accelerations$a_b

    r_a_next = r_a + dt * v_a + 0.5 * dt^2 * a_a
    r_b_next = r_b + dt * v_b + 0.5 * dt^2 * a_b

    next_accelerations = two_body_accelerations(r_a_next, r_b_next, m_a, m_b)
    a_a_next = next_accelerations$a_a
    a_b_next = next_accelerations$a_b

    v_a = v_a + 0.5 * dt * (a_a + a_a_next)
    v_b = v_b + 0.5 * dt * (a_b + a_b_next)
    r_a = r_a_next
    r_b = r_b_next

    # Store positions and velocities
    x_a = c(x_a, r_a[1])
    y_a = c(y_a, r_a[2])
    x_b = c(x_b, r_b[1])
    y_b = c(y_b, r_b[2])
    vx_a = c(vx_a, v_a[1])
    vy_a = c(vy_a, v_a[2])
    vx_b = c(vx_b, v_b[1])
    vy_b = c(vy_b, v_b[2])
  }

  final_separation = sqrt(sum((r_a - r_b)^2))
  E_N = two_body_total_energy(r_a, r_b, v_a, v_b, m_a, m_b)
  energy_ratio = E_N / E_0

  print_two_body_summary("Velocity Verlet", T, N, dt, m_a, m_b,
                         initial_separation, final_separation,
                         energy_ratio)

  return(two_body_result(x_a, y_a, x_b, y_b, energy_ratio,
                         r_ax0, r_ay0, r_bx0, r_by0, m_a, m_b,
                         vx_a, vy_a, vx_b, vy_b))
}
