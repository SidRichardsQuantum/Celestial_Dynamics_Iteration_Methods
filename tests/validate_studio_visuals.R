if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()

# Validate complete preset runs, including each new configuration's duration.
full_presets = lapply(studio_presets(), function(p) run_simulation(p$request))
for (name in names(full_presets)) {
  result = full_presets[[name]]
  stopifnot(all(is.finite(result$positions)), length(studio_accuracy_warnings(result)) == 0)
}
pythagorean = full_presets$pythagorean
coarse_request = pythagorean$request
coarse_request$timestep = 2 * coarse_request$timestep
coarse = run_simulation(coarse_request)
fine_drift = max(abs(pythagorean$diagnostics$energy_relative_drift))
stopifnot(fine_drift < 5e-5,
          fine_drift < max(abs(coarse$diagnostics$energy_relative_drift)) / 8,
          max(abs(coarse$positions - pythagorean$positions[seq(1, length(pythagorean$time), 2), , ])) / AU < 5e-5)
separations = sapply(list(c(1, 2), c(1, 3), c(2, 3)), function(pair) {
  sqrt(rowSums((pythagorean$positions[, pair[1], ] - pythagorean$positions[, pair[2], ])^2)) / AU
})
stopifnot(min(separations) < 0.02, which.min(apply(separations, 1, min)) < nrow(separations))

for (name in c("earth_moon_trojan", "sun_jupiter_particle", "lunar_satellite")) {
  result = full_presets[[name]]
  rotating = studio_display_state(result, "native")
  inertial = studio_display_state(result, "inertial")
  mu = result$request$parameters$mu
  stopifnot(dim(rotating$positions)[2] == 3,
            identical(rotating$body_names[1:2], result$request$parameters$primary_names),
            max(abs(rotating$positions[, 1, 1] + mu)) < 1e-14,
            max(abs(rotating$positions[, 2, 1] - (1 - mu))) < 1e-14,
            max(abs(sqrt(rowSums((inertial$positions[, 2, ] - inertial$positions[, 1, ])^2)) - 1)) < 1e-12,
            isTRUE(all.equal(rotating$positions[, 3, ], result$positions[, 1, ])),
            isTRUE(all.equal(inertial$positions[, 3, 3], result$positions[, 1, 3])),
            !"energy" %in% names(result$diagnostics), dim(result$positions)[2] == 1)
  # Inverse rotation recovers the particle's actual solved rotating states.
  theta = result$time
  restored_x = inertial$positions[, 3, 1] * cos(theta) + inertial$positions[, 3, 2] * sin(theta)
  stopifnot(max(abs(restored_x - result$positions[, 1, 1])) < 1e-12)
}
# Small librations must not be overwhelmed by an arbitrary absolute padding.
r = full_presets$sun_jupiter_particle
bounds = cd_animation_bounds(r$positions[, 1, 1], r$positions[, 1, 2])
span = max(diff(range(r$positions[, 1, 1])), diff(range(r$positions[, 1, 2])))
stopifnot(max(diff(bounds$x), diff(bounds$y)) < 1.2 * span,
          diff(cd_animation_bounds(1, 0)$x) > 0)

# A coarse close encounter should produce a visible conservation notice.
unreliable = pythagorean$request
unreliable$timestep = unreliable$duration / 2000
stopifnot(length(studio_accuracy_warnings(run_simulation(unreliable))) > 0)

path = tempfile(fileext = ".html")
for (name in c("sun_jupiter_particle", "earth_moon_trojan", "sitnikov", "earth_moon_binary")) {
  studio_animation(full_presets[[name]], path)
  html = paste(readLines(path, warn = FALSE), collapse = "\n")
  stopifnot(grepl('id="focus"', html, fixed = TRUE), grepl('id="zoom"', html, fixed = TRUE),
            grepl('const times =', html, fixed = TRUE))
  if (name == "sun_jupiter_particle") stopifnot(grepl('"label":"Sun"', html, fixed = TRUE),
                                                grepl('"label":"Jupiter"', html, fixed = TRUE))
  if (name == "earth_moon_trojan") stopifnot(grepl('"label":"Earth"', html, fixed = TRUE),
                                              grepl('"label":"Moon"', html, fixed = TRUE))
  if (name == "sitnikov") stopifnot(grepl('AU x-z', html, fixed = TRUE))
}
unlink(path)
if (requireNamespace("jsonlite", quietly = TRUE)) {
  label = paste0('</script><script>alert("x")</script>', "\n\001")
  encoded = cd_json_string(label)
  stopifnot(!grepl("</script>", encoded, fixed = TRUE), identical(jsonlite::fromJSON(encoded), label))
}
cat("Studio full presets, encounter refinement, display frames and animation checks passed.\n")
