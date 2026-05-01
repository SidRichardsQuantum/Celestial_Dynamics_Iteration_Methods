source("R/constants.R")
source("R/systems/plotting/plot_style.R")

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
  old_par = cd_open_png(filepath, width = 1200, height = 720, res = 140,
                        mar = c(4.8, 4.8, 3.2, 1.2), mfrow = c(1, 2))
  par(oma = c(0, 0, 2.5, 0))
  on.exit({
    cd_close_png(old_par)
  }, add = TRUE)

  primary_a_x = result$primary_a[, 1] / AU
  primary_a_y = result$primary_a[, 2] / AU
  primary_b_x = result$primary_b[, 1] / AU
  primary_b_y = result$primary_b[, 2] / AU
  third_x = result$third[, 1] / AU
  third_y = result$third[, 2] / AU
  all_x = c(primary_a_x, primary_b_x, third_x)
  all_y = c(primary_a_y, primary_b_y, third_y)
  xlim = cd_expand_range(all_x, 0.1, 0.02)
  ylim = cd_expand_range(all_y, 0.1, 0.02)
  cd_plot_empty(xlim, ylim,
                xlab = "x (AU)", ylab = "y (AU)",
                main = "Orbital-plane paths", asp = 1)
  lines(primary_a_x, primary_a_y, lwd = 2.3, col = cd_colors$orange)
  lines(primary_b_x, primary_b_y, lwd = 2.3, col = cd_colors$gray)
  lines(third_x, third_y, lwd = 2.3, col = cd_colors$blue)
  points(tail(primary_a_x, 1), tail(primary_a_y, 1), pch = 19,
         col = cd_colors$orange, cex = 1.5)
  points(tail(primary_b_x, 1), tail(primary_b_y, 1), pch = 19,
         col = cd_colors$gray, cex = 1.5)
  points(tail(third_x, 1), tail(third_y, 1), pch = 19,
         col = cd_colors$blue, cex = 1.5)
  legend("topright", legend = c("Primary 1 path", "Primary 2 path",
                                "Restricted body path"),
         col = c(cd_colors$orange, cd_colors$gray, cd_colors$blue),
         lty = 1, lwd = 2, bty = "n", cex = 0.82)

  txlim = cd_expand_range(result$t / YEAR, 0.02, 0.02)
  zylim = cd_expand_range(result$z / AU, 0.08, 0.005)
  cd_plot_empty(txlim, zylim,
                xlab = "time (years)", ylab = "restricted body z (AU)",
                main = "Vertical oscillation")
  lines(result$t / YEAR, result$z / AU, lwd = 2.3, col = cd_colors$blue)
  abline(h = 0, col = cd_colors$gray, lty = "dashed")
  legend("topright", legend = c("Restricted body z", "Primary orbital plane"),
         col = c(cd_colors$blue, cd_colors$gray), lty = c(1, 2),
         lwd = c(2, 1), bty = "n", cex = 0.82)

  mtext(title, outer = TRUE, cex = 1.15, font = 2, col = cd_colors$ink)

  cat(sprintf("Plot saved to: %s\n", filepath))
  cd_record_plot_manifest(
    filepath = filepath,
    artifact_type = "png",
    plot_type = "sitnikov",
    title = title,
    width = 1200,
    height = 720,
    res = 140,
    xlim = txlim,
    ylim = zylim,
    data_x = result$t / YEAR,
    data_y = result$z / AU
  )
}
