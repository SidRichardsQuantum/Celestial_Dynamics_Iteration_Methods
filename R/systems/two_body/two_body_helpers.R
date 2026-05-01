if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")

two_body_validate_inputs = function(T, N, m_a, m_b,
                                    r_ax0, r_ay0, r_bx0, r_by0,
                                    v_ax0, v_ay0, v_bx0, v_by0) {
  if (!is.finite(T) || T <= 0) {
    stop("T must be a positive finite value.")
  }
  if (!is.finite(N) || N <= 0 || N != as.integer(N)) {
    stop("N must be a positive integer.")
  }
  if (any(!is.finite(c(m_a, m_b))) || any(c(m_a, m_b) <= 0)) {
    stop("Body masses must be positive finite values.")
  }
  initial_values = c(r_ax0, r_ay0, r_bx0, r_by0,
                     v_ax0, v_ay0, v_bx0, v_by0)
  if (any(!is.finite(initial_values))) {
    stop("Initial positions and velocities must be finite values.")
  }
  if (sqrt((r_ax0 - r_bx0)^2 + (r_ay0 - r_by0)^2) <= 0) {
    stop("Body collision or overlapping positions.")
  }

  invisible(TRUE)
}

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
                           r_ax0, r_ay0, r_bx0, r_by0, m_a, m_b,
                           vx_a = NULL, vy_a = NULL, vx_b = NULL, vy_b = NULL) {
  list(
    x_a = x_a,
    y_a = y_a,
    vx_a = vx_a,
    vy_a = vy_a,
    x_b = x_b,
    y_b = y_b,
    vx_b = vx_b,
    vy_b = vy_b,
    energy_ratio = energy_ratio,
    initial_conditions = list(
      r_ax0 = r_ax0, r_ay0 = r_ay0,
      r_bx0 = r_bx0, r_by0 = r_by0,
      m_a = m_a, m_b = m_b
    )
  )
}

two_body_require_velocity_history = function(result) {
  velocity_fields = c("vx_a", "vy_a", "vx_b", "vy_b")
  if (any(vapply(result[velocity_fields], is.null, logical(1)))) {
    stop("Result does not include velocity history.")
  }
  invisible(TRUE)
}

two_body_energy_series = function(result) {
  two_body_require_velocity_history(result)
  m_a = result$initial_conditions$m_a
  m_b = result$initial_conditions$m_b
  separation = sqrt((result$x_a - result$x_b)^2 + (result$y_a - result$y_b)^2)
  if (any(!is.finite(separation)) || any(separation <= 0)) {
    stop("Body collision or overlapping positions.")
  }

  kinetic = 0.5 * m_a * (result$vx_a^2 + result$vy_a^2) +
    0.5 * m_b * (result$vx_b^2 + result$vy_b^2)
  potential = -G * m_a * m_b / separation
  kinetic + potential
}

two_body_angular_momentum_series = function(result) {
  two_body_require_velocity_history(result)
  m_a = result$initial_conditions$m_a
  m_b = result$initial_conditions$m_b

  m_a * (result$x_a * result$vy_a - result$y_a * result$vx_a) +
    m_b * (result$x_b * result$vy_b - result$y_b * result$vx_b)
}

relative_drift = function(values) {
  reference = values[1]
  scale = max(abs(reference), .Machine$double.eps)
  max(abs(values - reference)) / scale
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
