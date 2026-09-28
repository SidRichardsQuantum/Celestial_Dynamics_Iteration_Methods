# Presentation and process adapters; scientific calculations live in dynamics/.
studio_lyapunov_defaults = function(request) {
  problem = simulation_dynamics(request)
  list(components = cd_sensitivity_components(problem$state),
    position_scale = max(1, abs(problem$state$positions)),
    velocity_scale = max(1, abs(problem$state$velocities)),
    total_time = problem$duration,
    renormalisation_interval = min(10, round(problem$duration / problem$timestep)) * problem$timestep)
}

studio_start_lyapunov = function(arguments, root = cd_project_root()) {
  if (!requireNamespace("callr", quietly = TRUE)) stop("Install callr for background analysis.")
  callr::r_bg(function(root, arguments) {
    setwd(root)
    source(file.path(root, "R", "load.R"))
    cd_load_studio()
    do.call(run_lyapunov_analysis, arguments)
  }, args = list(root = root, arguments = arguments), supervise = TRUE)
}

studio_plot_lyapunov = function(analysis, view = c("separation", "log", "trajectories"), axes = c(1, 2)) {
  if (!inherits(analysis, "lyapunov_analysis")) stop("Expected a lyapunov_analysis.")
  view = match.arg(view)
  s = analysis$series; h = analysis$renormalisation_history
  colors = cd_palette(2)
  if (view == "log") {
    values = c(s$log_separation, s$cumulative_log_separation)
    cd_plot_empty(range(s$time), cd_expand_range(values), "Time (model units)",
      "Natural log of scaled separation", "Log separation and accumulated growth")
    graphics::lines(s$time, s$cumulative_log_separation, col = colors[1], lwd = 2)
    graphics::lines(s$time, s$log_separation, col = colors[2], lty = 2)
    graphics::legend("topleft", c("Accumulated: log(d0) + summed growth", "Measured nearby separation (pre-reset)"),
      col = colors, lty = c(1, 2), bty = "n", cex = 0.8)
  } else if (view == "separation") {
    values = c(s$separation, h$reset_separation[h$renormalised])
    cd_plot_empty(range(s$time), cd_expand_range(values),
      "Time (model units)", "Scaled phase-space separation", "Nearby separation with periodic resets")
    for (i in seq_len(nrow(h))) {
      rows = (h$start_step[i] + 2):(h$end_step[i] + 1)
      graphics::lines(c(h$start_time[i], s$time[rows]), c(h$start_separation[i], s$separation[rows]),
        col = colors[1], lwd = 1.7)
      if (h$renormalised[i]) graphics::segments(h$end_time[i], h$end_separation[i],
        h$end_time[i], h$reset_separation[i], col = colors[2], lty = 3)
    }
  } else {
    b = analysis$base$positions; p = analysis$perturbed$positions
    dimensions = dim(b)[3]; bodies = dim(b)[2]
    one_dimensional = dimensions == 1L
    if (!one_dimensional && (length(axes) != 2 || any(!axes %in% seq_len(dimensions)) || anyDuplicated(axes)))
      stop("Choose two distinct available coordinate axes.")
    scale = analysis$metadata$position_scale
    x = if (one_dimensional) s$time else c(b[, , axes[1]], p[, , axes[1]]) / scale
    y = if (one_dimensional) c(b, p) / scale else c(b[, , axes[2]], p[, , axes[2]]) / scale
    cd_plot_empty(cd_expand_range(x), cd_expand_range(y),
      if (one_dimensional) "Time (model units)" else paste("Coordinate", axes[1], "/ position scale"),
      if (one_dimensional) "Position / position scale" else paste("Coordinate", axes[2], "/ position scale"),
      paste("Base and periodically reset companion:", analysis$metadata$frame, "frame"))
    for (body in seq_len(bodies)) {
      graphics::lines(if (one_dimensional) s$time else b[, body, axes[1]] / scale,
        if (one_dimensional) b[, body, 1] / scale else b[, body, axes[2]] / scale, col = colors[1])
      for (i in seq_len(nrow(h))) {
        rows = (h$start_step[i] + 2):(h$end_step[i] + 1)
        initial = if (i == 1) analysis$perturbed$initial_state else analysis$restart_states[[i - 1]]
        px = if (one_dimensional) c(h$start_time[i], s$time[rows]) else
          c(initial$positions[body, axes[1]], p[rows, body, axes[1]]) / scale
        py = if (one_dimensional) c(initial$positions[body, 1], p[rows, body, 1]) / scale else
          c(initial$positions[body, axes[2]], p[rows, body, axes[2]]) / scale
        graphics::lines(px, py, col = colors[2], lty = 2)
      }
    }
    graphics::legend("topright", c("Base", "Perturbed (reset each interval)"), col = colors,
      lty = c(1, 2), bty = "n", cex = 0.8)
  }
  invisible(analysis)
}
