source("constants.R")

two_body_accelerations = function(r_a, r_b, m_a, m_b) {
  r_ab = r_a - r_b
  mag_r_ab = sqrt(sum(r_ab^2))
  if (!is.finite(mag_r_ab) || mag_r_ab <= 0) {
    stop("Body collision or overlapping positions.")
  }

  list(
    a_a = -G * m_b * r_ab / mag_r_ab^3,
    a_b = G * m_a * r_ab / mag_r_ab^3
  )
}

two_body_total_energy = function(r_a, r_b, v_a, v_b, m_a, m_b) {
  separation = sqrt(sum((r_a - r_b)^2))
  if (!is.finite(separation) || separation <= 0) {
    stop("Body collision or overlapping positions.")
  }

  kinetic = 0.5 * m_a * sum(v_a^2) + 0.5 * m_b * sum(v_b^2)
  potential = -G * m_a * m_b / separation
  kinetic + potential
}

two_body_result = function(x_a, y_a, x_b, y_b, energy_ratio,
                           r_ax0, r_ay0, r_bx0, r_by0, m_a, m_b) {
  list(
    x_a = x_a,
    y_a = y_a,
    x_b = x_b,
    y_b = y_b,
    energy_ratio = energy_ratio,
    initial_conditions = list(
      r_ax0 = r_ax0, r_ay0 = r_ay0,
      r_bx0 = r_bx0, r_by0 = r_by0,
      m_a = m_a, m_b = m_b
    )
  )
}

print_two_body_summary = function(method_name, T, N, dt, m_a, m_b,
                                  initial_separation, final_separation,
                                  energy_ratio) {
  cat(sprintf("Two-Body System Simulation %s Method Results:\n", method_name))
  cat(sprintf("Body a mass: %.2e kg\n", m_a))
  cat(sprintf("Body b mass: %.2e kg\n", m_b))
  cat(sprintf("Total simulation time: %.2f years\n", T / YEAR))
  cat(sprintf("Time steps: %d\n", N))
  cat(sprintf("Time step size: %.2f days\n", dt / DAY))
  cat(sprintf("Initial separation: %.3f AU\n", initial_separation / AU))
  cat(sprintf("Final separation: %.3f AU\n", final_separation / AU))
  cat(sprintf("Energy conservation ratio: %.6f\n", energy_ratio))
  cat("\n")
}
