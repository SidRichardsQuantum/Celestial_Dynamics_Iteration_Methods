if (!exists("cd_source", mode = "function")) source("R/load.R")

tests = c(
  "tests/validate_two_body.R",
  "tests/validate_three_body.R",
  "tests/validate_n_body.R",
  "tests/validate_dynamics.R",
  "tests/validate_periodic_orbits.R",
  "tests/validate_periodic_app.R",
  "tests/validate_experiment_plans.R",
  "tests/validate_planner_app.R",
  "tests/validate_cr3bp.R",
  "tests/validate_lyapunov.R",
  "tests/validate_sensitivity_app.R",
  "tests/validate_parameter_sweeps.R",
  "tests/validate_sweep_app.R",
  "tests/validate_conservation.R",
  "tests/validate_convergence.R",
  "tests/validate_invalid_inputs.R",
  "tests/validate_structure.R",
  "tests/validate_studio.R",
  "tests/validate_diagnostics.R",
  "tests/validate_studio_runs.R",
  "tests/validate_studio_visuals.R",
  "tests/validate_studio_app.R",
  "tests/validate_studio_experiments.R",
  "tests/validate_integrator_lab.R",
  "tests/validate_convergence_study.R",
  "tests/validate_studio_background.R",
  "tests/validate_studio_gallery.R",
  "tests/validate_plot_generation.R"
)

for (test in tests) {
  cat(sprintf("Running %s\n", test))
  source(cd_path(test))
}

cat("All validation checks passed.\n")
