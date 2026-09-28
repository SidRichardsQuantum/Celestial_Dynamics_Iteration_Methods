\name{studio}
\alias{studio}
\alias{cd_load_studio}
\alias{simulation_request}
\alias{run_simulation}
\alias{compare_integrators}
\alias{studio_catalog}
\alias{studio_integrators}
\alias{studio_presets}
\alias{studio_preset}
\alias{studio_request_json}
\alias{studio_request_from_json}
\alias{studio_save_history}
\alias{studio_load_history}
\alias{studio_history}
\alias{studio_export_trajectory}
\alias{studio_plot_trajectories}
\alias{studio_plot_diagnostic}
\alias{studio_plot_3d}
\alias{studio_animation}
\alias{studio_load_result}
\alias{studio_set_favorite}
\alias{studio_comparison}
\alias{studio_gallery_metadata}
\alias{studio_start_job}
\alias{studio_poll_job}
\alias{studio_cancel_job}
\title{Celestial Dynamics Studio}
\description{Catalog-driven requests and thin adapters around the existing fixed-step
Newtonian solvers, with diagnostics, presets, plotting and optional JSON history.}
\usage{
cd_load_studio()
simulation_request(system, integrator, parameters, duration, timestep)
run_simulation(request, progress = function(stage) invisible(NULL))
compare_integrators(request, integrators, settings = list())
studio_start_job(requests, directory = ".studio/history", root = NULL)
studio_poll_job(job)
studio_cancel_job(job, reason = "Cancelled by user.")
studio_catalog()
studio_integrators()
studio_presets()
studio_preset(name)
studio_request_json(request)
studio_request_from_json(text)
studio_save_history(result, directory = ".studio/history", preset = NULL,
                    tags = character(), favorite = FALSE)
studio_load_result(path)
studio_set_favorite(path, favorite)
studio_comparison(results)
studio_gallery_metadata(record, presets = studio_presets())
studio_load_history(path)
studio_history(directory = ".studio/history")
studio_export_trajectory(result, path)
studio_plot_trajectories(results, axes = c(1L, 2L), frame = "native",
                         limits = NULL)
studio_plot_diagnostic(results, diagnostic)
studio_plot_3d(result, azimuth = 35, elevation = 25, frame = "native")
studio_animation(result, path, axes = NULL, frame = "auto")
}
\arguments{
\item{system}{Catalog identifier: two_body, three_body, n_body, restricted_three_body, or sitnikov.}
\item{integrator}{Compatible identifier from \code{studio_integrators()}.}
\item{parameters}{Named list matching the catalog parameter schema. Massive systems use masses,
positions and velocities (body by coordinate matrices); restricted models use their catalog fields.}
\item{duration, timestep}{Positive values in system time units. Duration must be an integer multiple
of timestep, with at most 100000 steps, 256 massive bodies, 2 million position values,
and 10 million pair-steps (steps times the number of distinct body pairs).}
\item{requests}{List of validated requests to run sequentially in one background process.}
\item{root}{Source checkout root, or NULL to load the installed package in the worker.}
\item{job}{A job returned by studio_start_job, containing its owned process and record paths.}
\item{reason}{Cancellation reason retained in history.}
\item{progress}{Callback receiving actual coarse execution stages.}
\item{preset}{Optional preset identifier for presentation metadata.}
\item{favorite}{Logical flag stored in the history record.}
\item{tags}{Distinct nonempty presentation tags, each at most 64 characters.}
\item{record}{A loaded history record.}
\item{presets}{Preset catalogue used for metadata labels.}
\item{request}{A validated simulation_request object.}
\item{integrators}{Distinct compatible integrator identifiers for comparison.}
\item{settings}{Optional named list of per-integrator settings; currently only timestep.
See \code{\link{run_integrator_comparison}} for the persistent comparison workflow.}
\item{name}{Preset identifier from \code{studio_presets()}.}
\item{text}{JSON request text, never executable R code.}
\item{result}{A simulation_result object.}
\item{results}{One result or a list of results from the same physical setup.}
\item{directory}{Local directory for versioned JSON history files.}
\item{path}{Input or output file path.}
\item{axes}{Two coordinate indices for the displayed projection. Animation defaults to x-z
for Sitnikov and x-y otherwise.}
\item{limits}{Optional list with increasing finite two-element x and y plot bounds,
in displayed units (AU for SI systems, normalized coordinates for CR3BP).
Used to share scales in comparison panels.}
\item{frame}{Display frame: native or inertial. CR3BP native coordinates rotate with
the primaries. Animation auto selects inertial for CR3BP and native otherwise.
Display context includes prescribed CR3BP primaries without altering solver states.}
\item{diagnostic}{Applicable diagnostic column name from the result or its diagnostic registry.
See \code{\link{simulation_diagnostics}} for the structured diagnostics interface.}
\item{azimuth, elevation}{Orthographic camera angles in degrees.}
}
\value{Catalog and preset functions return named lists. The request constructor returns a validated
S3 list. A simulation result contains the resolved request, time, position and velocity arrays
(time by body by coordinate), original solver output, units, diagnostics, summaries and provenance.
Comparison returns a named list of results. History loading returns metadata and a validated request;
history saving returns its file path. New records use history schema 4 and retain
the scientific run ID separately from the archive-record ID. See \code{\link{studio_validate_result}}
for run validation, schema migration and reproduction. Plot functions draw on the current device. Export and animation
functions write files and invisibly return their path.}
\details{Massive models use SI units and planar Newtonian gravity. CR3BP uses normalized rotating
coordinates and the Jacobi constant. Circular Sitnikov uses particle specific energy.
Relative drift is undefined for a zero initial invariant. All methods are fixed-step; Verlet is
symplectic for its supported systems. Runtime is a single elapsed solver call, not a benchmark.
JSON functions need optional package jsonlite. Shiny is needed only for the source-checkout app.
Background jobs require optional package callr. Polling returns process liveness and current
history records; cancellation stops unfinished runs and preserves completed results. Closing the
Shiny session cancels its unfinished batch. For installed packages, no source loader is needed.}
\examples{
request <- studio_preset("circular_two_body")
request$duration <- 10 * request$timestep
result <- run_simulation(request)
head(result$diagnostics)
}
