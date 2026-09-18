# Metadata, defaults and validation are shared by the API and the UI.
studio_parameter = function(label, type = "number", default = NULL,
                            required = is.null(default), positive = FALSE,
                            length = NULL) {
  structure(list(label = label, type = type, default = default,
                 required = required, positive = positive, length = length),
            class = "studio_parameter")
}

studio_integrators = function() {
  registry = two_body_method_registry()
  lapply(names(registry), function(id) {
    method = registry[[id]]
    systems = "two_body"
    if (id == "RK4") systems = c(systems, "three_body", "n_body",
                                 "restricted_three_body", "sitnikov")
    if (id == "Verlet") systems = c(systems, "n_body")
    structure(list(name = id, description = method$label,
                   order = method$expected_order, adaptive = FALSE,
                   symplectic = isTRUE(method$symplectic),
                   systems = systems,
                   parameters = list(timestep = studio_parameter(
                     "Fixed timestep (system time units)", positive = TRUE))),
              class = "studio_integrator_spec")
  }) |> setNames(names(registry))
}

studio_catalog = function() {
  massive_parameters = list(
    masses = studio_parameter("Masses (kg), one per body", "vector", positive = TRUE),
    positions = studio_parameter("Positions (m), one [x,y] row per body", "matrix"),
    velocities = studio_parameter("Velocities (m/s), one [vx,vy] row per body", "matrix")
  )
  conserved = c("energy", "energy_relative_drift", "angular_momentum",
                "angular_momentum_relative_drift", "momentum_x", "momentum_y")
  spec = function(name, description, dimensions, parameters, diagnostics,
                  validator, adapter, units = "SI: m, kg, s", visualisations =
                    c("orbit", "diagnostics", "animation")) {
    integrators = names(Filter(function(x) name %in% x$systems, studio_integrators()))
    structure(list(name = name, description = description, dimensions = dimensions,
                   parameters = parameters, integrators = integrators,
                   diagnostics = diagnostics, visualisations = visualisations,
                   units = units, validate = validator, adapter = adapter),
              class = "studio_simulation_spec")
  }
  massive_validator = function(count = NULL) {
    force(count)
    function(p) {
      n_body_validate_inputs(1, 1, p$masses, p$positions, p$velocities)
      if (!is.null(count) && length(p$masses) != count) {
        stop("This system requires exactly ", count, " bodies.")
      }
    }
  }
  list(
    two_body = spec("two_body", "Two mutually gravitating massive bodies in a plane.",
      2L, massive_parameters, c(conserved, "semi_major_axis", "eccentricity"),
      massive_validator(2), studio_solve_two_body),
    three_body = spec("three_body", "Three mutually gravitating massive bodies in a plane.",
      2L, massive_parameters, conserved, massive_validator(3), studio_solve_three_body),
    n_body = spec("n_body", "Planar Newtonian N-body gravity, including Solar System and binary configurations.",
      2L, massive_parameters, conserved, massive_validator(), studio_solve_n_body),
    restricted_three_body = spec("restricted_three_body",
      "Massless particle in the rotating frame of two circular primaries (CR3BP).",
      3L, list(mu = studio_parameter("Secondary / total primary mass (0 < mu < 0.5)", positive = TRUE),
               state0 = studio_parameter("Initial [x,y,z,vx,vy,vz] in rotating frame", "vector", length = 6L),
               primary_names = studio_parameter("Primary names (larger, smaller)", "labels",
                 default = c("Primary 1", "Primary 2"), length = 2L)),
      c("jacobi", "jacobi_relative_drift"),
      function(p) {
        if (p$mu >= 0.5) stop("mu must be in (0, 0.5).")
        s = p$state0
        if (sum((s[1:3] - c(-p$mu, 0, 0))^2) == 0 ||
            sum((s[1:3] - c(1 - p$mu, 0, 0))^2) == 0) {
          stop("Initial state overlaps a primary.")
        }
      }, studio_solve_cr3bp,
      "Normalized: primary separation = 1, total mass = 1, angular speed = 1",
      c("orbit", "3d", "diagnostics", "animation")),
    sitnikov = spec("sitnikov", "Circular equal-mass primaries with a massless particle on the perpendicular axis.",
      3L, list(primary_mass = studio_parameter("Each primary mass (kg)", default = M_EARTH, positive = TRUE),
               primary_radius = studio_parameter("Each primary orbital radius (m)", default = 0.5 * AU, positive = TRUE),
               z0 = studio_parameter("Initial particle z (m)", default = 0.25 * AU),
               vz0 = studio_parameter("Initial particle vz (m/s)", default = 0)),
      c("specific_energy", "specific_energy_relative_drift"), function(p) invisible(TRUE),
      studio_solve_sitnikov, visualisations = c("orbit", "3d", "phase_space", "diagnostics", "animation"))
  )
}
