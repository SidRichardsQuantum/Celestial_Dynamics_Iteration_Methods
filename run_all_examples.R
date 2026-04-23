examples = c(
  "examples/projectile_trajectories/projectile_example.R",
  "examples/two_body_examples/run_all_two_body_examples.R",
  "examples/three_body_examples/run_all_three_body_examples.R"
)

for (example in examples) {
  cat(sprintf("Running %s\n", example))
  source(example)
}
