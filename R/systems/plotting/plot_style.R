if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")

cd_colors = list(
  ink = "#172033",
  muted = "#667085",
  grid = "#d8dee6",
  panel = "#ffffff",
  paper = "#f7f9fc",
  orange = "#d55e00",
  blue = "#0072b2",
  sky = "#56b4e9",
  green = "#009e73",
  yellow = "#e69f00",
  purple = "#cc79a7",
  red = "#d62728",
  gray = "#6b7280",
  black = "#222222",
  teal = "#0f766e"
)

cd_palette = function(n) {
  colors = unname(c(cd_colors$orange, cd_colors$blue, cd_colors$green,
                    cd_colors$purple, cd_colors$yellow, cd_colors$teal,
                    cd_colors$red, cd_colors$gray, cd_colors$black,
                    cd_colors$sky))
  rep(colors, length.out = n)
}

cd_ensure_output_dir = function(filepath) {
  output_dir = dirname(filepath)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
}

cd_plot_manifest_path = file.path("analysis", "generated", "plot_manifest.csv")

cd_manifest_columns = c(
  "filepath", "artifact_type", "plot_type", "title", "method", "time_value",
  "time_unit", "steps", "dt_days", "energy_ratio", "width", "height", "res",
  "x_min", "x_max", "y_min", "y_max", "data_x_min", "data_x_max",
  "data_y_min", "data_y_max", "x_margin_ratio", "y_margin_ratio"
)

cd_empty_manifest = function() {
  setNames(as.data.frame(matrix(ncol = length(cd_manifest_columns), nrow = 0),
                         stringsAsFactors = FALSE),
           cd_manifest_columns)
}

cd_parse_title_metadata = function(title) {
  title_one_line = gsub("\n", " ", title)
  method = NA_character_
  method_match = regexec("\\(([^()]*(Method|RK4)[^()]*)\\)", title_one_line)
  method_parts = regmatches(title_one_line, method_match)[[1]]
  if (length(method_parts) >= 2) {
    method = method_parts[2]
  } else if (grepl("RK4", title_one_line)) {
    method = "RK4"
  }

  time_value = NA_real_
  time_unit = NA_character_
  time_match = regexec("T = ([0-9.]+) ([A-Za-z -]+), N = ([0-9]+)",
                       title_one_line)
  time_parts = regmatches(title_one_line, time_match)[[1]]
  steps = NA_integer_
  if (length(time_parts) >= 4) {
    time_value = as.numeric(time_parts[2])
    time_unit = trimws(time_parts[3])
    steps = as.integer(time_parts[4])
  }

  list(method = method, time_value = time_value, time_unit = time_unit,
       steps = steps)
}

cd_range_margin_ratio = function(limits, data_values) {
  data_values = data_values[is.finite(data_values)]
  if (length(data_values) == 0) {
    return(NA_real_)
  }
  data_span = diff(range(data_values))
  axis_span = diff(limits)
  if (!is.finite(data_span) || !is.finite(axis_span) || data_span <= 0 ||
      axis_span <= 0) {
    return(NA_real_)
  }
  (axis_span - data_span) / axis_span
}

cd_record_plot_manifest = function(filepath, artifact_type, plot_type, title,
                                    width, height, res, xlim, ylim,
                                    data_x, data_y, method = NA_character_,
                                    time_value = NA_real_,
                                    time_unit = NA_character_,
                                    steps = NA_integer_,
                                    dt_days = NA_real_,
                                    energy_ratio = NA_real_) {
  dir.create(dirname(cd_plot_manifest_path), recursive = TRUE,
             showWarnings = FALSE)
  title_metadata = cd_parse_title_metadata(title)
  if (is.na(method)) {
    method = title_metadata$method
  }
  if (is.na(time_value)) {
    time_value = title_metadata$time_value
  }
  if (is.na(time_unit)) {
    time_unit = title_metadata$time_unit
  }
  if (is.na(steps)) {
    steps = title_metadata$steps
  }
  if (is.na(dt_days) && is.finite(time_value) && is.finite(steps)) {
    if (identical(time_unit, "years")) {
      dt_days = time_value * YEAR / steps / DAY
    } else if (identical(time_unit, "lunar months")) {
      dt_days = time_value * LUNAR_MONTH / steps / DAY
    }
  }

  row = data.frame(
    filepath = filepath,
    artifact_type = artifact_type,
    plot_type = plot_type,
    title = gsub("\n", " | ", title),
    method = method,
    time_value = time_value,
    time_unit = time_unit,
    steps = steps,
    dt_days = dt_days,
    energy_ratio = energy_ratio,
    width = width,
    height = height,
    res = res,
    x_min = xlim[1],
    x_max = xlim[2],
    y_min = ylim[1],
    y_max = ylim[2],
    data_x_min = min(data_x, na.rm = TRUE),
    data_x_max = max(data_x, na.rm = TRUE),
    data_y_min = min(data_y, na.rm = TRUE),
    data_y_max = max(data_y, na.rm = TRUE),
    x_margin_ratio = cd_range_margin_ratio(xlim, data_x),
    y_margin_ratio = cd_range_margin_ratio(ylim, data_y),
    stringsAsFactors = FALSE
  )

  manifest = if (file.exists(cd_plot_manifest_path)) {
    read.csv(cd_plot_manifest_path, stringsAsFactors = FALSE)
  } else {
    cd_empty_manifest()
  }
  for (column in setdiff(cd_manifest_columns, names(manifest))) {
    manifest[[column]] = NA
  }
  manifest = manifest[manifest$filepath != filepath, cd_manifest_columns]
  manifest = rbind(manifest, row[cd_manifest_columns])
  manifest = manifest[order(manifest$filepath), ]
  write.csv(manifest, cd_plot_manifest_path, row.names = FALSE)
}

cd_record_animation_manifest = function(filepath, title, xlim, ylim, data_x,
                                        data_y, frame_count) {
  cd_record_plot_manifest(
    filepath = filepath,
    artifact_type = "html",
    plot_type = "trajectory_animation",
    title = title,
    width = NA_integer_,
    height = NA_integer_,
    res = NA_integer_,
    xlim = xlim,
    ylim = ylim,
    data_x = data_x,
    data_y = data_y,
    steps = frame_count
  )
}

cd_open_png = function(filepath, width = 1000, height = 760, res = 140,
                       mar = c(5, 5, 4, 9), mfrow = NULL) {
  cd_ensure_output_dir(filepath)
  png(filepath, width = width, height = height, res = res, bg = cd_colors$panel)
  old_par = par(no.readonly = TRUE)
  par(bg = cd_colors$panel,
      fg = cd_colors$ink,
      col.axis = cd_colors$ink,
      col.lab = cd_colors$ink,
      col.main = cd_colors$ink,
      family = "sans",
      las = 1,
      lwd = 1.1,
      mar = mar,
      xaxs = "i",
      yaxs = "i")
  if (!is.null(mfrow)) {
    par(mfrow = mfrow)
  }
  old_par
}

cd_close_png = function(old_par) {
  par(old_par)
  dev.off()
}

cd_expand_range = function(values, pad_fraction = 0.08, min_padding = 0) {
  values = values[is.finite(values)]
  if (length(values) == 0) {
    return(c(-1, 1))
  }
  value_range = range(values)
  span = diff(value_range)
  if (!is.finite(span) || span == 0) {
    span = max(abs(value_range) * 0.2, min_padding, .Machine$double.eps)
  }
  padding = max(span * pad_fraction, min_padding)
  value_range + c(-padding, padding)
}

cd_add_grid = function() {
  grid(col = cd_colors$grid, lty = "dotted", lwd = 0.9)
}

cd_plot_empty = function(xlim, ylim, xlab, ylab, main, asp = NA) {
  plot(NULL,
       xlim = xlim,
       ylim = ylim,
       xlab = "",
       ylab = "",
       main = main,
       asp = asp,
       bty = "l")
  title(xlab = xlab, line = 3)
  title(ylab = ylab, line = 3.8)
  cd_add_grid()
}

cd_body_cex = function(masses, min_cex = 1.1, max_cex = 2.4) {
  if (is.null(masses) || length(masses) == 0) {
    return(rep(min_cex, length(masses)))
  }
  log_masses = log10(pmax(masses, .Machine$double.eps))
  span = diff(range(log_masses))
  if (!is.finite(span) || span == 0) {
    return(rep((min_cex + max_cex) / 2, length(masses)))
  }
  min_cex + (log_masses - min(log_masses)) / span * (max_cex - min_cex)
}

cd_draw_trajectory = function(x, y, color, label = NULL, body_cex = 1.3,
                               lwd = 2.4, draw_direction = FALSE) {
  lines(x, y, col = grDevices::adjustcolor(color, alpha.f = 0.74),
        lwd = lwd, lend = "round", ljoin = "round")

  if (draw_direction && length(x) > 8) {
    arrow_index = max(2, round(length(x) * 0.72))
    trajectory_span = max(diff(range(x, finite = TRUE)),
                          diff(range(y, finite = TRUE)),
                          .Machine$double.eps)
    dx = x[arrow_index] - x[arrow_index - 1]
    dy = y[arrow_index] - y[arrow_index - 1]
    if (trajectory_span > 1e-4 && sqrt(dx^2 + dy^2) > trajectory_span * 1e-8) {
      arrows(x[arrow_index - 1], y[arrow_index - 1],
             x[arrow_index], y[arrow_index],
             length = 0.08, angle = 24, col = color, lwd = lwd,
             code = 2)
    }
  }

  points(x[1], y[1], pch = 21, col = color, bg = cd_colors$panel,
         cex = body_cex, lwd = 1.5)
  points(tail(x, 1), tail(y, 1), pch = 19, col = color,
         cex = body_cex * 1.04)

  if (!is.null(label)) {
    text(tail(x, 1), tail(y, 1), labels = label, pos = 4,
         cex = 0.72, col = color, xpd = NA)
  }
}

cd_add_external_legend = function(labels, colors, lty = 1, lwd = 2.4,
                                  pch = NA, title = NULL) {
  legend("topright",
         inset = c(-0.32, 0),
         xpd = NA,
         title = title,
         legend = labels,
         col = colors,
         lty = lty,
         lwd = lwd,
         pch = pch,
         pt.cex = 1.1,
         bty = "n",
         text.col = cd_colors$ink,
         cex = 0.86)
}

cd_format_diagnostic_value = function(value, digits = 3) {
  if (!is.finite(value)) {
    return("n/a")
  }
  magnitude = abs(value)
  if (magnitude >= 1e-3 && magnitude < 1e4) {
    decimal_digits = if (magnitude < 10) digits else max(1, digits - 1)
    return(formatC(value, format = "f", digits = decimal_digits))
  }
  format(signif(value, digits), scientific = TRUE, trim = TRUE)
}

cd_relative_error_series = function(values) {
  (values - values[1]) / abs(values[1])
}

cd_diagnostic_lines = function(energy, angular_momentum, separation_label,
                               separation_value_au) {
  c(
    sprintf("Energy ratio: %s",
            cd_format_diagnostic_value(tail(energy, 1) / energy[1])),
    sprintf("max |dE/E0|: %s",
            cd_format_diagnostic_value(
              max(abs(cd_relative_error_series(energy))))),
    sprintf("max |dL/L0|: %s",
            cd_format_diagnostic_value(relative_drift(angular_momentum))),
    sprintf("%s: %s AU",
            separation_label,
            cd_format_diagnostic_value(separation_value_au))
  )
}

cd_add_external_diagnostics = function(lines, title = "Diagnostics") {
  legend("bottomright",
         inset = c(-0.32, 0),
         xpd = NA,
         title = title,
         legend = lines,
         bty = "n",
         text.col = cd_colors$ink,
         cex = 0.74)
}

cd_json_string = function(value) {
  escaped = gsub("\\\\", "\\\\\\\\", value)
  escaped = gsub("\"", "\\\\\"", escaped)
  paste0("\"", escaped, "\"")
}

cd_json_number_array = function(values, digits = 7) {
  values = round(values, digits)
  paste(format(values, scientific = FALSE, trim = TRUE), collapse = ",")
}

cd_write_trajectory_animation = function(filepath, title, series,
                                          units = "AU", frame_count = 900) {
  if (length(series) == 0) {
    stop("series must contain at least one trajectory.")
  }

  cd_ensure_output_dir(filepath)

  min_length = min(vapply(series, function(item) length(item$x), integer(1)))
  indices = unique(round(seq(1, min_length, length.out = min(min_length,
                                                             frame_count))))
  animated = lapply(series, function(item) {
    list(
      label = item$label,
      color = item$color,
      cex = if (is.null(item$cex)) 1.3 else item$cex,
      x = item$x[indices],
      y = item$y[indices]
    )
  })

  all_x = unlist(lapply(animated, function(item) item$x))
  all_y = unlist(lapply(animated, function(item) item$y))
  xlim = cd_expand_range(all_x, 0.1, 0.02)
  ylim = cd_expand_range(all_y, 0.1, 0.02)

  json_series = vapply(animated, function(item) {
    paste0(
      "{",
      "\"label\":", cd_json_string(item$label), ",",
      "\"color\":", cd_json_string(item$color), ",",
      "\"cex\":", format(item$cex, trim = TRUE), ",",
      "\"x\":[", cd_json_number_array(item$x), "],",
      "\"y\":[", cd_json_number_array(item$y), "]",
      "}"
    )
  }, character(1))

  output_dir = gsub("\\\\", "/", dirname(filepath))
  cwd = gsub("\\\\", "/", getwd())
  if (identical(output_dir, cwd)) {
    output_dir = "."
  } else if (startsWith(output_dir, paste0(cwd, "/"))) {
    output_dir = substring(output_dir, nchar(cwd) + 2)
  }
  path_parts = strsplit(output_dir, "/", fixed = TRUE)[[1]]
  path_parts = path_parts[nzchar(path_parts) & path_parts != "."]
  root_prefix = if (length(path_parts) == 0) "." else paste(rep("..", length(path_parts)), collapse = "/")
  results_href = paste0(root_prefix, "/analysis/generated/index.html")
  dashboard_href = paste0(root_prefix, "/analysis/generated/method_comparison_dashboard.html")
  artifacts_href = paste0(root_prefix, "/analysis/generated/artifact_index.html")

  html = c(
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "  <meta charset=\"utf-8\">",
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    paste0("  <title>", title, "</title>"),
    "  <style>",
    "    :root { color-scheme: light dark; --bg: #f7f7f4; --surface: #ffffff; --surface-muted: #ededeb; --text: #1d2328; --muted: #5b6670; --line: #d7d9d6; --accent: #126c83; --accent-strong: #0f5364; --shadow: 0 18px 45px rgba(34, 41, 47, 0.08); --shadow-soft: 0 10px 30px rgba(34, 41, 47, 0.06); }",
    "    @media (prefers-color-scheme: dark) { :root { --bg: #101416; --surface: #171d20; --surface-muted: #20282b; --text: #edf1f2; --muted: #a9b4b8; --line: #2e393d; --accent: #66c5d7; --accent-strong: #9eddea; --shadow: 0 18px 45px rgba(0, 0, 0, 0.25); --shadow-soft: 0 10px 30px rgba(0, 0, 0, 0.18); } }",
    "    * { box-sizing: border-box; }",
    "    body { margin: 0; background: var(--bg); color: var(--text); font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif; line-height: 1.6; text-rendering: optimizeLegibility; }",
    "    a { color: inherit; text-decoration-color: color-mix(in srgb, var(--accent) 65%, transparent); text-underline-offset: 0.2em; }",
    "    a:hover { color: var(--accent-strong); }",
    "    a:focus-visible, button:focus-visible, input:focus-visible, main:focus-visible { outline: 3px solid var(--accent); outline-offset: 4px; }",
    "    .skip-link { position: fixed; top: 0.75rem; left: 0.75rem; z-index: 20; transform: translateY(-150%); border: 1px solid var(--accent-strong); border-radius: 8px; padding: 0.65rem 0.9rem; background: var(--surface); color: var(--accent-strong); font-weight: 800; text-decoration: none; box-shadow: var(--shadow); transition: transform 160ms ease; }",
    "    .skip-link:focus-visible { transform: translateY(0); }",
    "    .site-header { position: sticky; top: 0; z-index: 10; display: flex; align-items: center; justify-content: space-between; gap: 1.5rem; padding: 1rem clamp(1rem, 4vw, 3rem); border-bottom: 1px solid var(--line); background: color-mix(in srgb, var(--bg) 88%, transparent); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); }",
    "    .brand { display: inline-flex; align-items: center; gap: 0.7rem; font-weight: 700; text-decoration: none; }",
    "    .brand-mark { display: inline-grid; width: 2.2rem; height: 2.2rem; place-items: center; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); color: var(--accent-strong); font-size: 0.82rem; letter-spacing: 0; }",
    "    .nav-links { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 0.35rem 1rem; color: var(--muted); font-size: 0.95rem; }",
    "    .nav-links a { border-radius: 6px; padding: 0.15rem 0; text-decoration: none; }",
    "    main { width: min(1180px, calc(100% - 2rem)); margin: 0 auto; padding: clamp(3rem, 8vw, 6rem) 0; }",
    "    header.page-hero { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 1.5rem; align-items: end; margin-bottom: 1.5rem; padding-bottom: 2rem; border-bottom: 1px solid var(--line); }",
    "    h1 { margin: 0; font-size: clamp(2rem, 5vw, 3.2rem); line-height: 1.05; letter-spacing: 0; }",
    "    .eyebrow { margin: 0 0 0.75rem; color: var(--accent-strong); font-size: 0.78rem; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; }",
    "    .status { color: var(--muted); font-size: 0.9rem; white-space: nowrap; }",
    "    .panel { background: var(--surface); border: 1px solid var(--line); border-radius: 8px; overflow: hidden; box-shadow: var(--shadow-soft); }",
    "    .panel:hover, .panel:focus-within { border-color: color-mix(in srgb, var(--accent) 45%, var(--line)); box-shadow: var(--shadow); }",
    "    .toolbar { display: flex; justify-content: space-between; gap: 0.75rem; align-items: center; flex-wrap: wrap; padding: 0.85rem 1rem; border-bottom: 1px solid var(--line); background: var(--surface-muted); }",
    "    .button-group { display: inline-flex; gap: 0.65rem; flex-wrap: wrap; align-items: center; }",
    "    button { display: inline-flex; min-height: 2.75rem; align-items: center; justify-content: center; border: 1px solid var(--line); border-radius: 8px; padding: 0.72rem 1rem; background: var(--surface); color: var(--text); cursor: pointer; font: inherit; font-weight: 700; line-height: 1; box-shadow: 0 1px 0 rgba(0, 0, 0, 0.03); transition: color 160ms ease, border-color 160ms ease, background-color 160ms ease, transform 160ms ease; }",
    "    button:hover { transform: translateY(-1px); border-color: var(--accent); color: var(--accent-strong); }",
    "    button.active { border-color: var(--accent-strong); background: var(--accent-strong); color: #fff; }",
    "    button.active:hover { color: #fff; }",
    "    button.secondary { color: var(--accent-strong); border-color: color-mix(in srgb, var(--accent) 45%, var(--line)); }",
    "    input[type=range] { width: 100%; accent-color: var(--accent); }",
    "    canvas { width: 100%; height: auto; border: 1px solid var(--line); border-radius: 8px; background: #fff; display: block; }",
    "    .scrub-row { display: grid; grid-template-columns: 1fr; gap: 0.5rem; padding: 0.85rem 1rem 0; }",
    "    .meta { display: flex; gap: 1rem; flex-wrap: wrap; padding: 0.55rem 1rem 0.75rem; color: var(--muted); font-size: 0.82rem; border-bottom: 1px solid var(--line); }",
    "    .legend { display: flex; flex-wrap: wrap; gap: 0.65rem 0.85rem; padding: 0.85rem 1rem 1rem; color: var(--muted); }",
    "    .legend label { display: inline-flex; align-items: center; gap: 0.45rem; cursor: pointer; font-size: 0.9rem; }",
    "    .legend input { accent-color: var(--accent); }",
    "    .legend label:has(input:not(:checked)) { opacity: .48; }",
    "    .swatch { width: 0.75rem; height: 0.75rem; border-radius: 2px; box-shadow: inset 0 0 0 1px rgba(29, 35, 40, .14); }",
    "    @media (max-width: 760px) { .site-header { align-items: flex-start; flex-direction: column; gap: 0.75rem; } .nav-links { justify-content: flex-start; } main { width: min(100% - 1rem, 1180px); } header.page-hero { align-items: start; grid-template-columns: 1fr; } .toolbar { align-items: stretch; } .button-group { width: 100%; } button { flex: 1 1 auto; } }",
    "  </style>",
  "</head>",
  "<body>",
    "  <a class=\"skip-link\" href=\"#top\">Skip to main content</a>",
    "  <header class=\"site-header\">",
    paste0("    <a class=\"brand\" href=\"", results_href, "\" aria-label=\"Celestial Dynamics home\"><span class=\"brand-mark\">SR</span><span>Celestial Dynamics</span></a>"),
    "    <nav class=\"nav-links\" aria-label=\"Primary navigation\">",
    paste0("      <a href=\"", results_href, "\">Results</a>"),
    paste0("      <a href=\"", dashboard_href, "\">Dashboard</a>"),
    paste0("      <a href=\"", artifacts_href, "\">Artifacts</a>"),
    "    </nav>",
    "  </header>",
    "  <main id=\"top\" tabindex=\"-1\">",
    "    <header class=\"page-hero\">",
    "      <div>",
    "        <div class=\"eyebrow\">Trajectory animation</div>",
    paste0("        <h1>", title, "</h1>"),
    "      </div>",
    "      <div id=\"frameLabel\" class=\"status\"></div>",
    "    </header>",
    "    <section class=\"panel\">",
    "      <div class=\"toolbar\">",
    "        <div class=\"button-group\">",
    "          <button id=\"play\" class=\"active\">Pause</button>",
    "          <button data-speed=\"1\">1x</button>",
    "          <button data-speed=\"3\" class=\"active\">3x</button>",
    "          <button data-speed=\"8\">8x</button>",
    "        </div>",
    "        <button id=\"exportFrame\" class=\"secondary\">Export frame</button>",
    "      </div>",
    "      <canvas id=\"scene\" width=\"1100\" height=\"720\"></canvas>",
    "      <div class=\"scrub-row\">",
    "        <input id=\"scrubber\" type=\"range\" min=\"0\" value=\"0\" aria-label=\"Animation frame\">",
    "      </div>",
    "      <div class=\"meta\">",
    "        <span id=\"boundsLabel\"></span>",
    "        <span id=\"visibleLabel\"></span>",
    "      </div>",
    "      <div id=\"legend\" class=\"legend\"></div>",
    "    </section>",
    "  </main>",
    "  <script>",
    paste0("    const units = ", cd_json_string(units), ";"),
    paste0("    const xlim = [", paste(format(xlim, scientific = FALSE, trim = TRUE),
                                      collapse = ","), "];"),
    paste0("    const ylim = [", paste(format(ylim, scientific = FALSE, trim = TRUE),
                                      collapse = ","), "];"),
    "    const bodies = [",
    paste0("      ", paste(json_series, collapse = ",\n      ")),
    "    ];",
    "    const canvas = document.getElementById('scene');",
    "    const ctx = canvas.getContext('2d');",
    "    const scrubber = document.getElementById('scrubber');",
    "    const frameLabel = document.getElementById('frameLabel');",
    "    const play = document.getElementById('play');",
    "    const exportFrame = document.getElementById('exportFrame');",
    "    const boundsLabel = document.getElementById('boundsLabel');",
    "    const visibleLabel = document.getElementById('visibleLabel');",
    "    let frame = 0, speed = 3, running = true;",
    "    const visible = Object.fromEntries(bodies.map(body => [body.label, true]));",
    "    scrubber.max = bodies[0].x.length - 1;",
    "    boundsLabel.textContent = `Window: x ${xlim[0].toFixed(4)} to ${xlim[1].toFixed(4)} ${units}, y ${ylim[0].toFixed(4)} to ${ylim[1].toFixed(4)} ${units}`;",
    "    document.getElementById('legend').innerHTML = bodies.map(body => `<label><input type=\"checkbox\" data-body=\"${body.label}\" checked><i class=\"swatch\" style=\"background:${body.color}\"></i>${body.label}</label>`).join('');",
    "    document.querySelectorAll('#legend input[data-body]').forEach(input => {",
    "      input.addEventListener('change', () => {",
    "        visible[input.dataset.body] = input.checked;",
    "        draw();",
    "      });",
    "    });",
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
    "    scrubber.addEventListener('input', () => { frame = Number(scrubber.value); running = false; play.textContent = 'Play'; play.classList.remove('active'); draw(); });",
    "    exportFrame.addEventListener('click', () => {",
    "      const link = document.createElement('a');",
    "      link.download = 'trajectory-frame-' + String(frame).padStart(4, '0') + '.png';",
    "      link.href = canvas.toDataURL('image/png');",
    "      link.click();",
    "    });",
    "    function project(x, y) {",
    "      const pad = 58;",
    "      const sx = (canvas.width - 2 * pad) / (xlim[1] - xlim[0] || 1);",
    "      const sy = (canvas.height - 2 * pad) / (ylim[1] - ylim[0] || 1);",
    "      const scale = Math.min(sx, sy);",
    "      const cx = (canvas.width - scale * (xlim[0] + xlim[1])) / 2;",
    "      const cy = (canvas.height + scale * (ylim[0] + ylim[1])) / 2;",
    "      return [cx + x * scale, cy - y * scale];",
    "    }",
    "    function drawAxes() {",
    "      ctx.strokeStyle = '#e5eaf0'; ctx.lineWidth = 1;",
    "      for (let i = 0; i <= 8; i++) {",
    "        const x = xlim[0] + i * (xlim[1] - xlim[0]) / 8;",
    "        const [px] = project(x, ylim[0]);",
    "        ctx.beginPath(); ctx.moveTo(px, 36); ctx.lineTo(px, canvas.height - 42); ctx.stroke();",
    "        const y = ylim[0] + i * (ylim[1] - ylim[0]) / 8;",
    "        const [, py] = project(xlim[0], y);",
    "        ctx.beginPath(); ctx.moveTo(46, py); ctx.lineTo(canvas.width - 46, py); ctx.stroke();",
    "      }",
    "      ctx.fillStyle = '#667085'; ctx.font = '14px system-ui'; ctx.fillText(`position (${units})`, 18, canvas.height - 18);",
    "    }",
    "    function draw() {",
    "      ctx.clearRect(0, 0, canvas.width, canvas.height);",
    "      ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, canvas.width, canvas.height);",
    "      drawAxes();",
    "      bodies.forEach(body => {",
    "        if (!visible[body.label]) return;",
    "        ctx.strokeStyle = body.color; ctx.globalAlpha = 0.16; ctx.lineWidth = 1.8;",
    "        ctx.beginPath();",
    "        for (let i = 0; i < body.x.length; i++) {",
    "          const [x, y] = project(body.x[i], body.y[i]);",
    "          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);",
    "        }",
    "        ctx.stroke();",
    "        ctx.strokeStyle = body.color; ctx.globalAlpha = 0.84; ctx.lineWidth = 2.6;",
    "        ctx.beginPath();",
    "        for (let i = 0; i <= frame; i++) {",
    "          const [x, y] = project(body.x[i], body.y[i]);",
    "          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);",
    "        }",
    "        ctx.stroke(); ctx.globalAlpha = 1;",
    "        const [sx, sy] = project(body.x[0], body.y[0]);",
    "        ctx.fillStyle = '#fff'; ctx.strokeStyle = body.color; ctx.lineWidth = 2;",
    "        ctx.beginPath(); ctx.arc(sx, sy, 5 + body.cex * 2, 0, Math.PI * 2); ctx.fill(); ctx.stroke();",
    "        const [px, py] = project(body.x[frame], body.y[frame]);",
    "        ctx.fillStyle = body.color;",
    "        ctx.beginPath(); ctx.arc(px, py, 5 + body.cex * 2, 0, Math.PI * 2); ctx.fill();",
    "      });",
    "      scrubber.value = frame;",
    "      const visibleCount = bodies.filter(body => visible[body.label]).length;",
    "      frameLabel.textContent = `Frame ${frame + 1} of ${bodies[0].x.length}`;",
    "      visibleLabel.textContent = `${visibleCount} of ${bodies.length} paths visible`;",
    "    }",
    "    function tick() {",
    "      if (running) frame = (frame + speed) % bodies[0].x.length;",
    "      draw(); requestAnimationFrame(tick);",
    "    }",
    "    tick();",
    "  </script>",
    "</body>",
    "</html>"
  )
  writeLines(html, filepath)
  cd_record_animation_manifest(filepath, title, xlim, ylim, all_x, all_y,
                               length(indices))
}

cd_plot_projectile = function(filepath, title, method_label,
                              x_numeric, y_numeric,
                              x_reference, y_reference,
                              width = 1000, height = 720, res = 140) {
  old_par = cd_open_png(filepath, width = width, height = height, res = res,
                        mar = c(5, 5, 4, 7))
  on.exit(cd_close_png(old_par), add = TRUE)

  all_x = c(x_numeric, x_reference)
  all_y = c(y_numeric, y_reference)
  cd_plot_empty(cd_expand_range(all_x, 0.05, 1),
                cd_expand_range(all_y, 0.08, 1),
                xlab = "Horizontal distance (m)",
                ylab = "Height (m)",
                main = title)
  lines(x_reference, y_reference,
        col = grDevices::adjustcolor(cd_colors$gray, 0.85),
        lwd = 2.2, lty = "dashed")
  lines(x_numeric, y_numeric,
        col = grDevices::adjustcolor(cd_colors$blue, 0.82),
        lwd = 2.6, lend = "round")
  points(x_numeric[1], y_numeric[1], pch = 21, col = cd_colors$blue,
         bg = cd_colors$panel, cex = 1.3, lwd = 1.4)
  points(tail(x_numeric, 1), tail(y_numeric, 1), pch = 19,
         col = cd_colors$blue, cex = 1.25)
  points(tail(x_reference, 1), tail(y_reference, 1), pch = 4,
         col = cd_colors$gray, cex = 1.15, lwd = 1.3)
  cd_add_external_legend(c(method_label, "analytical reference"),
                         c(cd_colors$blue, cd_colors$gray),
                         lty = c(1, 2), lwd = c(2.6, 2.2))

  cat(sprintf("Plot saved to: %s\n", filepath))
  cd_record_plot_manifest(
    filepath = filepath,
    artifact_type = "png",
    plot_type = "projectile",
    title = title,
    method = method_label,
    width = width,
    height = height,
    res = res,
    xlim = cd_expand_range(all_x, 0.05, 1),
    ylim = cd_expand_range(all_y, 0.08, 1),
    data_x = all_x,
    data_y = all_y
  )
}
