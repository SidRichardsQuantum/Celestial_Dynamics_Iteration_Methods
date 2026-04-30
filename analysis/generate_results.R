source("celestial_systems/two_body/two_body_method_registry.R")
source("celestial_systems/plotting/plot_style.R")
source("celestial_systems/three_body/three_body_runge_kutta.R")
source("celestial_systems/three_body/figure_8_initial_conditions.R")
source("celestial_systems/three_body/lagrange_initial_conditions.R")
source("celestial_systems/three_body/euler_collinear_initial_conditions.R")
source("celestial_systems/three_body/choreography_initial_conditions.R")
source("celestial_systems/n_body/n_body_runge_kutta.R")
source("celestial_systems/n_body/four_body_initial_conditions.R")

generated_dir = "analysis/generated"
analysis_image_dir = "images/analysis"
dashboard_path = file.path(generated_dir, "method_comparison_dashboard.html")

dir.create(generated_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(analysis_image_dir, recursive = TRUE, showWarnings = FALSE)

method_registry = two_body_method_registry()
methods = two_body_method_functions(method_registry)
method_colors = two_body_method_colors(method_registry)
expected_orders = two_body_method_expected_orders(method_registry)

relative_error_series = function(values) {
  (values - values[1]) / abs(values[1])
}

sample_indices = function(n, target_count) {
  unique(round(seq(1, n, length.out = min(n, target_count))))
}

format_numeric = function(values, digits = 6) {
  format(signif(values, digits), scientific = TRUE, trim = TRUE)
}

write_markdown_table = function(df) {
  header = paste0("| ", paste(names(df), collapse = " | "), " |")
  separator = paste0("| ", paste(rep("---", length(df)), collapse = " | "), " |")
  rows = apply(df, 1, function(row) {
    paste0("| ", paste(row, collapse = " | "), " |")
  })
  c(header, separator, rows)
}

summarize_two_body_result = function(result, method_name, system_name,
                                     duration_label) {
  energy = two_body_energy_series(result)
  angular_momentum = two_body_angular_momentum_series(result)
  separation = sqrt((result$x_a - result$x_b)^2 + (result$y_a - result$y_b)^2)

  data.frame(
    system = system_name,
    method = method_name,
    duration = duration_label,
    steps = length(result$x_a) - 1,
    final_separation_au = tail(separation, 1) / AU,
    final_energy_ratio = tail(energy, 1) / energy[1],
    max_abs_energy_error = max(abs(relative_error_series(energy))),
    max_abs_angular_momentum_drift = relative_drift(angular_momentum),
    stringsAsFactors = FALSE
  )
}

earth_moon_two_body_parameters = function(T, N) {
  list(
    T = T,
    N = N,
    m_a = M_EARTH,
    m_b = M_MOON,
    r_ax0 = 0, r_ay0 = 0,
    r_bx0 = 0.00257 * AU, r_by0 = 0,
    v_ax0 = 0, v_ay0 = 0,
    v_bx0 = 0, v_by0 = abs(V_MOON_ORBITAL)
  )
}

run_three_body_case = function(ic, N) {
  pos1 = ic$positions[[1]]
  pos2 = ic$positions[[2]]
  pos3 = ic$positions[[3]]
  vel1 = ic$velocities[[1]]
  vel2 = ic$velocities[[2]]
  vel3 = ic$velocities[[3]]

  runge_kutta_three_body(
    T = ic$period,
    N = N,
    m_a = M_EARTH,
    m_b = M_EARTH,
    m_c = M_EARTH,
    r_ax0 = pos1[1], r_ay0 = pos1[2],
    r_bx0 = pos2[1], r_by0 = pos2[2],
    r_cx0 = pos3[1], r_cy0 = pos3[2],
    v_ax0 = vel1[1], v_ay0 = vel1[2],
    v_bx0 = vel2[1], v_by0 = vel2[2],
    v_cx0 = vel3[1], v_cy0 = vel3[2]
  )
}

summarize_three_body_case = function(case_name, result, duration_years) {
  energy = three_body_energy_series(result)
  angular_momentum = three_body_angular_momentum_series(result)
  initial = result$initial_conditions
  initial_separations = three_body_separations(
    c(initial$r_ax0, initial$r_ay0),
    c(initial$r_bx0, initial$r_by0),
    c(initial$r_cx0, initial$r_cy0)
  )
  final_separations = three_body_separations(
    c(tail(result$x_a, 1), tail(result$y_a, 1)),
    c(tail(result$x_b, 1), tail(result$y_b, 1)),
    c(tail(result$x_c, 1), tail(result$y_c, 1))
  )

  data.frame(
    case = case_name,
    years = duration_years,
    steps = length(result$x_a) - 1,
    final_energy_ratio = tail(energy, 1) / energy[1],
    max_abs_energy_error = max(abs(relative_error_series(energy))),
    max_abs_angular_momentum_drift = relative_drift(angular_momentum),
    max_pair_separation_error_au =
      max(abs(final_separations - initial_separations)) / AU,
    stringsAsFactors = FALSE
  )
}

run_sun_earth_mars_jupiter = function() {
  masses = c(M_SUN, M_EARTH, M_MARS, M_JUPITER)
  orbital_velocity = function(radius) {
    sqrt(G * M_SUN / radius)
  }
  positions = rbind(
    c(0, 0),
    c(AU, 0),
    c(1.524 * AU, 0),
    c(5.203 * AU, 0)
  )
  velocities = rbind(
    c(0, 0),
    c(0, V_EARTH_ORBITAL),
    c(0, orbital_velocity(1.524 * AU)),
    c(0, orbital_velocity(5.203 * AU))
  )
  runge_kutta_n_body(12 * YEAR, 6000, masses, positions, velocities,
                     c("Sun", "Earth", "Mars", "Jupiter"))
}

summarize_n_body_case = function(case_name, result, duration_years) {
  energy = n_body_energy_series(result)
  angular_momentum = n_body_angular_momentum_series(result)
  data.frame(
    case = case_name,
    years = duration_years,
    steps = dim(result$positions)[1] - 1,
    bodies = length(result$masses),
    final_energy_ratio = tail(energy, 1) / energy[1],
    max_abs_energy_error = max(abs(relative_error_series(energy))),
    max_abs_angular_momentum_drift = relative_drift(angular_momentum),
    stringsAsFactors = FALSE
  )
}

results_25y = lapply(methods, run_sun_earth_two_body_method, quiet = TRUE)

summary_rows = lapply(names(results_25y), function(method_name) {
  result = results_25y[[method_name]]
  energy = two_body_energy_series(result)
  angular_momentum = two_body_angular_momentum_series(result)
  separation = sqrt((result$x_a - result$x_b)^2 + (result$y_a - result$y_b)^2)

  data.frame(
    method = method_name,
    years = 25,
    steps = length(result$x_a) - 1,
    final_separation_au = tail(separation, 1) / AU,
    final_energy_ratio = tail(energy, 1) / energy[1],
    max_abs_energy_error = max(abs(relative_error_series(energy))),
    max_abs_angular_momentum_drift = relative_drift(angular_momentum),
    stringsAsFactors = FALSE
  )
})
summary_table = do.call(rbind, summary_rows)
write.csv(summary_table, file.path(generated_dir, "method_summary.csv"),
          row.names = FALSE)

earth_moon_T = 10 * LUNAR_MONTH
earth_moon_N = 1000
earth_moon_parameters = earth_moon_two_body_parameters(earth_moon_T,
                                                       earth_moon_N)
earth_moon_results = lapply(methods, function(method_func) {
  run_two_body_method(method_func, earth_moon_parameters, quiet = TRUE)
})
earth_moon_summary_rows = lapply(names(earth_moon_results), function(method_name) {
  summarize_two_body_result(earth_moon_results[[method_name]], method_name,
                            "Earth-Moon", "10 lunar months")
})
earth_moon_summary_table = do.call(rbind, earth_moon_summary_rows)
write.csv(earth_moon_summary_table,
          file.path(generated_dir, "earth_moon_method_summary.csv"),
          row.names = FALSE)

three_body_cases = list(
  `Figure-8` = list(
    ic = figure_8_initial_conditions(distance_real = AU, body_mass = M_EARTH),
    N = 20000
  ),
  `Lagrange triangle` = list(
    ic = lagrange_initial_conditions(side_length_real = AU,
                                     body_mass = M_EARTH),
    N = 20000
  ),
  `Euler collinear` = list(
    ic = euler_collinear_initial_conditions(outer_separation_real = AU,
                                            body_mass = M_EARTH),
    N = 20000
  ),
  `Butterfly I` = list(
    ic = choreography_initial_conditions(name = "butterfly_i",
                                         outer_separation_real = AU,
                                         body_mass = M_EARTH),
    N = 100000
  )
)
three_body_summary_rows = lapply(names(three_body_cases), function(case_name) {
  case = three_body_cases[[case_name]]
  capture.output({
    result = run_three_body_case(case$ic, case$N)
  })
  summarize_three_body_case(case_name, result, case$ic$period / YEAR)
})
three_body_summary_table = do.call(rbind, three_body_summary_rows)
write.csv(three_body_summary_table,
          file.path(generated_dir, "three_body_special_summary.csv"),
          row.names = FALSE)

n_body_cases = list(
  `Sun-Earth-Mars-Jupiter` = list(
    result = {
      capture.output({
        value = run_sun_earth_mars_jupiter()
      })
      value
    },
    years = 12
  ),
  `Rotating square four-body` = {
    ic = rotating_square_four_body_initial_conditions()
    capture.output({
      value = runge_kutta_n_body(ic$period, 20000, ic$masses, ic$positions,
                                 ic$velocities, ic$body_names)
    })
    list(
      result = value,
      years = ic$period / YEAR
    )
  },
  `Triangular central four-body` = {
    ic = triangular_central_four_body_initial_conditions()
    capture.output({
      value = runge_kutta_n_body(ic$period, 20000, ic$masses, ic$positions,
                                 ic$velocities, ic$body_names)
    })
    list(
      result = value,
      years = ic$period / YEAR
    )
  }
)
n_body_summary_rows = lapply(names(n_body_cases), function(case_name) {
  summarize_n_body_case(case_name, n_body_cases[[case_name]]$result,
                        n_body_cases[[case_name]]$years)
})
n_body_summary_table = do.call(rbind, n_body_summary_rows)
write.csv(n_body_summary_table,
          file.path(generated_dir, "n_body_conservation_summary.csv"),
          row.names = FALSE)

reference = run_sun_earth_two_body_method(methods[["RK4"]], T = YEAR,
                                          N = 16000, quiet = TRUE)
reference_point = c(tail(reference$x_b, 1), tail(reference$y_b, 1))
step_counts = c(250, 500, 1000, 2000)

convergence_rows = list()
for (method_name in names(methods)) {
  previous_error = NA_real_
  for (N in step_counts) {
    result = run_sun_earth_two_body_method(methods[[method_name]], T = YEAR,
                                           N = N, quiet = TRUE)
    error = two_body_final_position_error(result, reference_point)
    observed_order = if (is.na(previous_error)) {
      NA_real_
    } else {
      log(previous_error / error) / log(2)
    }
    convergence_rows[[length(convergence_rows) + 1]] = data.frame(
      method = method_name,
      years = 1,
      steps = N,
      dt_days = YEAR / N / DAY,
      final_position_error_au = error,
      observed_order = observed_order,
      stringsAsFactors = FALSE
    )
    previous_error = error
  }
}
convergence_table = do.call(rbind, convergence_rows)
write.csv(convergence_table, file.path(generated_dir, "convergence_summary.csv"),
          row.names = FALSE)

benchmark_rows = list()
for (method_name in names(methods)) {
  for (N in step_counts) {
    elapsed = system.time({
      result = run_sun_earth_two_body_method(methods[[method_name]], T = YEAR,
                                             N = N, quiet = TRUE)
    })[["elapsed"]]
    error = two_body_final_position_error(result, reference_point)
    benchmark_rows[[length(benchmark_rows) + 1]] = data.frame(
      method = method_name,
      years = 1,
      steps = N,
      dt_days = YEAR / N / DAY,
      runtime_seconds = elapsed,
      final_position_error_au = error,
      error_per_second = error / max(elapsed, .Machine$double.eps),
      stringsAsFactors = FALSE
    )
  }
}
benchmark_table = do.call(rbind, benchmark_rows)
write.csv(benchmark_table, file.path(generated_dir, "runtime_benchmark.csv"),
          row.names = FALSE)

energy_plot_path = file.path(analysis_image_dir, "sun_earth_energy_error.png")
old_par = cd_open_png(energy_plot_path, width = 1000, height = 720, res = 140)
plot(NULL, xlim = c(0, 25), ylim = range(unlist(lapply(results_25y, function(result) {
  relative_error_series(two_body_energy_series(result))
}))),
     xlab = "Time (years)", ylab = "Relative energy error",
     main = "Sun-Earth Energy Error by Method", bty = "l")
cd_add_grid()
abline(h = 0, col = cd_colors$gray, lty = "dashed", lwd = 1)
for (method_name in names(results_25y)) {
  result = results_25y[[method_name]]
  time_years = seq(0, 25, length.out = length(result$x_a))
  lines(time_years, relative_error_series(two_body_energy_series(result)),
        col = grDevices::adjustcolor(method_colors[[method_name]], 0.84),
        lwd = 2.4)
}
cd_add_external_legend(names(results_25y), method_colors)
invisible(cd_close_png(old_par))
energy_values = unlist(lapply(results_25y, function(result) {
  relative_error_series(two_body_energy_series(result))
}))
cd_record_plot_manifest(
  filepath = energy_plot_path,
  artifact_type = "png",
  plot_type = "diagnostic",
  title = "Sun-Earth Energy Error by Method",
  width = 1000,
  height = 720,
  res = 140,
  xlim = c(0, 25),
  ylim = range(energy_values),
  data_x = rep(seq(0, 25, length.out = length(results_25y[[1]]$x_a)),
               length(results_25y)),
  data_y = energy_values
)

momentum_plot_path = file.path(analysis_image_dir, "sun_earth_angular_momentum_drift.png")
old_par = cd_open_png(momentum_plot_path, width = 1000, height = 720, res = 140)
plot(NULL, xlim = c(0, 25), ylim = range(unlist(lapply(results_25y, function(result) {
  relative_error_series(two_body_angular_momentum_series(result))
}))),
     xlab = "Time (years)", ylab = "Relative angular momentum drift",
     main = "Sun-Earth Angular Momentum Drift by Method", bty = "l")
cd_add_grid()
abline(h = 0, col = cd_colors$gray, lty = "dashed", lwd = 1)
for (method_name in names(results_25y)) {
  result = results_25y[[method_name]]
  time_years = seq(0, 25, length.out = length(result$x_a))
  lines(time_years, relative_error_series(two_body_angular_momentum_series(result)),
        col = grDevices::adjustcolor(method_colors[[method_name]], 0.84),
        lwd = 2.4)
}
cd_add_external_legend(names(results_25y), method_colors)
invisible(cd_close_png(old_par))
momentum_values = unlist(lapply(results_25y, function(result) {
  relative_error_series(two_body_angular_momentum_series(result))
}))
cd_record_plot_manifest(
  filepath = momentum_plot_path,
  artifact_type = "png",
  plot_type = "diagnostic",
  title = "Sun-Earth Angular Momentum Drift by Method",
  width = 1000,
  height = 720,
  res = 140,
  xlim = c(0, 25),
  ylim = range(momentum_values),
  data_x = rep(seq(0, 25, length.out = length(results_25y[[1]]$x_a)),
               length(results_25y)),
  data_y = momentum_values
)

convergence_plot_path = file.path(analysis_image_dir, "convergence_rates.png")
old_par = cd_open_png(convergence_plot_path, width = 1100, height = 720,
                      res = 140, mar = c(5, 5, 4, 11))
plot(NULL, log = "xy",
     xlim = range(convergence_table$dt_days),
     ylim = range(convergence_table$final_position_error_au),
     xlab = "dt (days)", ylab = "Final position error (AU)",
     main = "Sun-Earth Convergence Against Fine RK4 Reference",
     bty = "l")
cd_add_grid()
for (method_name in names(methods)) {
  rows = convergence_table[convergence_table$method == method_name, ]
  lines(rows$dt_days, rows$final_position_error_au,
        col = method_colors[[method_name]], lwd = 2.4, type = "b", pch = 19)
}
observed_order_labels = vapply(names(methods), function(method_name) {
  rows = convergence_table[convergence_table$method == method_name, ]
  finite_orders = rows$observed_order[is.finite(rows$observed_order)]
  if (length(finite_orders) == 0) {
    return("n/a")
  }
  sprintf("%.2g", tail(finite_orders, 1))
}, character(1))
legend_labels = sprintf("%s (p~%s, expected %s)", names(methods),
                        observed_order_labels[names(methods)],
                        format(expected_orders[names(methods)], trim = TRUE))
label_x = max(convergence_table$dt_days) * 1.06
label_multipliers = c(Euler = 1, Midpoint = 0.95, Heun = 1.75,
                      RK4 = 1, Verlet = 0.58)
for (method_name in names(methods)) {
  rows = convergence_table[convergence_table$method == method_name, ]
  text(label_x,
       tail(rows$final_position_error_au, 1) * label_multipliers[[method_name]],
       labels = legend_labels[match(method_name, names(methods))],
       pos = 4, cex = 0.78, col = method_colors[[method_name]], xpd = NA)
}
invisible(cd_close_png(old_par))
cd_record_plot_manifest(
  filepath = convergence_plot_path,
  artifact_type = "png",
  plot_type = "diagnostic",
  title = "Sun-Earth Convergence Against Fine RK4 Reference",
  width = 1100,
  height = 720,
  res = 140,
  xlim = range(convergence_table$dt_days),
  ylim = range(convergence_table$final_position_error_au),
  data_x = convergence_table$dt_days,
  data_y = convergence_table$final_position_error_au
)

summary_md = summary_table
summary_md$final_separation_au = format_numeric(summary_md$final_separation_au)
summary_md$final_energy_ratio = format_numeric(summary_md$final_energy_ratio)
summary_md$max_abs_energy_error = format_numeric(summary_md$max_abs_energy_error)
summary_md$max_abs_angular_momentum_drift =
  format_numeric(summary_md$max_abs_angular_momentum_drift)

convergence_md = convergence_table
convergence_md$dt_days = format_numeric(convergence_md$dt_days)
convergence_md$final_position_error_au =
  format_numeric(convergence_md$final_position_error_au)
convergence_md$observed_order = ifelse(
  is.na(convergence_md$observed_order),
  "",
  format_numeric(convergence_md$observed_order, digits = 4)
)

earth_moon_md = earth_moon_summary_table
earth_moon_md$final_separation_au =
  format_numeric(earth_moon_md$final_separation_au)
earth_moon_md$final_energy_ratio =
  format_numeric(earth_moon_md$final_energy_ratio)
earth_moon_md$max_abs_energy_error =
  format_numeric(earth_moon_md$max_abs_energy_error)
earth_moon_md$max_abs_angular_momentum_drift =
  format_numeric(earth_moon_md$max_abs_angular_momentum_drift)

three_body_md = three_body_summary_table
three_body_md$years = format_numeric(three_body_md$years)
three_body_md$final_energy_ratio =
  format_numeric(three_body_md$final_energy_ratio)
three_body_md$max_abs_energy_error =
  format_numeric(three_body_md$max_abs_energy_error)
three_body_md$max_abs_angular_momentum_drift =
  format_numeric(three_body_md$max_abs_angular_momentum_drift)
three_body_md$max_pair_separation_error_au =
  format_numeric(three_body_md$max_pair_separation_error_au)

n_body_md = n_body_summary_table
n_body_md$years = format_numeric(n_body_md$years)
n_body_md$final_energy_ratio = format_numeric(n_body_md$final_energy_ratio)
n_body_md$max_abs_energy_error =
  format_numeric(n_body_md$max_abs_energy_error)
n_body_md$max_abs_angular_momentum_drift =
  format_numeric(n_body_md$max_abs_angular_momentum_drift)

benchmark_md = benchmark_table
benchmark_md$dt_days = format_numeric(benchmark_md$dt_days)
benchmark_md$runtime_seconds = format_numeric(benchmark_md$runtime_seconds)
benchmark_md$final_position_error_au =
  format_numeric(benchmark_md$final_position_error_au)
benchmark_md$error_per_second = format_numeric(benchmark_md$error_per_second)

generated_results = c(
  "This section is generated by `Rscript analysis/generate_results.R`.",
  "Do not edit the numeric tables by hand; regenerate them from the solver code.",
  "",
  "### Sun-Earth Method Summary",
  "",
  write_markdown_table(summary_md),
  "",
  "### Sun-Earth Convergence Summary",
  "",
  "Errors are measured against a one-year RK4 reference run with `N = 16000`.",
  "",
  write_markdown_table(convergence_md),
  "",
  "### Earth-Moon Method Summary",
  "",
  "The same two-body methods are run for ten lunar months with `N = 1000`.",
  "",
  write_markdown_table(earth_moon_md),
  "",
  "### Special Three-Body Conservation Summary",
  "",
  "These RK4 runs check whether known periodic configurations return close to their starting shape after one nominal period.",
  "",
  write_markdown_table(three_body_md),
  "",
  "### N-Body Conservation Summary",
  "",
  "The n-body cases report energy and angular-momentum drift for multi-body examples beyond the dedicated two- and three-body solvers.",
  "",
  write_markdown_table(n_body_md),
  "",
  "### Runtime and Accuracy Benchmark",
  "",
  "Runtime is measured for one-year Sun-Earth runs against the same fine RK4 reference used in the convergence table.",
  "",
  write_markdown_table(benchmark_md),
  "",
  "### Interpretation Notes",
  "",
  "- Energy and angular momentum drift are the main diagnostics for whether an orbit is physically credible over long horizons.",
  "- Euler is useful as a failure baseline: its first-order error produces visible orbital drift even when the trajectory still looks smooth.",
  "- RK4 gives the smallest local error in these examples, while Velocity Verlet is included because symplectic methods often preserve qualitative orbital behavior over long integrations.",
  "- Three-body periodic solutions are validation cases, not generic stability guarantees; the perturbation examples show how quickly nearby trajectories can diverge.",
  "",
  "### Generated Figures",
  "",
  "- `images/analysis/sun_earth_energy_error.png`",
  "- `images/analysis/sun_earth_angular_momentum_drift.png`",
  "- `images/analysis/convergence_rates.png`",
  "- `analysis/generated/earth_moon_method_summary.csv`",
  "- `analysis/generated/three_body_special_summary.csv`",
  "- `analysis/generated/n_body_conservation_summary.csv`",
  "- `analysis/generated/runtime_benchmark.csv`",
  "- `analysis/generated/plot_manifest.csv`",
  "- `analysis/generated/artifact_baseline.csv`",
  "- `analysis/generated/index.html`",
  "- `analysis/generated/method_comparison_dashboard.html`",
  "- `images/two_body/sun_earth/sun_earth_runge_kutta.html`",
  "- `images/three_body/special_solutions/three_earths.html`",
  "- `images/n_body/sun_earth_mars_jupiter.html`",
  "",
  "![Sun-Earth energy error](images/analysis/sun_earth_energy_error.png)",
  "",
  "![Sun-Earth angular momentum drift](images/analysis/sun_earth_angular_momentum_drift.png)",
  "",
  "![Convergence rates](images/analysis/convergence_rates.png)"
)

update_generated_results_section = function(path, generated_lines) {
  begin_marker = "<!-- BEGIN GENERATED ANALYSIS -->"
  end_marker = "<!-- END GENERATED ANALYSIS -->"
  lines = readLines(path, warn = FALSE)
  begin = match(begin_marker, lines)
  end = match(end_marker, lines)

  if (is.na(begin) || is.na(end) || begin >= end) {
    stop(sprintf("Missing or invalid generated analysis markers in %s.", path))
  }

  updated = c(
    lines[seq_len(begin)],
    generated_lines,
    lines[end:length(lines)]
  )
  writeLines(updated, path)
}

update_generated_results_section("RESULTS.md", generated_results)

dashboard_results = lapply(names(results_25y), function(method_name) {
  result = results_25y[[method_name]]
  idx = sample_indices(length(result$x_b), 700)
  list(
    name = method_name,
    color = method_colors[[method_name]],
    x = round(result$x_b[idx] / AU, 6),
    y = round(result$y_b[idx] / AU, 6),
    energy = round(relative_error_series(two_body_energy_series(result))[idx], 10),
    angularMomentum = round(
      relative_error_series(two_body_angular_momentum_series(result))[idx], 10
    )
  )
})

json_number_array = function(values) {
  paste(format(values, scientific = FALSE, trim = TRUE), collapse = ",")
}

json_methods = vapply(dashboard_results, function(item) {
  paste0(
    "{",
    "\"name\":\"", item$name, "\",",
    "\"color\":\"", item$color, "\",",
    "\"x\":[", json_number_array(item$x), "],",
    "\"y\":[", json_number_array(item$y), "],",
    "\"energy\":[", json_number_array(item$energy), "],",
    "\"angularMomentum\":[", json_number_array(item$angularMomentum), "]",
    "}"
  )
}, character(1))

dashboard_html = c(
  "<!doctype html>",
  "<html lang=\"en\">",
  "<head>",
  "  <meta charset=\"utf-8\">",
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "  <title>Celestial Dynamics Method Dashboard</title>",
  "  <style>",
  "    :root { color-scheme: light; --ink: #172033; --muted: #667085; --line: #d8dee6; --soft: #eef2f6; --panel: #ffffff; --paper: #f6f8fb; --accent: #0f766e; }",
  "    * { box-sizing: border-box; }",
  "    body { margin: 0; font-family: system-ui, -apple-system, Segoe UI, sans-serif; color: var(--ink); background: linear-gradient(180deg, #ffffff 0, var(--paper) 300px); }",
  "    header { display: grid; grid-template-columns: 1fr auto; gap: 18px; align-items: end; padding: 26px 32px 16px; border-bottom: 1px solid var(--line); background: rgba(255,255,255,.9); }",
  "    h1 { margin: 0 0 7px; font-size: 28px; line-height: 1.12; letter-spacing: 0; }",
  "    h2 { margin: 0; font-size: 16px; line-height: 1.2; letter-spacing: 0; }",
  "    p { margin: 0; color: var(--muted); }",
  "    main { display: grid; grid-template-columns: minmax(0, 1.45fr) minmax(360px, .95fr); gap: 18px; padding: 18px 32px 32px; }",
  "    .metric-strip { display: flex; gap: 10px; flex-wrap: wrap; justify-content: flex-end; }",
  "    .metric { min-width: 112px; padding: 8px 10px; border: 1px solid var(--line); border-radius: 8px; background: #fff; }",
  "    .metric span { display: block; color: var(--muted); font-size: 12px; }",
  "    .metric strong { display: block; margin-top: 2px; font-size: 18px; }",
  "    .panel { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; overflow: hidden; box-shadow: 0 12px 28px rgba(16, 24, 40, .06); }",
  "    .panel-header { display: flex; justify-content: space-between; gap: 12px; align-items: center; padding: 13px 15px; border-bottom: 1px solid var(--line); background: #fbfcfe; }",
  "    .panel-header span { color: var(--muted); font-size: 13px; }",
  "    .panel-body { padding: 14px; }",
  "    canvas { width: 100%; height: auto; display: block; border: 1px solid var(--soft); background: #ffffff; }",
  "    .toolbar { display: flex; gap: 8px; align-items: center; margin-bottom: 12px; flex-wrap: wrap; }",
  "    .button-group { display: inline-flex; gap: 6px; flex-wrap: wrap; }",
  "    button { border: 1px solid #aab3bf; background: #ffffff; color: var(--ink); border-radius: 6px; padding: 8px 11px; cursor: pointer; font: inherit; line-height: 1; }",
  "    button:hover { border-color: var(--accent); color: var(--accent); }",
  "    button:focus-visible, input:focus-visible { outline: 3px solid rgba(15,118,110,.22); outline-offset: 2px; }",
  "    button.active { background: var(--ink); color: #ffffff; border-color: var(--ink); }",
  "    button.secondary { color: var(--accent); border-color: rgba(15,118,110,.45); }",
  "    input[type=range] { width: min(520px, 52vw); accent-color: var(--accent); }",
  "    table { width: 100%; border-collapse: collapse; font-size: 14px; }",
  "    th, td { padding: 9px 8px; border-bottom: 1px solid var(--soft); text-align: right; }",
  "    th:first-child, td:first-child { text-align: left; }",
  "    th { color: var(--muted); font-weight: 700; background: #fbfcfe; }",
  "    tbody tr:nth-child(even) { background: #fbfcfe; }",
  "    tr.dimmed { color: #98a2b3; }",
  "    .legend { display: flex; gap: 10px 14px; flex-wrap: wrap; margin-top: 10px; }",
  "    .legend label { display: inline-flex; align-items: center; gap: 7px; cursor: pointer; font-size: 14px; }",
  "    .legend input { accent-color: var(--accent); }",
  "    .legend label:has(input:not(:checked)) { opacity: .48; }",
  "    .readout { margin: 10px 0 0; min-height: 22px; color: #344054; font-size: 14px; line-height: 1.5; }",
  "    .swatch { width: 12px; height: 12px; border-radius: 2px; display: inline-block; box-shadow: inset 0 0 0 1px rgba(23,32,51,.14); }",
  "    @media (max-width: 1000px) { main { grid-template-columns: 1fr; padding: 16px; } header { grid-template-columns: 1fr; padding: 22px 16px 14px; } .metric-strip { justify-content: flex-start; } input[type=range] { width: 100%; } }",
  "  </style>",
  "</head>",
  "<body>",
  "  <header>",
  "    <div>",
  "      <h1>Celestial Dynamics Method Dashboard</h1>",
  "      <p>Generated Sun-Earth comparison for Euler, Midpoint, Heun, RK4, and Verlet over 25 years.</p>",
  "    </div>",
  "    <div class=\"metric-strip\">",
  "      <div class=\"metric\"><span>Methods</span><strong>5</strong></div>",
  "      <div class=\"metric\"><span>Duration</span><strong>25 y</strong></div>",
  "      <div class=\"metric\"><span>Views</span><strong>3</strong></div>",
  "    </div>",
  "  </header>",
  "  <main>",
  "    <section class=\"panel\">",
  "      <div class=\"panel-header\"><h2>Orbit playback</h2><span>Sun-Earth comparison</span></div>",
  "      <div class=\"panel-body\">",
  "        <div class=\"toolbar\">",
  "          <div class=\"button-group\">",
  "            <button id=\"play\" class=\"active\">Pause</button>",
  "            <button data-speed=\"1\">1x</button>",
  "            <button data-speed=\"3\" class=\"active\">3x</button>",
  "            <button data-speed=\"8\">8x</button>",
  "          </div>",
  "          <button id=\"exportFrame\" class=\"secondary\">Export frame</button>",
  "          <input id=\"scrubber\" type=\"range\" min=\"0\" value=\"0\" aria-label=\"Dashboard frame\">",
  "        </div>",
  "        <canvas id=\"orbit\" width=\"900\" height=\"650\"></canvas>",
  "        <div id=\"readout\" class=\"readout\"></div>",
  "        <div id=\"legend\" class=\"legend\"></div>",
  "      </div>",
  "    </section>",
  "    <section class=\"panel\">",
  "      <div class=\"panel-header\"><h2>Conservation diagnostics</h2><span>relative drift</span></div>",
  "      <div class=\"panel-body\">",
  "        <canvas id=\"energy\" width=\"620\" height=\"300\"></canvas>",
  "        <canvas id=\"momentum\" width=\"620\" height=\"300\" style=\"margin-top: 14px;\"></canvas>",
  "      </div>",
  "      <div class=\"panel-header\"><h2>25-Year Summary</h2><span>visible rows track legend</span></div>",
  "      <div class=\"panel-body\" style=\"padding-top:0;\">",
  "        <table>",
  "          <thead><tr><th>Method</th><th>Energy ratio</th><th>Max |energy err|</th><th>Max |L drift|</th></tr></thead>",
  "          <tbody>",
  paste0(
    "            <tr data-method=\"", summary_table$method, "\"><td>", summary_table$method, "</td><td>",
    format_numeric(summary_table$final_energy_ratio), "</td><td>",
    format_numeric(summary_table$max_abs_energy_error), "</td><td>",
    format_numeric(summary_table$max_abs_angular_momentum_drift), "</td></tr>"
  ),
  "          </tbody>",
  "        </table>",
  "      </div>",
  "    </section>",
  "  </main>",
  "  <script>",
  "    const methods = [",
  paste0("      ", paste(json_methods, collapse = ",\n      ")),
  "    ];",
  "    const orbit = document.getElementById('orbit');",
  "    const orbitCtx = orbit.getContext('2d');",
  "    const energy = document.getElementById('energy');",
  "    const energyCtx = energy.getContext('2d');",
  "    const momentum = document.getElementById('momentum');",
  "    const momentumCtx = momentum.getContext('2d');",
  "    const play = document.getElementById('play');",
  "    const scrubber = document.getElementById('scrubber');",
  "    const readout = document.getElementById('readout');",
  "    const exportFrame = document.getElementById('exportFrame');",
  "    let frame = 0, running = true, speed = 3;",
  "    const visible = Object.fromEntries(methods.map(m => [m.name, true]));",
  "    scrubber.max = methods[0].x.length - 1;",
  "    document.querySelectorAll('[data-speed]').forEach(button => {",
  "      button.addEventListener('click', () => {",
  "        speed = Number(button.dataset.speed);",
  "        document.querySelectorAll('[data-speed]').forEach(b => b.classList.remove('active'));",
  "        button.classList.add('active');",
  "      });",
  "    });",
  "    play.addEventListener('click', () => {",
  "      running = !running;",
  "      play.textContent = running ? 'Pause' : 'Play';",
  "      play.classList.toggle('active', running);",
  "    });",
  "    scrubber.addEventListener('input', () => { frame = Number(scrubber.value); running = false; play.textContent = 'Play'; play.classList.remove('active'); drawOrbit(); drawCharts(); });",
  "    exportFrame.addEventListener('click', () => {",
  "      const link = document.createElement('a');",
  "      link.download = `sun-earth-frame-${String(frame).padStart(4, '0')}.png`;",
  "      link.href = orbit.toDataURL('image/png');",
  "      link.click();",
  "    });",
  "    document.getElementById('legend').innerHTML = methods.map(m => `<label><input type=\"checkbox\" data-method=\"${m.name}\" checked><i class=\"swatch\" style=\"background:${m.color}\"></i>${m.name}</label>`).join('');",
  "    document.querySelectorAll('#legend input[data-method]').forEach(input => {",
  "      input.addEventListener('change', () => {",
  "        visible[input.dataset.method] = input.checked;",
  "        document.querySelectorAll('tr[data-method]').forEach(row => row.classList.toggle('dimmed', !visible[row.dataset.method]));",
  "        drawOrbit(); drawCharts();",
  "      });",
  "    });",
  "    function bounds() {",
  "      const xs = methods.flatMap(m => m.x), ys = methods.flatMap(m => m.y);",
  "      return { minX: Math.min(...xs), maxX: Math.max(...xs), minY: Math.min(...ys), maxY: Math.max(...ys) };",
  "    }",
  "    const b = bounds();",
  "    function project(x, y) {",
  "      const pad = 55;",
  "      const scale = Math.min((orbit.width - 2 * pad) / (b.maxX - b.minX), (orbit.height - 2 * pad) / (b.maxY - b.minY));",
  "      return [pad + (x - b.minX) * scale, orbit.height - pad - (y - b.minY) * scale];",
  "    }",
  "    function drawOrbit() {",
  "      orbitCtx.clearRect(0, 0, orbit.width, orbit.height);",
  "      orbitCtx.fillStyle = '#f8fafc';",
  "      orbitCtx.fillRect(0, 0, orbit.width, orbit.height);",
  "      const [sx, sy] = project(0, 0);",
  "      orbitCtx.fillStyle = '#c2410c';",
  "      orbitCtx.beginPath();",
  "      orbitCtx.arc(sx, sy, 7, 0, Math.PI * 2);",
  "      orbitCtx.fill();",
  "      methods.forEach(m => {",
  "        if (!visible[m.name]) return;",
  "        orbitCtx.strokeStyle = m.color;",
  "        orbitCtx.lineWidth = 2;",
  "        orbitCtx.beginPath();",
  "        for (let i = 0; i <= frame; i++) {",
  "          const [x, y] = project(m.x[i], m.y[i]);",
  "          if (i === 0) orbitCtx.moveTo(x, y); else orbitCtx.lineTo(x, y);",
  "        }",
  "        orbitCtx.stroke();",
  "        const [px, py] = project(m.x[frame], m.y[frame]);",
  "        orbitCtx.fillStyle = m.color;",
  "        orbitCtx.beginPath();",
  "        orbitCtx.arc(px, py, 5, 0, Math.PI * 2);",
  "        orbitCtx.fill();",
  "      });",
  "      orbitCtx.fillStyle = '#172033';",
  "      orbitCtx.fillText(`${(25 * frame / (methods[0].x.length - 1)).toFixed(2)} years`, 18, 28);",
  "      scrubber.value = frame;",
  "      const selected = methods.filter(m => visible[m.name]).map(m => `${m.name}: (${m.x[frame].toFixed(3)}, ${m.y[frame].toFixed(3)}) AU`);",
  "      readout.textContent = selected.join('   |   ');",
  "    }",
  "    function chart(ctx, key, title) {",
  "      ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);",
  "      ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);",
  "      const values = methods.flatMap(m => m[key]);",
  "      const min = Math.min(...values), max = Math.max(...values);",
  "      const pad = 42;",
  "      ctx.fillStyle = '#172033'; ctx.fillText(title, 16, 22);",
  "      ctx.strokeStyle = '#d8dee6'; ctx.strokeRect(pad, pad, ctx.canvas.width - 2 * pad, ctx.canvas.height - 2 * pad);",
  "      methods.forEach(m => {",
  "        if (!visible[m.name]) return;",
  "        ctx.strokeStyle = m.color; ctx.lineWidth = 2; ctx.beginPath();",
  "        m[key].forEach((value, i) => {",
  "          const x = pad + i * (ctx.canvas.width - 2 * pad) / (m[key].length - 1);",
  "          const y = ctx.canvas.height - pad - (value - min) * (ctx.canvas.height - 2 * pad) / (max - min || 1);",
  "          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);",
  "        });",
  "        ctx.stroke();",
  "      });",
  "      const cursorX = pad + frame * (ctx.canvas.width - 2 * pad) / (methods[0][key].length - 1);",
  "      ctx.strokeStyle = '#667085'; ctx.lineWidth = 1; ctx.setLineDash([4, 4]);",
  "      ctx.beginPath(); ctx.moveTo(cursorX, pad); ctx.lineTo(cursorX, ctx.canvas.height - pad); ctx.stroke(); ctx.setLineDash([]);",
  "    }",
  "    function drawCharts() {",
  "      chart(energyCtx, 'energy', 'Relative energy error');",
  "      chart(momentumCtx, 'angularMomentum', 'Relative angular momentum drift');",
  "    }",
  "    function tick() {",
  "      if (running) frame = (frame + speed) % methods[0].x.length;",
  "      drawOrbit();",
  "      drawCharts();",
  "      requestAnimationFrame(tick);",
  "    }",
  "    tick();",
  "  </script>",
  "</body>",
  "</html>"
)
writeLines(dashboard_html, dashboard_path)

plot_manifest = if (file.exists(cd_plot_manifest_path)) {
  read.csv(cd_plot_manifest_path, stringsAsFactors = FALSE)
} else {
  cd_empty_manifest()
}
plot_manifest = plot_manifest[order(plot_manifest$plot_type,
                                    plot_manifest$filepath), ]

html_escape = function(value) {
  value = as.character(value)
  value[is.na(value)] = ""
  value = gsub("&", "&amp;", value, fixed = TRUE)
  value = gsub("<", "&lt;", value, fixed = TRUE)
  value = gsub(">", "&gt;", value, fixed = TRUE)
  value = gsub("\"", "&quot;", value, fixed = TRUE)
  value
}

manifest_cell = function(row, name) {
  value = row[[name]]
  if (is.null(value) || is.na(value) || value == "NA") {
    return("")
  }
  html_escape(value)
}

png_count = sum(plot_manifest$artifact_type == "png", na.rm = TRUE)
html_count = sum(plot_manifest$artifact_type == "html", na.rm = TRUE)
csv_count = length(list.files(generated_dir, pattern = "\\.csv$"))

manifest_rows = if (nrow(plot_manifest) > 0) {
  apply(plot_manifest, 1, function(row) {
    href = row[["filepath"]]
    title = manifest_cell(row, "title")
    if (!nzchar(title)) {
      title = html_escape(basename(href))
    }
    type = manifest_cell(row, "artifact_type")
    kind = if (type == "html") {
      "animation"
    } else if (type == "png") {
      "plot"
    } else {
      "artifact"
    }
    plot_type = manifest_cell(row, "plot_type")
    method = manifest_cell(row, "method")
    steps = manifest_cell(row, "steps")
    energy_ratio = manifest_cell(row, "energy_ratio")
    href_display = html_escape(href)
    href_target = html_escape(paste0("../../", href))
    paste0(
      "<tr data-kind=\"", kind, "\" data-type=\"", plot_type, "\">",
      "<td><a class=\"artifact-link\" href=\"", href_target, "\">",
      html_escape(basename(href)), "</a><span class=\"path\">", href_display,
      "</span></td>",
      "<td><span class=\"tag\">", plot_type, "</span></td>",
      "<td>", method, "</td>",
      "<td>", steps, "</td>",
      "<td>", energy_ratio, "</td>",
      "<td>", title, "</td></tr>"
    )
  })
} else {
  "<tr><td colspan=\"6\">No plot manifest rows found.</td></tr>"
}

index_path = file.path(generated_dir, "index.html")
index_html = c(
  "<!doctype html>",
  "<html lang=\"en\">",
  "<head>",
  "  <meta charset=\"utf-8\">",
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "  <title>Celestial Dynamics Results Index</title>",
  "  <style>",
  "    :root { color-scheme: light; --ink: #172033; --muted: #667085; --line: #d8dee6; --soft: #eef2f6; --panel: #ffffff; --paper: #f6f8fb; --accent: #0f766e; }",
  "    * { box-sizing: border-box; }",
  "    body { margin: 0; font-family: system-ui, -apple-system, Segoe UI, sans-serif; color: var(--ink); background: linear-gradient(180deg, #ffffff 0, var(--paper) 300px); }",
  "    main { max-width: 1220px; margin: 0 auto; padding: 26px 24px 34px; }",
  "    header { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 18px; align-items: end; margin-bottom: 18px; }",
  "    h1 { margin: 0 0 7px; font-size: 30px; line-height: 1.1; letter-spacing: 0; }",
  "    p { margin: 0; color: var(--muted); }",
  "    .metric-strip { display: flex; gap: 10px; flex-wrap: wrap; justify-content: flex-end; }",
  "    .metric { min-width: 112px; padding: 9px 11px; border: 1px solid var(--line); border-radius: 8px; background: #fff; }",
  "    .metric span { display: block; color: var(--muted); font-size: 12px; }",
  "    .metric strong { display: block; margin-top: 2px; font-size: 19px; }",
  "    .links { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 16px; }",
  "    a.button { border: 1px solid #aab3bf; background: #fff; border-radius: 6px; padding: 8px 11px; text-decoration: none; color: var(--ink); line-height: 1; }",
  "    a.button:hover { border-color: var(--accent); color: var(--accent); }",
  "    .panel { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; overflow: hidden; box-shadow: 0 12px 28px rgba(16, 24, 40, .06); }",
  "    .toolbar { display: flex; justify-content: space-between; gap: 12px; flex-wrap: wrap; align-items: center; padding: 13px 15px; border-bottom: 1px solid var(--line); background: #fbfcfe; }",
  "    .filters { display: inline-flex; gap: 6px; flex-wrap: wrap; }",
  "    button { border: 1px solid #aab3bf; background: #fff; color: var(--ink); border-radius: 6px; padding: 8px 11px; cursor: pointer; font: inherit; line-height: 1; }",
  "    button:hover { border-color: var(--accent); color: var(--accent); }",
  "    button.active { background: var(--ink); color: #fff; border-color: var(--ink); }",
  "    input[type=search] { width: min(340px, 100%); border: 1px solid #aab3bf; border-radius: 6px; padding: 8px 10px; font: inherit; }",
  "    input:focus-visible, button:focus-visible, a.button:focus-visible { outline: 3px solid rgba(15,118,110,.22); outline-offset: 2px; }",
  "    .result-count { color: var(--muted); font-size: 13px; }",
  "    table { width: 100%; border-collapse: collapse; background: #fff; }",
  "    th, td { border-bottom: 1px solid var(--soft); padding: 10px 9px; text-align: left; vertical-align: top; }",
  "    th { background: #fbfcfe; color: var(--muted); font-size: 13px; }",
  "    td { font-size: 14px; }",
  "    tbody tr:nth-child(even) { background: #fbfcfe; }",
  "    .artifact-link { color: var(--ink); font-weight: 700; text-decoration-color: rgba(15,118,110,.45); text-underline-offset: 3px; }",
  "    .path { display: block; margin-top: 4px; color: var(--muted); font-size: 12px; overflow-wrap: anywhere; }",
  "    .tag { display: inline-flex; align-items: center; border: 1px solid var(--line); border-radius: 999px; padding: 3px 8px; background: #fff; color: #344054; font-size: 12px; }",
  "    tr.hidden { display: none; }",
  "    @media (max-width: 800px) { main { padding: 18px 16px 28px; } header { grid-template-columns: 1fr; } .metric-strip { justify-content: flex-start; } .toolbar { align-items: stretch; } input[type=search] { width: 100%; } }",
  "  </style>",
  "</head>",
  "<body>",
  "  <main>",
  "    <header>",
  "      <div>",
  "        <h1>Celestial Dynamics Results Index</h1>",
  "        <p>Generated plots, animations, diagnostics, and data exports for the repository examples.</p>",
  "      </div>",
  "      <div class=\"metric-strip\">",
  paste0("        <div class=\"metric\"><span>Plots</span><strong>", png_count, "</strong></div>"),
  paste0("        <div class=\"metric\"><span>Animations</span><strong>", html_count, "</strong></div>"),
  paste0("        <div class=\"metric\"><span>Data files</span><strong>", csv_count, "</strong></div>"),
  "      </div>",
  "    </header>",
  "    <div class=\"links\">",
  "      <a class=\"button\" href=\"method_comparison_dashboard.html\">Method dashboard</a>",
  "      <a class=\"button\" href=\"method_summary.csv\">Sun-Earth summary CSV</a>",
  "      <a class=\"button\" href=\"earth_moon_method_summary.csv\">Earth-Moon summary CSV</a>",
  "      <a class=\"button\" href=\"runtime_benchmark.csv\">Runtime benchmark CSV</a>",
  "      <a class=\"button\" href=\"plot_manifest.csv\">Plot manifest CSV</a>",
  "    </div>",
  "    <section class=\"panel\">",
  "      <div class=\"toolbar\">",
  "        <div class=\"filters\" aria-label=\"Artifact filters\">",
  "          <button class=\"active\" data-filter=\"all\">All</button>",
  "          <button data-filter=\"plot\">Plots</button>",
  "          <button data-filter=\"animation\">Animations</button>",
  "        </div>",
  "        <input id=\"search\" type=\"search\" placeholder=\"Search artifacts\" aria-label=\"Search artifacts\">",
  "        <span id=\"resultCount\" class=\"result-count\"></span>",
  "      </div>",
  "      <table>",
  "        <thead><tr><th>Artifact</th><th>Type</th><th>Method</th><th>Steps</th><th>Energy ratio</th><th>Title</th></tr></thead>",
  "        <tbody>",
  manifest_rows,
  "        </tbody>",
  "      </table>",
  "    </section>",
  "  </main>",
  "  <script>",
  "    const rows = Array.from(document.querySelectorAll('tbody tr[data-kind]'));",
  "    const search = document.getElementById('search');",
  "    const resultCount = document.getElementById('resultCount');",
  "    let filter = 'all';",
  "    function applyFilters() {",
  "      const query = search.value.trim().toLowerCase();",
  "      let visible = 0;",
  "      rows.forEach(row => {",
  "        const matchesKind = filter === 'all' || row.dataset.kind === filter;",
  "        const matchesQuery = !query || row.textContent.toLowerCase().includes(query);",
  "        const show = matchesKind && matchesQuery;",
  "        row.classList.toggle('hidden', !show);",
  "        if (show) visible += 1;",
  "      });",
  "      resultCount.textContent = `${visible} of ${rows.length} artifacts`;",
  "    }",
  "    document.querySelectorAll('[data-filter]').forEach(button => {",
  "      button.addEventListener('click', () => {",
  "        filter = button.dataset.filter;",
  "        document.querySelectorAll('[data-filter]').forEach(item => item.classList.remove('active'));",
  "        button.classList.add('active');",
  "        applyFilters();",
  "      });",
  "    });",
  "    search.addEventListener('input', applyFilters);",
  "    applyFilters();",
  "  </script>",
  "</body>",
  "</html>"
)
writeLines(index_html, index_path)

cat("Generated analysis artifacts:\n")
cat(sprintf("- %s\n", file.path(generated_dir, "method_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "convergence_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "earth_moon_method_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "three_body_special_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "n_body_conservation_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "runtime_benchmark.csv")))
cat(sprintf("- %s\n", cd_plot_manifest_path))
cat("- RESULTS.md generated analysis section\n")
cat(sprintf("- %s\n", dashboard_path))
cat(sprintf("- %s\n", index_path))
cat(sprintf("- %s\n", analysis_image_dir))
