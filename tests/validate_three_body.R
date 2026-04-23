source("constants.R")
source("celestial_systems/three_body/three_body_runge_kutta.R")
source("celestial_systems/three_body/figure_8_initial_conditions.R")
source("celestial_systems/three_body/lagrange_initial_conditions.R")
source("celestial_systems/three_body/euler_collinear_initial_conditions.R")
source("celestial_systems/three_body/choreography_initial_conditions.R")
source("celestial_systems/three_body/circular_restricted_three_body.R")
source("celestial_systems/three_body/sitnikov_problem.R")

assert_near = function(actual, expected, tolerance, label) {
  error = abs(actual - expected)
  if (!is.finite(error) || error > tolerance) {
    stop(sprintf(
      "%s failed: actual %.12g, expected %.12g, tolerance %.12g",
      label, actual, expected, tolerance
    ))
  }
}

separation = function(x1, y1, x2, y2) {
  sqrt((x1 - x2)^2 + (y1 - y2)^2)
}

run_three_body_case = function(ic, N = 20000) {
  pos1 = ic$positions[[1]]
  pos2 = ic$positions[[2]]
  pos3 = ic$positions[[3]]
  vel1 = ic$velocities[[1]]
  vel2 = ic$velocities[[2]]
  vel3 = ic$velocities[[3]]

  runge_kutta_three_body(
    T = ic$period,
    N = N,
    m_a = M_EARTH,
    m_b = M_EARTH,
    m_c = M_EARTH,
    r_ax0 = pos1[1], r_ay0 = pos1[2],
    r_bx0 = pos2[1], r_by0 = pos2[2],
    r_cx0 = pos3[1], r_cy0 = pos3[2],
    v_ax0 = vel1[1], v_ay0 = vel1[2],
    v_bx0 = vel2[1], v_by0 = vel2[2],
    v_cx0 = vel3[1], v_cy0 = vel3[2]
  )
}

assert_final_separations = function(result, ic, tolerance, label) {
  pos1 = ic$positions[[1]]
  pos2 = ic$positions[[2]]
  pos3 = ic$positions[[3]]

  initial_ab = separation(pos1[1], pos1[2], pos2[1], pos2[2])
  initial_ac = separation(pos1[1], pos1[2], pos3[1], pos3[2])
  initial_bc = separation(pos2[1], pos2[2], pos3[1], pos3[2])

  final_ab = separation(tail(result$x_a, 1), tail(result$y_a, 1),
                        tail(result$x_b, 1), tail(result$y_b, 1))
  final_ac = separation(tail(result$x_a, 1), tail(result$y_a, 1),
                        tail(result$x_c, 1), tail(result$y_c, 1))
  final_bc = separation(tail(result$x_b, 1), tail(result$y_b, 1),
                        tail(result$x_c, 1), tail(result$y_c, 1))

  assert_near(final_ab / AU, initial_ab / AU, tolerance,
              sprintf("%s a-b separation", label))
  assert_near(final_ac / AU, initial_ac / AU, tolerance,
              sprintf("%s a-c separation", label))
  assert_near(final_bc / AU, initial_bc / AU, tolerance,
              sprintf("%s b-c separation", label))
}

ic = figure_8_initial_conditions(distance_real = AU, body_mass = M_EARTH)
result = run_three_body_case(ic)
assert_final_separations(result, ic, 1e-3, "figure-8")
assert_near(result$energy_ratio, 1, 1e-6, "figure-8 energy ratio")

ic = lagrange_initial_conditions(side_length_real = AU, body_mass = M_EARTH)
result = run_three_body_case(ic)
assert_final_separations(result, ic, 1e-3, "Lagrange")
assert_near(result$energy_ratio, 1, 1e-6, "Lagrange energy ratio")

ic = euler_collinear_initial_conditions(outer_separation_real = AU,
                                        body_mass = M_EARTH)
result = run_three_body_case(ic)
assert_final_separations(result, ic, 1e-3, "Euler collinear")
assert_near(result$energy_ratio, 1, 1e-6, "Euler collinear energy ratio")

ic = choreography_initial_conditions(name = "butterfly_i",
                                     outer_separation_real = AU,
                                     body_mass = M_EARTH)
assert_near(ic$positions[[3]][1] - ic$positions[[1]][1], AU, 1e-12 * AU,
            "Butterfly I outer separation")

mu = M_MOON / (M_EARTH + M_MOON)
points = cr3bp_lagrange_points(mu)
l4_state = c(points$L4[1], points$L4[2], 0, 0, 0, 0)
l4_derivative = cr3bp_derivative(l4_state, mu)
assert_near(l4_derivative[4], 0, 1e-12, "CR3BP L4 x acceleration")
assert_near(l4_derivative[5], 0, 1e-12, "CR3BP L4 y acceleration")

sitnikov = sitnikov_runge_kutta(T = YEAR, N = 1000,
                                primary_mass = M_EARTH,
                                primary_radius = 0.05 * AU,
                                z0 = 0.04 * AU,
                                vz0 = 0)
if (any(!is.finite(sitnikov$z))) {
  stop("Sitnikov z trajectory contains non-finite values.")
}

cat("Three-body validation passed.\n")
