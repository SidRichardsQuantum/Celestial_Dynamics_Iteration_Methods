source("R/systems/two_body/two_body_method_registry.R")

assert_near = function(actual, expected, tolerance, label) {
  error = abs(actual - expected)
  if (!is.finite(error) || error > tolerance) {
    stop(sprintf(
      "%s failed: actual %.12g, expected %.12g, tolerance %.12g",
      label, actual, expected, tolerance
    ))
  }
}

run_sun_earth_case = function(method_func) {
  run_sun_earth_two_body_method(method_func, T = 25 * YEAR, N = 1000)
}

methods = two_body_method_functions()

euler_result = run_sun_earth_case(methods[["Euler"]])
midpoint_result = run_sun_earth_case(methods[["Midpoint"]])
heun_result = run_sun_earth_case(methods[["Heun"]])
rk4_result = run_sun_earth_case(methods[["RK4"]])
verlet_result = run_sun_earth_case(methods[["Verlet"]])

assert_near(rk4_result$energy_ratio, 1, 1e-3, "RK4 Sun-Earth energy ratio")
assert_near(verlet_result$energy_ratio, 1, 1e-2,
            "Velocity Verlet Sun-Earth energy ratio")

if (abs(euler_result$energy_ratio - 1) <= abs(heun_result$energy_ratio - 1)) {
  stop("Euler should conserve energy worse than Heun's method for the Sun-Earth case.")
}

if (abs(heun_result$energy_ratio - 1) <= abs(midpoint_result$energy_ratio - 1)) {
  stop("Heun's method should conserve energy worse than midpoint for the Sun-Earth case.")
}

if (abs(midpoint_result$energy_ratio - 1) <= abs(rk4_result$energy_ratio - 1)) {
  stop("Midpoint should conserve energy worse than RK4 for the Sun-Earth case.")
}

if (abs(euler_result$energy_ratio - 1) <= abs(verlet_result$energy_ratio - 1)) {
  stop("Euler should conserve energy worse than velocity Verlet for the Sun-Earth case.")
}

cat("Two-body validation passed.\n")
