# Correction of the repository's known figure-eight seed, not a discovery.
source("R/load.R")
cd_load_periodic_orbits()
cd_source("R/systems/three_body/figure_8_initial_conditions.R")
seed = figure_8_initial_conditions()
state = list(positions = do.call(rbind, seed$positions) / seed$position_scale,
  velocities = do.call(rbind, seed$velocities) / seed$velocity_scale)
model = dynamical_model("newtonian_gravity", list(masses = rep(1, 3), G = 1))
state$velocities[1, 1] = state$velocities[1, 1] + 1e-4
result = shoot_periodic_orbit(model, state, seed$period / seed$time_scale * 1.0001,
  free_components = periodic_orbit_components(state)[7:12], vary_period = TRUE)
print(result[c("status", "message", "period", "residual_norm", "verification")])
print(result$history)
# Full correction states, trajectory and controls are available in result.
