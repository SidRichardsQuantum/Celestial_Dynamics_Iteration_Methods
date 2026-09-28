# Run from the checkout root: Rscript examples/comparisons/parameter_sweeps.R
source("R/load.R")
cd_load_studio()

base = studio_preset("circular_two_body")
base$duration = 20 * base$timestep

# Timestep values must divide the fixed duration. Use an explicit reference for error.
timestep_sweep = run_parameter_sweep(base,
  list(timestep = base$timestep / c(1, 2, 4)),
  c("energy_relative_drift", "angular_momentum_relative_drift", "final_position_error"),
  list(reference = "analytic_circular"))

# Change m2/m1 by changing only m2; initial positions and velocities stay fixed.
ratio = base$parameters$masses[2] / base$parameters$masses[1]
mass_sweep = run_parameter_sweep(base, list(mass_ratio = ratio * c(0.9, 1, 1.1)),
  c("minimum_separation", "energy_relative_drift"))

# Offset values always apply to the original base state, never the previous point.
position_sweep = run_parameter_sweep(base,
  list("position_offset[2,1]" = c(-1000, 0, 1000)), "minimum_separation")
velocity_sweep = run_parameter_sweep(base,
  list("velocity_offset[2,2]" = c(-1, 0, 1)), "energy_relative_drift")

# Cartesian CR3BP initial x/y grid, with coordinates in the native rotating frame.
restricted = studio_preset("earth_moon_trojan")
restricted$duration = 0.2
xy_sweep = run_parameter_sweep(restricted,
  list(initial_x = seq(0.48, 0.52, length.out = 3),
       initial_y = seq(0.85, 0.89, length.out = 3)),
  c("jacobi_relative_drift", "minimum_separation"))

# Optional extra two-trajectory analysis per member, with fixed metric scales.
lyapunov_sweep = run_parameter_sweep(restricted,
  list(initial_x = c(0.49, 0.5)), "finite_time_lyapunov",
  list(lyapunov = list(epsilon = 1e-7, component = "position[1,1]",
    renormalisation_interval = 0.05, position_scale = 1, velocity_scale = 1)))

print(timestep_sweep$scalar_metrics)
print(xy_sweep$scalar_metrics)
stopifnot(all(xy_sweep$runs$status == "completed"))
member = sweep_run(xy_sweep, 5)
stopifnot(identical(member$id, xy_sweep$runs$run_id[5]))

# In an interactive R session:
# studio_plot_sweep(timestep_sweep, "final_position_error")
# studio_plot_sweep(xy_sweep, "minimum_separation")
# Add store_history = TRUE, directory = ".studio/history" to archive member runs.
# saveRDS(xy_sweep, "xy-sweep.rds") retains the sweep and its in-memory trajectories.
