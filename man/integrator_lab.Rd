\name{integrator_lab}
\alias{integrator_lab}
\alias{studio_comparison_requests}
\alias{run_integrator_comparison}
\alias{studio_start_comparison}
\alias{studio_compare_runs}
\alias{studio_save_comparison}
\alias{studio_load_comparison}
\alias{studio_comparison_history}
\alias{studio_plot_comparison}
\title{Integrator Lab: linked multi-run comparisons}
\description{Run the same physical problem with multiple integrators, retain each
attempt as ordinary history, and compare conservation, state differences and cost
without combining them into a ranking or score. Scientific computation does not
require Shiny.}
\usage{
studio_comparison_requests(request, integrators, settings = list())
run_integrator_comparison(request, integrators, settings = list(),
                         reference = integrators[1],
                         directory = ".studio/history")
studio_start_comparison(requests, reference = 1L,
                        directory = ".studio/history", root = NULL)
studio_compare_runs(paths, reference = 1L)
studio_save_comparison(comparison)
studio_load_comparison(path)
studio_comparison_history(directory = ".studio/history")
studio_plot_comparison(comparison,
    view = c("trajectory", "energy", "angular_momentum", "side_by_side"))
}
\arguments{
\item{request}{One validated simulation_request, for example from studio_preset
or a loaded experiment's request.}
\item{integrators}{At least two distinct available method identifiers.}
\item{settings}{Named list by selected integrator, such as
list(RK4 = list(timestep = 100)). Currently timestep is the only supported override;
physical parameters and duration cannot vary. Omitted timesteps use the base request.}
\item{requests}{Compatible requests, normally from studio_comparison_requests.
New background batches require distinct integrators.}
\item{reference}{A one-based member index, scientific run ID, or unambiguous
integrator name. New batches also accept method names before run IDs exist.}
\item{directory}{Ordinary Studio history directory. Each attempt gets a normal
record; comparison manifests live in its .comparisons subdirectory.}
\item{root}{Source checkout root for the existing background worker, or NULL
for an installed package.}
\item{paths}{At least two distinct history record paths, including completed,
failed, cancelled, queued or running attempts. Repeated scientific run IDs are rejected.}
\item{comparison}{An integrator_comparison returned by these functions.}
\item{path}{A comparison manifest under a history .comparisons directory.}
\item{view}{Trajectory overlay, model-appropriate energy-error time series,
angular-momentum-error time series, or trajectory panels with shared axis limits.}
}
\value{studio_comparison_requests returns named ordinary simulation_request objects.
run_integrator_comparison executes sequentially, saves each attempt and a comparison
manifest, and returns an integrator_comparison. Numerical failure of one member does
not prevent later members from running. studio_start_comparison returns the existing
job object plus comparison_path; use studio_poll_job and studio_cancel_job normally,
then studio_load_comparison to obtain current statuses and metrics.

studio_compare_runs and studio_load_comparison return a passive S3 list with
schema_version, id, timestamp, problem, reference_run_id, reference_status,
members, metrics, differences, results, diagnostics and definitions. Members link
record paths and run IDs; metrics has one row per attempted run. Results and
diagnostics hold completed trajectories/reports in memory; other entries are NULL.
Differences contains per-member numeric time series of position and velocity
differences, or NULL if the member or reference is incomplete. Save/load operations
add or return the manifest path. studio_save_comparison returns a file path;
studio_comparison_history returns named manifest metadata without loading trajectories.
Plotting draws on the current graphics device.
}
\details{
Compatibility uses the existing studio_comparison rules: system, physical initial
conditions, constants, units and duration agree exactly; method and timestep can
vary. Body identity/order is retained; display-only primary labels may differ.
Existing saved-run comparisons can include the same method at different timesteps.
Models with only one available integrator cannot launch a new multi-integrator
batch, but can compare compatible saved runs.

For each stored time on the union of a run's grid and its reference grid, positions
and velocities are interpolated piecewise-linearly without extrapolation. Position
difference is max_i norm(r_i(t)-r_ref_i(t)); velocity difference is defined separately
as max_i norm(v_i(t)-v_ref_i(t)). Only integrated bodies participate. These use native
coordinates (including the rotating CR3BP frame). Final differences use the common
endpoint's actual states; maximum differences use all union knots. Position and
velocity are never added into a mixed-unit score. The reference is a numerical
trajectory, not a claim of truth, and interpolation can dominate when its grid is
coarse. A failed or missing reference leaves all differences NA; no substitute is
silently selected.

Metrics include runtime_seconds, step_count, force_evaluation_count, explicit
maximum absolute and relative energy/angular momentum drift, centre-of-mass drift,
model-specific Jacobi or circular Sitnikov drift, final/max position and velocity
differences, trajectory_valid, status and error. Definitions and denominator
safeguards come from simulation_diagnostics. Missing force evaluations and failed-run
statistics remain NA. Model-inapplicable invariants remain NA. The energy view uses
Jacobi or specific energy for restricted models; angular momentum is explicitly
unavailable there. Plots fall back to absolute drift if relative references are
undefined. Runtime is one solver adapter call, excluding diagnostics added by Studio,
comparison analysis, previews and persistence.

Manifests store relative history-record links, scientific run IDs and the chosen
reference, not copies of trajectory data. Save requires all members in one history
directory. Moving the entire history tree preserves links; removing or replacing a
member fails explicitly on load. Loading recomputes metrics from stored trajectories
using the current diagnostics implementation, without rerunning simulations.
The background workflow saves its manifest immediately; cancellation and partial
failure retain the links and ordinary run records. Save again after changing a
reference to retain that choice. These functions require optional jsonlite;
background execution additionally requires callr. Batches use one sequential worker,
not parallel integrator execution. All completed member trajectories are loaded in
memory for analysis; large comparisons can consume substantial memory.

The existing compare_integrators API remains a lightweight named list of results
and accepts optional settings without writing history. studio_comparison continues
to return its original completed-run table.
}
\examples{
\dontrun{
request <- studio_preset("circular_two_body")
request$duration <- 10 * request$timestep
lab <- run_integrator_comparison(request, c("RK4", "Verlet"),
    settings = list(Verlet = list(timestep = request$timestep / 2)),
    reference = "RK4", directory = tempfile("lab-history-"))
lab$metrics
studio_plot_comparison(lab, "energy")
reloaded <- studio_load_comparison(lab$path)
}
}
