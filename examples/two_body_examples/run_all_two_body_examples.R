examples = c(
  "examples/two_body_examples/sun_earth_examples/sun_earth_euler.R",
  "examples/two_body_examples/sun_earth_examples/sun_earth_midpoint.R",
  "examples/two_body_examples/sun_earth_examples/sun_earth_heuns.R",
  "examples/two_body_examples/sun_earth_examples/sun_earth_runge_kutta.R",
  "examples/two_body_examples/sun_earth_examples/sun_earth_velocity_verlet.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_euler.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_midpoint.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_heuns.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_runge_kutta.R",
  "examples/two_body_examples/earth_moon_examples/earth_moon_velocity_verlet.R"
)

for (example in examples) {
  cat(sprintf("Running %s\n", example))
  status = system2("Rscript", example, stdout = "", stderr = "")
  if (!identical(status, 0L)) {
    stop(sprintf("%s failed with exit status %s", example, status))
  }
}
