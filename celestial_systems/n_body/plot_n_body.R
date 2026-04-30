source("constants.R")

plot_n_body_result = function(result, filepath, title,
                              colors = NULL,
                              x_label = "x (AU)", y_label = "y (AU)",
                              width = 900, height = 700, res = 120) {
  output_dir = dirname(filepath)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  body_count = length(result$masses)
  if (is.null(colors)) {
    colors = grDevices::rainbow(body_count)
  }
  if (length(colors) != body_count) {
    stop("colors must contain one value per body.")
  }

  x = result$positions[, , 1] / AU
  y = result$positions[, , 2] / AU

  png(filepath, width = width, height = height, res = res)
  on.exit(dev.off(), add = TRUE)

  x_padding = max(diff(range(x)) * 0.08, 0.02)
  y_padding = max(diff(range(y)) * 0.08, 0.02)
  plot(NULL,
       xlim = range(x) + c(-x_padding, x_padding),
       ylim = range(y) + c(-y_padding, y_padding),
       xlab = x_label,
       ylab = y_label,
       main = title,
       asp = 1)

  for (body_index in seq_len(body_count)) {
    lines(x[, body_index], y[, body_index],
          col = colors[body_index], lwd = 2)
    points(x[1, body_index], y[1, body_index],
           pch = 21, col = colors[body_index], bg = "white",
           cex = 1.2, lwd = 1.4)
    points(tail(x[, body_index], 1), tail(y[, body_index], 1),
           pch = 19, col = colors[body_index], cex = 1.2)
  }

  legend("topright", legend = result$body_names,
         col = colors, lty = rep(1, body_count), lwd = rep(2, body_count),
         bg = "white")
  grid(col = "lightgray", lty = "dotted")

  cat(sprintf("Plot saved to: %s\n", filepath))
}
