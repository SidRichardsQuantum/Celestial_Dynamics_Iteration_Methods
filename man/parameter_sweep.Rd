\name{run_parameter_sweep}
\alias{run_parameter_sweep}
\alias{prepare_parameter_sweep}
\alias{sweep_parameters}
\alias{sweep_metrics}
\alias{sweep_run}
\alias{studio_plot_sweep}
\title{Bounded One- and Two-Parameter Experiment Sweeps}
\description{Run a sequential Cartesian family of ordinary simulation requests, with independent run identities, optional history, selected scalar metrics and per-point failure metadata.}
\usage{
sweep_parameters(experiment)
sweep_metrics(experiment)
prepare_parameter_sweep(experiment, parameters,
  metrics = "minimum_separation", metric_options = list())
run_parameter_sweep(experiment, parameters,
  metrics = "minimum_separation", metric_options = list(),
  store_history = FALSE, directory = ".studio/history")
sweep_run(sweep, point)
studio_plot_sweep(sweep, metric = sweep$metrics[1])
}
\arguments{
\item{experiment}{A base \code{simulation_request}. Its integrator, duration and all unswept inputs stay fixed.}
\item{parameters}{Named list of one or two distinct finite real numeric vectors. Names come from \code{sweep_parameters(experiment)}.}
\item{metrics}{Distinct metric names from \code{sweep_metrics(experiment)}.}
\item{metric_options}{Named list. Escape time requires positive \code{escape_radius}, with optional integrated \code{escape_body} (default last) and fixed \code{escape_origin} (default zero). Final-state errors require \code{reference = "analytic_circular"} or a compatible completed \code{simulation_result}. Lyapunov requires a \code{lyapunov} list containing epsilon, renormalisation_interval, position_scale and velocity_scale; direction or component is optional.}
\item{store_history}{Whether to save ordinary member run records and artifacts. Defaults to FALSE; no JSON dependency is needed without history.}
\item{directory}{Member history directory when storing results.}
\item{sweep}{A \code{parameter_sweep} result.}
\item{point}{One-based integer grid row to inspect.}
\item{metric}{Selected scalar metric to plot.}
}
\details{
Parameters include timestep; mass_ratio; mass[i]; position[i,j] and velocity[i,j];
position_offset[i,j] and velocity_offset[i,j]; CR3BP initial_x, initial_y and mu;
and Sitnikov primary_mass and primary_radius. Indices refer to integrated states,
so Sitnikov has body 1 and coordinate 1 (z). Absolute coordinates replace one
entry; offsets add to the original base request, never to previous grid points.
Mass ratio sets m2 = ratio * m1 with m1 fixed in massive systems, or
mu = ratio / (1 + ratio) in CR3BP with normalized total mass fixed.
No recentering or adjustment of velocities is performed. Overlapping or
interdependent sweep parameters are rejected.

The first parameter varies fastest; supplied value order is retained. All
requests are validated before any execution or history writes. A timestep must
divide fixed duration under ordinary request tolerance. Invalid points reject
the whole plan. Runtime failures are isolated by point; optional metric failures
do not erase successful trajectories. Every member uses run_simulation with a
unique scientific ID, matching its history record if stored.

Energy, angular momentum, Jacobi and specific-energy drift metrics are maxima
of the absolute existing drift series, with model-appropriate metrics only.
Relative drift is unavailable for undefined initial references. Minimum
separation uses the sampled pair-distance diagnostic, including prescribed
primaries. Escape time is the first sample at or beyond a fixed radius about
the specified origin in native coordinates, not proof of physical unbinding;
already outside gives zero and no crossing gives NA with status not_reached.

Final position/velocity errors are separate maximum Euclidean endpoint errors
over integrated bodies. An analytic reference requires circular two-body
initial conditions at each point. A numerical reference must match physics,
duration, model and constants; integrator and timestep may differ. A changed
physical configuration generally makes a fixed numerical reference incompatible.

The Lyapunov metric calls run_lyapunov_analysis with fixed options and each
member's timestep and full duration. It retains only the scalar finite-time
directional estimate, not a true asymptotic exponent or chaos classification.
Intervals must be compatible with each member's timestep. Unavailable diagnostics
and failed extra analyses yield NA and explicit status/failure messages.

Hard aggregate limits are 256 points, 500000 integration steps, 4 million
position values and 20 million pair-steps. Lyapunov multiplies estimated cost
by three. Prescribed-body budgets are conservative. Ordinary per-run limits
also apply. Velocity arrays, raw solver output and R overhead require memory
beyond the position count. There is no parallel/HPC infrastructure or resume API.

Plots use actual parameter coordinates: a sorted line for 1D, cells with midpoint
boundaries for 2D. Missing values are gaps/crossed cells, never interpolated.
Save the report with saveRDS. When history is enabled, keep its linked absolute
history paths; trajectories are not duplicated in the report. Without history,
successful trajectories are retained in memory and serialized with the report.
}
\value{
\code{sweep_parameters} returns a descriptor table of parameter IDs, labels,
base values, state fields, indices, modes and dependency targets.
\code{sweep_metrics} returns metric IDs, labels and units.
\code{prepare_parameter_sweep} returns a \code{parameter_sweep_plan} containing
the grid, resolved requests, settings, registries and aggregate budget/limits,
without execution or persistence.

\code{run_parameter_sweep} returns a \code{parameter_sweep} containing the plan
fields plus sweep identity, timestamp, provenance, \code{runs} (point, run_id,
path, simulation status and aggregate metric status), \code{scalar_metrics},
per-metric \code{metric_status}, \code{failures} (point, run ID, stage, metric,
error class and message), in-memory \code{results}, and metric definitions.
Simulation status can be completed while metric status is partial.
\code{sweep_run} retrieves and verifies one standard simulation_result.
\code{studio_plot_sweep} draws on the current device and returns the sweep invisibly.
}
\examples{
base <- studio_preset("earth_moon_trojan")
base$duration <- 0.1
study <- run_parameter_sweep(base,
  list(initial_x = c(0.49, 0.51), initial_y = c(0.85, 0.87)),
  metrics = c("minimum_separation", "jacobi_relative_drift"))
study$scalar_metrics
member <- sweep_run(study, 1)
studio_plot_sweep(study, "minimum_separation")
}
