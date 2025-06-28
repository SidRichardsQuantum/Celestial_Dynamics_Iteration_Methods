# Load physical constants
source("constants.R")

# Euler method
Euler = function(T, y_0, v_0, theta, N) {
  # Particle trajectory in a constant gravitational field
  # Args:
  # T: total time of simulation
  # y_0: initial y coordinate
  # v_0: initial speed
  # theta: angle of initial trajectory (between the horizontal and initial velocity direction)
  # N: number of steps over time T
  
  r = R_EARTH + y_0       # Initial height above Earth's center
  g_x = 0                 # No acceleration in the x-direction
  g_y = G * M_EARTH / r^2 # Initial gravitational acceleration
  
  # Calculate incremental time step
  dt = T / N

  # Initialize arrays
  x = numeric(N + 1)
  y = numeric(N + 1)
  v_x = numeric(N + 1)
  v_y = numeric(N + 1)
  
  # Initial parameters
  # Initial x-coordinate is 0
  x[1] = 0
  y[1] = y_0
  v_x[1] = v_0 * cos(theta)
  v_y[1] = v_0 * sin(theta)
  
  # Log the approximated coordinates for plotting
  s = c(x[1]) # x-values
  l = c(y[1]) # y-values
  
  # Energy conservation test: energy is conserved if the ratio of initial to final energies equals 1
  # Initial energy (kinetic + potential) per unit mass
  E_0 = 0.5 * v_0^2 - G * M_EARTH / r
  
  # Run Euler method
  for (i in 1:N) {
    x[i+1] = x[i] + dt * v_x[i]
    y[i+1] = y[i] + dt * v_y[i]
    
    v_x[i+1] = v_x[i] + dt * g_x
    v_y[i+1] = v_y[i] + dt * g_y
    
    s = c(s, x[i+1])
    l = c(l, y[i+1])
  }
  
  # Final height above Earth's center
  r_final = R_EARTH + l[N + 1]
  
  # Final speed^2 calculation
  v_final_squared = v_x[N+1]^2 + v_y[N+1]^2
  
  # Final energy per unit mass
  E_N = 0.5 * v_final_squared - G * M_EARTH / r_final
  
  # Create images directory if it doesn't exist
  if (!dir.exists("images")) {
    dir.create("images")
  }
  
  # Ensure filename has .png extension
  filename = sprintf("euler_trajectory.png")
  if (!grepl("\\.png$", filename, ignore.case = TRUE)) {
    filename = paste0(filename, ".png")
  }
  
  # Full path to save the plot
  filepath = file.path("images", filename)
  
  # Open PNG device
  png(filepath, width = 800, height = 600, res = 100)
  
  # Plot the numerical approximation
  plot(s, l, type = "l", col = "red", lwd = 2,
       xlab = "Horizontal distance (m)", ylab = "Height (m)",
       main = "Projectile Trajectory: Euler Method vs Analytical Solution")
  
  # Plot the analytical trajectory still assuming constant gravitational acceleration
  t = seq(from = 0, to = T, length.out = N)
  x_analytical = v_0 * cos(theta) * t
  y_analytical = y_0 + v_0 * sin(theta) * t + 0.5 * g_y * t^2
  lines(x_analytical, y_analytical, col = "blue", lwd = 2, lty = 2)
  
  # Add legend
  legend("topright", legend = c("Euler Method", "Analytical Solution"),
         lty = c("solid", "dashed"), col = c("red", "blue"), lwd = c(2, 2))
  
  # Add grid for better readability
  grid(col = "gray", lty = "dotted")
  
  # Close the PNG device
  dev.off()
  
  cat(sprintf("Plot saved to: %s\n", filepath))
  
  # Print some useful information
  cat("Simulation Results:\n")
  cat(sprintf("Initial height: %.1f m\n", y_0))
  cat(sprintf("Launch angle: %.1f degrees\n", theta * 180 / pi))
  cat(sprintf("Initial velocity: %.1f m/s\n", v_0))
  cat(sprintf("Maximum height (Euler): %.1f m\n", max(l)))
  cat(sprintf("Total time: %.2f s\n", T))
  cat(sprintf("Energy conservation ratio: %.6f\n", E_N / E_0))
  cat("\n")
  
  return(E_N / E_0)
}
