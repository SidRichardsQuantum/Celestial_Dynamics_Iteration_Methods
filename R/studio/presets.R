studio_presets = function() {
  make = function(name, description, system, parameters, duration, steps = 2000,
                   source = "Repository constants and Newtonian initial conditions") {
    list(name = name, description = description, source = source,
         request = simulation_request(system, "RK4", parameters, duration, duration / steps))
  }
  binary = function(eccentricity = 0, masses = c(M_SUN, M_EARTH), semi_major_axis = AU) {
    separation = semi_major_axis * (1 - eccentricity)
    speed = sqrt(G * sum(masses) * (1 + eccentricity) / separation)
    fractions = c(-masses[2], masses[1]) / sum(masses)
    list(masses = masses, positions = cbind(fractions * separation, 0),
         velocities = cbind(0, fractions * speed))
  }
  period = 2 * pi * sqrt(AU^3 / (G * (M_SUN + M_EARTH)))
  figure = figure_8_initial_conditions()
  square = rotating_square_four_body_initial_conditions()
  triangle = triangular_central_four_body_initial_conditions()
  lagrange = lagrange_initial_conditions()
  collinear = euler_collinear_initial_conditions()
  butterfly = choreography_initial_conditions()
  equal_three = function(ic) list(masses = rep(M_EARTH, 3),
    positions = do.call(rbind, ic$positions), velocities = do.call(rbind, ic$velocities))
  mu = M_MOON / (M_EARTH + M_MOON)
  jupiter_mu = M_JUPITER / (M_SUN + M_JUPITER)
  solar = list(masses = c(M_SUN, M_EARTH, M_MARS, M_JUPITER),
    positions = cbind(c(0, 1, 1.524, 5.203) * AU, 0),
    velocities = cbind(0, c(0, V_EARTH_ORBITAL,
      sqrt(G * M_SUN / (1.524 * AU)), sqrt(G * M_SUN / (5.203 * AU)))))
  separation = 0.2 * AU
  omega = sqrt(G * 2 * M_SUN / separation^3)
  stars = list(masses = c(M_SUN, M_SUN, M_JUPITER),
    positions = rbind(c(-separation / 2, 0), c(separation / 2, 0), c(3 * AU, 0)),
    velocities = rbind(c(0, -omega * separation / 2), c(0, omega * separation / 2),
                        c(0, sqrt(G * (2 * M_SUN + M_JUPITER) / (3 * AU)))))
  stars$positions = sweep(stars$positions, 2, colSums(stars$positions * stars$masses) / sum(stars$masses))
  stars$velocities = sweep(stars$velocities, 2, colSums(stars$velocities * stars$masses) / sum(stars$masses))
  list(
    circular_two_body = make("Circular Sun-Earth", "Barycentric circular orbit at 1 AU.",
      "two_body", binary(), period),
    eccentric_two_body = make("Eccentric Sun-Earth", "Barycentric e = 0.6 orbit, a = 1 AU; starts at periapsis.",
      "two_body", binary(0.6), period, 4000),
    earth_moon_binary = make("Earth-Moon orbit", "Barycentric circular orbit at 384,400 km separation.",
      "two_body", binary(masses = c(M_EARTH, M_MOON), semi_major_axis = 384400000),
      2 * pi * sqrt(384400000^3 / (G * (M_EARTH + M_MOON)))),
    equal_mass_binary = make("Equal-mass binary stars", "Two solar-mass stars in an eccentric e = 0.4 barycentric orbit, a = 1 AU.",
      "two_body", binary(0.4, c(M_SUN, M_SUN)),
      2 * pi * sqrt(AU^3 / (G * 2 * M_SUN)), 4000),
    figure_eight = make("Three-body figure-eight", "Equal Earth masses; existing SI-scaled figure-eight generator.",
      "three_body", list(masses = rep(M_EARTH, 3),
        positions = do.call(rbind, figure$positions), velocities = do.call(rbind, figure$velocities)),
      figure$period, source = "R/systems/three_body/figure_8_initial_conditions.R"),
    lagrange_triangle = make("Lagrange equilateral triangle", "Three equal Earth masses rotating as an equilateral triangle for one period.",
      "three_body", equal_three(lagrange), lagrange$period,
      source = "R/systems/three_body/lagrange_initial_conditions.R"),
    euler_collinear = make("Euler collinear rotation", "Three equal Earth masses in an unstable rotating collinear configuration; one period.",
      "three_body", equal_three(collinear), collinear$period, 4000,
      "R/systems/three_body/euler_collinear_initial_conditions.R"),
    butterfly = make("Butterfly I choreography", "Existing approximate periodic initial conditions; 100,000 steps resolve close approaches.",
      "three_body", equal_three(butterfly), butterfly$period, 100000,
      "R/systems/three_body/choreography_initial_conditions.R"),
    pythagorean = make("Pythagorean three-body", "Mass ratio 3:4:5, initially at rest. Runs through the first close encounter using 100,000 RK4 steps; not a validated long-term evolution.",
      "three_body", list(masses = c(3, 4, 5) * M_EARTH,
        positions = rbind(c(1, 3), c(-2, -1), c(1, -1)) * AU,
        velocities = matrix(0, 3, 2)), 2 * sqrt(AU^3 / (G * M_EARTH)), 100000),
    earth_moon_trojan = make("Earth-Moon Trojan", "Perturbed L4 test particle in normalized rotating coordinates.",
      "restricted_three_body", list(mu = mu, state0 = c(0.5 - mu + 0.01, sqrt(3) / 2, 0, 0, 0, 0),
        primary_names = c("Earth", "Moon")), 20),
    earth_moon_l5 = make("Earth-Moon trailing Trojan", "Planar perturbation near L5, trailing the Moon in the rotating frame.",
      "restricted_three_body", list(mu = mu,
        state0 = c(0.5 - mu - 0.015, -sqrt(3) / 2, 0, 0, 0, 0),
        primary_names = c("Earth", "Moon")), 20, 4000),
    lunar_satellite = make("Retrograde lunar test particle", "Initially circular relative to the Moon at 0.05 primary separations; Earth's gravity perturbs the orbit.",
      "restricted_three_body", list(mu = mu,
        state0 = c(1 - mu + 0.05, 0, 0, 0, -sqrt(mu / 0.05) - 0.05, 0),
        primary_names = c("Earth", "Moon")), 5, 10000),
    sun_jupiter_particle = make("Sun-Jupiter test particle", "Spatial perturbation near L4; normalized rotating coordinates.",
      "restricted_three_body", list(mu = jupiter_mu,
        state0 = c(0.5 - jupiter_mu, sqrt(3) / 2, 0.01, 0, 0, 0),
        primary_names = c("Sun", "Jupiter")), 20),
    solar_system = make("Sun-Earth-Mars-Jupiter", "Planar illustrative Solar System, not an ephemeris.",
      "n_body", solar, 12 * YEAR, 6000, "examples/n_body/sun_earth_mars_jupiter.R"),
    binary_stars = make("Binary stars and distant third", "Two solar masses and a distant Jupiter-mass companion.",
      "three_body", stars, YEAR, 4000, "examples/three_body/general/binary_distant_third.R"),
    rotating_square = make("Rotating square", "Four equal Earth masses in a central configuration.",
      "n_body", square[c("masses", "positions", "velocities")], square$period,
      source = "R/systems/n_body/four_body_initial_conditions.R"),
    triangular_four_body = make("Triangle around a central body", "Three equal outer masses rotating around a central Earth mass; one period.",
      "n_body", triangle[c("masses", "positions", "velocities")], triangle$period,
      source = "R/systems/n_body/four_body_initial_conditions.R"),
    sitnikov = make("Circular Sitnikov", "Vertical massless particle and two circular Earth-mass primaries.",
      "sitnikov", list(primary_mass = M_EARTH, primary_radius = 0.05 * AU,
                       z0 = 0.04 * AU, vz0 = 0), 8 * YEAR, 8000),
    sitnikov_small = make("Small-amplitude Sitnikov", "Nearly harmonic vertical oscillation, shown over several cycles.",
      "sitnikov", list(primary_mass = M_EARTH, primary_radius = 0.05 * AU,
                       z0 = 0.01 * AU, vz0 = 0), 10 * YEAR, 8000)
  )
}

studio_preset = function(name) {
  presets = studio_presets()
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
      !name %in% names(presets)) stop("Unknown preset.")
  presets[[name]]$request
}
