# Runs different numerical methods for the same exmaple

# Source all method implementations
source("iteration_methods/euler_method.R")
source("iteration_methods/heuns_method.R")
source("iteration_methods/midpoint_method.R")
source("iteration_methods/runge_kutta_method.R")

# Function to run example with specified method
run_example <- function(method_name, T = 100, y_0 = 0, v_0 = 200, theta = pi/4, N = 50) {
  # Check if method exists
  if (!exists(method_name, mode = "function")) {
    stop(paste("Method", method_name, "not found. Available methods: Euler, Heun, Midpoint, RungeKutta"))
  }
  
  # Get the function by name and call it
  method_func <- get(method_name)
  cat(paste("=== Example Low Altitude Artillery Shell Example (", method_name, "Method ) ===\n"))
  result <- method_func(T, y_0, v_0, theta, N)
  cat("\n")
  return(result)
}

result1 <- run_example("Euler")
result2 <- run_example("Heun")
result3 <- run_example("Midpoint")
result4 <- run_example("RungeKutta")
