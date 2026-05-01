# Pair of massive bodies interacting in 2D
# Runge-Kutta Method for Two-Body System
source("R/systems/two_body/two_body_helpers.R")

runge_kutta_two_body = function(T, N, m_a, m_b, r_ax0, r_ay0, r_bx0, r_by0, v_ax0, v_ay0, v_bx0, v_by0) {
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
  
  # Initialize position arrays for plotting
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

  # Numerical integration using the Runge-Kutta (RK4) method
  for(i in 1:N) {
    # k1: Current accelerations and velocities
    accelerations_k1 = two_body_accelerations(r_a, r_b, m_a, m_b)
    a_a_k1 = accelerations_k1$a_a
    a_b_k1 = accelerations_k1$a_b
    v_a_k1 = v_a
    v_b_k1 = v_b
  
    # k2: Midpoint using k1
    r_a_k2 = r_a + 0.5 * dt * v_a_k1
    r_b_k2 = r_b + 0.5 * dt * v_b_k1
    v_a_k2 = v_a + 0.5 * dt * a_a_k1
    v_b_k2 = v_b + 0.5 * dt * a_b_k1
    accelerations_k2 = two_body_accelerations(r_a_k2, r_b_k2, m_a, m_b)
    a_a_k2 = accelerations_k2$a_a
    a_b_k2 = accelerations_k2$a_b
  
    # k3: Midpoint using k2
    r_a_k3 = r_a + 0.5 * dt * v_a_k2
    r_b_k3 = r_b + 0.5 * dt * v_b_k2
    v_a_k3 = v_a + 0.5 * dt * a_a_k2
    v_b_k3 = v_b + 0.5 * dt * a_b_k2
    accelerations_k3 = two_body_accelerations(r_a_k3, r_b_k3, m_a, m_b)
    a_a_k3 = accelerations_k3$a_a
    a_b_k3 = accelerations_k3$a_b
  
    # k4: Endpoint using k3
    r_a_k4 = r_a + dt * v_a_k3
    r_b_k4 = r_b + dt * v_b_k3
    v_a_k4 = v_a + dt * a_a_k3
    v_b_k4 = v_b + dt * a_b_k3
    accelerations_k4 = two_body_accelerations(r_a_k4, r_b_k4, m_a, m_b)
    a_a_k4 = accelerations_k4$a_a
    a_b_k4 = accelerations_k4$a_b
  
    # Final update using RK4 weighted average
    r_a = r_a + (dt/6) * (v_a_k1 + 2*v_a_k2 + 2*v_a_k3 + v_a_k4)
    r_b = r_b + (dt/6) * (v_b_k1 + 2*v_b_k2 + 2*v_b_k3 + v_b_k4)
    v_a = v_a + (dt/6) * (a_a_k1 + 2*a_a_k2 + 2*a_a_k3 + a_a_k4)
    v_b = v_b + (dt/6) * (a_b_k1 + 2*a_b_k2 + 2*a_b_k3 + a_b_k4)
  
    # Store positions for plotting
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
  
  print_two_body_summary("Runge-Kutta", T, N, dt, m_a, m_b,
                         initial_separation, final_separation,
                         energy_ratio)
  
  return(two_body_result(x_a, y_a, x_b, y_b, energy_ratio,
                         r_ax0, r_ay0, r_bx0, r_by0, m_a, m_b,
                         vx_a, vy_a, vx_b, vy_b))
}
