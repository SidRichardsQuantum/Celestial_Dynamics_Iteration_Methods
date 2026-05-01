if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/systems/plotting/plot_style.R")

plot_three_body_result = function(result, filepath, title, labels,
                                  colors = c("black", "blue", "red"),
                                  width = 1000, height = 760, res = 140,
                                  animation_path = sub("\\.png$", ".html",
                                                       filepath,
                                                       ignore.case = TRUE)) {
  if (length(labels) != 3 || length(colors) != 3) {
    stop("labels and colors must each contain exactly three values.")
  }

  old_par = cd_open_png(filepath, width = width, height = height, res = res)
  on.exit(cd_close_png(old_par), add = TRUE)

  x_a_au = result$x_a / AU
  y_a_au = result$y_a / AU
  x_b_au = result$x_b / AU
  y_b_au = result$y_b / AU
  x_c_au = result$x_c / AU
  y_c_au = result$y_c / AU

  all_x = c(x_a_au, x_b_au, x_c_au)
  all_y = c(y_a_au, y_b_au, y_c_au)
  masses = c(result$initial_conditions$m_a,
             result$initial_conditions$m_b,
             result$initial_conditions$m_c)
  body_cex = cd_body_cex(masses)
  center_x = (masses[1] * x_a_au + masses[2] * x_b_au +
                masses[3] * x_c_au) / sum(masses)
  center_y = (masses[1] * y_a_au + masses[2] * y_b_au +
                masses[3] * y_c_au) / sum(masses)

  xlim = cd_expand_range(all_x)
  ylim = cd_expand_range(all_y)
  cd_plot_empty(xlim, ylim,
                xlab = "x (AU)", ylab = "y (AU)", main = title, asp = 1)
  lines(center_x, center_y, col = grDevices::adjustcolor(cd_colors$gray, 0.7),
        lwd = 1.4, lty = "dashed")
  points(tail(center_x, 1), tail(center_y, 1), pch = 4,
         col = cd_colors$gray, cex = 1.0, lwd = 1.3)

  cd_draw_trajectory(x_a_au, y_a_au, colors[1], body_cex = body_cex[1])
  cd_draw_trajectory(x_b_au, y_b_au, colors[2], body_cex = body_cex[2])
  cd_draw_trajectory(x_c_au, y_c_au, colors[3], body_cex = body_cex[3])

  cd_add_external_legend(c(labels, "center of mass"),
                         c(colors, cd_colors$gray),
                         lty = c(1, 1, 1, 2),
                         lwd = c(rep(2.4, 3), 1.4),
                         pch = c(NA, NA, NA, 4))

  cat(sprintf("Plot saved to: %s\n", filepath))
  cd_record_plot_manifest(
    filepath = filepath,
    artifact_type = "png",
    plot_type = "three_body_orbit",
    title = title,
    width = width,
    height = height,
    res = res,
    xlim = xlim,
    ylim = ylim,
    data_x = all_x,
    data_y = all_y,
    energy_ratio = result$energy_ratio
  )

  if (!is.null(animation_path) && nzchar(animation_path)) {
    cd_write_trajectory_animation(
      animation_path,
      title = title,
      units = "AU",
      series = list(
        list(label = labels[1], color = colors[1], cex = body_cex[1],
             x = x_a_au, y = y_a_au),
        list(label = labels[2], color = colors[2], cex = body_cex[2],
             x = x_b_au, y = y_b_au),
        list(label = labels[3], color = colors[3], cex = body_cex[3],
             x = x_c_au, y = y_c_au)
      )
    )
    cat(sprintf("Animation saved to: %s\n", animation_path))
  }
}
