\name{studio_runs}
\alias{studio_validate_result}
\alias{studio_run_summary}
\alias{studio_rerun}
\alias{studio_result_json}
\alias{studio_result_from_json}
\alias{studio_set_tags}
\alias{print.simulation_result}
\alias{summary.simulation_result}
\title{Versioned scientific simulation runs}
\description{Validate, summarize, serialize and reproduce the scientific run
returned by \code{run_simulation()}. The existing \code{simulation_result} class
and its trajectory fields are preserved.}
\usage{
studio_validate_result(result)
studio_run_summary(result)
studio_rerun(result, progress = function(stage) invisible(NULL),
             allow_engine_change = FALSE)
studio_result_json(result)
studio_result_from_json(text)
studio_set_tags(path, tags)
\method{print}{simulation_result}(x, ...)
\method{summary}{simulation_result}(object, ...)
}
\arguments{
\item{result, x, object}{A completed \code{simulation_result}.}
\item{progress}{Callback receiving the existing runner's coarse progress stages.}
\item{allow_engine_change}{Allow a different or unknown package/source identity,
with a warning. A changed physical gravitational constant still prevents rerunning.}
\item{text}{Typed scientific JSON produced by \code{studio_result_json()}, or
legacy typed result JSON. It is distinct from the simpler request JSON format.}
\item{path}{A history metadata JSON file.}
\item{tags}{Distinct nonempty strings, each at most 64 characters. Use
\code{character()} to clear tags. Tags do not modify the scientific artifact.}
\item{...}{Reserved for S3 compatibility.}
}
\value{Validation invisibly returns the validated result, upgrading schema 1 in
memory when needed. Summaries return one data-frame row. Rerunning returns a new
result with a fresh ID and parent-run lineage. Serialization returns a JSON
string; decoding returns a validated result. Tag updates return the metadata path.
Printing invisibly returns its input.}
\details{
Result schema 2 retains \code{request}, \code{time}, \code{positions},
\code{velocities}, \code{masses}, \code{body_names}, \code{units}, \code{raw},
\code{diagnostics}, \code{diagnostic_summary}, \code{runtime_seconds},
\code{timestamp} and \code{provenance}. Additions are \code{id},
\code{schema_version}, \code{model}, \code{timestamps} and \code{lineage}.
The request remains the sole source of initial conditions, physical parameters,
integrator selection, duration and fixed timestep. Model metadata specifies the
force formulation, version, frame, units, constants and integrated/prescribed
body roles. Provenance records package version, R, platform and source checksums
captured at source load or package build. Runtime still measures the solver call,
including its existing summaries, and excludes Studio diagnostics and persistence.

Validation checks passive data types, request structure, finite trajectory arrays,
initial conditions, fixed time grid, diagnostic alignment and summaries, runtime,
provenance and timestamps. It does not independently certify numerical accuracy.
Unknown result schemas are rejected. Legacy typed results are upgraded without
recomputing trajectories or diagnostics; unknown start times and source identity
remain unknown. Save the returned upgrade to retain a newly assigned standalone
legacy run ID. History loading derives legacy identity from the record instead.

History schema 4 stores a \code{run_id} alongside its archive-record \code{id}.
Repeated \code{studio_save_history()} calls retain scientific identity while
creating separate records, as before. Favorites, tags and preset labels live
only in metadata. Background jobs use the same ID from queueing to completion.
Schemas 1--3 remain readable without rewriting files. Metadata-only records can
be reused, but cannot supply an original trajectory.

Historical decoding does not apply current Studio resource budgets; running a
request still does. Current catalogue definitions are still required. Rerunning
does not restore an old software environment and does not promise bitwise
equivalence across R versions or platforms. All persistent data is passive;
closures, environments, reactive objects and process handles are rejected.
JSON and history operations require the optional \pkg{jsonlite} package.
}
\examples{
request <- studio_preset("circular_two_body")
request$duration <- 5 * request$timestep
run <- run_simulation(request)
print(run)
summary(run)
repeated <- studio_rerun(run)
stopifnot(repeated$lineage$parent_run_id == run$id)
if (requireNamespace("jsonlite", quietly = TRUE)) {
  restored <- studio_result_from_json(studio_result_json(run))
  stopifnot(identical(restored, run))
}
}
