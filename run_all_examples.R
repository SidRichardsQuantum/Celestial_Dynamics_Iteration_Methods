if (!exists("cd_source", mode = "function")) source("R/load.R")
examples = c(
  "examples/projectile/projectile_example.R",
  "examples/comparisons/sun_earth_all_methods.R",
  "examples/two_body/run_all_two_body_examples.R",
  "examples/n_body/run_all_n_body_examples.R",
  "examples/three_body/run_all_three_body_examples.R"
)

cd_load_plotting()
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
