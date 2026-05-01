cd_package_files = c(
  "R/methods/euler_method.R",
  "R/methods/heuns_method.R",
  "R/methods/midpoint_method.R",
  "R/methods/runge_kutta_method.R",
  "R/systems/plotting/plot_style.R",
  "R/systems/two_body/two_body_helpers.R",
  "R/systems/two_body/two_body_euler.R",
  "R/systems/two_body/two_body_midpoint.R",
  "R/systems/two_body/two_body_heuns.R",
  "R/systems/two_body/two_body_runge_kutta.R",
  "R/systems/two_body/two_body_velocity_verlet.R",
  "R/systems/two_body/two_body_method_registry.R",
  "R/systems/two_body/plot_two_body.R",
  "R/systems/three_body/three_body_helpers.R",
  "R/systems/three_body/three_body_runge_kutta.R",
  "R/systems/three_body/figure_8_initial_conditions.R",
  "R/systems/three_body/lagrange_initial_conditions.R",
  "R/systems/three_body/euler_collinear_initial_conditions.R",
  "R/systems/three_body/choreography_initial_conditions.R",
  "R/systems/three_body/circular_restricted_three_body.R",
  "R/systems/three_body/sitnikov_problem.R",
  "R/systems/three_body/plot_three_body.R",
  "R/systems/n_body/n_body_helpers.R",
  "R/systems/n_body/n_body_runge_kutta.R",
  "R/systems/n_body/n_body_velocity_verlet.R",
  "R/systems/n_body/four_body_initial_conditions.R",
  "R/systems/n_body/plot_n_body.R"
)

for (cd_package_file in cd_package_files) {
  sys.source(cd_package_file, envir = environment())
}

rm(cd_package_file)
