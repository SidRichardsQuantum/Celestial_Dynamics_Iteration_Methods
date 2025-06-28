# Pair of massive bodies interacting in 2D
# Euler Method for Two-Body System
source("constants.R")

euler_2d = function(T, N, m_a, m_b, r_ax0, r_ay0, r_bx0, r_by0, v_ax0, v_ay0, v_bx0, v_by0) {
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
  
  # Numerical integration using Euler method
  for(i in 1:N) {
    # Calculate current separation vector and distance
    r_ab = r_a - r_b  # Vector from b to a
    mag_r_ab = sqrt(sum(r_ab^2))
    
    # Calculate accelerations
    a_a = G * m_b * r_ab / mag_r_ab^3
    a_b = -G * m_a * r_ab / mag_r_ab^3
    
    # Update positions using current velocities
    r_a = r_a + dt * v_a
    r_b = r_b + dt * v_b
    
    # Update velocities using current accelerations
    v_a = v_a + dt * a_a
    v_b = v_b + dt * a_b
    
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
  
  # Create images directory if it doesn't exist
  if (!dir.exists("images")) {
    dir.create("images")
  }
  
  # Create filename and save plot
  filename = "two_body_euler.png"
  filepath = file.path("images", filename)
  
  # Open PNG device
  png(filepath, width = 800, height = 600, res = 100)
  
  # Convert to AU for plotting
  x_a_au = x_a / AU
  y_a_au = y_a / AU
  x_b_au = x_b / AU
  y_b_au = y_b / AU
  
  # Create single 2D plot showing both orbits
  plot(x_b_au, y_b_au, type="l", col="blue", lwd=2,
       xlab="x (AU)", ylab="y (AU)", 
       main="Two-Body Gravitational System (Euler Method)")
  lines(x_a_au, y_a_au, col="red", lwd=2)
  
  # Add starting positions
  points(r_ax0 / AU, r_ay0 / AU, pch=19, col="red", cex=1.5)
  points(r_bx0 / AU, r_by0 / AU, pch=19, col="blue", cex=1.5)
  
  # Add legend
  legend("topright", legend=c("Body a", "Body b"), 
         lty=c("solid", "solid"), col=c("red", "blue"), lwd=c(2, 2))
  
  # Add grid for better readability
  grid(col = "gray", lty = "dotted")
  
  # Close the PNG device
  dev.off()
  
  cat(sprintf("Plot saved to: %s\n", filepath))
  
  # Print simulation results
  cat("Two-Body System Simulation Results:\n")
  cat(sprintf("Body a mass: %.2e kg\n", m_a))
  cat(sprintf("Body b mass: %.2e kg\n", m_b))
  cat(sprintf("Total simulation time: %.2f years\n", T / (365.25 * 24 * 3600)))
  cat(sprintf("Time steps: %d\n", N))
  cat(sprintf("Time step size: %.2f days\n", dt / (24 * 3600)))
  cat(sprintf("Initial separation: %.3f AU\n", sqrt(sum((c(r_ax0, r_ay0) - c(r_bx0, r_by0))^2)) / AU))
  cat(sprintf("Final separation: %.3f AU\n", r_abN / AU))
  cat(sprintf("Energy conservation ratio: %.6f\n", E_N / E_0))
  cat("\n")
  
  return(E_N / E_0)
}
