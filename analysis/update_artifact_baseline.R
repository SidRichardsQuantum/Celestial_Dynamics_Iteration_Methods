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

required_animation_artifacts = c(
  file.path("images", "two_body", "sun_earth", "sun_earth_runge_kutta.html"),
  file.path("images", "three_body", "special_solutions", "three_earths.html"),
  file.path("images", "n_body", "sun_earth_mars_jupiter.html")
)

required_analysis_artifacts = c(
  file.path("analysis", "generated", "method_summary.csv"),
  file.path("analysis", "generated", "convergence_summary.csv"),
  file.path("analysis", "generated", "earth_moon_method_summary.csv"),
  file.path("analysis", "generated", "three_body_special_summary.csv"),
  file.path("analysis", "generated", "n_body_conservation_summary.csv"),
  file.path("analysis", "generated", "runtime_benchmark.csv"),
  file.path("analysis", "generated", "plot_manifest.csv"),
  file.path("analysis", "generated", "artifact_index.html"),
  file.path("analysis", "generated", "index.html"),
  file.path("analysis", "generated", "method_comparison_dashboard.html")
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

artifact_paths = sort(unique(c(
  required_plots,
  required_animation_artifacts,
  required_analysis_artifacts
)))

missing_artifacts = artifact_paths[!file.exists(artifact_paths)]
if (length(missing_artifacts) > 0) {
  stop(sprintf("Cannot baseline missing artifacts:\n%s",
               paste(missing_artifacts, collapse = "\n")))
}

baseline_rows = lapply(artifact_paths, function(path) {
  artifact_type = if (grepl("\\.png$", path, ignore.case = TRUE)) {
    "png"
  } else if (grepl("\\.html$", path, ignore.case = TRUE)) {
    "html"
  } else {
    "data"
  }

  width = NA_integer_
  height = NA_integer_
  if (artifact_type == "png") {
    dimensions = read_png_dimensions(path)
    width = dimensions["width"]
    height = dimensions["height"]
  }

  data.frame(
    filepath = path,
    artifact_type = artifact_type,
    size_bytes = file.info(path)$size,
    width = width,
    height = height,
    stringsAsFactors = FALSE
  )
})

baseline = do.call(rbind, baseline_rows)
dir.create(file.path("analysis", "generated"), recursive = TRUE,
           showWarnings = FALSE)
write.csv(baseline, file.path("analysis", "generated", "artifact_baseline.csv"),
          row.names = FALSE)
cat("Updated analysis/generated/artifact_baseline.csv\n")
