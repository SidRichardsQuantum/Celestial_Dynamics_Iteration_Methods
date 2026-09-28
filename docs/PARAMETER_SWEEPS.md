# Parameter sweeps

`run_parameter_sweep()` runs a bounded, sequential family of ordinary Celestial
Dynamics experiments. It accepts one or two named numeric parameter vectors.
Each Cartesian grid point is a fresh modification of the same base request;
everything outside the named parameters remains fixed. Every member uses
`run_simulation()`, has its own scientific run ID and includes standard
diagnostics. There is no parallel cluster or HPC dependency.

```r
source("R/load.R")
cd_load_studio()
base = studio_preset("circular_two_body")
base$duration = 20 * base$timestep

study = run_parameter_sweep(
  base,
  parameters = list(timestep = base$timestep / c(1, 2, 4)),
  metrics = c("energy_relative_drift", "final_position_error"),
  metric_options = list(reference = "analytic_circular"),
  store_history = FALSE
)
study$grid
study$runs
study$scalar_metrics
studio_plot_sweep(study, "final_position_error")
member = sweep_run(study, 2)
```

With an installed package, start with
`library(CelestialDynamicsIterationMethods)` instead of sourcing the loader.
`prepare_parameter_sweep()` accepts the same scientific arguments and returns
validated requests, the grid and a budget preview without executing or writing
anything. `sweep_parameters(base)` and `sweep_metrics(base)` discover supported
choices, labels and metric units.

## Parameters and grid semantics

| Parameter | Effect |
| --- | --- |
| `timestep` | Replace the fixed timestep; duration and integrator stay fixed. Every value must divide duration under the normal request tolerance. |
| `mass_ratio` | For massive systems, set m2 = ratio * base m1; m1 and all other masses stay fixed. For CR3BP, set mu = ratio / (1 + ratio), keeping the model's normalized total primary mass fixed; ratio must be in (0, 1]. |
| `mass[i]` | Replace one integrated body's mass in a massive system. |
| `position[i,j]`, `velocity[i,j]` | Replace body i, coordinate j of the integrated initial state. |
| `position_offset[i,j]`, `velocity_offset[i,j]` | Add the value to the corresponding **original** base-state entry. |
| `initial_x`, `initial_y` | CR3BP aliases for absolute `position[1,1]`, `position[1,2]` in the rotating frame. |
| `mu` | Direct CR3BP secondary/total primary mass fraction. |
| `primary_mass`, `primary_radius` | Circular Sitnikov force parameters. |

Indices are one-based; coordinate 1 is z for Sitnikov, whose integrated body
index is 1. Prescribed primaries are not editable state entries. Values use native
model units. Changing mass does not recenter states or recompute circular
velocities; this intentionally holds all other experiment inputs fixed.

The first parameter varies fastest. Input value order is preserved in tables;
line plots sort by the parameter coordinate. Duplicate, nonfinite, complex or
empty value vectors are rejected. A 2D sweep cannot set the same state component
through an alias and an offset, or combine mass ratio with a mass it depends on.
Two different independent mass entries may be swept together.

```r
# 1D mass ratio; m1 remains fixed
q = base$parameters$masses[2] / base$parameters$masses[1]
mass = run_parameter_sweep(base, list(mass_ratio = q * c(0.9, 1, 1.1)))

# 1D initial position and velocity perturbations
position = run_parameter_sweep(base, list("position_offset[2,1]" = c(-1000, 0, 1000)))
velocity = run_parameter_sweep(base, list("velocity_offset[2,2]" = c(-1, 0, 1)))

# 2D Cartesian grid
cr = studio_preset("earth_moon_trojan")
cr$duration = 0.2
xy = run_parameter_sweep(cr,
  list(initial_x = seq(0.48, 0.52, length.out = 3),
       initial_y = seq(0.85, 0.89, length.out = 3)),
  metrics = c("jacobi_relative_drift", "minimum_separation"))
studio_plot_sweep(xy, "minimum_separation")
```

The runnable [example script](../examples/comparisons/parameter_sweeps.R) covers
all of these, plus a finite-time Lyapunov metric sweep.

## Scalar metrics

Select one or several metric names from `sweep_metrics(base)`. Scalar metric
definitions and units are retained in the report.

- **Drift:** `energy_drift`, `energy_relative_drift`, `angular_momentum_drift`,
  `angular_momentum_relative_drift` for closed massive systems; `jacobi_drift`,
  `jacobi_relative_drift` for CR3BP; `specific_energy_drift`,
  `specific_energy_relative_drift` for Sitnikov. Values are the maximum absolute
  values of the existing signed drift series over stored samples. Undefined
  relative references yield NA and an `unavailable` metric status, never zero.
- **`minimum_separation`:** minimum over the existing sampled pairwise distance
  diagnostic. As in ordinary diagnostics, this includes prescribed primaries
  for CR3BP and Sitnikov; their mutual distance can set the minimum. It is not a
  continuous-time closest approach or exclusively a particle-primary distance.
- **`escape_time`:** requires `metric_options$escape_radius > 0`. The default
  `escape_body` is the last integrated body (index 1 for CR3BP/Sitnikov), and
  `escape_origin` defaults to the zero vector in integrated coordinate dimensions.
  The value is the first stored sample whose Euclidean distance from that fixed
  origin is at least the radius. Already outside gives 0; no crossing gives NA
  with status `not_reached`. This is a sampled radius crossing, not a proof of
  physical unbinding. The native frame and origin remain fixed across the grid.
- **`final_position_error`, `final_velocity_error`:** require
  `metric_options$reference = "analytic_circular"`, or a completed
  `simulation_result`. Analytic reference requires circular two-body initial
  conditions at each point. A numerical reference must have matching physical
  inputs, duration, model and constants; integrator/timestep may differ. Values
  are maximum Euclidean endpoint differences over integrated bodies, separately
  in length and velocity units. No interpolation is needed at the common final
  time. Changing physical parameters generally makes a fixed reference
  incompatible; that metric fails while the run and other metrics survive.
- **`finite_time_lyapunov`:** calls the existing nearby-trajectory renormalisation
  workflow for each member, using its full duration and timestep. Supply
  `metric_options$lyapunov` with explicit `epsilon`, `renormalisation_interval`,
  `position_scale`, and `velocity_scale`; `direction` or `component` is optional.
  The settings remain fixed across the grid, and intervals must fit each member's
  timestep. The metric is a directional finite-time estimate, with all the
  [Lyapunov workflow's limitations](LYAPUNOV.md). No chaos threshold is applied.
  Only its scalar estimate is retained in the sweep; rerun the member's analysis
  for the full separation and renormalisation history.

Metrics use the same saved trajectory samples as the standard runner. A very
coarse timestep can miss crossings or encounters and distort all metrics.
No metric here automatically establishes numerical convergence.

## Reports, history and failure handling

The `parameter_sweep` result contains:

- `grid`, `parameters`, `experiment`, `requests`: complete input grid and exact
  validated member requests.
- `runs`: grid point number, unique run ID, optional history path, simulation
  status and aggregate metric status.
- `scalar_metrics`: point number and the selected numeric metric columns.
- `metric_status`: per-point/per-metric status and an explanatory message.
- `failures`: point, run ID, stage, optional metric, error class and message.
- `results`: in-memory ordinary simulation results when not stored in history;
  also retains a completed result if publishing its history artifact fails.
- `metric_options`, registries, definitions, budget/limits, schema version,
  sweep identity, timestamp and engine provenance.

Request validation is all-or-nothing before execution: invalid grid entries
(including off-grid timesteps or initial overlaps) reject the sweep without
launching runs or creating history. Runtime failures are isolated to individual
points. Optional metric failures do not erase successfully integrated runs or
other metrics. The simulation status may therefore be `completed` while metric
status is `partial`. Inspect `metric_status` and `failures` when a value is NA.

Use `store_history = TRUE, directory = ".studio/history"` to retain each member
through standard queued/running/completed/failed history records and artifacts.
The run IDs in the sweep match those in history. `sweep_run(study, point)` loads
the selected standard result from memory or history and verifies its identity.
It can be passed to normal trajectory plots, diagnostics, exports or reruns.

`saveRDS(study, "study.rds")` saves the sweep. With history enabled, the report
contains absolute member paths rather than duplicate trajectories; preserve
those history files to inspect runs after reloading. Without history, the RDS
includes successful trajectories. There is no dedicated saved-sweep gallery,
portable manifest relocation or resume API in this first version.

## Studio and execution limits

The **Sweeps** tab uses the composer and its first selected integrator. Choose
one or two parameters, explicit comma-separated values or linear/logarithmic
ranges, and one or more metrics. A preview validates the grid and shows costs.
Timestep ranges are never silently rounded to a different resolution. The
Studio final-state reference is analytic circular two-body; the programmatic
interface additionally accepts numerical reference results.

One background worker processes points sequentially. Cancel stops the worker,
retains completed runs, and marks unfinished points cancelled. Atomic checkpoints
let the Studio recover completed points when a worker fails. Cancellation during
an extra metric can leave a completed trajectory with cancelled metric status.
This is partial-result recovery, not resumable execution. RDS and CSV downloads
retain the sweep and grid/metrics respectively.

The line plot leaves gaps at failed/unavailable points. Heatmaps show cells
centered on actual parameter values, including irregular grids, with unavailable
cells crossed out; they do not interpolate missing results. Click near a point
or use the point selector, inspect metric/failure details, then open its normal
run in the Viewer. No-history runs can also be inspected during the session.

Hard limits are **256 grid points**, **500,000 total integration steps**,
**4 million position values** and **20 million pair-steps**, in addition to all
ordinary per-request limits. Selecting the Lyapunov metric multiplies aggregate
cost estimates by three (ordinary run plus two analysis trajectories). Estimates
for prescribed-body models are conservative. The position budget is not a byte
budget: velocities, solver raw arrays, diagnostics and R object overhead also
consume memory. Limits are deliberately fixed for local/Codespace execution.

## Validation

`tests/validate_parameter_sweeps.R` checks grid ordering, unchanged base inputs,
mass-ratio semantics, deterministic metric reproduction, analytic/numerical
references, known radius crossings, Lyapunov agreement, invalid inputs, work
limits, isolated runtime/metric failures, history identity, RDS round-trips,
plots and cancellation preserving completed members.
`tests/validate_sweep_app.R` checks range inputs, background execution, 1D/2D
plots, point inspection with and without history, size rejection and cancellation.

Run `Rscript tests/run_all_tests.R` for the complete validation suite.
