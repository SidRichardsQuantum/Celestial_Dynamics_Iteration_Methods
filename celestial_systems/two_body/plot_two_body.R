source("constants.R")

plot_two_body_result = function(result, filepath, title, labels, colors,
                                x_label = "x (AU)", y_label = "y (AU)",
                                width = 800, height = 600, res = 100) {
  if (length(labels) != 2 || length(colors) != 2) {
    stop("labels and colors must each contain exactly two values.")
  }

  output_dir = dirname(filepath)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  png(filepath, width = width, height = height, res = res)
  on.exit(dev.off(), add = TRUE)

  x_a_au = result$x_a / AU
  y_a_au = result$y_a / AU
  x_b_au = result$x_b / AU
  y_b_au = result$y_b / AU
  all_x = c(x_a_au, x_b_au)
  all_y = c(y_a_au, y_b_au)
  x_padding = max(diff(range(all_x)) * 0.08, 0.02)
  y_padding = max(diff(range(all_y)) * 0.08, 0.02)

  plot(x_b_au, y_b_au, type = "l", col = colors[2], lwd = 2,
       xlim = range(all_x) + c(-x_padding, x_padding),
       ylim = range(all_y) + c(-y_padding, y_padding),
       xlab = x_label, ylab = y_label, main = title)
  lines(x_a_au, y_a_au, col = colors[1], lwd = 2)

  points(x_a_au[1], y_a_au[1], pch = 21, col = colors[1],
         bg = "white", cex = 1.4, lwd = 1.5)
  points(x_b_au[1], y_b_au[1], pch = 21, col = colors[2],
         bg = "white", cex = 1.4, lwd = 1.5)
  points(tail(x_a_au, 1), tail(y_a_au, 1),
         pch = 19, col = colors[1], cex = 1.5)
  points(tail(x_b_au, 1), tail(y_b_au, 1),
         pch = 19, col = colors[2], cex = 1.5)

  legend("topright", legend = labels,
         lty = rep("solid", 2), col = colors, lwd = rep(2, 2))
  grid(col = "lightgray", lty = "dotted")

  cat(sprintf("Plot saved to: %s\n", filepath))
}
