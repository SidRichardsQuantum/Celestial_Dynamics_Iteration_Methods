source("constants.R")

sitnikov_runge_kutta = function(T, N, primary_mass = M_EARTH,
                                primary_radius = 0.5 * AU,
                                z0 = 0.25 * AU, vz0 = 0) {
  if (!is.finite(T) || T <= 0) {
    stop("T must be a positive finite value.")
  }
  if (!is.finite(N) || N <= 0 || N != as.integer(N)) {
    stop("N must be a positive integer.")
  }
  if (any(!is.finite(c(primary_mass, primary_radius, z0, vz0))) ||
      primary_mass <= 0 || primary_radius <= 0) {
    stop("primary_mass and primary_radius must be positive finite values.")
  }

  omega = sqrt(G * primary_mass / (4 * primary_radius^3))
  dt = T / N
  z = z0
  vz = vz0
  t = seq(0, T, length.out = N + 1)
  z_values = numeric(N + 1)
  vz_values = numeric(N + 1)
  z_values[1] = z
  vz_values[1] = vz

  derivative = function(state) {
    z_state = state[1]
    vz_state = state[2]
    acceleration = -2 * G * primary_mass * z_state /
      (primary_radius^2 + z_state^2)^(3 / 2)
    c(vz_state, acceleration)
  }

  for (i in 1:N) {
    state = c(z, vz)
    k1 = derivative(state)
    k2 = derivative(state + 0.5 * dt * k1)
    k3 = derivative(state + 0.5 * dt * k2)
    k4 = derivative(state + dt * k3)
    state = state + (dt / 6) * (k1 + 2 * k2 + 2 * k3 + k4)
    z = state[1]
    vz = state[2]
    z_values[i + 1] = z
    vz_values[i + 1] = vz
  }

  theta = omega * t
  primary_a = cbind(primary_radius * cos(theta),
                    primary_radius * sin(theta),
                    rep(0, length(t)))
  primary_b = -primary_a
  third = cbind(rep(0, length(t)), rep(0, length(t)), z_values)

  return(list(
    t = t,
    z = z_values,
    vz = vz_values,
    primary_a = primary_a,
    primary_b = primary_b,
    third = third,
    period = 2 * pi / omega
  ))
}

plot_sitnikov_result = function(result, filepath, title) {
  output_dir = dirname(filepath)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  png(filepath, width = 800, height = 600, res = 100)
  old_par = par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
  on.exit({
    par(old_par)
    dev.off()
  }, add = TRUE)

  primary_a_x = result$primary_a[, 1] / AU
  primary_a_y = result$primary_a[, 2] / AU
  primary_b_x = result$primary_b[, 1] / AU
  primary_b_y = result$primary_b[, 2] / AU
  third_x = result$third[, 1] / AU
  third_y = result$third[, 2] / AU
  all_x = c(primary_a_x, primary_b_x, third_x)
  all_y = c(primary_a_y, primary_b_y, third_y)
  x_padding = max(diff(range(all_x)) * 0.1, 0.02)
  y_padding = max(diff(range(all_y)) * 0.1, 0.02)

  plot(primary_a_x, primary_a_y, type = "l", lwd = 2, col = "orange",
       xlim = range(all_x) + c(-x_padding, x_padding),
       ylim = range(all_y) + c(-y_padding, y_padding),
       xlab = "x (AU)", ylab = "y (AU)", main = "Orbital-plane paths",
       asp = 1)
  lines(primary_b_x, primary_b_y, lwd = 2, col = "gray40")
  lines(third_x, third_y, lwd = 2, col = "blue")
  points(tail(primary_a_x, 1), tail(primary_a_y, 1), pch = 19,
         col = "orange", cex = 1.5)
  points(tail(primary_b_x, 1), tail(primary_b_y, 1), pch = 19,
         col = "gray40", cex = 1.5)
  points(tail(third_x, 1), tail(third_y, 1), pch = 19,
         col = "blue", cex = 1.5)
  legend("topright", legend = c("Primary 1 path", "Primary 2 path",
                                "Restricted body path"),
         col = c("orange", "gray40", "blue"), lty = 1, lwd = 2)
  grid(col = "lightgray", lty = "dotted")

  plot(result$t / YEAR, result$z / AU, type = "l", lwd = 2, col = "blue",
       xlab = "time (years)", ylab = "restricted body z (AU)",
       main = title)
  abline(h = 0, col = "gray50", lty = "dashed")
  legend("topright", legend = c("Restricted body z", "Primary orbital plane"),
         col = c("blue", "gray50"), lty = c(1, 2), lwd = c(2, 1))
  grid(col = "lightgray", lty = "dotted")

  cat(sprintf("Plot saved to: %s\n", filepath))
}
