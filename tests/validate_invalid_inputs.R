if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/systems/two_body/two_body_method_registry.R")
cd_source("R/systems/three_body/three_body_runge_kutta.R")

assert_errors = function(expr, label) {
  did_error = FALSE
  tryCatch(
    expr,
    error = function(e) {
      did_error <<- TRUE
    }
  )
  if (!did_error) {
    stop(sprintf("%s failed: expected an error.", label))
  }
}

assert_errors(
  euler_two_body(-YEAR, 100, M_SUN, M_EARTH,
                 0, 0, AU, 0, 0, 0, 0, V_EARTH_ORBITAL),
  "Two-body negative simulation time"
)

assert_errors(
  midpoint_two_body(YEAR, 100.5, M_SUN, M_EARTH,
                    0, 0, AU, 0, 0, 0, 0, V_EARTH_ORBITAL),
  "Two-body non-integer step count"
)

assert_errors(
  heuns_two_body(YEAR, 100, -M_SUN, M_EARTH,
                 0, 0, AU, 0, 0, 0, 0, V_EARTH_ORBITAL),
  "Two-body negative mass"
)

assert_errors(
  runge_kutta_two_body(YEAR, 100, M_SUN, M_EARTH,
                       0, 0, 0, 0, 0, 0, 0, V_EARTH_ORBITAL),
  "Two-body overlapping initial positions"
)

assert_errors(
  velocity_verlet_two_body(YEAR, 100, M_SUN, M_EARTH,
                           0, 0, AU, 0, Inf, 0, 0, V_EARTH_ORBITAL),
  "Velocity Verlet non-finite initial velocity"
)

assert_errors(
  runge_kutta_three_body(YEAR, 100, M_EARTH, M_EARTH, M_EARTH,
                         0, 0, AU, 0, AU, 0,
                         0, 0, 0, 0, 0, 0),
  "Three-body overlapping initial positions"
)

assert_errors(
  runge_kutta_three_body(YEAR, 100, M_EARTH, 0, M_EARTH,
                         0, 0, AU, 0, 0, AU,
                         0, 0, 0, 0, 0, 0),
  "Three-body zero mass"
)

cat("Invalid input validation passed.\n")
