if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")

three_body_validate_inputs = function(T, N, m_a, m_b, m_c,
                                      r_ax0, r_ay0, r_bx0, r_by0, r_cx0, r_cy0,
                                      v_ax0, v_ay0, v_bx0, v_by0, v_cx0, v_cy0) {
  if (!is.finite(T) || T <= 0) {
    stop("T must be a positive finite value.")
  }
  if (!is.finite(N) || N <= 0 || N != as.integer(N)) {
    stop("N must be a positive integer.")
  }
  if (any(!is.finite(c(m_a, m_b, m_c))) || any(c(m_a, m_b, m_c) <= 0)) {
    stop("Body masses must be positive finite values.")
  }
  initial_values = c(r_ax0, r_ay0, r_bx0, r_by0, r_cx0, r_cy0,
                     v_ax0, v_ay0, v_bx0, v_by0, v_cx0, v_cy0)
  if (any(!is.finite(initial_values))) {
    stop("Initial positions and velocities must be finite values.")
  }

  separations = three_body_separations(c(r_ax0, r_ay0),
                                       c(r_bx0, r_by0),
                                       c(r_cx0, r_cy0))
  if (any(!is.finite(separations)) || any(separations <= 0)) {
    stop("Body collision or overlapping positions.")
  }

  invisible(TRUE)
}

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
                             m_a, m_b, m_c,
                             vx_a = NULL, vy_a = NULL,
                             vx_b = NULL, vy_b = NULL,
                             vx_c = NULL, vy_c = NULL) {
  list(
    x_a = x_a,
    y_a = y_a,
    vx_a = vx_a,
    vy_a = vy_a,
    x_b = x_b,
    y_b = y_b,
    vx_b = vx_b,
    vy_b = vy_b,
    x_c = x_c,
    y_c = y_c,
    vx_c = vx_c,
    vy_c = vy_c,
    energy_ratio = energy_ratio,
    initial_conditions = list(
      r_ax0 = r_ax0, r_ay0 = r_ay0,
      r_bx0 = r_bx0, r_by0 = r_by0,
      r_cx0 = r_cx0, r_cy0 = r_cy0,
      m_a = m_a, m_b = m_b, m_c = m_c
    )
  )
}

three_body_require_velocity_history = function(result) {
  velocity_fields = c("vx_a", "vy_a", "vx_b", "vy_b", "vx_c", "vy_c")
  if (any(vapply(result[velocity_fields], is.null, logical(1)))) {
    stop("Result does not include velocity history.")
  }
  invisible(TRUE)
}

three_body_energy_series = function(result) {
  three_body_require_velocity_history(result)
  m_a = result$initial_conditions$m_a
  m_b = result$initial_conditions$m_b
  m_c = result$initial_conditions$m_c

  ab = sqrt((result$x_a - result$x_b)^2 + (result$y_a - result$y_b)^2)
  ac = sqrt((result$x_a - result$x_c)^2 + (result$y_a - result$y_c)^2)
  bc = sqrt((result$x_b - result$x_c)^2 + (result$y_b - result$y_c)^2)
  if (any(!is.finite(c(ab, ac, bc))) || any(c(ab, ac, bc) <= 0)) {
    stop("Body collision or overlapping positions.")
  }

  kinetic = 0.5 * m_a * (result$vx_a^2 + result$vy_a^2) +
    0.5 * m_b * (result$vx_b^2 + result$vy_b^2) +
    0.5 * m_c * (result$vx_c^2 + result$vy_c^2)
  potential = -G * m_a * m_b / ab -
    G * m_a * m_c / ac -
    G * m_b * m_c / bc
  kinetic + potential
}

three_body_angular_momentum_series = function(result) {
  three_body_require_velocity_history(result)
  m_a = result$initial_conditions$m_a
  m_b = result$initial_conditions$m_b
  m_c = result$initial_conditions$m_c

  m_a * (result$x_a * result$vy_a - result$y_a * result$vx_a) +
    m_b * (result$x_b * result$vy_b - result$y_b * result$vx_b) +
    m_c * (result$x_c * result$vy_c - result$y_c * result$vx_c)
}

if (!exists("relative_drift")) {
  relative_drift = function(values) {
    reference = values[1]
    scale = max(abs(reference), .Machine$double.eps)
    max(abs(values - reference)) / scale
  }
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
