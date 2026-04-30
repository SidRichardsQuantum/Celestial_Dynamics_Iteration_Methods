examples = c(
  "examples/three_body_examples/general/earth_mars_sun.R",
  "examples/three_body_examples/general/earth_moon_spacecraft.R",
  "examples/three_body_examples/general/binary_distant_third.R",
  "examples/three_body_examples/special_solutions/three_earths.R",
  "examples/three_body_examples/special_solutions/lagrange_three_earths.R",
  "examples/three_body_examples/special_solutions/euler_collinear_three_earths.R",
  "examples/three_body_examples/special_solutions/butterfly_choreography.R",
  "examples/three_body_examples/perturbations/perturbed_figure_8.R",
  "examples/three_body_examples/perturbations/perturbed_lagrange_three_earths.R",
  "examples/three_body_examples/restricted/restricted_earth_moon_trojan.R",
  "examples/three_body_examples/restricted/lyapunov_near_l1.R",
  "examples/three_body_examples/restricted/sitnikov_three_body.R"
)

for (example in examples) {
  cat(sprintf("Running %s\n", example))
  status = system2("Rscript", example, stdout = "", stderr = "")
  if (!identical(status, 0L)) {
    stop(sprintf("%s failed with exit status %s", example, status))
  }
}
