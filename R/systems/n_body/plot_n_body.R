if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/systems/plotting/plot_style.R")

plot_n_body_result = function(result, filepath, title,
                              colors = NULL,
                              x_label = "x (AU)", y_label = "y (AU)",
                              width = 1050, height = 780, res = 140,
                              animation_path = sub("\\.png$", ".html",
                                                   filepath,
                                                   ignore.case = TRUE)) {
  body_count = length(result$masses)
  if (is.null(colors)) {
    colors = cd_palette(body_count)
  }
  if (length(colors) != body_count) {
    stop("colors must contain one value per body.")
  }

  x = result$positions[, , 1] / AU
  y = result$positions[, , 2] / AU
  body_cex = cd_body_cex(result$masses, min_cex = 1.0, max_cex = 2.3)

  old_par = cd_open_png(filepath, width = width, height = height, res = res)
  on.exit(cd_close_png(old_par), add = TRUE)

  center_x = as.vector(x %*% result$masses) / sum(result$masses)
  center_y = as.vector(y %*% result$masses) / sum(result$masses)

  xlim = cd_expand_range(x)
  ylim = cd_expand_range(y)
  cd_plot_empty(xlim, ylim,
                xlab = x_label, ylab = y_label, main = title, asp = 1)
  lines(center_x, center_y, col = grDevices::adjustcolor(cd_colors$gray, 0.7),
        lwd = 1.4, lty = "dashed")
  points(tail(center_x, 1), tail(center_y, 1), pch = 4,
         col = cd_colors$gray, cex = 1.0, lwd = 1.3)

  for (body_index in seq_len(body_count)) {
    cd_draw_trajectory(x[, body_index], y[, body_index],
                       colors[body_index],
                       body_cex = body_cex[body_index])
  }

  cd_add_external_legend(c(result$body_names, "center of mass"),
                         c(colors, cd_colors$gray),
                         lty = c(rep(1, body_count), 2),
                         lwd = c(rep(2.4, body_count), 1.4),
                         pch = c(rep(NA, body_count), 4))

  cat(sprintf("Plot saved to: %s\n", filepath))
  cd_record_plot_manifest(
    filepath = filepath,
    artifact_type = "png",
    plot_type = "n_body_orbit",
    title = title,
    width = width,
    height = height,
    res = res,
    xlim = xlim,
    ylim = ylim,
    data_x = as.vector(x),
    data_y = as.vector(y),
    method = result$method,
    dt_days = result$dt / DAY,
    energy_ratio = result$energy_ratio
  )

  if (!is.null(animation_path) && nzchar(animation_path)) {
    series = lapply(seq_len(body_count), function(body_index) {
      list(label = result$body_names[body_index],
           color = colors[body_index],
           cex = body_cex[body_index],
           x = x[, body_index],
           y = y[, body_index])
    })
    cd_write_trajectory_animation(animation_path, title = title, units = "AU",
                                  series = series)
    cat(sprintf("Animation saved to: %s\n", animation_path))
  }
}
