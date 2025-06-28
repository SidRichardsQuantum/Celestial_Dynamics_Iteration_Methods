# Pair of massive bodies interacting in 2D
# Runge-Kutta Method for Two-Body System
source("constants.R")

runge_kutta_2d = function(T, N, m_a, m_b, r_ax0, r_ay0, r_bx0, r_by0, v_ax0, v_ay0, v_bx0, v_by0) {
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
  
  # Calculate initial total energy for conservation check
  # Kinetic energy
  KE_0 = 0.5 * m_a * sum(v_a^2) + 0.5 * m_b * sum(v_b^2)
  # Potential energy (note: G is negative in constants.R)
  r_ab0 = sqrt(sum((r_a - r_b)^2))
  U_0 = G * m_a * m_b / r_ab0
  E_0 = KE_0 + U_0

  # Numerical integration using the Runge-Kutta (RK4) method
  for(i in 1:N) {
    # Calculate current separation vector and distance
    r_ab = r_a - r_b # Vector from b to a
    mag_r_ab = sqrt(sum(r_ab^2))
  
    # k1: Current accelerations and velocities
    a_a_k1 = G * m_b * r_ab / mag_r_ab^3
    a_b_k1 = -G * m_a * r_ab / mag_r_ab^3
    v_a_k1 = v_a
    v_b_k1 = v_b
  
    # k2: Midpoint using k1
    r_a_k2 = r_a + 0.5 * dt * v_a_k1
    r_b_k2 = r_b + 0.5 * dt * v_b_k1
    v_a_k2 = v_a + 0.5 * dt * a_a_k1
    v_b_k2 = v_b + 0.5 * dt * a_b_k1
    r_ab_k2 = r_a_k2 - r_b_k2
    mag_r_ab_k2 = sqrt(sum(r_ab_k2^2))
    a_a_k2 = G * m_b * r_ab_k2 / mag_r_ab_k2^3
    a_b_k2 = -G * m_a * r_ab_k2 / mag_r_ab_k2^3
  
    # k3: Midpoint using k2
    r_a_k3 = r_a + 0.5 * dt * v_a_k2
    r_b_k3 = r_b + 0.5 * dt * v_b_k2
    v_a_k3 = v_a + 0.5 * dt * a_a_k2
    v_b_k3 = v_b + 0.5 * dt * a_b_k2
    r_ab_k3 = r_a_k3 - r_b_k3
    mag_r_ab_k3 = sqrt(sum(r_ab_k3^2))
    a_a_k3 = G * m_b * r_ab_k3 / mag_r_ab_k3^3
    a_b_k3 = -G * m_a * r_ab_k3 / mag_r_ab_k3^3
  
    # k4: Endpoint using k3
    r_a_k4 = r_a + dt * v_a_k3
    r_b_k4 = r_b + dt * v_b_k3
    v_a_k4 = v_a + dt * a_a_k3
    v_b_k4 = v_b + dt * a_b_k3
    r_ab_k4 = r_a_k4 - r_b_k4
    mag_r_ab_k4 = sqrt(sum(r_ab_k4^2))
    a_a_k4 = G * m_b * r_ab_k4 / mag_r_ab_k4^3
    a_b_k4 = -G * m_a * r_ab_k4 / mag_r_ab_k4^3
  
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
  }

  # Calculate final energy for conservation check
  KE_N = 0.5 * m_a * sum(v_a^2) + 0.5 * m_b * sum(v_b^2)
  r_abN = sqrt(sum((r_a - r_b)^2))
  U_N = G * m_a * m_b / r_abN
  E_N = KE_N + U_N
  
  # Print simulation results
  cat("Two-Body System Simulation Runge-Kutta Method Results:\n")
  cat(sprintf("Body a mass: %.2e kg\n", m_a))
  cat(sprintf("Body b mass: %.2e kg\n", m_b))
  cat(sprintf("Total simulation time: %.2f years\n", T / (365.25 * 24 * 3600)))
  cat(sprintf("Time steps: %d\n", N))
  cat(sprintf("Time step size: %.2f days\n", dt / (24 * 3600)))
  cat(sprintf("Initial separation: %.3f AU\n", sqrt(sum((c(r_ax0, r_ay0) - c(r_bx0, r_by0))^2)) / AU))
  cat(sprintf("Final separation: %.3f AU\n", r_abN / AU))
  cat(sprintf("Energy conservation ratio: %.6f\n", E_N / E_0))
  cat("\n")
  
  # Return results as a list
  return(list(
    x_a = x_a,
    y_a = y_a,
    x_b = x_b,
    y_b = y_b,
    energy_ratio = E_N / E_0,
    initial_conditions = list(
      r_ax0 = r_ax0, r_ay0 = r_ay0,
      r_bx0 = r_bx0, r_by0 = r_by0,
      m_a = m_a, m_b = m_b
    )
  ))
}
