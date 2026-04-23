tests = c(
  "tests/validate_two_body.R",
  "tests/validate_three_body.R",
  "tests/validate_plot_generation.R"
)

for (test in tests) {
  cat(sprintf("Running %s\n", test))
  source(test)
}

cat("All validation checks passed.\n")
