if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/dynamics/models.R")

# The numerical loop knows only the state and a resolved acceleration callback.
# No model IDs, force laws, body labels, plots or conservation assumptions here.
integrate_dynamics = function(model, state, integrator, duration, timestep, start_time = 0) {
  model = cd_validate_model(model)
  spec = cd_model_definitions()[[model$id]]
  cd_validate_state(state, model, spec)
  cd_model_scalar(duration, "duration")
  cd_model_scalar(timestep, "timestep")
  cd_model_scalar(start_time, "start_time", positive = FALSE)
  if (!is.finite(start_time + duration)) stop("Integration end time must be finite.")
  count = duration / timestep
  if (!is.finite(count) || round(count) < 1 || round(count) >= .Machine$integer.max ||
      abs(count - round(count)) > 1e-9 * max(1, count)) stop("duration / timestep must be a positive integer.")
  count = round(count)
  if (!is.character(integrator) || length(integrator) != 1L || is.na(integrator) ||
      !integrator %in% c("Euler", "Midpoint", "Heun", "RK4", "Verlet")) stop("Unknown integrator.")
  if (integrator == "Verlet" && !spec$velocity_independent)
    stop("Verlet requires velocity-independent acceleration; incompatible model.")
  dt = duration / count
  q = state$positions; v = state$velocities
  positions = velocities = array(0, c(count + 1, dim(q)))
  positions[1, , ] = q; velocities[1, , ] = v
  acceleration = function(t, q, v) cd_checked_acceleration(spec, model$parameters, t, q, v)
  for (step in seq_len(count)) {
    time = start_time + (step - 1) * dt
    a = acceleration(time, q, v)
    if (integrator == "Verlet") {
      next_q = q + dt * v + 0.5 * dt^2 * a
      next_a = acceleration(time + dt, next_q, v)
      v = v + 0.5 * dt * (a + next_a)
      q = next_q
    } else if (integrator == "Euler") {
      q = q + dt * v
      v = v + dt * a
    } else if (integrator == "Midpoint") {
      mid_v = v + 0.5 * dt * a
      mid_a = acceleration(time + 0.5 * dt, q + 0.5 * dt * v, mid_v)
      q = q + dt * mid_v
      v = v + dt * mid_a
    } else if (integrator == "Heun") {
      end_v = v + dt * a
      end_a = acceleration(time + dt, q + dt * v, end_v)
      q = q + 0.5 * dt * (v + end_v)
      v = v + 0.5 * dt * (a + end_a)
    } else {
      k1_r = v; k1_v = a
      k2_r = v + 0.5 * dt * k1_v
      k2_v = acceleration(time + 0.5 * dt, q + 0.5 * dt * k1_r, k2_r)
      k3_r = v + 0.5 * dt * k2_v
      k3_v = acceleration(time + 0.5 * dt, q + 0.5 * dt * k2_r, k3_r)
      k4_r = v + dt * k3_v
      k4_v = acceleration(time + dt, q + dt * k3_r, k4_r)
      q = q + (dt / 6) * (k1_r + 2 * k2_r + 2 * k3_r + k4_r)
      v = v + (dt / 6) * (k1_v + 2 * k2_v + 2 * k3_v + k4_v)
    }
    if (any(!is.finite(q)) || any(!is.finite(v))) stop("Integrator produced nonfinite state.")
    positions[step + 1, , ] = q; velocities[step + 1, , ] = v
  }
  list(model = model, initial_state = state, integrator = integrator,
    duration = duration, timestep = dt, time = start_time + seq(0, duration, length.out = count + 1),
    positions = positions, velocities = velocities)
}
