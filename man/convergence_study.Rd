\name{run_convergence_study}
\alias{run_convergence_study}
\alias{studio_convergence_requests}
\alias{studio_start_convergence_study}
\alias{studio_convergence_study}
\alias{studio_save_convergence_study}
\alias{studio_load_convergence_study}
\alias{estimate_convergence_order}
\alias{studio_plot_convergence}
\alias{print.convergence_study}
\alias{summary.convergence_study}
\title{Fixed-Timestep Convergence Studies}
\description{Compare resolutions of one integrator against an explicitly chosen reference, preserving ordinary Studio runs and comparison links.}
\usage{
run_convergence_study(request, integrator, timesteps, reference,
  reference_run = NULL, estimate_order = TRUE, directory = ".studio/history")
studio_convergence_requests(request, integrator, timesteps)
studio_start_convergence_study(request, integrator, timesteps, reference,
  reference_run = NULL, estimate_order = TRUE, directory = ".studio/history",
  root = NULL)
studio_convergence_study(paths, reference, reference_run = NULL,
  estimate_order = TRUE)
studio_save_convergence_study(study)
studio_load_convergence_study(path)
estimate_convergence_order(timesteps, errors)
studio_plot_convergence(study, metric = "final_position_error",
  log_log = TRUE, show_fit = TRUE)
\method{print}{convergence_study}(x, ...)
\method{summary}{convergence_study}(object, ...)
}
\arguments{
\item{request}{A \code{simulation_request} specifying the common physical problem and duration.}
\item{integrator}{One supported integrator identifier, such as \code{"RK4"}.}
\item{timesteps}{At least two distinct positive finite timesteps, each dividing duration into an integer number of steps within request validation tolerance.}
\item{reference}{Required choice: \code{"analytic"}, \code{"finest"}, or \code{"numerical"}.}
\item{reference_run}{For a numerical reference, a completed result or history path. Saved-run analysis requires a path. The physical problem, duration, units and constants must match.}
\item{estimate_order}{Whether to fit empirical orders.}
\item{directory}{History directory; execution requires jsonlite.}
\item{root}{Project root for the existing background job worker, which requires callr.}
\item{paths}{Paths to at least two saved runs of one integrator at distinct resolutions.}
\item{study, x, object}{A convergence study result.}
\item{path}{Saved convergence comparison manifest path.}
\item{errors}{Numeric errors corresponding to timesteps.}
\item{metric}{A metric name from the study's metric registry.}
\item{log_log}{Use logarithmic axes instead of linear axes.}
\item{show_fit}{Overlay the empirical fit on a log-log plot when available.}
\item{...}{Reserved for S3 compatibility.}
}
\details{
The analytic reference currently supports circular two-body Kepler orbits,
including uniform barycentre motion. Other initial conditions are rejected.
The finest reference is the smallest-timestep study member, even if it fails;
it is never silently replaced. Numerical references are approximations,
not exact solutions. Users select their high-accuracy numerical reference;
the framework does not certify its accuracy.

State metrics report final and maximum sampled position and velocity errors
separately, as maximum Euclidean differences across integrated bodies in
native units. Candidate stored times are used; numerical reference states
are linearly interpolated without extrapolation. Interpolation and reference
error can limit observed convergence. Conservation metrics measure drift
from initial invariants independently of the state reference. Unsupported
invariants remain unavailable. Runtime measures the solver adapter call,
excluding analysis and persistence; step counts and available diagnostics
come from the comparison architecture.

Order estimates are unconstrained least-squares slopes of log(error) against
log(actual timestep), with adjacent-resolution estimates and inclusion records.
Failed or invalid runs, nonfinite or nonpositive errors, and numerical reference
self-differences are excluded. Theoretical order is metadata; conservation
slopes need not match it. Sampled maxima can miss between-sample peaks.
}
\value{
Execution and saved-run analysis return a \code{convergence_study} with a
metrics table, metric registry, sampled error series, estimates, theoretical
order, explicit reference metadata and underlying comparison. Summary returns
the metrics table; print gives a compact description. Saving returns a manifest
path; loading reconstructs the study from its linked history runs.
Request preparation returns requests; background execution returns a Studio
job with a convergence manifest path. The order estimator returns fit statistics,
sample inclusion records and local slopes. Plotting invisibly returns plotted
sample information, or NULL when no metric values are eligible.
}
\examples{
if (requireNamespace("jsonlite", quietly = TRUE)) {
  request <- studio_preset("circular_two_body")
  request$duration <- request$duration / 4
  directory <- tempfile("convergence-")
  study <- run_convergence_study(request, "RK4",
    request$duration / c(20, 40, 80), reference = "analytic",
    directory = directory)
  summary(study)
  study$estimate_table
  studio_plot_convergence(study)
  unlink(directory, recursive = TRUE)
}
}
