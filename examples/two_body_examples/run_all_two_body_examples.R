examples = c(
  "examples/two_body_examples/sun_earth_examples/sun_earth_euler.R",
  "examples/two_body_examples/sun_earth_examples/sun_earth_midpoint.R",
  "examples/two_body_examples/sun_earth_examples/sun_earth_heuns.R",
  "examples/two_body_examples/sun_earth_examples/sun_earth_runge_kutta.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_euler.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_midpoint.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_heuns.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_runge_kutta.R"
)

for (example in examples) {
  cat(sprintf("Running %s\n", example))
  source(example)
}
