if (!exists("cd_source", mode = "function")) source("R/load.R")

tests = c(
  "tests/validate_two_body.R",
  "tests/validate_three_body.R",
  "tests/validate_n_body.R",
  "tests/validate_conservation.R",
  "tests/validate_convergence.R",
  "tests/validate_invalid_inputs.R",
  "tests/validate_structure.R",
  "tests/validate_plot_generation.R"
)

for (test in tests) {
  cat(sprintf("Running %s\n", test))
  source(cd_path(test))
}

cat("All validation checks passed.\n")
