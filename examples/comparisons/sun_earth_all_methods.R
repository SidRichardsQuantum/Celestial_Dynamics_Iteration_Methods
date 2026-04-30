# Sun-Earth comparison using every two-body iteration method.
source("celestial_systems/two_body/two_body_method_registry.R")

output_dir = file.path("images", "comparisons")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

T = YEAR
N = 250

method_registry = two_body_method_registry()
methods = two_body_method_functions(method_registry)
method_colors = two_body_method_colors(method_registry)

results = lapply(methods, run_sun_earth_two_body_method, T = T, N = N)

trajectory_path = file.path(output_dir, "sun_earth_all_methods.png")
png(trajectory_path, width = 900, height = 700, res = 120)
par(mar = c(5, 5, 4, 2))

all_x = unlist(lapply(results, function(result) result$x_b / AU))
all_y = unlist(lapply(results, function(result) result$y_b / AU))
plot(NULL,
     xlim = range(all_x) + c(-0.1, 0.1),
     ylim = range(all_y) + c(-0.1, 0.1),
     asp = 1,
     xlab = "x (AU)",
     ylab = "y (AU)",
     main = sprintf("Sun-Earth One-Year Trajectory Comparison\nN = %d steps", N))
points(0, 0, pch = 19, cex = 1.5, col = "red")
for (method_name in names(results)) {
  result = results[[method_name]]
  lines(result$x_b / AU, result$y_b / AU,
        col = method_colors[[method_name]], lwd = 2)
  points(tail(result$x_b, 1) / AU, tail(result$y_b, 1) / AU,
         pch = 19, col = method_colors[[method_name]], cex = 0.8)
}
legend("topright", legend = c("Sun", names(results)),
       col = c("red", method_colors), pch = c(19, rep(NA, length(results))),
       lty = c(NA, rep(1, length(results))), lwd = c(NA, rep(2, length(results))),
       bg = "white")
grid(col = "lightgray", lty = "dotted")
invisible(dev.off())
cat(sprintf("Plot saved to: %s\n", trajectory_path))

energy_path = file.path(output_dir, "sun_earth_energy_error_all_methods.png")
png(energy_path, width = 900, height = 650, res = 120)
par(mar = c(5, 5, 4, 2))

energy_errors = lapply(results, function(result) {
  energy = two_body_energy_series(result)
  abs((energy - energy[1]) / abs(energy[1]))
})
positive_errors = unlist(energy_errors)
positive_errors = positive_errors[positive_errors > 0]
error_floor = min(positive_errors) / 10
energy_errors = lapply(energy_errors, function(errors) {
  pmax(errors, error_floor)
})
plot(NULL,
     log = "y",
     xlim = c(0, T / YEAR),
     ylim = range(unlist(energy_errors)),
     xlab = "Time (years)",
     ylab = "Absolute relative energy error",
     main = sprintf("Sun-Earth One-Year Energy Error Comparison\nN = %d steps", N))
for (method_name in names(results)) {
  time_years = seq(0, T / YEAR, length.out = length(results[[method_name]]$x_b))
  lines(time_years, energy_errors[[method_name]],
        col = method_colors[[method_name]], lwd = 2)
}
legend("topleft", legend = names(results), col = method_colors,
       lwd = 2, bg = "white")
grid(col = "lightgray", lty = "dotted")
invisible(dev.off())
cat(sprintf("Plot saved to: %s\n", energy_path))
