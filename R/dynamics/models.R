if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/dynamics/cr3bp.R")

# Model descriptors contain only data. Executable definitions live here, never
# in saved requests/results, and have no dependency on Studio or presentation.
cd_model_scalar = function(x, name, positive = TRUE) {
  if (!is.numeric(x) || is.complex(x) || length(x) != 1L || !is.null(dim(x)) ||
      !is.finite(x) || (positive && x <= 0)) stop("Invalid model parameter: ", name)
}

cd_gravity_acceleration = function(time, positions, velocities, parameters) {
  masses = parameters$masses
  softening = parameters$softening
  if (is.null(softening)) softening = 0
  count = length(masses)
  acceleration = matrix(0, count, ncol(positions))
  for (i in 1:(count - 1)) {
    for (j in (i + 1):count) {
      displacement = positions[j, ] - positions[i, ]
      distance = sqrt(sum(displacement^2) + softening^2)
      if (!is.finite(distance) || distance <= 0) stop("Body collision or overlapping positions.")
      factor = parameters$G * displacement / distance^3
      acceleration[i, ] = acceleration[i, ] + masses[j] * factor
      acceleration[j, ] = acceleration[j, ] - masses[i] * factor
    }
  }
  acceleration
}

cd_sitnikov_acceleration = function(time, positions, velocities, parameters) {
  -2 * parameters$G * parameters$primary_mass * positions /
    (parameters$primary_radius^2 + positions^2)^(3 / 2)
}

# Add a definition here to share all fixed-step methods. Verlet is allowed only
# when acceleration is independent of velocity. Time is passed at every stage.
cd_model_definitions = function() {
  gravity = list(defaults = list(G = G), required = "masses",
    validate = function(p) {
      if (!is.numeric(p$masses) || is.complex(p$masses) || !is.null(dim(p$masses)) || length(p$masses) < 2L ||
          any(!is.finite(p$masses)) || any(p$masses <= 0)) stop("masses must be a positive finite vector with at least two bodies.")
      cd_model_scalar(p$G, "G")
    }, shape = function(p) list(bodies = length(p$masses), dimensions = 1:3),
    acceleration = cd_gravity_acceleration, velocity_independent = TRUE,
    frame = "inertial", units = "SI")
  softened = gravity
  softened$required = c("masses", "softening")
  softened$validate = function(p) {
    gravity$validate(p)
    cd_model_scalar(p$softening, "softening")
  }
  list(
    newtonian_gravity = gravity,
    softened_gravity = softened,
    cr3bp_rotating = list(defaults = list(), required = "mu",
      validate = function(p) {
        cr3bp_validate_mu(p$mu)
      }, shape = function(p) list(bodies = 1L, dimensions = 3L),
      acceleration = cd_cr3bp_acceleration, velocity_independent = FALSE,
      frame = "rotating", units = "normalized"),
    sitnikov_circular = list(defaults = list(G = G), required = c("primary_mass", "primary_radius"),
      validate = function(p) {
        for (name in c("G", "primary_mass", "primary_radius")) cd_model_scalar(p[[name]], name)
      }, shape = function(p) list(bodies = 1L, dimensions = 1L),
      acceleration = cd_sitnikov_acceleration, velocity_independent = TRUE,
      frame = "inertial", units = "SI"))
}

dynamical_model = function(id, parameters = list()) {
  definitions = cd_model_definitions()
  if (!is.character(id) || length(id) != 1L || is.na(id) || !id %in% names(definitions))
    stop("Unknown dynamical model ID.")
  spec = definitions[[id]]
  if (!is.list(parameters) || (length(parameters) && (is.null(names(parameters)) ||
      anyNA(names(parameters)) || anyDuplicated(names(parameters)) ||
      any(!names(parameters) %in% c(spec$required, names(spec$defaults))))))
    stop("Model parameters must be a uniquely named list of supported fields.")
  for (name in names(spec$defaults)) if (is.null(parameters[[name]])) parameters[[name]] = spec$defaults[[name]]
  if (any(!spec$required %in% names(parameters))) stop("Missing required model parameters.")
  spec$validate(parameters)
  # Canonical numeric values strip arbitrary attributes from saved descriptors.
  parameters = lapply(parameters, as.numeric)
  list(id = id, version = 1L, parameters = parameters)
}

cd_validate_model = function(model) {
  if (!is.list(model) || !setequal(names(model), c("id", "version", "parameters")) ||
      length(model) != 3L || !is.numeric(model$version) || is.complex(model$version) || length(model$version) != 1L ||
      is.na(model$version) || model$version != 1) stop("Unsupported dynamical model descriptor.")
  validated = dynamical_model(model$id, model$parameters)
  if (!setequal(names(validated$parameters), names(model$parameters)) ||
      any(vapply(model$parameters, is.null, logical(1))))
    stop("Saved model descriptors must include resolved parameter defaults.")
  validated
}

cd_validate_state = function(state, model, spec) {
  if (!is.list(state) || length(state) != 2L ||
      !setequal(names(state), c("positions", "velocities"))) stop("State needs positions and velocities matrices.")
  q = state$positions; v = state$velocities
  shape = spec$shape(model$parameters)
  if (!is.numeric(q) || !is.numeric(v) || is.complex(q) || is.complex(v) || !is.matrix(q) || !is.matrix(v) ||
      !identical(dim(q), dim(v)) || nrow(q) != shape$bodies ||
      !ncol(q) %in% shape$dimensions || any(!is.finite(q)) || any(!is.finite(v)))
    stop("Invalid state dimensions or nonfinite state values for this model.")
  invisible(state)
}

cd_checked_acceleration = function(spec, parameters, time, positions, velocities) {
  value = spec$acceleration(time, positions, velocities, parameters)
  if (!is.numeric(value) || is.complex(value) || !identical(dim(value), dim(positions)) || any(!is.finite(value)))
    stop("Model produced invalid or nonfinite acceleration.")
  value
}

dynamics_derivative = function(model, time, state) {
  model = cd_validate_model(model)
  spec = cd_model_definitions()[[model$id]]
  cd_model_scalar(time, "time", positive = FALSE)
  cd_validate_state(state, model, spec)
  list(positions = state$velocities,
    velocities = cd_checked_acceleration(spec, model$parameters, time, state$positions, state$velocities))
}
