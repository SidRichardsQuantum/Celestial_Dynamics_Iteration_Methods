if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/systems/two_body/two_body_helpers.R")
cd_source("R/systems/plotting/plot_style.R")

plot_two_body_result = function(result, filepath, title, labels, colors,
                                x_label = "x (AU)", y_label = "y (AU)",
                                width = 1000, height = 760, res = 140,
                                animation_path = sub("\\.png$", ".html",
                                                     filepath,
                                                     ignore.case = TRUE)) {
  if (length(labels) != 2 || length(colors) != 2) {
    stop("labels and colors must each contain exactly two values.")
  }

  old_par = cd_open_png(filepath, width = width, height = height, res = res)
  on.exit(cd_close_png(old_par), add = TRUE)

  x_a_au = result$x_a / AU
  y_a_au = result$y_a / AU
  x_b_au = result$x_b / AU
  y_b_au = result$y_b / AU
  all_x = c(x_a_au, x_b_au)
  all_y = c(y_a_au, y_b_au)
  masses = c(result$initial_conditions$m_a, result$initial_conditions$m_b)
  body_cex = cd_body_cex(masses)
  center_x = (masses[1] * x_a_au + masses[2] * x_b_au) / sum(masses)
  center_y = (masses[1] * y_a_au + masses[2] * y_b_au) / sum(masses)

  xlim = cd_expand_range(all_x)
  ylim = cd_expand_range(all_y)
  cd_plot_empty(xlim, ylim,
                xlab = x_label, ylab = y_label, main = title, asp = 1)
  lines(center_x, center_y, col = grDevices::adjustcolor(cd_colors$gray, 0.72),
        lwd = 1.4, lty = "dashed")
  points(tail(center_x, 1), tail(center_y, 1), pch = 4, col = cd_colors$gray,
         cex = 1.0, lwd = 1.3)

  cd_draw_trajectory(x_a_au, y_a_au, colors[1], body_cex = body_cex[1])
  cd_draw_trajectory(x_b_au, y_b_au, colors[2], body_cex = body_cex[2])

  cd_add_external_legend(c(labels, "center of mass"),
                         c(colors, cd_colors$gray),
                         lty = c(1, 1, 2),
                         lwd = c(2.4, 2.4, 1.4),
                         pch = c(NA, NA, 4))

  energy = two_body_energy_series(result)
  angular_momentum = two_body_angular_momentum_series(result)
  final_separation_au =
    sqrt((tail(result$x_a, 1) - tail(result$x_b, 1))^2 +
           (tail(result$y_a, 1) - tail(result$y_b, 1))^2) / AU
  cd_add_external_diagnostics(
    cd_diagnostic_lines(energy, angular_momentum,
                        "final separation", final_separation_au)
  )

  cat(sprintf("Plot saved to: %s\n", filepath))
  cd_record_plot_manifest(
    filepath = filepath,
    artifact_type = "png",
    plot_type = "two_body_orbit",
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
             x = x_b_au, y = y_b_au)
      )
    )
    cat(sprintf("Animation saved to: %s\n", animation_path))
  }
}
