source("constants.R")

three_body_accelerations = function(r_a, r_b, r_c, m_a, m_b, m_c) {
  r_ab = r_a - r_b
  r_ac = r_a - r_c
  r_bc = r_b - r_c

  mag_r_ab = sqrt(sum(r_ab^2))
  mag_r_ac = sqrt(sum(r_ac^2))
  mag_r_bc = sqrt(sum(r_bc^2))
  if (any(!is.finite(c(mag_r_ab, mag_r_ac, mag_r_bc))) ||
      any(c(mag_r_ab, mag_r_ac, mag_r_bc) <= 0)) {
    stop("Body collision or overlapping positions.")
  }

  list(
    a_a = -G * m_b * r_ab / mag_r_ab^3 - G * m_c * r_ac / mag_r_ac^3,
    a_b = G * m_a * r_ab / mag_r_ab^3 - G * m_c * r_bc / mag_r_bc^3,
    a_c = G * m_a * r_ac / mag_r_ac^3 + G * m_b * r_bc / mag_r_bc^3
  )
}

three_body_separations = function(r_a, r_b, r_c) {
  c(
    ab = sqrt(sum((r_a - r_b)^2)),
    ac = sqrt(sum((r_a - r_c)^2)),
    bc = sqrt(sum((r_b - r_c)^2))
  )
}

three_body_total_energy = function(r_a, r_b, r_c, v_a, v_b, v_c,
                                   m_a, m_b, m_c) {
  separations = three_body_separations(r_a, r_b, r_c)
  if (any(!is.finite(separations)) || any(separations <= 0)) {
    stop("Body collision or overlapping positions.")
  }

  kinetic = 0.5 * m_a * sum(v_a^2) +
    0.5 * m_b * sum(v_b^2) +
    0.5 * m_c * sum(v_c^2)
  potential = -G * m_a * m_b / separations["ab"] -
    G * m_a * m_c / separations["ac"] -
    G * m_b * m_c / separations["bc"]
  kinetic + potential
}

three_body_result = function(x_a, y_a, x_b, y_b, x_c, y_c, energy_ratio,
                             r_ax0, r_ay0, r_bx0, r_by0, r_cx0, r_cy0,
                             m_a, m_b, m_c) {
  list(
    x_a = x_a,
    y_a = y_a,
    x_b = x_b,
    y_b = y_b,
    x_c = x_c,
    y_c = y_c,
    energy_ratio = energy_ratio,
    initial_conditions = list(
      r_ax0 = r_ax0, r_ay0 = r_ay0,
      r_bx0 = r_bx0, r_by0 = r_by0,
      r_cx0 = r_cx0, r_cy0 = r_cy0,
      m_a = m_a, m_b = m_b, m_c = m_c
    )
  )
}

print_three_body_summary = function(T, N, dt, m_a, m_b, m_c,
                                    initial_separations, final_separations,
                                    energy_ratio) {
  cat("Three-Body System Simulation Runge-Kutta Method Results:\n")
  cat(sprintf("Body a mass: %.2e kg\n", m_a))
  cat(sprintf("Body b mass: %.2e kg\n", m_b))
  cat(sprintf("Body c mass: %.2e kg\n", m_c))
  cat(sprintf("Total simulation time: %.2f years\n", T / YEAR))
  cat(sprintf("Time steps: %d\n", N))
  cat(sprintf("Time step size: %.2f days\n", dt / DAY))
  cat(sprintf("Initial separation a-b: %.3f AU\n", initial_separations["ab"] / AU))
  cat(sprintf("Initial separation a-c: %.3f AU\n", initial_separations["ac"] / AU))
  cat(sprintf("Initial separation b-c: %.3f AU\n", initial_separations["bc"] / AU))
  cat(sprintf("Final separation a-b: %.3f AU\n", final_separations["ab"] / AU))
  cat(sprintf("Final separation a-c: %.3f AU\n", final_separations["ac"] / AU))
  cat(sprintf("Final separation b-c: %.3f AU\n", final_separations["bc"] / AU))
  cat(sprintf("Energy conservation ratio: %.6f\n", energy_ratio))
  cat("\n")
}
