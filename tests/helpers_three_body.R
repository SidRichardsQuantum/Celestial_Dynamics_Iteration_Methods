if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/systems/three_body/three_body_runge_kutta.R")

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
