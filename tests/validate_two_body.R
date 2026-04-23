source("constants.R")
source("celestial_systems/two_body/two_body_euler.R")
source("celestial_systems/two_body/two_body_midpoint.R")
source("celestial_systems/two_body/two_body_heuns.R")
source("celestial_systems/two_body/two_body_runge_kutta.R")

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
  method_func(
    T = 25 * YEAR,
    N = 1000,
    m_a = M_SUN,
    m_b = M_EARTH,
    r_ax0 = 0, r_ay0 = 0,
    r_bx0 = AU, r_by0 = 0,
    v_ax0 = 0, v_ay0 = 0,
    v_bx0 = 0, v_by0 = abs(V_EARTH_ORBITAL)
  )
}

euler_result = run_sun_earth_case(euler_two_body)
midpoint_result = run_sun_earth_case(midpoint_two_body)
heun_result = run_sun_earth_case(heuns_two_body)
rk4_result = run_sun_earth_case(runge_kutta_two_body)

assert_near(rk4_result$energy_ratio, 1, 1e-3, "RK4 Sun-Earth energy ratio")

if (abs(euler_result$energy_ratio - 1) <= abs(heun_result$energy_ratio - 1)) {
  stop("Euler should conserve energy worse than Heun's method for the Sun-Earth case.")
}

if (abs(heun_result$energy_ratio - 1) <= abs(midpoint_result$energy_ratio - 1)) {
  stop("Heun's method should conserve energy worse than midpoint for the Sun-Earth case.")
}

if (abs(midpoint_result$energy_ratio - 1) <= abs(rk4_result$energy_ratio - 1)) {
  stop("Midpoint should conserve energy worse than RK4 for the Sun-Earth case.")
}

cat("Two-body validation passed.\n")
