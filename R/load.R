cd_find_project_root = function(start = getwd()) {
  current = normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    repo_markers = file.path(current, c("R", "examples", "tests", "analysis"))
    package_markers = file.path(current, c("DESCRIPTION", "R"))
    if (all(file.exists(repo_markers)) || all(file.exists(package_markers))) {
      return(current)
    }

    parent = dirname(current)
    if (identical(parent, current)) {
      stop("Could not find project root from ", start, call. = FALSE)
    }
    current = parent
  }
}

cd_project_root = function() {
  if (!exists(".cd_project_root", envir = .GlobalEnv, inherits = FALSE)) {
    assign(".cd_project_root", cd_find_project_root(), envir = .GlobalEnv)
  }
  get(".cd_project_root", envir = .GlobalEnv, inherits = FALSE)
}

cd_path = function(...) {
  file.path(cd_project_root(), ...)
}

cd_sourced_files = function() {
  if (!exists(".cd_sourced_files", envir = .GlobalEnv, inherits = FALSE)) {
    assign(".cd_sourced_files", new.env(parent = emptyenv()), envir = .GlobalEnv)
  }
  get(".cd_sourced_files", envir = .GlobalEnv, inherits = FALSE)
}

cd_source = function(path, chdir = FALSE) {
  source_path = normalizePath(cd_path(path), winslash = "/", mustWork = TRUE)
  sourced = cd_sourced_files()

  if (!exists(source_path, envir = sourced, inherits = FALSE)) {
    assign(source_path, TRUE, envir = sourced)
    source(source_path, chdir = chdir)
  }

  invisible(source_path)
}

cd_source_many = function(paths) {
  invisible(lapply(paths, cd_source))
}

cd_load_projectile_methods = function() {
  cd_source_many(c(
    "R/methods/euler_method.R",
    "R/methods/heuns_method.R",
    "R/methods/midpoint_method.R",
    "R/methods/runge_kutta_method.R"
  ))
}

cd_load_two_body = function() {
  cd_source("R/systems/two_body/two_body_method_registry.R")
}

cd_load_three_body = function() {
  cd_source_many(c(
    "R/systems/three_body/three_body_runge_kutta.R",
    "R/systems/three_body/figure_8_initial_conditions.R",
    "R/systems/three_body/lagrange_initial_conditions.R",
    "R/systems/three_body/euler_collinear_initial_conditions.R",
    "R/systems/three_body/choreography_initial_conditions.R",
    "R/systems/three_body/circular_restricted_three_body.R",
    "R/systems/three_body/sitnikov_problem.R",
    "R/systems/three_body/plot_three_body.R"
  ))
}

cd_load_n_body = function() {
  cd_source_many(c(
    "R/systems/n_body/four_body_initial_conditions.R",
    "R/systems/n_body/n_body_runge_kutta.R",
    "R/systems/n_body/n_body_velocity_verlet.R",
    "R/systems/n_body/plot_n_body.R"
  ))
}

cd_load_plotting = function() {
  cd_source("R/systems/plotting/plot_style.R")
}
