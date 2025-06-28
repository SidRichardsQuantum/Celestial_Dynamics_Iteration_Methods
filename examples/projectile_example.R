# Runs different numerical methods for the same exmaple

# Source all method implementations
source("iteration_methods/euler_method.R")
source("iteration_methods/heuns_method.R")
source("iteration_methods/midpoint_method.R")
source("iteration_methods/runge_kutta_method.R")

# Function to run example with specified method
run_example <- function(method_name, a = 0, b = 10000, y0 = 0, v0 = 200, theta = pi/4, N = 100) {
  # Check if method exists
  if (!exists(method_name, mode = "function")) {
    stop(paste("Method", method_name, "not found. Available methods: Euler, Heun, Midpoint, Runge-Kutta"))
  }
  
  # Get the function by name and call it
  method_func <- get(method_name)
  cat(paste("=== Example Low Altitude Artillery Shell Example (", method_name, "Method ) ===\n"))
  result <- method_func(a, b, y0, v0, theta, N)
  cat(sprintf("Energy conservation ratio: %.6f\n", result))
  cat("\n")
  return(result)
}

result1 <- run_example("Euler")
result2 <- run_example("Heun")
result3 <- run_example("Midpoint")
result4 <- run_example("Runge-Kutta")
