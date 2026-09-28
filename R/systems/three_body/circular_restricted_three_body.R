if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/systems/plotting/plot_style.R")

cd_source("R/dynamics/integrate.R")

# Compatibility adapters retain the six-vector and legacy trajectory layout.
cr3bp_derivative = function(state, mu) {
  values = cd_cr3bp_rows(state, 6L)
  if (nrow(values) != 1L) stop("Supply one six-component state.")
  derivative = dynamics_derivative(dynamical_model("cr3bp_rotating", list(mu = mu)), 0,
    list(positions = values[, 1:3, drop = FALSE], velocities = values[, 4:6, drop = FALSE]))
  c(as.numeric(derivative$positions), as.numeric(derivative$velocities))
}

cr3bp_runge_kutta = function(T, N, mu, state0) {
  cd_model_scalar(T, "T")
  cd_model_scalar(N, "N")
  if (N != floor(N)) stop("N must be a positive integer.")
  state = cd_cr3bp_rows(state0, 6L)
  if (nrow(state) != 1L) stop("Supply one six-component initial state.")
  trajectory = integrate_dynamics(dynamical_model("cr3bp_rotating", list(mu = mu)),
    list(positions = state[, 1:3, drop = FALSE], velocities = state[, 4:6, drop = FALSE]),
    "RK4", T, T / N)
  states = cbind(matrix(trajectory$positions, N + 1, 3), matrix(trajectory$velocities, N + 1, 3))
  colnames(states) = c("x", "y", "z", "vx", "vy", "vz")
  list(t = trajectory$time, states = states, mu = mu)
}

cr3bp_rotating_to_inertial = function(result) {
  theta = result$t
  cos_theta = cos(theta)
  sin_theta = sin(theta)
  states = result$states
  mu = result$mu

  rotate_x = function(x, y) {
    x * cos_theta - y * sin_theta
  }
  rotate_y = function(x, y) {
    x * sin_theta + y * cos_theta
  }

  list(
    restricted = cbind(
      x = rotate_x(states[, "x"], states[, "y"]),
      y = rotate_y(states[, "x"], states[, "y"])
    ),
    primary_1 = cbind(
      x = rotate_x(rep(-mu, length(theta)), rep(0, length(theta))),
      y = rotate_y(rep(-mu, length(theta)), rep(0, length(theta)))
    ),
    primary_2 = cbind(
      x = rotate_x(rep(1 - mu, length(theta)), rep(0, length(theta))),
      y = rotate_y(rep(1 - mu, length(theta)), rep(0, length(theta)))
    )
  )
}

plot_cr3bp_result = function(result, filepath, title, show_lagrange_points = TRUE) {
  old_par = cd_open_png(filepath, width = 1200, height = 720, res = 140,
                        mar = c(4.8, 4.8, 3.2, 1.2), mfrow = c(1, 2))
  par(oma = c(0, 0, 2.5, 0))
  on.exit({
    cd_close_png(old_par)
  }, add = TRUE)

  states = result$states
  mu = result$mu
  primary_x = c(-mu, 1 - mu)
  lagrange_points = cr3bp_lagrange_points(mu)
  lagrange_x = sapply(lagrange_points, function(point) point[1])
  lagrange_y = sapply(lagrange_points, function(point) point[2])
  all_x = c(states[, "x"], primary_x, lagrange_x)
  all_y = c(states[, "y"], 0, 0, lagrange_y)
  xlim = cd_expand_range(all_x, 0.08, 0.04)
  ylim = cd_expand_range(all_y, 0.08, 0.04)
  cd_plot_empty(xlim, ylim,
                xlab = "x (primary separation units)",
                ylab = "y (primary separation units)",
                main = "Rotating frame", asp = 1)
  lines(states[, "x"], states[, "y"], lwd = 2.4,
        col = grDevices::adjustcolor(cd_colors$blue, 0.78))
  points(primary_x, c(0, 0), pch = 19,
         col = c(cd_colors$orange, cd_colors$gray), cex = c(2, 1.2))
  if (show_lagrange_points) {
    points(lagrange_x, lagrange_y, pch = 4, col = cd_colors$black, cex = 1.1,
           lwd = 1.4)
    text(lagrange_x, lagrange_y, labels = names(lagrange_points),
         pos = c(3, 3, 1, 3, 1), cex = 0.76, col = cd_colors$ink)
  }
  points(states[1, "x"], states[1, "y"], pch = 21, col = cd_colors$blue,
         bg = cd_colors$panel, cex = 1.4, lwd = 1.4)
  points(tail(states[, "x"], 1), tail(states[, "y"], 1),
         pch = 19, col = cd_colors$blue, cex = 1.2)
  legend("topleft", legend = c("Restricted body path", "Primary 1", "Primary 2",
           if (show_lagrange_points) "Lagrange points"),
         col = c(cd_colors$blue, cd_colors$orange, cd_colors$gray,
           if (show_lagrange_points) cd_colors$black),
         lty = c(1, NA, NA, if (show_lagrange_points) NA),
         pch = c(NA, 19, 19, if (show_lagrange_points) 4),
         bty = "n", cex = 0.82)

  inertial = cr3bp_rotating_to_inertial(result)
  all_ix = c(inertial$restricted[, "x"], inertial$primary_1[, "x"],
             inertial$primary_2[, "x"])
  all_iy = c(inertial$restricted[, "y"], inertial$primary_1[, "y"],
             inertial$primary_2[, "y"])
  ixlim = cd_expand_range(all_ix, 0.08, 0.04)
  iylim = cd_expand_range(all_iy, 0.08, 0.04)
  cd_plot_empty(ixlim, iylim,
                xlab = "x (primary separation units)",
                ylab = "y (primary separation units)",
                main = "Inertial frame", asp = 1)
  lines(inertial$restricted[, "x"], inertial$restricted[, "y"],
        lwd = 2.4, col = grDevices::adjustcolor(cd_colors$blue, 0.78))
  lines(inertial$primary_1[, "x"], inertial$primary_1[, "y"],
        lwd = 2.2, col = cd_colors$orange)
  lines(inertial$primary_2[, "x"], inertial$primary_2[, "y"],
        lwd = 2.2, col = cd_colors$gray)
  points(inertial$restricted[1, "x"], inertial$restricted[1, "y"],
         pch = 21, col = cd_colors$blue, bg = cd_colors$panel, cex = 1.2)
  points(inertial$primary_1[1, "x"], inertial$primary_1[1, "y"],
         pch = 21, col = cd_colors$orange, bg = cd_colors$panel, cex = 1.2)
  points(inertial$primary_2[1, "x"], inertial$primary_2[1, "y"],
         pch = 21, col = cd_colors$gray, bg = cd_colors$panel, cex = 1.2)
  points(tail(inertial$restricted[, "x"], 1),
         tail(inertial$restricted[, "y"], 1), pch = 19,
         col = cd_colors$blue, cex = 1.2)
  points(tail(inertial$primary_1[, "x"], 1),
         tail(inertial$primary_1[, "y"], 1), pch = 19,
         col = cd_colors$orange, cex = 1.2)
  points(tail(inertial$primary_2[, "x"], 1),
         tail(inertial$primary_2[, "y"], 1), pch = 19,
         col = cd_colors$gray, cex = 1.2)
  legend("topright",
         legend = c("Restricted body", "Primary 1", "Primary 2"),
         col = c(cd_colors$blue, cd_colors$orange, cd_colors$gray),
         lty = 1, lwd = 2, bty = "n", cex = 0.82)

  mtext(title, outer = TRUE, cex = 1.15, font = 2, col = cd_colors$ink)

  cat(sprintf("Plot saved to: %s\n", filepath))
  cd_record_plot_manifest(
    filepath = filepath,
    artifact_type = "png",
    plot_type = "restricted_three_body",
    title = title,
    width = 1200,
    height = 720,
    res = 140,
    xlim = ixlim,
    ylim = iylim,
    data_x = all_ix,
    data_y = all_iy
  )
}
