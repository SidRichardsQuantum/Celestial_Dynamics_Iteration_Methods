# Device-independent plots reuse the repository's styling and drawing helpers.
# Prescribed primaries are display context, never added to particle diagnostics.
studio_display_state = function(result, frame = "native") {
  frame = match.arg(frame, c("native", "inertial"))
  if (result$request$system != "restricted_three_body") {
    return(list(positions = result$positions, body_names = result$body_names))
  }
  n = length(result$time)
  mu = result$request$parameters$mu
  positions = array(0, c(n, 3, 3))
  positions[, 1, 1] = -mu
  positions[, 2, 1] = 1 - mu
  positions[, 3, ] = result$positions[, 1, ]
  if (frame == "inertial") {
    inertial = cr3bp_rotating_to_inertial(result$raw)
    positions[, 1, 1:2] = inertial$primary_1
    positions[, 2, 1:2] = inertial$primary_2
    positions[, 3, 1:2] = inertial$restricted
  }
  names = result$request$parameters$primary_names
  if (is.null(names)) names = c("Primary 1", "Primary 2")
  list(positions = positions, body_names = c(names, "Test particle"))
}

studio_plot_trajectories = function(results, axes = c(1L, 2L), frame = "native") {
  if (inherits(results, "simulation_result")) results = list(results)
  if (length(axes) != 2 || any(!axes %in% seq_len(dim(results[[1]]$positions)[3]))) {
    stop("Choose two available coordinate axes.")
  }
  if (length(results) > 1L) studio_comparison(results)
  scale = if (results[[1]]$request$system == "restricted_three_body") 1 else AU
  unit = if (scale == 1) "normalized" else "AU"
  displays = lapply(results, studio_display_state, frame = frame)
  x = unlist(lapply(displays, function(r) r$positions[, , axes[1]] / scale))
  y = unlist(lapply(displays, function(r) r$positions[, , axes[2]] / scale))
  cd_plot_empty(cd_expand_range(x), cd_expand_range(y),
    paste0(c("x", "y", "z")[axes[1]], " (", unit, ")"),
    paste0(c("x", "y", "z")[axes[2]], " (", unit, ")"), "Trajectories", asp = 1)
  colors = cd_palette(dim(displays[[1]]$positions)[2])
  labels = character()
  for (j in seq_along(results)) {
    r = displays[[j]]
    for (body in seq_len(dim(r$positions)[2])) {
      graphics::lines(r$positions[, body, axes[1]] / scale,
                      r$positions[, body, axes[2]] / scale,
                      col = colors[body], lty = j, lwd = 1.5)
      graphics::points(tail(r$positions[, body, axes[1]], 1) / scale,
                       tail(r$positions[, body, axes[2]], 1) / scale,
                       col = colors[body], pch = 19)
      labels = c(labels, paste(if (!is.null(names(results))) names(results)[j] else results[[j]]$request$integrator, r$body_names[body]))
    }
  }
  graphics::legend("topright", legend = labels, col = rep(colors, length(results)),
                   lty = rep(seq_along(results), each = length(colors)), cex = 0.75, bty = "n")
}

studio_plot_diagnostic = function(results, diagnostic) {
  if (inherits(results, "simulation_result")) results = list(results)
  if (!all(vapply(results, function(r) diagnostic %in% names(r$diagnostics), logical(1)))) {
    stop("Diagnostic is not applicable to these results.")
  }
  if (length(results) > 1L) studio_comparison(results)
  values = unlist(lapply(results, function(r) r$diagnostics[[diagnostic]]))
  if (!any(is.finite(values))) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "Relative drift is undefined for a zero initial invariant.\nSelect the absolute invariant instead.")
    return(invisible(NULL))
  }
  cd_plot_empty(range(results[[1]]$time), cd_expand_range(values[is.finite(values)]),
                "Time (system time units)", diagnostic, diagnostic)
  colors = cd_palette(length(results))
  for (j in seq_along(results)) {
    graphics::lines(results[[j]]$time, results[[j]]$diagnostics[[diagnostic]],
                    col = colors[j], lwd = 1.7)
  }
  graphics::legend("topright", legend = if (!is.null(names(results))) names(results) else vapply(results, function(r) r$request$integrator,
                                               character(1)), col = colors, lty = 1, bty = "n")
}

studio_plot_3d = function(result, azimuth = 35, elevation = 25, frame = "native") {
  if (dim(result$positions)[3] != 3) stop("3D visualization requires spatial states.")
  # Orthographic camera rotation preserves the real spatial trajectory.
  a = azimuth * pi / 180
  e = elevation * pi / 180
  scale = if (result$request$system == "restricted_three_body") 1 else AU
  unit = if (scale == 1) "normalized" else "AU"
  display = studio_display_state(result, frame)
  p = display$positions / scale
  x = p[, , 1] * cos(a) - p[, , 2] * sin(a)
  y = -(p[, , 1] * sin(a) + p[, , 2] * cos(a)) * sin(e) + p[, , 3] * cos(e)
  x = matrix(x, nrow = length(result$time))
  y = matrix(y, nrow = length(result$time))
  cd_plot_empty(cd_expand_range(x), cd_expand_range(y), paste("Camera horizontal (", unit, ")"),
                paste("Camera vertical (", unit, ")"), "3D trajectory: orthographic view", asp = 1)
  colors = cd_palette(ncol(x))
  for (i in seq_len(ncol(x))) cd_draw_trajectory(x[, i], y[, i], colors[i])
  graphics::legend("topright", legend = display$body_names, col = colors, lty = 1, bty = "n")
}

studio_animation = function(result, path, axes = NULL, frame = "auto") {
  frame = match.arg(frame, c("auto", "native", "inertial"))
  restricted = result$request$system == "restricted_three_body"
  if (frame == "auto") frame = if (restricted) "inertial" else "native"
  if (is.null(axes)) axes = if (result$request$system == "sitnikov") c(1L, 3L) else c(1L, 2L)
  if (length(axes) != 2 || any(!axes %in% seq_len(dim(result$positions)[3]))) {
    stop("Choose two available coordinate axes.")
  }
  scale = if (restricted) 1 else AU
  display = studio_display_state(result, frame)
  colors = cd_palette(dim(display$positions)[2])
  series = lapply(seq_len(dim(display$positions)[2]), function(i) {
    list(label = display$body_names[i], color = colors[i], cex = 1.3,
         x = display$positions[, i, axes[1]] / scale,
         y = display$positions[, i, axes[2]] / scale)
  })
  title = if (restricted) paste("CR3BP", if (frame == "native") "rotating frame" else "inertial frame") else
    "Celestial Dynamics Studio"
  cd_write_trajectory_animation(path, title, series,
    units = paste(if (scale == 1) "normalized" else "AU",
                  paste(c("x", "y", "z")[axes], collapse = "-")),
    record_manifest = FALSE, compact = TRUE, times = result$time,
    time_units = if (restricted) "normalized time" else "s")
  invisible(path)
}
