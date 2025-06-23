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
  h = (b - a) / N
  r = R_EARTH + y0  # Initial height above Earth's center
  g = G * M_EARTH / r^2  # Constant gravitational acceleration (calculated at initial height)
  
  l = c(y0)  # Sequence of approximated y-values
  s = seq(a + h, b, by = h)  # Sequence of x-values
  
  # Initial energy (kinetic + potential) per unit mass
  Ea = 0.5 * v0^2 - G * M_EARTH / r
  
  yprime = function(x) {
    tan(theta) + (g * (x - a)) / (v0 * cos(theta))^2
  }
  
  # Run Midpoint method
  for (i in 1:N) {
    # Calculate slope at current point
    k1 = yprime(s[i])
    
    # Use Euler step to estimate y at midpoint
    y_mid = l[i] + (h/2) * k1
    
    # Calculate slope at midpoint
    x_mid = s[i] + h/2
    k2 = yprime(x_mid)
    
    # Use midpoint slope for final step
    l = c(l, l[i] + h * k2)
  }
  
  # Final height above Earth's center
  r_final = R_EARTH + l[N + 1]
  
  # Final speed
  v_final = sqrt(
    (v0 * cos(theta))^2 + 
    (v0 * sin(theta) + g * (b - a))^2
  )
  
  # Final energy per unit mass
  Eb = 0.5 * v_final^2 - G * M_EARTH / r_final
  
  # Create images directory if it doesn't exist
  if (!dir.exists("images")) {
    dir.create("images")
  }
  filename = sprintf("midpoint_trajectory_%s.png")
  
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
    c(a, s), l, type = "l", col = "red", lwd = 2,
    xlab = "Horizontal distance (m)", ylab = "Height (m)",
    main = "Projectile Trajectory: Midpoint Method vs Analytical Solution"
  )
  
  # Plot the analytical trajectory
  x = c(a, s)
  y = y0 + (x - a) * tan(theta) + (g * (x - a)^2) / (2 * (v0 * cos(theta))^2)
  lines(x, y, col = "blue", lwd = 2, lty = 2)
  
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
