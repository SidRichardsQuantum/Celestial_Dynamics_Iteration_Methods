required_plots = c(
  file.path("images", "projectile", "euler_trajectory.png"),
  file.path("images", "projectile", "heun_trajectory.png"),
  file.path("images", "projectile", "midpoint_trajectory.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_euler.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_midpoint.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_heuns.png"),
  file.path("images", "two_body", "sun_earth", "sun_earth_runge_kutta.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_euler.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_midpoint.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_heuns.png"),
  file.path("images", "two_body", "earth_moon", "earth_moon_runge_kutta.png"),
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
  file.path("images", "three_body", "restricted", "sitnikov_three_body.png")
)

missing_plots = required_plots[!file.exists(required_plots)]
if (length(missing_plots) > 0) {
  stop(sprintf("Missing generated plots:\n%s", paste(missing_plots, collapse = "\n")))
}

cat("Plot generation validation passed.\n")
