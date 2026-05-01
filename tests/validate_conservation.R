if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/systems/two_body/two_body_method_registry.R")
cd_source("tests/helpers_three_body.R")
cd_source("R/systems/three_body/lagrange_initial_conditions.R")

assert_less_than = function(actual, limit, label) {
  if (!is.finite(actual) || actual >= limit) {
    stop(sprintf("%s failed: actual %.12g, limit %.12g",
                 label, actual, limit))
  }
}

relative_energy_drift = function(energy) {
  max(abs((energy - energy[1]) / abs(energy[1])))
}

capture.output({
  sun_earth = run_sun_earth_two_body_method(
    two_body_method_functions()[["RK4"]],
    T = YEAR,
    N = 1000
  )
})

assert_less_than(relative_energy_drift(two_body_energy_series(sun_earth)),
                 1e-10, "RK4 Sun-Earth energy drift")
assert_less_than(relative_drift(two_body_angular_momentum_series(sun_earth)),
                 1e-10, "RK4 Sun-Earth angular momentum drift")

lagrange = lagrange_initial_conditions(side_length_real = AU,
                                       body_mass = M_EARTH)
capture.output({
  lagrange_result = run_three_body_case(lagrange, N = 5000)
})

assert_less_than(relative_energy_drift(three_body_energy_series(lagrange_result)),
                 1e-10, "Lagrange three-body energy drift")
assert_less_than(relative_drift(three_body_angular_momentum_series(lagrange_result)),
                 1e-10, "Lagrange three-body angular momentum drift")

cat("Conservation validation passed.\n")
