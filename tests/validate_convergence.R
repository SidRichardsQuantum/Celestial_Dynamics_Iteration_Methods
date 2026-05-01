if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/systems/two_body/two_body_method_registry.R")

assert_true = function(condition, label) {
  if (!isTRUE(condition)) {
    stop(sprintf("%s failed.", label))
  }
}

method_registry = two_body_method_registry()
methods = two_body_method_functions(method_registry)

reference = run_sun_earth_two_body_method(methods[["RK4"]], T = YEAR,
                                          N = 16000, quiet = TRUE)
reference_point = c(tail(reference$x_b, 1), tail(reference$y_b, 1))
step_counts = c(250, 500, 1000, 2000)

minimum_observed_order = c(
  Euler = 0.75,
  Midpoint = 1.8,
  Heun = 1.8,
  RK4 = 3.8,
  Verlet = 1.8
)

for (method_name in names(methods)) {
  errors = vapply(step_counts, function(N) {
    result = run_sun_earth_two_body_method(methods[[method_name]], T = YEAR,
                                           N = N, quiet = TRUE)
    two_body_final_position_error(result, reference_point)
  }, numeric(1))

  assert_true(all(diff(errors) < 0),
              sprintf("%s errors decrease as dt decreases", method_name))

  observed_orders = log(errors[-length(errors)] / errors[-1]) / log(2)
  assert_true(min(observed_orders) > minimum_observed_order[[method_name]],
              sprintf("%s observed convergence order", method_name))
}

cat("Convergence validation passed.\n")
