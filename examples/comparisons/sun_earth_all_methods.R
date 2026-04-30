# Sun-Earth comparison using every two-body iteration method.
source("celestial_systems/two_body/two_body_method_registry.R")
source("celestial_systems/plotting/plot_style.R")

output_dir = file.path("images", "comparisons")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

T = YEAR
N = 250

method_registry = two_body_method_registry()
methods = two_body_method_functions(method_registry)
method_colors = two_body_method_colors(method_registry)

results = lapply(methods, run_sun_earth_two_body_method, T = T, N = N)

trajectory_path = file.path(output_dir, "sun_earth_all_methods.png")
old_par = cd_open_png(trajectory_path, width = 1000, height = 760, res = 140)

all_x = unlist(lapply(results, function(result) result$x_b / AU))
all_y = unlist(lapply(results, function(result) result$y_b / AU))
cd_plot_empty(cd_expand_range(all_x, 0.08, 0.1),
              cd_expand_range(all_y, 0.08, 0.1),
              asp = 1,
              xlab = "x (AU)",
              ylab = "y (AU)",
              main = sprintf("Sun-Earth One-Year Trajectory Comparison\nN = %d steps", N))
points(0, 0, pch = 19, cex = 1.7, col = cd_colors$orange)
for (method_name in names(results)) {
  result = results[[method_name]]
  lines(result$x_b / AU, result$y_b / AU,
        col = grDevices::adjustcolor(method_colors[[method_name]], 0.8),
        lwd = 2.3, lend = "round")
  points(tail(result$x_b, 1) / AU, tail(result$y_b, 1) / AU,
         pch = 19, col = method_colors[[method_name]], cex = 0.8)
}
cd_add_external_legend(c("Sun", names(results)),
                       c(cd_colors$orange, method_colors),
                       pch = c(19, rep(NA, length(results))),
                       lty = c(NA, rep(1, length(results))),
                       lwd = c(NA, rep(2.3, length(results))))
invisible(cd_close_png(old_par))
cd_record_plot_manifest(
  filepath = trajectory_path,
  artifact_type = "png",
  plot_type = "method_comparison_orbit",
  title = sprintf("Sun-Earth One-Year Trajectory Comparison | N = %d steps", N),
  width = 1000,
  height = 760,
  res = 140,
  xlim = cd_expand_range(all_x, 0.08, 0.1),
  ylim = cd_expand_range(all_y, 0.08, 0.1),
  data_x = all_x,
  data_y = all_y,
  time_value = T / YEAR,
  time_unit = "years",
  steps = N
)
cat(sprintf("Plot saved to: %s\n", trajectory_path))

energy_path = file.path(output_dir, "sun_earth_energy_error_all_methods.png")
old_par = cd_open_png(energy_path, width = 1000, height = 720, res = 140)

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
     main = sprintf("Sun-Earth One-Year Energy Error Comparison\nN = %d steps", N),
     bty = "l")
cd_add_grid()
for (method_name in names(results)) {
  time_years = seq(0, T / YEAR, length.out = length(results[[method_name]]$x_b))
  lines(time_years, energy_errors[[method_name]],
        col = grDevices::adjustcolor(method_colors[[method_name]], 0.84),
        lwd = 2.4)
}
cd_add_external_legend(names(results), method_colors)
invisible(cd_close_png(old_par))
cd_record_plot_manifest(
  filepath = energy_path,
  artifact_type = "png",
  plot_type = "method_comparison_diagnostic",
  title = sprintf("Sun-Earth One-Year Energy Error Comparison | N = %d steps", N),
  width = 1000,
  height = 720,
  res = 140,
  xlim = c(0, T / YEAR),
  ylim = range(unlist(energy_errors)),
  data_x = rep(seq(0, T / YEAR, length.out = length(results[[1]]$x_b)),
               length(results)),
  data_y = unlist(energy_errors),
  time_value = T / YEAR,
  time_unit = "years",
  steps = N
)
cat(sprintf("Plot saved to: %s\n", energy_path))
