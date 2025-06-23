# Load physical constants
source("constants.R")

# Midpoint method
# AKA: Modified Euler method

Midpoint = function(a, b, y0, v0, theta, N) {
  # Particle trajectory in a static (constant) gravitational field using midpoint method
 
  # Args:
  # a: initial x coordinate
  # b: final x coordinate
  # y0: initial y coordinate
  # v0: initial speed
  # theta: angle of initial trajectory (between the horizontal and initial velocity)
  # N: number of steps between a and b
 
  # Energy conservation test: energy is conserved if the ratio of initial to final energies equals 1
 
  # Calculate time step based on horizontal motion
  t_total = (b - a) / (v0 * cos(theta))
  dt = t_total / N
 
  r = R_EARTH + y0  # Initial height above Earth's center
  g = -G * M_EARTH / r^2  # Constant gravitational acceleration (calculated at initial height)
 
  # Initialize arrays
  x = numeric(N + 1)
  y = numeric(N + 1)
  vx = numeric(N + 1)
  vy = numeric(N + 1)
 
  # Initial conditions
  x[1] = a
  y[1] = y0
  vx[1] = v0 * cos(theta)
  vy[1] = v0 * sin(theta)
 
  l = c(y0)  # Sequence of approximated y-values
  s = c(a)  # Sequence of x-values
 
  # Initial energy (kinetic + potential) per unit mass
  Ea = 0.5 * v0^2 - G * M_EARTH / r
 
  # Run Midpoint method
  for (i in 1:N) {
    # Calculate k1 values (derivatives at current point)
    k1_x = vx[i]
    k1_y = vy[i]
    k1_vx = 0
    k1_vy = -g
   
    # Calculate midpoint estimates
    x_mid = x[i] + (dt/2) * k1_x
    y_mid = y[i] + (dt/2) * k1_y
    vx_mid = vx[i] + (dt/2) * k1_vx
    vy_mid = vy[i] + (dt/2) * k1_vy
   
    # Calculate k2 values (derivatives at midpoint)
    k2_x = vx_mid
    k2_y = vy_mid
    k2_vx = 0
    k2_vy = -g
   
    # Update using midpoint derivatives
    x[i+1] = x[i] + dt * k2_x
    y[i+1] = y[i] + dt * k2_y
    vx[i+1] = vx[i] + dt * k2_vx
    vy[i+1] = vy[i] + dt * k2_vy
   
    l = c(l, y[i+1])
    s = c(s, x[i+1])
  }
 
  # Final height above Earth's center
  r_final = R_EARTH + l[N + 1]
 
  # Final speed
  v_final = sqrt(vx[N+1]^2 + vy[N+1]^2)
 
  # Final energy per unit mass
  Eb = 0.5 * v_final^2 - G * M_EARTH / r_final
 
  # Create images directory if it doesn't exist
  if (!dir.exists("images")) {
    dir.create("images")
  }
 
  filename = sprintf("midpoint_trajectory.png")
 
  # Ensure filename has .png extension
  if (!grepl("\\.png$", filename, ignore.case = TRUE)) {
    filename = paste0(filename, ".png")
  }
 
  # Full path to save the plot
  filepath = file.path("images", filename)
 
  # Open PNG device
  png(filepath, width = 800, height = 600, res = 100)
 
  # Plot the numerical approximation
  plot(
    s, l, type = "l", col = "red", lwd = 2,
    xlab = "Horizontal distance (m)", ylab = "Height (m)",
    main = "Projectile Trajectory: Midpoint Method vs Analytical Solution"
  )
 
  # Plot the analytical trajectory
  x_analytical = s
  y_analytical = y0 + (x_analytical - a) * tan(theta) - (g * (x_analytical - a)^2) / (2 * (v0 * cos(theta))^2)
  lines(x_analytical, y_analytical, col = "blue", lwd = 2, lty = 2)
 
  # Add legend
  legend(
    "topright",
    legend = c("Midpoint Method", "Analytical Solution"),
    lty = c("solid", "dashed"),
    col = c("red", "blue"),
    lwd = c(2, 2)
  )
 
  # Add grid for better readability
  grid(col = "gray", lty = "dotted")
 
  # Close the PNG device
  dev.off()
  cat(sprintf("Plot saved to: %s\n", filepath))
 
  # Print some useful information
  cat("Simulation Results:\n")
  cat(sprintf("Initial height: %.1f m\n", y0))
  cat(sprintf("Launch angle: %.1f degrees\n", theta * 180 / pi))
  cat(sprintf("Initial velocity: %.1f m/s\n", v0))
  cat(sprintf("Constant gravity: %.3f m/s²\n", abs(g)))
  cat(sprintf("Maximum height (Midpoint): %.1f m\n", max(l)))
  cat(sprintf("Range: %.1f m\n", b - a))
  cat(sprintf("Energy conservation ratio: %.6f\n", Eb / Ea))
  cat("\n")
 
  return(Eb / Ea)
}

# Example low-altitude projectile
cat("=== Example Low Altitude Artillery Shell Example ===\n")
result = Midpoint(0, 10000, 0, 200, pi/4, 100)
