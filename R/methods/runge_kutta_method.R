if (!exists("cd_source", mode = "function")) source("R/load.R")
# Load physical constants
cd_source("R/constants.R")
cd_source("R/systems/plotting/plot_style.R")

# Runge-Kutta method
RungeKutta = function(T, y_0, v_0, theta, N) {
  # Particle trajectory in a constant gravitational field
  # Args:
  # T: total time of simulation
  # y_0: initial y coordinate
  # v_0: initial speed
  # theta: angle of initial trajectory (between the horizontal and initial velocity direction)
  # N: number of steps over time T

  r = R_EARTH + y_0       # Initial height above Earth's center
  g_x = 0                 # No acceleration in the x-direction
  g_y = -G * M_EARTH / r^2 # Initial gravitational acceleration
  
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
  E_0 = 0.5 * v_0^2 + G * M_EARTH / r

  # Run Runge-Kutta method
  for (i in 1:N) {
    # k1 coefficients
    k_1x = dt * v_x[i]
    k_1y = dt * v_y[i]
    k_1vx = dt * g_x
    k_1vy = dt * g_y
    
    # k2 coefficients
    k_2x = dt * (v_x[i] + k_1vx/2)
    k_2y = dt * (v_y[i] + k_1vy/2)
    k_2vx = dt * g_x
    k_2vy = dt * g_y
    
    # k3 coefficients
    k_3x = dt * (v_x[i] + k_2vx/2)
    k_3y = dt * (v_y[i] + k_2vy/2)
    k_3vx = dt * g_x
    k_3vy = dt * g_y
    
    # k4 coefficients
    k_4x = dt * (v_x[i] + k_3vx)
    k_4y = dt * (v_y[i] + k_3vy)
    k_4vx = dt * g_x
    k_4vy = dt * g_y
    
    # Update using weighted average of k coefficients
    x[i+1] = x[i] + (k_1x + 2*k_2x + 2*k_3x + k_4x)/6
    y[i+1] = y[i] + (k_1y + 2*k_2y + 2*k_3y + k_4y)/6
    v_x[i+1] = v_x[i] + (k_1vx + 2*k_2vx + 2*k_3vx + k_4vx)/6
    v_y[i+1] = v_y[i] + (k_1vy + 2*k_2vy + 2*k_3vy + k_4vy)/6
    l = c(l, y[i+1])
    s = c(s, x[i+1])
  }

  # Final height above Earth's center
  r_final = R_EARTH + l[N + 1]
  
  # Final speed^2 calculation
  v_final_squared = v_x[N+1]^2 + v_y[N+1]^2
  
  # Final energy per unit mass
  E_N = 0.5 * v_final_squared + G * M_EARTH / r_final
  
  # Create images directory if it doesn't exist
  if (!dir.exists(file.path("images", "projectile"))) {
    dir.create(file.path("images", "projectile"), recursive = TRUE)
  }
  
  # Ensure filename has .png extension
  filename = sprintf("rungekutta_trajectory.png")
  if (!grepl("\\.png$", filename, ignore.case = TRUE)) {
    filename = paste0(filename, ".png")
  }
  
  # Full path to save the plot
  filepath = file.path("images", "projectile", filename)
  
  # Plot the analytical trajectory assuming constant gravitational acceleration
  t = seq(from = 0, to = T, length.out = length(s))
  x_analytical = v_0 * cos(theta) * t
  y_analytical = y_0 + v_0 * sin(theta) * t + 0.5 * g_y * t^2
  cd_plot_projectile(
    filepath = filepath,
    title = "Projectile Trajectory: Runge-Kutta Method vs Analytical Solution",
    method_label = "Runge-Kutta Method",
    x_numeric = s,
    y_numeric = l,
    x_reference = x_analytical,
    y_reference = y_analytical
  )

  # Print some useful information
  cat("Simulation Results:\n")
  cat(sprintf("Initial height: %.1f m\n", y_0))
  cat(sprintf("Launch angle: %.1f degrees\n", theta * 180 / pi))
  cat(sprintf("Initial velocity: %.1f m/s\n", v_0))
  cat(sprintf("Maximum height (Runge-Kutta): %.1f m\n", max(l)))
  cat(sprintf("Total time: %.2f s\n", T))
  cat(sprintf("Energy conservation ratio: %.6f\n", E_N / E_0))
  cat("\n")
  
  return(E_N / E_0)
}
