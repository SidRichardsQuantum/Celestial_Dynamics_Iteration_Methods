\name{experiment_plan_schema}
\alias{experiment_plan_schema}
\alias{cd_load_experiment_planning}
\alias{validate_experiment_plan}
\alias{parse_experiment_plan}
\alias{plan_experiment}
\alias{mock_experiment_provider}
\alias{experiment_plan_requests}
\title{Optional Data-Only Experiment Planning}
\description{Provider-neutral experiment proposals with strict typed-data validation, explicit clarification and conversion to ordinary numerical simulation requests. Planning never integrates trajectories or executes generated code.}
\usage{
cd_load_experiment_planning()
experiment_plan_schema()
validate_experiment_plan(plan)
parse_experiment_plan(text)
plan_experiment(prompt, provider)
mock_experiment_provider(response)
experiment_plan_requests(plan)
}
\arguments{
\item{plan}{Plain named R list following the version-one typed schema. No classes, calls, expressions, functions, environments, matrices or nonfinite values. Matrix parameters use lists of numeric row lists.}
\item{text}{One JSON object encoded as a string, at most 64 KiB. Only JSON is decoded; R source, filenames, URLs, prose and code fences are rejected.}
\item{prompt}{Nonempty natural-language description, at most 8000 bytes.}
\item{provider}{Explicitly supplied trusted adapter function with arguments \code{prompt} and \code{schema}, returning a single JSON string. No vendor adapter or SDK is bundled.}
\item{response}{Fixed JSON response returned by the deterministic mock. The mock does not interpret language.}
}
\details{
\code{experiment_plan_schema()} is the authoritative typed R schema and provider
context, derived from the installed catalogue, integrator registry, model registry
and presets. It is not a JSON Schema dialect. All objects reject unknown and
duplicate fields. The root fields are:
\describe{
\item{schema_version}{Required numeric value 1.}
\item{kind}{\code{simulate} (one integrator) or \code{compare} (at least two distinct integrators).}
\item{system, model}{Actual catalogue and dynamical-model IDs, with an existing compatible adapter.}
\item{preset}{Actual preset ID, or explicit NULL for custom initial conditions. An absent field requires clarification.}
\item{parameters}{Optional uniquely named object of registered system parameters. Empty means preset values or registered defaults. Numeric scalars, numeric vectors, rectangular row arrays and label vectors follow the catalogue types. Unknown parameters are always rejected.}
\item{integrators}{Nonempty array of distinct registered IDs compatible with the selected system. No aliases are silently substituted.}
\item{duration, timestep}{Objects with only \code{value} (positive finite number) and \code{unit} (\code{model_time} or \code{preset_periods}). No implicit units or timestep rounding.}
\item{plots}{Array of \code{trajectory} and/or diagnostic IDs supported by the system. An empty array explicitly requests no plots. This is a display specification, not numerical output.}
}

Except for schema_version, missing or NULL essential values are permitted in
drafts and produce \code{needs_clarification}, never runnable requests. Explicit
NULL preset selects custom inputs. Parameter overrides set to NULL also require
clarification. Registered optional parameter defaults may be used, but time,
integrators, model, system, kind and requested plots are never guessed.

JSON arrays must actually be arrays; scalar integrator IDs are rejected. For
typed R input, unnamed atomic vectors may represent integrator, plot and numeric
vector arrays. Empty objects use \code{setNames(list(), character())}; empty
arrays use \code{list()} or \code{character()} for ID arrays.

Reference periods are restricted to named known-period presets enumerated by
the schema. A catalogue duration is not generally an orbital period. Period
units are forbidden with parameter overrides. Model-time units are the existing
system units (SI seconds or normalized CR3BP time). Presets may use another
explicitly chosen backend only when model and initial parameters remain compatible.

Existing \code{simulation_request} validation enforces collision, shape,
integrator compatibility, integer step counts and execution limits. Planning
adds a 500000 aggregate-step budget, 12 nesting levels, 256 KiB for typed R data
and bounded strings/arrays. These checks do not certify numerical accuracy.
\code{experiment_plan_requests} always revalidates its input; classes or saved
validation flags never bypass checks.

The provider is trusted application code configured by the host, not generated
code. It receives only the prompt and public schema; its response is untrusted
data. The planner never evaluates R source, runs shell commands, invokes tools
selected by the provider, loads response paths, changes physics models or accepts
provider-generated trajectories/diagnostics. Raw provider exceptions are not
returned because they may contain secrets. Adapters must enforce their own
network timeouts and read credentials from environment variables or a secret
store outside source control. There is no implicit provider selection or network
access. Normal Studio does not load or invoke this feature unless opted in.

The optional Studio review panel requires missing values to be resolved and
explicit approval of the exact plan. Editing inputs invalidates approval.
Confirmation loads the composer only; the normal Run action invokes existing
numerical solvers. Plot IDs are retained in review; use the existing Viewer or
Integrator Lab for the requested diagnostics. No chat UI or generated-results
explanation is implemented in this first layer.
}
\value{
\code{experiment_plan_schema} returns field descriptors, compatibility tables,
parameter types/defaults, units, reference periods and boundary rules.
\code{validate_experiment_plan}, \code{parse_experiment_plan} and
\code{plan_experiment} return lists with \code{status} (\code{ready},
\code{needs_clarification}, \code{invalid}, or \code{provider_error}),
\code{errors} and \code{clarifications} data frames (field and message),
plain \code{plan}, \code{requests}, and a resolved \code{preview} table.
Requests and preview are NULL unless ready. Invalid plans are not retained.
Provider failures return a generic message; programmer errors in prompt/provider
arguments raise errors. \code{experiment_plan_requests} returns named ordinary
\code{simulation_request} objects or errors if the plan is not ready.
\code{mock_experiment_provider} returns a deterministic adapter function.
}
\examples{
plan <- list(schema_version = 1, kind = "compare", system = "n_body",
  model = "newtonian_gravity", preset = "figure_eight",
  integrators = c("Verlet", "RK4"),
  duration = list(value = 20, unit = "preset_periods"),
  timestep = list(value = 0.001, unit = "preset_periods"),
  plots = "energy_relative_drift")
review <- validate_experiment_plan(plan)
review$status
review$preview
requests <- experiment_plan_requests(plan)
# No integration occurs until the caller explicitly runs these requests.
}
