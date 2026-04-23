cr3bp_lagrange_points = function(mu) {
  if (!is.finite(mu) || mu <= 0 || mu >= 0.5) {
    stop("mu must be finite and in the interval (0, 0.5).")
  }

  collinear_equation = function(x) {
    r1 = abs(x + mu)
    r2 = abs(x - 1 + mu)
    x - (1 - mu) * (x + mu) / r1^3 - mu * (x - 1 + mu) / r2^3
  }

  list(
    L1 = c(uniroot(collinear_equation, c(0.01, 1 - mu - 0.01))$root, 0),
    L2 = c(uniroot(collinear_equation, c(1 - mu + 0.01, 2))$root, 0),
    L3 = c(uniroot(collinear_equation, c(-2, -mu - 0.01))$root, 0),
    L4 = c(0.5 - mu, sqrt(3) / 2),
    L5 = c(0.5 - mu, -sqrt(3) / 2)
  )
}

cr3bp_derivative = function(state, mu) {
  x = state[1]
  y = state[2]
  z = state[3]
  vx = state[4]
  vy = state[5]
  vz = state[6]

  r1 = sqrt((x + mu)^2 + y^2 + z^2)
  r2 = sqrt((x - 1 + mu)^2 + y^2 + z^2)

  c(
    vx,
    vy,
    vz,
    2 * vy + x - (1 - mu) * (x + mu) / r1^3 -
      mu * (x - 1 + mu) / r2^3,
    -2 * vx + y - (1 - mu) * y / r1^3 - mu * y / r2^3,
    -(1 - mu) * z / r1^3 - mu * z / r2^3
  )
}

cr3bp_runge_kutta = function(T, N, mu, state0) {
  if (!is.finite(T) || T <= 0) {
    stop("T must be a positive finite value.")
  }
  if (!is.finite(N) || N <= 0 || N != as.integer(N)) {
    stop("N must be a positive integer.")
  }
  if (length(state0) != 6 || any(!is.finite(state0))) {
    stop("state0 must contain six finite values: x, y, z, vx, vy, vz.")
  }

  dt = T / N
  state = state0
  states = matrix(0, nrow = N + 1, ncol = 6)
  states[1, ] = state

  for (i in 1:N) {
    k1 = cr3bp_derivative(state, mu)
    k2 = cr3bp_derivative(state + 0.5 * dt * k1, mu)
    k3 = cr3bp_derivative(state + 0.5 * dt * k2, mu)
    k4 = cr3bp_derivative(state + dt * k3, mu)
    state = state + (dt / 6) * (k1 + 2 * k2 + 2 * k3 + k4)
    states[i + 1, ] = state
  }

  colnames(states) = c("x", "y", "z", "vx", "vy", "vz")
  return(list(t = seq(0, T, length.out = N + 1), states = states, mu = mu))
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

  states = result$states
  mu = result$mu
  primary_x = c(-mu, 1 - mu)
  lagrange_points = cr3bp_lagrange_points(mu)
  lagrange_x = sapply(lagrange_points, function(point) point[1])
  lagrange_y = sapply(lagrange_points, function(point) point[2])
  all_x = c(states[, "x"], primary_x, lagrange_x)
  all_y = c(states[, "y"], 0, 0, lagrange_y)
  x_padding = max(diff(range(all_x)) * 0.08, 0.04)
  y_padding = max(diff(range(all_y)) * 0.08, 0.04)

  plot(states[, "x"], states[, "y"], type = "l", lwd = 2, col = "blue",
       xlim = range(all_x) + c(-x_padding, x_padding),
       ylim = range(all_y) + c(-y_padding, y_padding),
       xlab = "x (primary separation units)",
       ylab = "y (primary separation units)",
       main = "Rotating frame", asp = 1)
  points(primary_x, c(0, 0), pch = 19,
         col = c("orange", "gray40"), cex = c(2, 1.2))
  if (show_lagrange_points) {
    points(lagrange_x, lagrange_y, pch = 4, col = "black", cex = 1.1,
           lwd = 1.4)
    text(lagrange_x, lagrange_y, labels = names(lagrange_points),
         pos = c(3, 3, 1, 3, 1), cex = 0.8)
  }
  points(states[1, "x"], states[1, "y"], pch = 1, col = "blue", cex = 1.4)
  points(tail(states[, "x"], 1), tail(states[, "y"], 1),
         pch = 19, col = "blue", cex = 1.2)
  legend("topright", legend = c("Restricted body path", "Lagrange points"),
         col = c("blue", "black"), lty = c(1, NA), pch = c(NA, 4),
         lwd = c(2, NA))
  grid(col = "lightgray", lty = "dotted")

  inertial = cr3bp_rotating_to_inertial(result)
  all_ix = c(inertial$restricted[, "x"], inertial$primary_1[, "x"],
             inertial$primary_2[, "x"])
  all_iy = c(inertial$restricted[, "y"], inertial$primary_1[, "y"],
             inertial$primary_2[, "y"])
  ix_padding = max(diff(range(all_ix)) * 0.08, 0.04)
  iy_padding = max(diff(range(all_iy)) * 0.08, 0.04)

  plot(inertial$restricted[, "x"], inertial$restricted[, "y"],
       type = "l", lwd = 2, col = "blue",
       xlim = range(all_ix) + c(-ix_padding, ix_padding),
       ylim = range(all_iy) + c(-iy_padding, iy_padding),
       xlab = "x (primary separation units)",
       ylab = "y (primary separation units)",
       main = title, asp = 1)
  lines(inertial$primary_1[, "x"], inertial$primary_1[, "y"],
        lwd = 2, col = "orange")
  lines(inertial$primary_2[, "x"], inertial$primary_2[, "y"],
        lwd = 2, col = "gray40")
  points(inertial$restricted[1, "x"], inertial$restricted[1, "y"],
         pch = 21, col = "blue", bg = "white", cex = 1.2)
  points(inertial$primary_1[1, "x"], inertial$primary_1[1, "y"],
         pch = 21, col = "orange", bg = "white", cex = 1.2)
  points(inertial$primary_2[1, "x"], inertial$primary_2[1, "y"],
         pch = 21, col = "gray40", bg = "white", cex = 1.2)
  points(tail(inertial$restricted[, "x"], 1),
         tail(inertial$restricted[, "y"], 1), pch = 19,
         col = "blue", cex = 1.2)
  points(tail(inertial$primary_1[, "x"], 1),
         tail(inertial$primary_1[, "y"], 1), pch = 19,
         col = "orange", cex = 1.2)
  points(tail(inertial$primary_2[, "x"], 1),
         tail(inertial$primary_2[, "y"], 1), pch = 19,
         col = "gray40", cex = 1.2)
  legend("topright",
         legend = c("Restricted body", "Primary 1", "Primary 2"),
         col = c("blue", "orange", "gray40"), lty = 1, lwd = 2)
  grid(col = "lightgray", lty = "dotted")

  cat(sprintf("Plot saved to: %s\n", filepath))
}
