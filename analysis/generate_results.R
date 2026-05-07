if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_load_two_body()
cd_load_plotting()
cd_load_three_body()
cd_load_n_body()

generated_dir = "analysis/generated"
analysis_image_dir = "images/analysis"
dashboard_path = file.path(generated_dir, "method_comparison_dashboard.html")
package_url = "https://sidrichardsquantum.r-universe.dev/CelestialDynamicsIterationMethods"
doc_link_map = c(
  "README.md" = "readme.html",
  "docs/USAGE.md" = "usage.html",
  "docs/THEORY.md" = "theory.html",
  "docs/RESULTS.md" = "index.html",
  "docs/R_UNIVERSE.md" = "r-universe.html",
  "analysis/README.md" = "analysis.html",
  "examples/README.md" = "examples.html",
  "examples/three_body/README.md" = "three-body-examples.html"
)
current_markdown_dir = "."

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
  "- `analysis/generated/artifact_index.html`",
  "- `analysis/generated/method_comparison_dashboard.html`",
  "- `images/two_body/sun_earth/sun_earth_runge_kutta.html`",
  "- `images/three_body/special_solutions/three_earths.html`",
  "- `images/n_body/sun_earth_mars_jupiter.html`",
  "",
  "![Sun-Earth energy error](../images/analysis/sun_earth_energy_error.png)",
  "",
  "![Sun-Earth angular momentum drift](../images/analysis/sun_earth_angular_momentum_drift.png)",
  "",
  "![Convergence rates](../images/analysis/convergence_rates.png)"
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

update_generated_results_section("docs/RESULTS.md", generated_results)

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

portfolio_css = function(extra = character()) {
  c(
    "    :root {",
    "      color-scheme: light dark;",
    "      --bg: #f7f7f4;",
    "      --surface: #ffffff;",
    "      --surface-muted: #ededeb;",
    "      --text: #1d2328;",
    "      --muted: #5b6670;",
    "      --line: #d7d9d6;",
    "      --accent: #126c83;",
    "      --accent-strong: #0f5364;",
    "      --accent-soft: #dceff3;",
    "      --code-bg: #eef2f1;",
    "      --shadow: 0 18px 45px rgba(34, 41, 47, 0.08);",
    "      --shadow-soft: 0 10px 30px rgba(34, 41, 47, 0.06);",
    "    }",
    "    @media (prefers-color-scheme: dark) {",
    "      :root {",
    "        --bg: #101416;",
    "        --surface: #171d20;",
    "        --surface-muted: #20282b;",
    "        --text: #edf1f2;",
    "        --muted: #a9b4b8;",
    "        --line: #2e393d;",
    "        --accent: #66c5d7;",
    "        --accent-strong: #9eddea;",
    "        --accent-soft: #17333a;",
    "        --code-bg: #11191c;",
    "        --shadow: 0 18px 45px rgba(0, 0, 0, 0.25);",
    "        --shadow-soft: 0 10px 30px rgba(0, 0, 0, 0.18);",
    "      }",
    "    }",
    "    * { box-sizing: border-box; }",
    "    html { scroll-behavior: smooth; }",
    "    body {",
    "      margin: 0;",
    "      background: var(--bg);",
    "      color: var(--text);",
    "      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;",
    "      line-height: 1.6;",
    "      text-rendering: optimizeLegibility;",
    "    }",
    "    a { color: inherit; text-decoration-color: color-mix(in srgb, var(--accent) 65%, transparent); text-underline-offset: 0.2em; }",
    "    a:hover { color: var(--accent-strong); }",
    "    a:focus-visible, button:focus-visible, input:focus-visible, main:focus-visible { outline: 3px solid var(--accent); outline-offset: 4px; }",
    "    .skip-link {",
    "      position: fixed; top: 0.75rem; left: 0.75rem; z-index: 20;",
    "      transform: translateY(-150%); border: 1px solid var(--accent-strong);",
    "      border-radius: 8px; padding: 0.65rem 0.9rem; background: var(--surface);",
    "      color: var(--accent-strong); font-weight: 800; text-decoration: none;",
    "      box-shadow: var(--shadow); transition: transform 160ms ease;",
    "    }",
    "    .skip-link:focus-visible { transform: translateY(0); }",
    "    .site-header {",
    "      position: sticky; top: 0; z-index: 10; display: flex; align-items: center;",
    "      justify-content: space-between; gap: 1.5rem; padding: 1rem clamp(1rem, 4vw, 3rem);",
    "      border-bottom: 1px solid var(--line); background: color-mix(in srgb, var(--bg) 88%, transparent);",
    "      backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px);",
    "    }",
    "    .brand { display: inline-flex; align-items: center; gap: 0.7rem; font-weight: 700; text-decoration: none; }",
    "    .brand-mark {",
    "      display: inline-grid; width: 2.2rem; height: 2.2rem; place-items: center;",
    "      border: 1px solid var(--line); border-radius: 8px; background: var(--surface);",
    "      color: var(--accent-strong); font-size: 0.82rem; letter-spacing: 0;",
    "    }",
    "    .nav-links { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 0.35rem 1rem; color: var(--muted); font-size: 0.95rem; }",
    "    .nav-links a { border-radius: 6px; padding: 0.15rem 0; text-decoration: none; }",
    "    .eyebrow { margin: 0 0 0.75rem; color: var(--accent-strong); font-size: 0.78rem; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; }",
    "    .button, button, a.button {",
    "      display: inline-flex; min-height: 2.75rem; align-items: center; justify-content: center;",
    "      border: 1px solid var(--line); border-radius: 8px; padding: 0.72rem 1rem;",
    "      background: var(--surface); color: var(--text); font: inherit; font-weight: 700;",
    "      line-height: 1; text-decoration: none; cursor: pointer; box-shadow: 0 1px 0 rgba(0, 0, 0, 0.03);",
    "      transition: color 160ms ease, border-color 160ms ease, background-color 160ms ease, transform 160ms ease;",
    "    }",
    "    .button.primary, button.active { border-color: var(--accent-strong); background: var(--accent-strong); color: #ffffff; }",
    "    .button:hover, button:hover, a.button:hover { transform: translateY(-1px); border-color: var(--accent); color: var(--accent-strong); }",
    "    button.active:hover { color: #ffffff; }",
    "    button.secondary { color: var(--accent-strong); border-color: color-mix(in srgb, var(--accent) 45%, var(--line)); }",
    "    .section { width: min(1120px, calc(100% - 2rem)); margin: 0 auto; padding: clamp(3rem, 8vw, 6rem) 0; scroll-margin-top: 6rem; }",
    "    .page-hero { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: end; gap: 1.5rem; border-bottom: 1px solid var(--line); padding-bottom: 2rem; }",
    "    .page-hero h1 { margin: 0; font-size: clamp(2.6rem, 8vw, 5.8rem); line-height: 0.95; letter-spacing: 0; }",
    "    .page-hero p { max-width: 760px; margin: 1rem 0 0; color: var(--muted); font-size: clamp(1rem, 2vw, 1.2rem); }",
    "    .metric-strip { display: flex; gap: 0.75rem; flex-wrap: wrap; justify-content: flex-end; }",
    "    .metric { min-width: 7rem; border: 1px solid var(--line); border-radius: 8px; padding: 0.8rem 0.9rem; background: var(--surface); box-shadow: var(--shadow-soft); }",
    "    .metric span { display: block; color: var(--muted); font-size: 0.76rem; font-weight: 700; }",
    "    .metric strong { display: block; margin-top: 0.1rem; font-size: 1.2rem; line-height: 1.1; }",
    "    .panel, .project-card { border: 1px solid var(--line); border-radius: 8px; background: var(--surface); box-shadow: var(--shadow-soft); }",
    "    .panel { overflow: hidden; }",
    "    .panel:hover, .panel:focus-within, .project-card:hover, .project-card:focus-within { border-color: color-mix(in srgb, var(--accent) 45%, var(--line)); box-shadow: var(--shadow); }",
    "    .panel-header, .toolbar { display: flex; justify-content: space-between; gap: 0.75rem; align-items: center; border-bottom: 1px solid var(--line); padding: 0.85rem 1rem; background: var(--surface-muted); }",
    "    .panel-header span, .result-count, .readout, figcaption, .path, p, li { color: var(--muted); }",
    "    .panel-body { padding: 1rem; }",
    "    .links, .toolbar, .button-group, .filters, .legend { display: flex; flex-wrap: wrap; gap: 0.65rem; align-items: center; }",
    "    .links { margin: 1.5rem 0; }",
    "    h2 { letter-spacing: 0; }",
    "    h3 { line-height: 1.25; }",
    "    code { display: inline-block; max-width: 100%; border: 1px solid var(--line); border-radius: 8px; padding: 0.1rem 0.35rem; background: var(--code-bg); color: var(--text); font-family: \"SFMono-Regular\", Consolas, \"Liberation Mono\", monospace; font-size: 0.9em; }",
    "    pre { overflow-x: auto; border: 1px solid var(--line); border-radius: 8px; padding: 1rem; background: var(--code-bg); }",
    "    pre code { border: 0; padding: 0; background: transparent; }",
    "    table { width: 100%; border-collapse: collapse; background: var(--surface); }",
    "    th, td { border-bottom: 1px solid var(--line); padding: 0.65rem 0.6rem; vertical-align: top; }",
    "    th { color: var(--muted); font-size: 0.82rem; text-align: left; background: var(--surface-muted); }",
    "    tbody tr:nth-child(even) { background: color-mix(in srgb, var(--surface-muted) 60%, transparent); }",
    "    tr:last-child td { border-bottom: 0; }",
    "    .table-wrap { overflow-x: auto; margin: 1rem 0 1.25rem; border: 1px solid var(--line); border-radius: 8px; }",
    "    .tag { display: inline-flex; align-items: center; border: 1px solid var(--line); border-radius: 999px; padding: 0.22rem 0.55rem; background: var(--surface-muted); color: var(--muted); font-size: 0.78rem; font-weight: 700; }",
    "    input[type=search] { width: min(340px, 100%); border: 1px solid var(--line); border-radius: 8px; padding: 0.7rem 0.8rem; background: var(--surface); color: var(--text); font: inherit; }",
    "    input[type=range] { accent-color: var(--accent); }",
    "    canvas, img { max-width: 100%; border: 1px solid var(--line); border-radius: 8px; background: #ffffff; }",
    "    .badge-image { border: 0; border-radius: 0; background: transparent; vertical-align: middle; }",
    "    canvas { width: 100%; height: auto; display: block; }",
    "    figure { margin: 1.25rem 0 1.6rem; }",
    "    figcaption { margin-top: 0.45rem; font-size: 0.82rem; }",
    "    .swatch { width: 0.75rem; height: 0.75rem; border-radius: 2px; display: inline-block; box-shadow: inset 0 0 0 1px rgba(29, 35, 40, .14); }",
    "    tr.hidden { display: none; }",
    "    tr.dimmed { opacity: .48; }",
    "    @media (max-width: 880px) { .page-hero { grid-template-columns: 1fr; } .metric-strip { justify-content: flex-start; } }",
    "    @media (max-width: 620px) { .site-header { align-items: flex-start; flex-direction: column; gap: 0.75rem; } .nav-links { justify-content: flex-start; } .section { width: min(100% - 1rem, 1120px); padding: clamp(2.5rem, 12vw, 4rem) 0; } .button, button, a.button { width: 100%; } }",
    "    @media (prefers-reduced-motion: reduce) { *, *::before, *::after { scroll-behavior: auto !important; transition-duration: 0.01ms !important; animation-duration: 0.01ms !important; animation-iteration-count: 1 !important; } .button:hover, button:hover, a.button:hover { transform: none; } }",
    extra
  )
}

dashboard_html = c(
  "<!doctype html>",
  "<html lang=\"en\">",
  "<head>",
  "  <meta charset=\"utf-8\">",
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "  <title>Celestial Dynamics Method Dashboard</title>",
  "  <style>",
  portfolio_css(c(
  "    .dashboard-grid { display: grid; grid-template-columns: minmax(0, 1.45fr) minmax(360px, .95fr); gap: 1rem; padding-top: 1.5rem; }",
  "    .dashboard-grid h2 { margin: 0; font-size: 1rem; line-height: 1.2; }",
  "    .toolbar { margin-bottom: 0.75rem; border: 0; padding: 0; background: transparent; justify-content: flex-start; }",
  "    .legend label { display: inline-flex; align-items: center; gap: 0.45rem; cursor: pointer; font-size: 0.9rem; }",
  "    .legend input { accent-color: var(--accent); }",
  "    .legend label:has(input:not(:checked)) { opacity: .48; }",
  "    .readout { margin: 0.75rem 0 0; min-height: 1.4rem; font-size: 0.9rem; }",
  "    .summary-table th, .summary-table td { text-align: right; }",
  "    .summary-table th:first-child, .summary-table td:first-child { text-align: left; }",
  "    @media (max-width: 1000px) { .dashboard-grid { grid-template-columns: 1fr; } input[type=range] { width: 100%; } }"
  )),
  "  </style>",
  "</head>",
  "<body>",
  "  <a class=\"skip-link\" href=\"#top\">Skip to main content</a>",
  "  <header class=\"site-header\">",
  "    <a class=\"brand\" href=\"index.html\" aria-label=\"Celestial Dynamics home\"><span class=\"brand-mark\">SR</span><span>Celestial Dynamics</span></a>",
  "    <nav class=\"nav-links\" aria-label=\"Primary navigation\">",
    "      <a href=\"index.html\">Results</a>",
    "      <a href=\"method_comparison_dashboard.html\">Dashboard</a>",
    "      <a href=\"artifact_index.html\">Artifacts</a>",
    "      <a href=\"docs.html\">Docs</a>",
    paste0("      <a href=\"", package_url, "\">Package</a>"),
    "      <a href=\"readme.html\">README</a>",
  "    </nav>",
  "  </header>",
  "  <main id=\"top\" tabindex=\"-1\" class=\"section\">",
  "    <section class=\"page-hero\">",
  "      <div>",
  "        <p class=\"eyebrow\">Interactive analysis</p>",
  "      <h1>Celestial Dynamics Method Dashboard</h1>",
  "      <p>Generated Sun-Earth comparison for Euler, Midpoint, Heun, RK4, and Verlet over 25 years.</p>",
  "      </div>",
  "      <div class=\"metric-strip\">",
  "      <div class=\"metric\"><span>Methods</span><strong>5</strong></div>",
  "      <div class=\"metric\"><span>Duration</span><strong>25 y</strong></div>",
  "      <div class=\"metric\"><span>Views</span><strong>3</strong></div>",
  "      </div>",
  "    </section>",
  "    <div class=\"dashboard-grid\">",
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
  "        <table class=\"summary-table\">",
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
  "    </div>",
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

html_escape = function(value) {
  value = as.character(value)
  value[is.na(value)] = ""
  value = gsub("&", "&amp;", value, fixed = TRUE)
  value = gsub("<", "&lt;", value, fixed = TRUE)
  value = gsub(">", "&gt;", value, fixed = TRUE)
  value = gsub("\"", "&quot;", value, fixed = TRUE)
  value
}

site_relative_path = function(path) {
  if (grepl("^(https?:|mailto:|#)", path)) {
    return(path)
  }

  normalized = path
  if (!startsWith(normalized, "/")) {
    if (!identical(current_markdown_dir, ".")) {
      normalized = file.path(current_markdown_dir, normalized)
    }
    normalized = gsub("\\\\", "/", normalized)
    normalized = gsub("/\\./", "/", normalized)
    while (grepl("(^|/)[^/]+/\\.\\./", normalized)) {
      normalized = sub("(^|/)[^/]+/\\.\\./", "\\1", normalized)
    }
    normalized = sub("^\\./", "", normalized)
    while (startsWith(normalized, "../")) {
      normalized = sub("^\\.\\./", "", normalized)
    }
  }

  if (normalized %in% names(doc_link_map)) {
    return(unname(doc_link_map[[normalized]]))
  }
  if (startsWith(normalized, "analysis/generated/")) {
    return(sub("^analysis/generated/", "", normalized))
  }
  if (startsWith(normalized, "images/")) {
    return(paste0("../../", normalized))
  }
  paste0("../../", normalized)
}

render_inline_text = function(text) {
  escaped = html_escape(text)
  escaped = gsub("`([^`]+)`", "<code>\\1</code>", escaped, perl = TRUE)
  escaped = gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", escaped,
                 perl = TRUE)
  escaped
}

render_markdown_links_and_images = function(text) {
  pattern = "(!?)\\[([^]]*)\\]\\(([^)]+)\\)"
  matches = gregexpr(pattern, text, perl = TRUE)[[1]]
  if (matches[1] == -1) {
    return(render_inline_text(text))
  }

  captures = regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1]]
  starts = as.integer(matches)
  lengths = attr(matches, "match.length")
  output = character(0)
  cursor = 1

  for (i in seq_along(captures)) {
    start = starts[i]
    finish = start + lengths[i] - 1
    if (start > cursor) {
      output = c(output, render_inline_text(substr(text, cursor, start - 1)))
    }
    parts = regexec(pattern, captures[i], perl = TRUE)
    values = regmatches(captures[i], parts)[[1]]
    is_image = identical(values[2], "!")
    label = values[3]
    target = html_escape(site_relative_path(values[4]))
    if (is_image) {
      output = c(output, paste0(
        "<img class=\"badge-image\" src=\"", target, "\" alt=\"",
        html_escape(label), "\">"
      ))
    } else {
      output = c(output, paste0(
        "<a href=\"", target, "\">", render_inline_text(label), "</a>"
      ))
    }
    cursor = finish + 1
  }

  if (cursor <= nchar(text)) {
    output = c(output, render_inline_text(substr(text, cursor, nchar(text))))
  }

  paste0(output, collapse = "")
}

render_inline_markdown = function(text) {
  linked_image_pattern = "\\[!\\[([^]]*)\\]\\(([^)]+)\\)\\]\\(([^)]+)\\)"
  matches = gregexpr(linked_image_pattern, text, perl = TRUE)[[1]]
  if (matches[1] == -1) {
    return(render_markdown_links_and_images(text))
  }

  captures = regmatches(text, gregexpr(linked_image_pattern, text,
                                      perl = TRUE))[[1]]
  starts = as.integer(matches)
  lengths = attr(matches, "match.length")
  output = character(0)
  cursor = 1

  for (i in seq_along(captures)) {
    start = starts[i]
    finish = start + lengths[i] - 1
    if (start > cursor) {
      output = c(output, render_markdown_links_and_images(
        substr(text, cursor, start - 1)
      ))
    }
    parts = regexec(linked_image_pattern, captures[i], perl = TRUE)
    values = regmatches(captures[i], parts)[[1]]
    alt = html_escape(values[2])
    src = html_escape(site_relative_path(values[3]))
    href = html_escape(site_relative_path(values[4]))
    output = c(output, paste0(
      "<a href=\"", href, "\"><img class=\"badge-image\" src=\"", src,
      "\" alt=\"", alt, "\"></a>"
    ))
    cursor = finish + 1
  }

  if (cursor <= nchar(text)) {
    output = c(output, render_markdown_links_and_images(
      substr(text, cursor, nchar(text))
    ))
  }

  paste0(output, collapse = "")
}

mathjax_head = function() {
  c(
    "  <script>",
    "    window.MathJax = {",
    "      tex: { inlineMath: [['$', '$'], ['\\\\(', '\\\\)']] },",
    "      options: { skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'] }",
    "    };",
    "  </script>",
    "  <script defer src=\"https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js\"></script>"
  )
}

slugify_heading = function(text) {
  slug = gsub("`", "", text, fixed = TRUE)
  slug = gsub("'", "", slug, fixed = TRUE)
  slug = gsub(intToUtf8(0x2019), "", slug, fixed = TRUE)
  slug = tolower(slug)
  slug = gsub("[^a-z0-9]+", "-", slug)
  slug = gsub("^-|-$", "", slug)
  slug
}

render_markdown_page = function(input_path, output_path, title, eyebrow,
                                 description, primary_links = character()) {
  old_markdown_dir = current_markdown_dir
  current_markdown_dir <<- dirname(input_path)
  on.exit(current_markdown_dir <<- old_markdown_dir, add = TRUE)

  lines = readLines(input_path, warn = FALSE)
  output = character(0)
  list_open = FALSE
  table_open = FALSE
  table_header_pending = FALSE
  table_header_written = FALSE
  table_body_open = FALSE
  code_open = FALSE
  paragraph = character(0)

  close_paragraph = function() {
    if (length(paragraph) > 0) {
      output <<- c(output, paste0("<p>", render_inline_markdown(
        paste(paragraph, collapse = " ")
      ), "</p>"))
      paragraph <<- character(0)
    }
  }
  close_list = function() {
    if (list_open) {
      output <<- c(output, "</ul>")
      list_open <<- FALSE
    }
  }
  close_table = function() {
    if (table_open) {
      if (table_body_open) {
        output <<- c(output, "</tbody>")
      } else if (table_header_pending) {
        output <<- c(output, "</thead>")
      }
      output <<- c(output, "</table></div>")
      table_open <<- FALSE
      table_header_pending <<- FALSE
      table_header_written <<- FALSE
      table_body_open <<- FALSE
    }
  }
  close_blocks = function() {
    close_paragraph()
    close_list()
    close_table()
  }
  table_cells = function(line) {
    stripped = sub("^\\|", "", sub("\\|$", "", trimws(line)))
    trimws(strsplit(stripped, "\\|", fixed = FALSE)[[1]])
  }
  render_table_row = function(line, header = FALSE) {
    tag = if (header) "th" else "td"
    cells = vapply(table_cells(line), render_inline_markdown, character(1))
    paste0("<tr>", paste0("<", tag, ">", cells, "</", tag, ">",
                          collapse = ""), "</tr>")
  }

  for (line_index in seq_along(lines)) {
    line = lines[[line_index]]
    if (line_index == 1 && grepl("^# ", trimws(line))) {
      next
    }
    if (grepl("^```", line)) {
      if (code_open) {
        output = c(output, "</code></pre>")
        code_open = FALSE
      } else {
        close_blocks()
        output = c(output, "<pre><code>")
        code_open = TRUE
      }
      next
    }
    if (code_open) {
      output = c(output, html_escape(line))
      next
    }
    if (!nzchar(trimws(line))) {
      close_blocks()
      next
    }
    if (grepl("^<!--", trimws(line))) {
      close_blocks()
      next
    }
    if (grepl("^#{1,6} ", line)) {
      close_blocks()
      level = nchar(sub("^(#+).*", "\\1", line))
      text = sub("^#{1,6} ", "", line)
      id = slugify_heading(text)
      output = c(output, sprintf("<h%d id=\"%s\">%s</h%d>", level, id,
                                 render_inline_markdown(text), level))
      next
    }
    if (grepl("^!\\[[^]]*\\]\\([^)]+\\)", line)) {
      close_blocks()
      parts = regmatches(line, regexec("^!\\[([^]]*)\\]\\(([^)]+)\\)",
                                       line, perl = TRUE))[[1]]
      alt = html_escape(parts[2])
      src = html_escape(site_relative_path(parts[3]))
      output = c(output, paste0("<figure><img src=\"", src, "\" alt=\"",
                                alt, "\"><figcaption>", alt,
                                "</figcaption></figure>"))
      next
    }
    if (grepl("^\\|", trimws(line))) {
      close_paragraph()
      close_list()
      if (!table_open) {
        output = c(output, "<div class=\"table-wrap\"><table>", "<thead>")
        table_open = TRUE
        table_header_pending = TRUE
        table_header_written = FALSE
      }
      if (grepl("^\\|[[:space:]|:\\-]+\\|?$", trimws(line))) {
        next
      }
      if (table_header_pending && !table_body_open &&
          table_header_written) {
        output = c(output, "</thead>", "<tbody>")
        table_body_open = TRUE
        table_header_pending = FALSE
      }
      output = c(output, render_table_row(line, header = !table_body_open))
      if (!table_body_open) {
        table_header_written = TRUE
      }
      next
    }
    if (grepl("^[[:space:]]*- ", line)) {
      close_paragraph()
      close_table()
      if (!list_open) {
        output = c(output, "<ul>")
        list_open = TRUE
      }
      item = sub("^[[:space:]]*- ", "", line)
      output = c(output, paste0("<li>", render_inline_markdown(item), "</li>"))
      next
    }
    paragraph = c(paragraph, trimws(line))
  }
  close_blocks()

  page = c(
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "  <meta charset=\"utf-8\">",
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    paste0("  <title>", html_escape(title), "</title>"),
    "  <style>",
    portfolio_css(c(
    "    .results-content { max-width: 900px; padding-top: 2rem; }",
    "    .results-content h2 { margin-top: 2.2rem; padding-top: 1rem; border-top: 1px solid var(--line); font-size: clamp(1.5rem, 3vw, 2rem); line-height: 1.1; }",
    "    .results-content h2:first-child { margin-top: 0; }",
    "    .results-content h3 { margin-top: 1.7rem; font-size: 1.12rem; }",
    "    .results-content ul { padding-left: 1.2rem; }",
    "    .results-content li { margin: 0.2rem 0; }",
    "    .results-content .table-wrap { max-width: min(100%, calc(100vw - 2rem)); }",
    "    .results-content th, .results-content td { white-space: nowrap; text-align: left; }",
    "    .results-content img { display: block; width: 100%; height: auto; }"
    )),
    "  </style>",
    mathjax_head(),
  "</head>",
  "<body>",
    "  <a class=\"skip-link\" href=\"#top\">Skip to main content</a>",
    "  <header class=\"site-header\">",
    "    <a class=\"brand\" href=\"index.html\" aria-label=\"Celestial Dynamics home\"><span class=\"brand-mark\">SR</span><span>Celestial Dynamics</span></a>",
    "    <nav class=\"nav-links\" aria-label=\"Primary navigation\">",
    "      <a href=\"index.html\">Results</a>",
    "      <a href=\"method_comparison_dashboard.html\">Dashboard</a>",
    "      <a href=\"artifact_index.html\">Artifacts</a>",
    "      <a href=\"docs.html\">Docs</a>",
    paste0("      <a href=\"", package_url, "\">Package</a>"),
    "      <a href=\"readme.html\">README</a>",
    "    </nav>",
    "  </header>",
    "  <main id=\"top\" tabindex=\"-1\" class=\"section\">",
    "    <section class=\"page-hero\">",
    "      <div>",
    paste0("        <p class=\"eyebrow\">", html_escape(eyebrow), "</p>"),
    paste0("        <h1>", html_escape(title), "</h1>"),
    paste0("        <p>", html_escape(description), "</p>"),
    "      </div>",
    "      <div class=\"metric-strip\">",
    "        <div class=\"metric\"><span>Methods</span><strong>5</strong></div>",
    "        <div class=\"metric\"><span>Systems</span><strong>4</strong></div>",
    "        <div class=\"metric\"><span>Views</span><strong>3</strong></div>",
    "      </div>",
    "    </section>",
    "    <div class=\"links\">",
    "      <a class=\"button primary\" href=\"method_comparison_dashboard.html\">Method Dashboard</a>",
    "      <a class=\"button\" href=\"artifact_index.html\">Artifact Browser</a>",
    "      <a class=\"button\" href=\"docs.html\">Documentation</a>",
    paste0("      <a class=\"button\" href=\"", package_url, "\">R-universe Package</a>"),
    primary_links,
    "    </div>",
    "    <article class=\"results-content\">",
    output,
    "    </article>",
    "  </main>",
    "</body>",
    "</html>"
  )
  writeLines(page, output_path)
}

render_markdown_page(
  "docs/RESULTS.md",
  file.path(generated_dir, "index.html"),
  "Celestial Dynamics Results",
  "Numerical methods and orbital simulation",
  "Generated results for projectile, two-body, three-body, restricted three-body, and n-body examples.",
  c(
    "      <a class=\"button\" href=\"method_summary.csv\">Sun-Earth CSV</a>",
    "      <a class=\"button\" href=\"runtime_benchmark.csv\">Runtime CSV</a>"
  )
)

documentation_pages = data.frame(
  source = c(
    "README.md",
    "docs/USAGE.md",
    "docs/THEORY.md",
    "docs/R_UNIVERSE.md",
    "analysis/README.md",
    "examples/README.md",
    "examples/three_body/README.md"
  ),
  output = c(
    "readme.html",
    "usage.html",
    "theory.html",
    "r-universe.html",
    "analysis.html",
    "examples.html",
    "three-body-examples.html"
  ),
  title = c(
    "Project README",
    "Usage",
    "Theory",
    "R-universe Setup",
    "Analysis Workflow",
    "Examples",
    "Three-Body Examples"
  ),
  eyebrow = c(
    "Project overview",
    "Setup and commands",
    "Numerical methods",
    "Package distribution",
    "Generated diagnostics",
    "Runnable simulations",
    "Three-body systems"
  ),
  description = c(
    "The repository front page, package install commands, project overview, and links.",
    "Detailed setup, command reference, examples, repository layout, and generated artifacts.",
    "Numerical method descriptions and the modelling assumptions used in the simulations.",
    "R-universe registry details and installation notes for the package.",
    "How analysis tables, dashboards, diagnostics, and result artifacts are generated.",
    "Runnable examples grouped by model type.",
    "Special, restricted, perturbed, and general three-body example scripts."
  ),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(documentation_pages))) {
  render_markdown_page(
    documentation_pages$source[i],
    file.path(generated_dir, documentation_pages$output[i]),
    documentation_pages$title[i],
    documentation_pages$eyebrow[i],
    documentation_pages$description[i]
  )
}

doc_cards = vapply(seq_len(nrow(documentation_pages)), function(i) {
  paste0(
    "      <article class=\"project-card\"><div><h3>",
    html_escape(documentation_pages$title[i]),
    "</h3><p>",
    html_escape(documentation_pages$description[i]),
    "</p></div><div class=\"card-links\"><a href=\"",
    html_escape(documentation_pages$output[i]),
    "\">Open</a></div></article>"
  )
}, character(1))

docs_index_html = c(
  "<!doctype html>",
  "<html lang=\"en\">",
  "<head>",
  "  <meta charset=\"utf-8\">",
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "  <title>Celestial Dynamics Documentation</title>",
  "  <style>",
  portfolio_css(c(
  "    .docs-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1rem; padding-top: 1.5rem; }",
  "    .project-card { display: grid; gap: 1.25rem; align-content: space-between; min-height: 12rem; padding: 1.1rem; }",
  "    .project-card h3 { margin: 0 0 0.45rem; }",
  "    .project-card p { margin: 0; }",
  "    .card-links { display: flex; flex-wrap: wrap; gap: 0.75rem; font-weight: 800; }"
  )),
  "  </style>",
  "</head>",
  "<body>",
  "  <a class=\"skip-link\" href=\"#top\">Skip to main content</a>",
  "  <header class=\"site-header\">",
  "    <a class=\"brand\" href=\"index.html\" aria-label=\"Celestial Dynamics home\"><span class=\"brand-mark\">SR</span><span>Celestial Dynamics</span></a>",
  "    <nav class=\"nav-links\" aria-label=\"Primary navigation\">",
  "      <a href=\"index.html\">Results</a>",
  "      <a href=\"method_comparison_dashboard.html\">Dashboard</a>",
  "      <a href=\"artifact_index.html\">Artifacts</a>",
  "      <a href=\"docs.html\">Docs</a>",
  paste0("      <a href=\"", package_url, "\">Package</a>"),
  "      <a href=\"readme.html\">README</a>",
  "    </nav>",
  "  </header>",
  "  <main id=\"top\" tabindex=\"-1\" class=\"section\">",
  "    <section class=\"page-hero\">",
  "      <div>",
  "        <p class=\"eyebrow\">Project documentation</p>",
  "        <h1>Celestial Dynamics Documentation</h1>",
  "        <p>Styled versions of the repository markdown documentation, generated with the same visual system as the results pages.</p>",
  "      </div>",
  "      <div class=\"metric-strip\">",
  paste0("        <div class=\"metric\"><span>Pages</span><strong>", nrow(documentation_pages), "</strong></div>"),
  "        <div class=\"metric\"><span>Package</span><strong>R</strong></div>",
  "        <div class=\"metric\"><span>Theme</span><strong>SR</strong></div>",
  "      </div>",
  "    </section>",
  "    <section class=\"docs-grid\" aria-label=\"Documentation pages\">",
  doc_cards,
  "    </section>",
  "  </main>",
  "</body>",
  "</html>"
)
writeLines(docs_index_html, file.path(generated_dir, "docs.html"))

plot_manifest = if (file.exists(cd_plot_manifest_path)) {
  read.csv(cd_plot_manifest_path, stringsAsFactors = FALSE)
} else {
  cd_empty_manifest()
}
plot_manifest = plot_manifest[order(plot_manifest$plot_type,
                                    plot_manifest$filepath), ]

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

artifact_index_path = file.path(generated_dir, "artifact_index.html")
index_html = c(
  "<!doctype html>",
  "<html lang=\"en\">",
  "<head>",
  "  <meta charset=\"utf-8\">",
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "  <title>Celestial Dynamics Results Index</title>",
  "  <style>",
  portfolio_css(c(
  "    .artifact-table-wrap { overflow-x: auto; }",
  "    .artifact-link { color: var(--text); font-weight: 800; text-decoration-color: color-mix(in srgb, var(--accent) 45%, transparent); }",
  "    .path { display: block; margin-top: 0.25rem; font-size: 0.78rem; overflow-wrap: anywhere; }",
  "    .toolbar { align-items: center; }",
  "    @media (max-width: 800px) { .toolbar { align-items: stretch; } input[type=search] { width: 100%; } }"
  )),
  "  </style>",
  "</head>",
  "<body>",
  "  <a class=\"skip-link\" href=\"#top\">Skip to main content</a>",
  "  <header class=\"site-header\">",
  "    <a class=\"brand\" href=\"index.html\" aria-label=\"Celestial Dynamics home\"><span class=\"brand-mark\">SR</span><span>Celestial Dynamics</span></a>",
  "    <nav class=\"nav-links\" aria-label=\"Primary navigation\">",
  "      <a href=\"index.html\">Results</a>",
  "      <a href=\"method_comparison_dashboard.html\">Dashboard</a>",
  "      <a href=\"artifact_index.html\">Artifacts</a>",
  "      <a href=\"docs.html\">Docs</a>",
  paste0("      <a href=\"", package_url, "\">Package</a>"),
  "      <a href=\"readme.html\">README</a>",
  "    </nav>",
  "  </header>",
  "  <main id=\"top\" tabindex=\"-1\" class=\"section\">",
  "    <section class=\"page-hero\">",
  "      <div>",
  "        <p class=\"eyebrow\">Generated artifact browser</p>",
  "        <h1>Celestial Dynamics Results Index</h1>",
  "        <p>Generated plots, animations, diagnostics, and data exports for the repository examples.</p>",
  "      </div>",
  "      <div class=\"metric-strip\">",
  paste0("        <div class=\"metric\"><span>Plots</span><strong>", png_count, "</strong></div>"),
  paste0("        <div class=\"metric\"><span>Animations</span><strong>", html_count, "</strong></div>"),
  paste0("        <div class=\"metric\"><span>Data files</span><strong>", csv_count, "</strong></div>"),
  "      </div>",
  "    </section>",
  "    <div class=\"links\">",
  "      <a class=\"button primary\" href=\"index.html\">Results narrative</a>",
  "      <a class=\"button\" href=\"method_comparison_dashboard.html\">Method dashboard</a>",
  paste0("      <a class=\"button\" href=\"", package_url, "\">R-universe package</a>"),
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
  "      <div class=\"artifact-table-wrap\">",
  "      <table>",
  "        <thead><tr><th>Artifact</th><th>Type</th><th>Method</th><th>Steps</th><th>Energy ratio</th><th>Title</th></tr></thead>",
  "        <tbody>",
  manifest_rows,
  "        </tbody>",
  "      </table>",
  "      </div>",
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
writeLines(index_html, artifact_index_path)

cat("Generated analysis artifacts:\n")
cat(sprintf("- %s\n", file.path(generated_dir, "method_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "convergence_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "earth_moon_method_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "three_body_special_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "n_body_conservation_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "runtime_benchmark.csv")))
cat(sprintf("- %s\n", cd_plot_manifest_path))
cat("- docs/RESULTS.md generated analysis section\n")
cat(sprintf("- %s\n", file.path(generated_dir, "index.html")))
cat(sprintf("- %s\n", dashboard_path))
cat(sprintf("- %s\n", artifact_index_path))
cat(sprintf("- %s\n", analysis_image_dir))
