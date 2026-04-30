examples = c(
  "examples/n_body_examples/sun_earth_mars_jupiter.R",
  "examples/n_body_examples/special_solutions/rotating_square_four_body.R",
  "examples/n_body_examples/special_solutions/triangular_central_four_body.R"
)

for (example in examples) {
  cat(sprintf("Running %s\n", example))
  status = system2("Rscript", example, stdout = "", stderr = "")
  if (!identical(status, 0L)) {
    stop(sprintf("%s failed with exit status %s", example, status))
  }
}
