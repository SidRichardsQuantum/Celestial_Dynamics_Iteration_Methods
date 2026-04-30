examples = c(
  "examples/projectile_trajectories/projectile_example.R",
  "examples/comparisons/sun_earth_all_methods.R",
  "examples/two_body_examples/run_all_two_body_examples.R",
  "examples/n_body_examples/run_all_n_body_examples.R",
  "examples/three_body_examples/run_all_three_body_examples.R"
)

source("celestial_systems/plotting/plot_style.R")
if (file.exists(cd_plot_manifest_path)) {
  invisible(file.remove(cd_plot_manifest_path))
}

for (example in examples) {
  cat(sprintf("Running %s\n", example))
  status = system2("Rscript", example, stdout = "", stderr = "")
  if (!identical(status, 0L)) {
    stop(sprintf("%s failed with exit status %s", example, status))
  }
}
