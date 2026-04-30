source("celestial_systems/two_body/two_body_method_registry.R")

generated_dir = "analysis/generated"
analysis_image_dir = "images/analysis"
dashboard_path = file.path(generated_dir, "method_comparison_dashboard.html")

dir.create(generated_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(analysis_image_dir, recursive = TRUE, showWarnings = FALSE)

method_registry = two_body_method_registry()
methods = two_body_method_functions(method_registry)
method_colors = two_body_method_colors(method_registry)

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

png(file.path(analysis_image_dir, "sun_earth_energy_error.png"),
    width = 900, height = 650, res = 120)
par(mar = c(5, 5, 4, 2))
plot(NULL, xlim = c(0, 25), ylim = range(unlist(lapply(results_25y, function(result) {
  relative_error_series(two_body_energy_series(result))
}))),
     xlab = "Time (years)", ylab = "Relative energy error",
     main = "Sun-Earth Energy Error by Method")
for (method_name in names(results_25y)) {
  result = results_25y[[method_name]]
  time_years = seq(0, 25, length.out = length(result$x_a))
  lines(time_years, relative_error_series(two_body_energy_series(result)),
        col = method_colors[[method_name]], lwd = 2)
}
legend("topleft", legend = names(results_25y), col = method_colors,
       lwd = 2, bg = "white")
grid(col = "lightgray", lty = "dotted")
invisible(dev.off())

png(file.path(analysis_image_dir, "sun_earth_angular_momentum_drift.png"),
    width = 900, height = 650, res = 120)
par(mar = c(5, 5, 4, 2))
plot(NULL, xlim = c(0, 25), ylim = range(unlist(lapply(results_25y, function(result) {
  relative_error_series(two_body_angular_momentum_series(result))
}))),
     xlab = "Time (years)", ylab = "Relative angular momentum drift",
     main = "Sun-Earth Angular Momentum Drift by Method")
for (method_name in names(results_25y)) {
  result = results_25y[[method_name]]
  time_years = seq(0, 25, length.out = length(result$x_a))
  lines(time_years, relative_error_series(two_body_angular_momentum_series(result)),
        col = method_colors[[method_name]], lwd = 2)
}
legend("topleft", legend = names(results_25y), col = method_colors,
       lwd = 2, bg = "white")
grid(col = "lightgray", lty = "dotted")
invisible(dev.off())

png(file.path(analysis_image_dir, "convergence_rates.png"),
    width = 900, height = 650, res = 120)
par(mar = c(5, 5, 4, 2))
plot(NULL, log = "xy",
     xlim = range(convergence_table$dt_days),
     ylim = range(convergence_table$final_position_error_au),
     xlab = "dt (days)", ylab = "Final position error (AU)",
     main = "Sun-Earth Convergence Against Fine RK4 Reference")
for (method_name in names(methods)) {
  rows = convergence_table[convergence_table$method == method_name, ]
  lines(rows$dt_days, rows$final_position_error_au,
        col = method_colors[[method_name]], lwd = 2, type = "b", pch = 19)
}
legend("topleft", legend = names(methods), col = method_colors,
       lwd = 2, pch = 19, bg = "white")
grid(col = "lightgray", lty = "dotted")
invisible(dev.off())

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
  "### Generated Figures",
  "",
  "- `images/analysis/sun_earth_energy_error.png`",
  "- `images/analysis/sun_earth_angular_momentum_drift.png`",
  "- `images/analysis/convergence_rates.png`",
  "- `analysis/generated/method_comparison_dashboard.html`",
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
  "    body { margin: 0; font-family: system-ui, -apple-system, Segoe UI, sans-serif; color: #1f2933; background: #f6f7f9; }",
  "    header { padding: 24px 32px 12px; background: #ffffff; border-bottom: 1px solid #d8dee6; }",
  "    h1 { margin: 0 0 6px; font-size: 26px; letter-spacing: 0; }",
  "    p { margin: 0; color: #52606d; }",
  "    main { display: grid; grid-template-columns: 1.4fr 1fr; gap: 18px; padding: 18px 32px 32px; }",
  "    section { background: #ffffff; border: 1px solid #d8dee6; border-radius: 8px; padding: 16px; }",
  "    canvas { width: 100%; height: auto; border: 1px solid #e4e7eb; background: #ffffff; }",
  "    .toolbar { display: flex; gap: 8px; align-items: center; margin-bottom: 12px; flex-wrap: wrap; }",
  "    button { border: 1px solid #9aa5b1; background: #ffffff; border-radius: 6px; padding: 8px 12px; cursor: pointer; }",
  "    button.active { background: #1f2933; color: #ffffff; }",
  "    table { width: 100%; border-collapse: collapse; font-size: 14px; }",
  "    th, td { padding: 8px; border-bottom: 1px solid #e4e7eb; text-align: right; }",
  "    th:first-child, td:first-child { text-align: left; }",
  "    .legend { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 10px; }",
  "    .legend span { display: inline-flex; align-items: center; gap: 6px; }",
  "    .swatch { width: 12px; height: 12px; border-radius: 2px; display: inline-block; }",
  "    @media (max-width: 900px) { main { grid-template-columns: 1fr; padding: 16px; } header { padding: 20px 16px 10px; } }",
  "  </style>",
  "</head>",
  "<body>",
  "  <header>",
  "    <h1>Celestial Dynamics Method Dashboard</h1>",
  "    <p>Generated Sun-Earth comparison for Euler, Midpoint, Heun, RK4, and Verlet over 25 years.</p>",
  "  </header>",
  "  <main>",
  "    <section>",
  "      <div class=\"toolbar\">",
  "        <button id=\"play\" class=\"active\">Pause</button>",
  "        <button data-speed=\"1\">1x</button>",
  "        <button data-speed=\"3\" class=\"active\">3x</button>",
  "        <button data-speed=\"8\">8x</button>",
  "      </div>",
  "      <canvas id=\"orbit\" width=\"900\" height=\"650\"></canvas>",
  "      <div id=\"legend\" class=\"legend\"></div>",
  "    </section>",
  "    <section>",
  "      <canvas id=\"energy\" width=\"620\" height=\"300\"></canvas>",
  "      <canvas id=\"momentum\" width=\"620\" height=\"300\" style=\"margin-top: 16px;\"></canvas>",
  "      <h2 style=\"font-size:18px; margin: 16px 0 8px;\">25-Year Summary</h2>",
  "      <table>",
  "        <thead><tr><th>Method</th><th>Energy ratio</th><th>Max |energy err|</th><th>Max |L drift|</th></tr></thead>",
  "        <tbody>",
  paste0(
    "          <tr><td>", summary_table$method, "</td><td>",
    format_numeric(summary_table$final_energy_ratio), "</td><td>",
    format_numeric(summary_table$max_abs_energy_error), "</td><td>",
    format_numeric(summary_table$max_abs_angular_momentum_drift), "</td></tr>"
  ),
  "        </tbody>",
  "      </table>",
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
  "    let frame = 0, running = true, speed = 3;",
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
  "    document.getElementById('legend').innerHTML = methods.map(m => `<span><i class=\"swatch\" style=\"background:${m.color}\"></i>${m.name}</span>`).join('');",
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
  "      orbitCtx.fillStyle = '#1f2933';",
  "      orbitCtx.fillText(`${(25 * frame / (methods[0].x.length - 1)).toFixed(2)} years`, 18, 28);",
  "    }",
  "    function chart(ctx, key, title) {",
  "      ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);",
  "      ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);",
  "      const values = methods.flatMap(m => m[key]);",
  "      const min = Math.min(...values), max = Math.max(...values);",
  "      const pad = 42;",
  "      ctx.fillStyle = '#1f2933'; ctx.fillText(title, 16, 22);",
  "      ctx.strokeStyle = '#d8dee6'; ctx.strokeRect(pad, pad, ctx.canvas.width - 2 * pad, ctx.canvas.height - 2 * pad);",
  "      methods.forEach(m => {",
  "        ctx.strokeStyle = m.color; ctx.lineWidth = 2; ctx.beginPath();",
  "        m[key].forEach((value, i) => {",
  "          const x = pad + i * (ctx.canvas.width - 2 * pad) / (m[key].length - 1);",
  "          const y = ctx.canvas.height - pad - (value - min) * (ctx.canvas.height - 2 * pad) / (max - min || 1);",
  "          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);",
  "        });",
  "        ctx.stroke();",
  "      });",
  "    }",
  "    function tick() {",
  "      if (running) frame = (frame + speed) % methods[0].x.length;",
  "      drawOrbit();",
  "      requestAnimationFrame(tick);",
  "    }",
  "    chart(energyCtx, 'energy', 'Relative energy error');",
  "    chart(momentumCtx, 'angularMomentum', 'Relative angular momentum drift');",
  "    tick();",
  "  </script>",
  "</body>",
  "</html>"
)
writeLines(dashboard_html, dashboard_path)

cat("Generated analysis artifacts:\n")
cat(sprintf("- %s\n", file.path(generated_dir, "method_summary.csv")))
cat(sprintf("- %s\n", file.path(generated_dir, "convergence_summary.csv")))
cat("- RESULTS.md generated analysis section\n")
cat(sprintf("- %s\n", dashboard_path))
cat(sprintf("- %s\n", analysis_image_dir))
