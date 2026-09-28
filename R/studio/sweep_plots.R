# Plot coordinates are actual parameter values; failed/unavailable cells stay blank.
studio_sweep_values = function(mode, text = "", from = NULL, to = NULL, count = NULL) {
  if (!is.character(mode) || length(mode) != 1L || is.na(mode) || !mode %in% c("values", "linear", "log"))
    stop("Choose explicit values, a linear range or a logarithmic range.")
  if (identical(mode, "values")) {
    if (!is.character(text) || length(text) != 1L || is.na(text) || !nzchar(trimws(text))) stop("Enter parameter values.")
    tokens = strsplit(trimws(text), "[,[:space:]]+")[[1]]
    if (!length(tokens) || length(tokens) > 256) stop("Supply 1 to 256 values per parameter.")
    values = suppressWarnings(as.numeric(tokens))
  } else {
    if (!mode %in% c("linear", "log")) stop("Choose explicit values, a linear range or a logarithmic range.")
    for (value in list(from, to)) cd_model_scalar(value, "range endpoint", positive = FALSE)
    if (!is.numeric(count) || length(count) != 1L || !is.finite(count) ||
        count != floor(count) || count < 1 || count > 256) stop("Range count must be an integer from 1 to 256.")
    if (mode == "log" && (from <= 0 || to <= 0)) stop("Logarithmic ranges require positive endpoints.")
    values = if (mode == "log") exp(seq(log(from), log(to), length.out = count)) else seq(from, to, length.out = count)
    # Preserve the requested endpoints exactly instead of exp(log(x)) roundoff.
    values[1] = from
    if (count > 1) values[count] = to
  }
  if (any(!is.finite(values)) || anyDuplicated(values)) stop("Sweep values must be distinct finite numbers.")
  values
}

studio_plot_sweep = function(sweep, metric = sweep$metrics[1]) {
  if (!inherits(sweep, "parameter_sweep") || !metric %in% sweep$metrics) stop("Select a metric from this sweep.")
  grid = sweep$grid; values = sweep$scalar_metrics[[metric]]
  old = graphics::par(mar = c(5.1, 5.5, 4.1, if (ncol(grid) == 2) 6.5 else 2.1))
  on.exit(graphics::par(old))
  registry = sweep$metric_registry[match(metric, sweep$metric_registry$metric), ]
  title = paste0(registry$label, " [", registry$units, "]")
  colors = cd_palette(2)
  if (ncol(grid) == 1) {
    order = order(grid[[1]])
    finite = is.finite(values)
    ylim = if (any(finite)) cd_expand_range(values[finite]) else c(0, 1)
    cd_plot_empty(cd_expand_range(grid[[1]]), ylim, names(grid)[1], title, "Parameter sweep")
    # NA leaves a gap; never bridge a failed point with an interpolated line.
    graphics::lines(grid[[1]][order], values[order], col = colors[1], type = "b", pch = 19)
    if (any(!finite)) graphics::rug(grid[[1]][!finite], col = colors[2], ticksize = 0.04)
    if (!any(finite)) graphics::text(mean(range(grid[[1]])), 0.5, "No finite metric values; inspect point status.")
  } else {
    x = sort(unique(grid[[1]])); y = sort(unique(grid[[2]]))
    # Explicit cell boundaries also support singleton axes and irregular spacing.
    bounds = function(v) {
      if (length(v) == 1) return(cd_expand_range(v))
      mids = v[-length(v)] / 2 + v[-1] / 2
      c(v[1] - (mids[1] - v[1]), mids, tail(v, 1) + (tail(v, 1) - tail(mids, 1)))
    }
    xb = bounds(x); yb = bounds(y)
    cd_plot_empty(range(xb), range(yb), names(grid)[1], names(grid)[2], title)
    finite = is.finite(values)
    palette = grDevices::hcl.colors(32, "Viridis")
    limits = if (any(finite)) range(values[finite]) else c(0, 1)
    span = diff(limits)
    index = rep(NA_integer_, length(values))
    index[finite] = if (span == 0) 16L else pmax(1, pmin(32, 1 + floor(31 * (values[finite] - limits[1]) / span)))
    for (i in seq_len(nrow(grid))) {
      xi = match(grid[[1]][i], x); yi = match(grid[[2]][i], y)
      graphics::rect(xb[xi], yb[yi], xb[xi + 1], yb[yi + 1],
        col = if (finite[i]) palette[index[i]] else "#404854", border = "#18202b")
      if (!finite[i]) graphics::points(grid[[1]][i], grid[[2]][i], pch = 4, col = "white")
    }
    if (any(finite)) {
      bounds = graphics::par("usr")
      graphics::legend(bounds[2] + 0.02 * (bounds[2] - bounds[1]), bounds[4],
        legend = format(if (span == 0) limits[1] else seq(limits[1], limits[2], length.out = 5), digits = 3),
        fill = if (span == 0) palette[16] else palette[round(seq(1, 32, length.out = 5))],
        bty = "n", cex = 0.8, xpd = NA, xjust = 0, yjust = 1)
    }
  }
  invisible(sweep)
}

studio_sweep_point = function(sweep, x, y = NULL) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) stop("Select a plot coordinate.")
  normalized_distance = function(values, target) {
    span = diff(range(values))
    if (span == 0) rep(0, length(values)) else (values - target) / span
  }
  distance = normalized_distance(sweep$grid[[1]], x)^2
  if (ncol(sweep$grid) == 2) {
    if (!is.numeric(y) || length(y) != 1L || !is.finite(y)) stop("Select both plot coordinates.")
    distance = distance + normalized_distance(sweep$grid[[2]], y)^2
  }
  which.min(distance)
}
