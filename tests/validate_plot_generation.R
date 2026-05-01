required_plots = c(
  file.path("images", "projectile", "euler_trajectory.png"),
  file.path("images", "projectile", "heun_trajectory.png"),
  file.path("images", "projectile", "midpoint_trajectory.png"),
  file.path("images", "comparisons", "sun_earth_all_methods.png"),
  file.path("images", "comparisons", "sun_earth_energy_error_all_methods.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_euler.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_midpoint.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_heuns.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_runge_kutta.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_velocity_verlet.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_euler.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_midpoint.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_heuns.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_runge_kutta.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_velocity_verlet.png"),
  file.path("images", "n_body", "sun_earth_mars_jupiter.png"),
  file.path("images", "n_body", "special_solutions", "rotating_square_four_body.png"),
  file.path("images", "n_body", "special_solutions", "triangular_central_four_body.png"),
  file.path("images", "three_body", "general", "earth_mars_sun.png"),
  file.path("images", "three_body", "general", "earth_moon_spacecraft.png"),
  file.path("images", "three_body", "general", "binary_distant_third.png"),
  file.path("images", "three_body", "special_solutions", "three_earths.png"),
  file.path("images", "three_body", "special_solutions", "lagrange_three_earths.png"),
  file.path("images", "three_body", "special_solutions", "euler_collinear_three_earths.png"),
  file.path("images", "three_body", "special_solutions", "butterfly_choreography.png"),
  file.path("images", "three_body", "perturbations", "perturbed_figure_8.png"),
  file.path("images", "three_body", "perturbations", "perturbed_lagrange_three_earths.png"),
  file.path("images", "three_body", "restricted", "restricted_earth_moon_trojan.png"),
  file.path("images", "three_body", "restricted", "lyapunov_near_l1.png"),
  file.path("images", "three_body", "restricted", "sitnikov_three_body.png"),
  file.path("images", "analysis", "sun_earth_energy_error.png"),
  file.path("images", "analysis", "sun_earth_angular_momentum_drift.png"),
  file.path("images", "analysis", "convergence_rates.png")
)

read_png_dimensions = function(path) {
  connection = file(path, "rb")
  on.exit(close(connection), add = TRUE)
  signature = readBin(connection, "raw", n = 8)
  expected_signature = as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))
  if (!identical(signature, expected_signature)) {
    stop(sprintf("Not a valid PNG file: %s", path))
  }

  readBin(connection, "raw", n = 8)
  width = readBin(connection, "integer", n = 1, size = 4, endian = "big")
  height = readBin(connection, "integer", n = 1, size = 4, endian = "big")
  c(width = width, height = height)
}

missing_plots = required_plots[!file.exists(required_plots)]
if (length(missing_plots) > 0) {
  stop(sprintf("Missing generated plots:\n%s", paste(missing_plots, collapse = "\n")))
}

for (plot_path in required_plots) {
  plot_info = file.info(plot_path)
  if (!is.finite(plot_info$size) || plot_info$size < 10000) {
    stop(sprintf("Generated plot is unexpectedly small: %s", plot_path))
  }

  dimensions = read_png_dimensions(plot_path)
  if (dimensions["width"] < 700 || dimensions["height"] < 500) {
    stop(sprintf("Generated plot dimensions are too small: %s (%dx%d)",
                 plot_path, dimensions["width"], dimensions["height"]))
  }
}

cat("Plot generation validation passed.\n")

required_animation_artifacts = c(
  file.path("images", "two_body", "sun_earth", "sun_earth_runge_kutta.html"),
  file.path("images", "three_body", "special_solutions", "three_earths.html"),
  file.path("images", "n_body", "sun_earth_mars_jupiter.html")
)

missing_animation_artifacts =
  required_animation_artifacts[!file.exists(required_animation_artifacts)]
if (length(missing_animation_artifacts) > 0) {
  stop(sprintf("Missing generated animation artifacts:\n%s",
               paste(missing_animation_artifacts, collapse = "\n")))
}

for (animation_path in required_animation_artifacts) {
  animation_html = paste(readLines(animation_path, warn = FALSE), collapse = "\n")
  if (!grepl("<canvas", animation_html, fixed = TRUE) ||
      !grepl("requestAnimationFrame", animation_html, fixed = TRUE)) {
    stop(sprintf("Animation artifact does not contain an interactive canvas: %s",
                 animation_path))
  }
}

cat("Animation artifact validation passed.\n")

required_analysis_artifacts = c(
  file.path("analysis", "generated", "method_summary.csv"),
  file.path("analysis", "generated", "convergence_summary.csv"),
  file.path("analysis", "generated", "earth_moon_method_summary.csv"),
  file.path("analysis", "generated", "three_body_special_summary.csv"),
  file.path("analysis", "generated", "n_body_conservation_summary.csv"),
  file.path("analysis", "generated", "runtime_benchmark.csv"),
  file.path("analysis", "generated", "plot_manifest.csv"),
  file.path("analysis", "generated", "artifact_baseline.csv"),
  file.path("analysis", "generated", "artifact_index.html"),
  file.path("analysis", "generated", "index.html"),
  file.path("analysis", "generated", "method_comparison_dashboard.html")
)

missing_analysis_artifacts =
  required_analysis_artifacts[!file.exists(required_analysis_artifacts)]
if (length(missing_analysis_artifacts) > 0) {
  stop(sprintf("Missing generated analysis artifacts:\n%s",
               paste(missing_analysis_artifacts, collapse = "\n")))
}

cat("Generated analysis artifact validation passed.\n")

manifest_path = file.path("analysis", "generated", "plot_manifest.csv")
plot_manifest = read.csv(manifest_path, stringsAsFactors = FALSE)
missing_manifest_rows =
  required_plots[!required_plots %in% plot_manifest$filepath]
if (length(missing_manifest_rows) > 0) {
  stop(sprintf("Plot manifest is missing required plot rows:\n%s",
               paste(missing_manifest_rows, collapse = "\n")))
}

required_manifest_columns = c("filepath", "plot_type", "x_margin_ratio",
                              "y_margin_ratio", "width", "height")
missing_manifest_columns =
  required_manifest_columns[!required_manifest_columns %in% names(plot_manifest)]
if (length(missing_manifest_columns) > 0) {
  stop(sprintf("Plot manifest is missing columns: %s",
               paste(missing_manifest_columns, collapse = ", ")))
}

orbit_rows = grepl("orbit$", plot_manifest$plot_type) &
  plot_manifest$artifact_type == "png"
wide_margin_rows = plot_manifest[
  orbit_rows &
    (plot_manifest$x_margin_ratio > 0.55 |
       plot_manifest$y_margin_ratio > 0.55),
]
if (nrow(wide_margin_rows) > 0) {
  stop(sprintf("Orbit plots have excessive empty margins:\n%s",
               paste(wide_margin_rows$filepath, collapse = "\n")))
}

cat("Plot quality manifest validation passed.\n")

baseline_path = file.path("analysis", "generated", "artifact_baseline.csv")
artifact_baseline = read.csv(baseline_path, stringsAsFactors = FALSE)
missing_baseline_artifacts =
  artifact_baseline$filepath[!file.exists(artifact_baseline$filepath)]
if (length(missing_baseline_artifacts) > 0) {
  stop(sprintf("Baseline artifacts are missing:\n%s",
               paste(missing_baseline_artifacts, collapse = "\n")))
}

for (row_index in seq_len(nrow(artifact_baseline))) {
  row = artifact_baseline[row_index, ]
  artifact_size = file.info(row$filepath)$size
  if (isTRUE(row$artifact_type == "png")) {
    dimensions = read_png_dimensions(row$filepath)
    if (!identical(as.integer(dimensions["width"]), as.integer(row$width)) ||
        !identical(as.integer(dimensions["height"]), as.integer(row$height))) {
      stop(sprintf("Artifact dimensions changed unexpectedly: %s",
                   row$filepath))
    }
  }
  ratio = artifact_size / row$size_bytes
  if (!is.finite(ratio) || ratio < 0.4 || ratio > 2.5) {
    stop(sprintf("Artifact size drift is too large for %s: %.2f",
                 row$filepath, ratio))
  }
}

cat("Artifact baseline comparison passed.\n")
