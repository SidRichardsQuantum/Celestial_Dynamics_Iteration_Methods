studio_positive_scalar = function(value, name) {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || value <= 0) {
    stop(name, " must be a positive finite number.")
  }
}

simulation_request = function(system, integrator, parameters, duration, timestep) {
  studio_request(system, integrator, parameters, duration, timestep)
}

# Historical decoding checks scientific structure without imposing today's
# execution budgets. Submission and rerunning always apply the budgets.
studio_request = function(system, integrator, parameters, duration, timestep,
                          execution = TRUE) {
  if (!is.character(system) || length(system) != 1L || is.na(system) ||
      !system %in% names(studio_catalog())) stop("Unknown simulation system.")
  spec = studio_catalog()[[system]]
  if (!is.character(integrator) || length(integrator) != 1L || is.na(integrator) ||
      !integrator %in% spec$integrators) stop("Integrator is incompatible with this system.")
  studio_positive_scalar(duration, "duration")
  studio_positive_scalar(timestep, "timestep")
  steps = duration / timestep
  if (!is.finite(steps) || round(steps) < 1 || (execution && round(steps) > 100000) ||
      abs(steps - round(steps)) > 1e-9 * max(1, steps)) {
    stop("duration / timestep must be an integer from 1 to 100000; timestep is never silently changed.")
  }
  if (!is.list(parameters) || (length(parameters) &&
      (is.null(names(parameters)) || anyNA(names(parameters)) ||
       any(!nzchar(names(parameters))) || anyDuplicated(names(parameters))))) {
    stop("parameters must be a uniquely named list.")
  }
  unknown = setdiff(names(parameters), names(spec$parameters))
  if (length(unknown)) stop("Unknown parameters: ", paste(unknown, collapse = ", "))
  for (name in names(spec$parameters)) {
    field = spec$parameters[[name]]
    value = parameters[[name]]
    if (is.null(value)) value = field$default
    if (is.null(value) && field$required) stop("Missing parameter: ", name)
    if (field$type == "labels") {
      if (!is.character(value) || anyNA(value) || !is.null(dim(value)) ||
          any(!nzchar(trimws(value))) || any(nchar(value) > 64) ||
          length(value) != field$length || anyDuplicated(value)) {
        stop(name, " must contain distinct nonempty labels of at most 64 characters.")
      }
      parameters[[name]] = value
      next
    }
    if (!is.numeric(value) || !length(value) || any(!is.finite(value))) {
      stop(name, " must contain finite numbers.")
    }
    if (field$type == "number" && length(value) != 1L) stop(name, " must be scalar.")
    if (field$type == "vector" && !is.null(dim(value))) stop(name, " must be a vector.")
    if (field$type == "matrix" && !is.matrix(value)) stop(name, " must be a matrix.")
    if (!is.null(field$length) && length(value) != field$length) stop(name, " has incorrect length.")
    if (field$positive && any(value <= 0)) stop(name, " must be positive.")
    parameters[[name]] = value
  }
  # Bound allocation and quadratic work before physics validation constructs
  # the pairwise distance matrix. These limits apply only to Studio requests.
  bodies = if (is.null(parameters$masses)) 3 else length(parameters$masses)
  if (execution && !is.null(parameters$masses) && bodies > 256) {
    stop("Request exceeds the Studio's 256-body limit.")
  }
  if (execution && (round(steps) + 1) * bodies * spec$dimensions > 2000000) {
    stop("Request exceeds the Studio's 2 million position-value limit.")
  }
  if (execution && !is.null(parameters$masses) && round(steps) * bodies * (bodies - 1) / 2 > 10000000) {
    stop("Request exceeds the Studio's 10 million pair-step limit; reduce bodies or steps.")
  }
  spec$validate(parameters)
  structure(list(system = system, integrator = integrator, parameters = parameters,
                 duration = duration, timestep = timestep), class = "simulation_request")
}

studio_validate_request = function(request, execution = TRUE) {
  if (!inherits(request, "simulation_request")) stop("Expected a simulation_request.")
  do.call(studio_request, c(unclass(request), list(execution = execution)))
}
