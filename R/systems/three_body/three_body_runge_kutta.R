# Three massive bodies interacting in 2D
# This is the file "two_body_runge_kutta.R" adapted to include a third celestial
source("R/systems/three_body/three_body_helpers.R")

runge_kutta_three_body = function(T, N, 
                                  m_a, m_b, m_c,
                                  r_ax0, r_ay0, r_bx0, r_by0, r_cx0, r_cy0,
                                  v_ax0, v_ay0, v_bx0, v_by0, v_cx0, v_cy0) {

  three_body_validate_inputs(T, N, m_a, m_b, m_c,
                             r_ax0, r_ay0, r_bx0, r_by0, r_cx0, r_cy0,
                             v_ax0, v_ay0, v_bx0, v_by0, v_cx0, v_cy0)

  # Calculate time step
  dt = T / N
  
  # Initialize position vectors
  r_a = c(r_ax0, r_ay0)
  r_b = c(r_bx0, r_by0)
  r_c = c(r_cx0, r_cy0)
  
  # Initialize velocity vectors
  v_a = c(v_ax0, v_ay0)
  v_b = c(v_bx0, v_by0)
  v_c = c(v_cx0, v_cy0)
  
  # Initialize position arrays for plotting
  x_a = numeric(N + 1)
  y_a = numeric(N + 1)
  x_b = numeric(N + 1)
  y_b = numeric(N + 1)
  x_c = numeric(N + 1)
  y_c = numeric(N + 1)
  vx_a = numeric(N + 1)
  vy_a = numeric(N + 1)
  vx_b = numeric(N + 1)
  vy_b = numeric(N + 1)
  vx_c = numeric(N + 1)
  vy_c = numeric(N + 1)
  x_a[1] = r_ax0
  y_a[1] = r_ay0
  x_b[1] = r_bx0
  y_b[1] = r_by0
  x_c[1] = r_cx0
  y_c[1] = r_cy0
  vx_a[1] = v_ax0
  vy_a[1] = v_ay0
  vx_b[1] = v_bx0
  vy_b[1] = v_by0
  vx_c[1] = v_cx0
  vy_c[1] = v_cy0
  
  initial_separations = three_body_separations(r_a, r_b, r_c)
  E_0 = three_body_total_energy(r_a, r_b, r_c, v_a, v_b, v_c,
                                m_a, m_b, m_c)
  
  # Numerical integration using the Runge-Kutta (RK4) method
  for(i in 1:N) {
    
    # k1: Current accelerations and velocities
    accelerations_k1 = tryCatch(
      three_body_accelerations(r_a, r_b, r_c, m_a, m_b, m_c),
      error = function(e) stop(sprintf("%s at step %d.", e$message, i))
    )
    a_a_k1 = accelerations_k1$a_a
    a_b_k1 = accelerations_k1$a_b
    a_c_k1 = accelerations_k1$a_c
    
    v_a_k1 = v_a
    v_b_k1 = v_b
    v_c_k1 = v_c
    
    # k2: Midpoint using k1
    r_a_k2 = r_a + 0.5 * dt * v_a_k1
    r_b_k2 = r_b + 0.5 * dt * v_b_k1
    r_c_k2 = r_c + 0.5 * dt * v_c_k1
    v_a_k2 = v_a + 0.5 * dt * a_a_k1
    v_b_k2 = v_b + 0.5 * dt * a_b_k1
    v_c_k2 = v_c + 0.5 * dt * a_c_k1
    
    accelerations_k2 = tryCatch(
      three_body_accelerations(r_a_k2, r_b_k2, r_c_k2, m_a, m_b, m_c),
      error = function(e) stop(sprintf("%s at step %d.", e$message, i))
    )
    a_a_k2 = accelerations_k2$a_a
    a_b_k2 = accelerations_k2$a_b
    a_c_k2 = accelerations_k2$a_c
    
    # k3: Midpoint using k2
    r_a_k3 = r_a + 0.5 * dt * v_a_k2
    r_b_k3 = r_b + 0.5 * dt * v_b_k2
    r_c_k3 = r_c + 0.5 * dt * v_c_k2
    v_a_k3 = v_a + 0.5 * dt * a_a_k2
    v_b_k3 = v_b + 0.5 * dt * a_b_k2
    v_c_k3 = v_c + 0.5 * dt * a_c_k2
    
    accelerations_k3 = tryCatch(
      three_body_accelerations(r_a_k3, r_b_k3, r_c_k3, m_a, m_b, m_c),
      error = function(e) stop(sprintf("%s at step %d.", e$message, i))
    )
    a_a_k3 = accelerations_k3$a_a
    a_b_k3 = accelerations_k3$a_b
    a_c_k3 = accelerations_k3$a_c
    
    # k4: Endpoint using k3
    r_a_k4 = r_a + dt * v_a_k3
    r_b_k4 = r_b + dt * v_b_k3
    r_c_k4 = r_c + dt * v_c_k3
    v_a_k4 = v_a + dt * a_a_k3
    v_b_k4 = v_b + dt * a_b_k3
    v_c_k4 = v_c + dt * a_c_k3
    
    accelerations_k4 = tryCatch(
      three_body_accelerations(r_a_k4, r_b_k4, r_c_k4, m_a, m_b, m_c),
      error = function(e) stop(sprintf("%s at step %d.", e$message, i))
    )
    a_a_k4 = accelerations_k4$a_a
    a_b_k4 = accelerations_k4$a_b
    a_c_k4 = accelerations_k4$a_c
    
    # Final update using RK4 weighted average
    r_a = r_a + (dt/6) * (v_a_k1 + 2*v_a_k2 + 2*v_a_k3 + v_a_k4)
    r_b = r_b + (dt/6) * (v_b_k1 + 2*v_b_k2 + 2*v_b_k3 + v_b_k4)
    r_c = r_c + (dt/6) * (v_c_k1 + 2*v_c_k2 + 2*v_c_k3 + v_c_k4)
    v_a = v_a + (dt/6) * (a_a_k1 + 2*a_a_k2 + 2*a_a_k3 + a_a_k4)
    v_b = v_b + (dt/6) * (a_b_k1 + 2*a_b_k2 + 2*a_b_k3 + a_b_k4)
    v_c = v_c + (dt/6) * (a_c_k1 + 2*a_c_k2 + 2*a_c_k3 + a_c_k4)
    
    # Store positions for plotting
    x_a[i + 1] = r_a[1]
    y_a[i + 1] = r_a[2]
    x_b[i + 1] = r_b[1]
    y_b[i + 1] = r_b[2]
    x_c[i + 1] = r_c[1]
    y_c[i + 1] = r_c[2]
    vx_a[i + 1] = v_a[1]
    vy_a[i + 1] = v_a[2]
    vx_b[i + 1] = v_b[1]
    vy_b[i + 1] = v_b[2]
    vx_c[i + 1] = v_c[1]
    vy_c[i + 1] = v_c[2]
  }
  
  final_separations = three_body_separations(r_a, r_b, r_c)
  E_N = three_body_total_energy(r_a, r_b, r_c, v_a, v_b, v_c,
                                m_a, m_b, m_c)
  energy_ratio = E_N / E_0

  print_three_body_summary(T, N, dt, m_a, m_b, m_c,
                           initial_separations, final_separations,
                           energy_ratio)
  
  return(three_body_result(
    x_a, y_a, x_b, y_b, x_c, y_c, energy_ratio,
    r_ax0, r_ay0, r_bx0, r_by0, r_cx0, r_cy0,
    m_a, m_b, m_c,
    vx_a, vy_a, vx_b, vy_b, vx_c, vy_c
  ))
}
