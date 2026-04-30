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

missing_plots = required_plots[!file.exists(required_plots)]
if (length(missing_plots) > 0) {
  stop(sprintf("Missing generated plots:\n%s", paste(missing_plots, collapse = "\n")))
}

cat("Plot generation validation passed.\n")

required_analysis_artifacts = c(
  file.path("analysis", "generated", "method_summary.csv"),
  file.path("analysis", "generated", "convergence_summary.csv"),
  file.path("analysis", "generated", "method_comparison_dashboard.html")
)

missing_analysis_artifacts =
  required_analysis_artifacts[!file.exists(required_analysis_artifacts)]
if (length(missing_analysis_artifacts) > 0) {
  stop(sprintf("Missing generated analysis artifacts:\n%s",
               paste(missing_analysis_artifacts, collapse = "\n")))
}

cat("Generated analysis artifact validation passed.\n")
