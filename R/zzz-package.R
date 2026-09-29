cd_package_files = c(
  "R/dynamics/cr3bp.R",
  "R/dynamics/models.R",
  "R/dynamics/integrate.R",
  "R/dynamics/lyapunov.R",
  "R/experimental/periodic_orbits.R",
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
  "R/systems/n_body/plot_n_body.R",
  "R/studio/models.R",
  "R/studio/catalog.R",
  "R/studio/runs.R",
  "R/studio/runner.R",
  "R/studio/diagnostics.R",
  "R/studio/presets.R",
  "R/studio/history.R",
  "R/studio/plots.R",
  "R/studio/experiments.R",
  "R/studio/jobs.R",
  "R/studio/comparisons.R",
  "R/studio/convergence.R",
  "R/studio/sensitivity.R",
  "R/studio/sweeps.R",
  "R/studio/sweep_plots.R",
  "R/studio/gallery.R",
  "R/planning/experiment_plans.R"
)

for (cd_package_file in cd_package_files) {
  sys.source(cd_package_file, envir = environment())
}

rm(cd_package_file)

cd_engine_fingerprint = studio_source_fingerprint(".")
