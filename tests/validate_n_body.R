if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/systems/two_body/two_body_method_registry.R")
cd_source("R/systems/three_body/three_body_runge_kutta.R")
cd_source("R/systems/n_body/four_body_initial_conditions.R")
cd_source("R/systems/n_body/n_body_runge_kutta.R")
cd_source("R/systems/n_body/n_body_velocity_verlet.R")

assert_less_than = function(actual, limit, label) {
  if (!is.finite(actual) || actual >= limit) {
    stop(sprintf("%s failed: actual %.12g, limit %.12g",
                 label, actual, limit))
  }
}

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

assert_pairwise_distance_return = function(result, tolerance_au, label) {
  initial_distances = n_body_pairwise_distances(result$positions[1, , ])
  final_distances = n_body_pairwise_distances(result$positions[dim(result$positions)[1], , ])
  error_au = max(abs(initial_distances - final_distances)) / AU
  assert_less_than(error_au, tolerance_au, label)
}

invisible(capture.output({
  two_body = run_sun_earth_two_body_method(
    two_body_method_functions()[["RK4"]],
    T = YEAR,
    N = 1000
  )
}))

sun_earth_positions = rbind(c(0, 0), c(AU, 0))
sun_earth_velocities = rbind(c(0, 0), c(0, V_EARTH_ORBITAL))

invisible(capture.output({
  n_body_two = runge_kutta_n_body(
    T = YEAR,
    N = 1000,
    masses = c(M_SUN, M_EARTH),
    positions = sun_earth_positions,
    velocities = sun_earth_velocities,
    body_names = c("Sun", "Earth")
  )
}))

assert_less_than(max(abs(n_body_two$positions[, 1, 1] - two_body$x_a)),
                 1e-2, "n-body/two-body Sun x parity")
assert_less_than(max(abs(n_body_two$positions[, 1, 2] - two_body$y_a)),
                 1e-2, "n-body/two-body Sun y parity")
assert_less_than(max(abs(n_body_two$positions[, 2, 1] - two_body$x_b)),
                 1e-2, "n-body/two-body Earth x parity")
assert_less_than(max(abs(n_body_two$positions[, 2, 2] - two_body$y_b)),
                 1e-2, "n-body/two-body Earth y parity")

positions_three = rbind(
  c(-0.5 * AU, 0),
  c(0.5 * AU, 0),
  c(0, sqrt(3) * 0.5 * AU)
)
center = colMeans(positions_three)
positions_three = sweep(positions_three, 2, center)
omega = sqrt(G * (3 * M_EARTH) / AU^3)
velocities_three = cbind(
  -omega * positions_three[, 2],
  omega * positions_three[, 1]
)

invisible(capture.output({
  three_body = runge_kutta_three_body(
    T = YEAR,
    N = 1000,
    m_a = M_EARTH,
    m_b = M_EARTH,
    m_c = M_EARTH,
    r_ax0 = positions_three[1, 1], r_ay0 = positions_three[1, 2],
    r_bx0 = positions_three[2, 1], r_by0 = positions_three[2, 2],
    r_cx0 = positions_three[3, 1], r_cy0 = positions_three[3, 2],
    v_ax0 = velocities_three[1, 1], v_ay0 = velocities_three[1, 2],
    v_bx0 = velocities_three[2, 1], v_by0 = velocities_three[2, 2],
    v_cx0 = velocities_three[3, 1], v_cy0 = velocities_three[3, 2]
  )
  n_body_three = runge_kutta_n_body(
    T = YEAR,
    N = 1000,
    masses = c(M_EARTH, M_EARTH, M_EARTH),
    positions = positions_three,
    velocities = velocities_three
  )
}))

assert_less_than(max(abs(n_body_three$positions[, 1, 1] - three_body$x_a)),
                 1e-2, "n-body/three-body a x parity")
assert_less_than(max(abs(n_body_three$positions[, 2, 2] - three_body$y_b)),
                 1e-2, "n-body/three-body b y parity")
assert_less_than(max(abs(n_body_three$positions[, 3, 1] - three_body$x_c)),
                 1e-2, "n-body/three-body c x parity")

invisible(capture.output({
  verlet_result = velocity_verlet_n_body(
    T = YEAR,
    N = 1000,
    masses = c(M_SUN, M_EARTH),
    positions = sun_earth_positions,
    velocities = sun_earth_velocities
  )
}))

assert_less_than(relative_drift(n_body_angular_momentum_series(verlet_result)),
                 1e-10, "n-body Velocity Verlet angular momentum drift")

square_ic = rotating_square_four_body_initial_conditions(
  half_side_real = 0.25 * AU,
  body_mass = M_EARTH
)
invisible(capture.output({
  square_result = runge_kutta_n_body(
    T = square_ic$period,
    N = 10000,
    masses = square_ic$masses,
    positions = square_ic$positions,
    velocities = square_ic$velocities
  )
}))
assert_pairwise_distance_return(square_result, 1e-5,
                                "rotating square four-body shape return")
assert_less_than(relative_drift(n_body_angular_momentum_series(square_result)),
                 1e-8, "rotating square angular momentum drift")

triangular_ic = triangular_central_four_body_initial_conditions(
  radius_real = 0.5 * AU,
  outer_mass = M_EARTH,
  central_mass = M_EARTH
)
invisible(capture.output({
  triangular_result = runge_kutta_n_body(
    T = triangular_ic$period,
    N = 10000,
    masses = triangular_ic$masses,
    positions = triangular_ic$positions,
    velocities = triangular_ic$velocities
  )
}))
assert_pairwise_distance_return(triangular_result, 1e-5,
                                "triangular central four-body shape return")
assert_less_than(relative_drift(n_body_angular_momentum_series(triangular_result)),
                 1e-8, "triangular central angular momentum drift")

assert_errors(
  runge_kutta_n_body(YEAR, 100, c(M_SUN, M_EARTH),
                     sun_earth_positions,
                     rbind(c(0, 0), c(Inf, 0))),
  "n-body non-finite velocity"
)

assert_errors(
  runge_kutta_n_body(YEAR, 100, c(M_SUN, M_EARTH),
                     rbind(c(0, 0), c(0, 0)),
                     sun_earth_velocities),
  "n-body overlapping initial positions"
)

cat("N-body validation passed.\n")
