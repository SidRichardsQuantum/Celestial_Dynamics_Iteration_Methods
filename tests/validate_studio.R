if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_studio()

studio_assert_error = function(expr) {
  stopifnot(inherits(tryCatch({ force(expr); NULL }, error = identity), "error"))
}

catalog = studio_catalog()
integrators = studio_integrators()
for (id in names(catalog)) {
  spec = catalog[[id]]
  stopifnot(inherits(spec, "studio_simulation_spec"), identical(spec$name, id),
            length(spec$parameters) > 0, is.function(spec$validate), is.function(spec$adapter))
  for (method in spec$integrators) stopifnot(id %in% integrators[[method]]$systems)
}
stopifnot(integrators$Verlet$symplectic, !integrators$Midpoint$symplectic,
          !any(vapply(integrators, function(x) x$adaptive, logical(1))))

request = studio_preset("circular_two_body")
invalid = function(...) do.call(simulation_request, utils::modifyList(unclass(request), list(...)))
studio_assert_error(invalid(system = "missing"))
studio_assert_error(invalid(system = "three_body", integrator = "Euler"))
studio_assert_error(invalid(duration = -1))
studio_assert_error(invalid(duration = Inf))
studio_assert_error(invalid(timestep = 0))
studio_assert_error(invalid(timestep = request$duration / 3.5))
studio_assert_error(invalid(parameters = list(extra = 1)))
studio_assert_error(invalid(parameters = list(masses = c(-1, 2))))
studio_assert_error(invalid(parameters = list(positions = matrix(0, 2, 2))))
studio_assert_error(invalid(parameters = list(velocities = matrix(NA_real_, 2, 2))))
studio_assert_error(invalid(parameters = list(positions = matrix(1, 2, 3))))
studio_assert_error(simulation_request("restricted_three_body", "RK4", list(mu = 0.6, state0 = rep(0, 6)), 1, 0.01))
studio_assert_error(simulation_request("restricted_three_body", "RK4", list(mu = 0.1, state0 = c(-0.1, 0, 0, 0, 0, 0)), 1, 0.01))
studio_assert_error(studio_preset("unknown"))
studio_assert_error(compare_integrators(request, c("RK4", "missing")))

# Overlapping inputs would fail physics validation: resource errors must occur
# first, before allocating the quadratic pairwise distance matrix.
for (case in list(list(bodies = 257, steps = 1, error = "256-body"),
                  list(bodies = 20, steps = 100000, error = "position-value"),
                  list(bodies = 100, steps = 3000, error = "pair-step"))) {
  error = tryCatch(simulation_request("n_body", "RK4", list(
    masses = rep(1, case$bodies), positions = matrix(0, case$bodies, 2),
    velocities = matrix(0, case$bodies, 2)), case$steps, 1), error = identity)
  stopifnot(inherits(error, "error"), grepl(case$error, conditionMessage(error), fixed = TRUE))
}
# The body limit itself is inclusive; small supported runs remain valid.
stopifnot(inherits(simulation_request("n_body", "RK4", list(
  masses = rep(1, 256), positions = cbind(seq_len(256), 0),
  velocities = matrix(0, 256, 2)), 1, 1), "simulation_request"))

for (preset in studio_presets()) {
  # Exercise every adapter with a short segment of the explicit preset.
  r = preset$request
  r$duration = 10 * r$timestep
  output = run_simulation(r)
  stopifnot(dim(output$positions)[1] == 11,
            all(is.finite(output$positions)), all(is.finite(output$velocities)),
            identical(names(output$diagnostics)[-1], catalog[[r$system]]$diagnostics))
}

request$timestep = request$duration / 1000
result = run_simulation(request)
repeat_result = run_simulation(request)
stopifnot(isTRUE(all.equal(result$positions, repeat_result$positions, tolerance = 1e-13)),
          max(abs(result$diagnostics$energy_relative_drift)) < 1e-9,
          max(abs(result$diagnostics$angular_momentum_relative_drift)) < 1e-9,
          max(result$diagnostics$eccentricity) < 1e-8,
          max(abs(result$diagnostics$semi_major_axis / AU - 1)) < 1e-8)
expected_energy = -G * prod(request$parameters$masses) / (2 * AU)
stopifnot(abs(result$diagnostics$energy[1] / expected_energy - 1) < 1e-12)
p_scale = sum(request$parameters$masses * sqrt(rowSums(request$parameters$velocities^2)))
stopifnot(max(abs(result$diagnostics$momentum_x)) / p_scale < 1e-12,
          max(abs(result$diagnostics$momentum_y)) / p_scale < 1e-12)
comparison = compare_integrators(request, c("RK4", "Verlet"))
stopifnot(isTRUE(all.equal(comparison$RK4$positions, result$positions)),
          max(abs(comparison$Verlet$diagnostics$energy_relative_drift)) < 1e-7,
          max(abs(comparison$Verlet$diagnostics$angular_momentum_relative_drift)) < 1e-12,
          identical(comparison$RK4$request$parameters, comparison$Verlet$request$parameters))

# Existing public solvers remain the source of the Studio's trajectories.
legacy = run_two_body_method(runge_kutta_two_body, studio_legacy_arguments(request), quiet = TRUE)
stopifnot(isTRUE(all.equal(result$positions[, 2, 1], legacy$x_b)),
          isTRUE(all.equal(result$diagnostics$energy, two_body_energy_series(legacy))))
mu = 0.01215
l4 = simulation_request("restricted_three_body", "RK4",
  list(mu = mu, state0 = c(0.5 - mu, sqrt(3) / 2, 0, 0, 0, 0)), 1, 0.01)
l4_result = run_simulation(l4)
stopifnot(max(abs(l4_result$diagnostics$jacobi - (3 - mu + mu^2))) < 1e-12,
          !"energy" %in% names(l4_result$diagnostics),
          max(abs(l4_result$diagnostics$jacobi_relative_drift)) < 1e-12,
          all(is.na(studio_relative_series(rep(0, 5)))))
spatial = run_simulation(studio_preset("sun_jupiter_particle"))
stopifnot(max(abs(spatial$diagnostics$jacobi_relative_drift)) < 1e-7)
sitnikov = run_simulation(studio_preset("sitnikov"))
stopifnot(max(abs(sitnikov$diagnostics$specific_energy_relative_drift)) < 1e-7)

if (requireNamespace("jsonlite", quietly = TRUE)) {
  directory = tempfile("studio-history-")
  dir.create(directory)
  for (preset in studio_presets()) {
    restored = studio_request_from_json(studio_request_json(preset$request))
    stopifnot(isTRUE(all.equal(restored, preset$request, tolerance = 1e-14)))
  }
  first = studio_save_history(result, directory)
  second = studio_save_history(result, directory)
  restored = studio_load_history(first)
  stopifnot(first != second, length(studio_history(directory)) == 2,
            isTRUE(all.equal(result$request, restored$request, tolerance = 1e-14)),
            !"positions" %in% names(restored), file.info(first)$size < 15000)
  replay = run_simulation(restored$request)
  stopifnot(isTRUE(all.equal(replay$positions, result$positions, tolerance = 1e-12)))
  writeLines('{"schema_version":99}', file.path(directory, "bad.json"))
  studio_assert_error(studio_load_history(file.path(directory, "bad.json")))
  stopifnot(length(suppressWarnings(studio_history(directory))) == 2)
  record = jsonlite::read_json(first, simplifyVector = FALSE)
  for (timestamp in list(NULL, 123, character(), c("a", "b"), "",
                         "2026-02-30T12:00:00Z", "2026-09-18T25:00:00Z",
                         "2026-09-18T12:00:00", "not a timestamp")) {
    record$timestamp = timestamp
    jsonlite::write_json(record, file.path(directory, "bad.json"),
                        auto_unbox = TRUE, digits = NA)
    studio_assert_error(studio_load_history(file.path(directory, "bad.json")))
    warnings = character()
    valid = withCallingHandlers(studio_history(directory), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
    stopifnot(length(valid) == 2, length(warnings) == 1,
              grepl("timestamp", warnings[1], fixed = TRUE))
  }
  # Sort chronologically even when valid timestamps have different precision.
  record$timestamp = "2026-09-18T12:00:00Z"
  jsonlite::write_json(record, first, auto_unbox = TRUE, digits = NA)
  record$timestamp = "2026-09-18T12:00:00.1Z"
  jsonlite::write_json(record, second, auto_unbox = TRUE, digits = NA)
  stopifnot(identical(names(suppressWarnings(studio_history(directory))), c(second, first)))
  studio_assert_error(studio_request_from_json('{"system":"two_body","parameters":{"positions":[[1,2],[3]]}}'))
  unlink(directory, recursive = TRUE)
} else cat("Optional JSON history tests skipped: install jsonlite to enable.\n")

# Plot and export smoke checks use disposable artifacts.
path = tempfile(fileext = ".pdf")
grDevices::pdf(path)
studio_plot_trajectories(comparison)
studio_plot_diagnostic(comparison, "energy_relative_drift")
studio_plot_3d(spatial)
grDevices::dev.off()
stopifnot(file.info(path)$size > 0)
unlink(path)
path = tempfile(fileext = ".csv")
studio_export_trajectory(result, path)
stopifnot(nrow(utils::read.csv(path)) == 2 * length(result$time))
unlink(path)
cat("Studio catalog, validation, presets, diagnostics, conservation and history checks passed.\n")
