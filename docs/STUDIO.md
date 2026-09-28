# Studio architecture and repository audit

The Studio is implemented natively in R. Shiny was chosen over Streamlit because
all production solvers, diagnostics, plotting, and tests are R code. It needs no
Python bridge or second physics implementation. Background execution uses a separate
R process that calls the same package runner.

## Audit before implementation

| Area | Existing implementation | Studio reuse |
| --- | --- | --- |
| Package | `DESCRIPTION`, `NAMESPACE`, `R/zzz-package.R` loads nested sources; `R/load.R` supports source checkouts | Additive loader and exports; existing signatures retained |
| Two-body | Planar Newtonian gravity; Euler, explicit midpoint, explicit Heun, classical RK4, velocity Verlet; method registry | Original five functions through adapters; registry supplies order and symplectic metadata |
| Three-body | Planar general RK4; figure-eight, Lagrange, Euler collinear, Butterfly I generators | Original RK4 and figure-eight generator; other generators remain available |
| N-body | Planar RK4 and velocity Verlet; rotating-square and triangular-central generators | Original engines, square generator, Solar System initial conditions |
| Restricted | Spatial rotating-frame CR3BP RK4; circular equal-mass Sitnikov RK4 | Original solvers with stricter request validation |
| Projectile | Constant-gravity Euler, midpoint, Heun, RK4; write plots and return a scalar ratio | Preserved outside Studio; no structured trajectory API to adapt |
| Diagnostics | Two/three/N-body energy and planar angular momentum; relative drift | N-body helpers on normalized massive-body state arrays; additional state-derived metrics |
| Visualisation | Base R PNG orbit plots and style helpers; canvas HTML animations; CR3BP rotating/inertial projections and Sitnikov plots | Shared style, palette, trajectory helpers and HTML animation; new device-independent comparison and camera views |
| Entry points | R functions and `Rscript` examples; `run_all_examples.R`; `analysis/generate_results.R`; no web server | New R API and optional `app/app.R` |
| Tests | `tests/run_all_tests.R`; scientific, input, structure and artifact validation; restricted/special checks included via three-body suite | Existing suite retained; new Studio validation and optional Shiny server smoke tests |
| Examples | Projectile, Sun-Earth/Earth-Moon, general/restricted/special three-body, planetary/four-body, comparisons | Explicit presets derived from constants, generators and selected example initial conditions |
| Configuration | Plain R lists, scalar solver arguments, shared SI constants; CR3BP normalized units | Validated S3 requests/specifications/results; no new mandatory dependencies |
| Python | Optional SciPy figure-eight initial-condition helper, `requirements.txt` | Unchanged |
| Automation | R validation/build workflow, plot regeneration and Pages publishing | JSON/Shiny validation enabled in R CI |

No existing solver is adaptive. Explicit midpoint is not implicit midpoint and
is not symplectic. Velocity Verlet is second-order symplectic for the supported
separable Newtonian systems. Three-body Studio requests use the existing dedicated
RK4 routine; choose N-body with three masses if you want to compare RK4 and Verlet.

## Modules

- `R/studio/catalog.R`: S3 simulation/integrator specifications and parameter schemas.
- `models.R`: S3 request constructor; shared input, compatibility, shape and resource validation.
- `runs.R`: scientific result validation, model context, provenance, identity, summaries and reruns.
- `runner.R`: adapters, normalized result arrays and same-setup comparisons.
- `diagnostics.R`: invariant series, drift, orbital elements and summaries.
- `presets.R`: explicit SI or normalized initial conditions and provenance descriptions.
- `history.R`: versioned JSON records, scientific artifact persistence, favorites, request reload and CSV export.
- `experiments.R`: deterministic gallery metadata and saved-result comparison policy.
- `jobs.R`: background worker ownership, lifecycle records, polling and cancellation.
- `gallery.R`: derived metadata index, filtered pagination and bounded preview cache.
- `plots.R`: plots and animation adapters, separate from integration.
- `app/app.R`: reactive controls generated from the catalog; no numerical algorithms.

The catalog declares required fields and optional defaults, dimensions, units,
compatible methods, diagnostics, visualisations, validation callbacks and solver
adapters. The API and UI use the same catalog. A new solver adapter can be added
without creating a new screen.

## API and result contract

```r
source("R/load.R")
cd_load_studio()
preset <- studio_preset("circular_two_body")
request <- simulation_request(
  system = preset$system,
  integrator = "Verlet",
  parameters = preset$parameters,
  duration = preset$duration,
  timestep = preset$duration / 2000
)
result <- run_simulation(request)
comparison <- compare_integrators(request, c("RK4", "Verlet"))
studio_plot_trajectories(comparison)
studio_plot_diagnostic(comparison, "energy_relative_drift")
path <- studio_save_history(result)
replayed <- run_simulation(studio_load_history(path)$request)
studio_export_trajectory(result, "trajectory.csv")
```

Installed-package users can call the exported Studio functions after
`library(CelestialDynamicsIterationMethods)` without sourcing or calling a loader.

`parameters` is a named list. Massive systems use a positive mass vector and
body-by-2 position/velocity matrices. CR3BP uses `mu` and a six-component `state0`, plus optional `primary_names`
(two display labels, defaulting to Primary 1 and Primary 2). Labels do not affect
the solver and are stored in the request for reproducible display.
Sitnikov uses `primary_mass`, `primary_radius`, `z0`, `vz0`, with defaults in the
catalog. Massive systems have an editable table with one row per body and columns
for mass (kg), x/y (m) and vx/vy (m/s). N-body systems allow adding and removing
rows within the 2–256 body limit; new rows require explicit values. Two- and
three-body systems keep their fixed row counts. Advanced JSON controls remain
available and synchronize with the table, preserving numerical precision.
Other array parameters use JSON; input is never evaluated as R code.

The composer validates drafts before submission, displays duration/timestep as
the step count per integrator, and places errors beside their fields. Checks
include finite values, positive masses, array shapes, distinct initial positions,
integer step counts and the existing resource limits. Run is disabled while the
draft is invalid or the session has a batch running. Submission uses the same
validated requests as the live feedback and still enforces server-side checks.

Composer server regression checks are included in `tests/validate_studio_app.R`.
Optional browser checks live in `tests/validate_studio_composer.cjs` and require
Playwright with Chromium installed. Start the Studio with an isolated
`CELESTIAL_STUDIO_HISTORY` directory, then run `node tests/validate_studio_composer.cjs`
with Playwright on Node's module path. Set `STUDIO_URL` if the app is not at
`http://127.0.0.1:8766`. These checks create a short run in that history directory.

The result contains `request`, `time`, `positions` and `velocities` (time × body ×
coordinate), `masses` (NULL for restricted models), `body_names`, `units`, the
unchanged original solver return value in `raw`, `diagnostics`,
`diagnostic_summary`, `timestamp`, `provenance`, and `runtime_seconds`.
CR3BP states are rotating-frame particle states. Sitnikov states include both
prescribed primaries and the vertical particle. Runtime measures one solver call
(including existing solver summaries), excludes Studio diagnostics and plotting,
and is not a benchmark.

New runs also include `diagnostic_registry` (metric kinds, units and definitions)
and `solver_statistics` (completed fixed steps; force evaluations are unavailable
unless explicitly recorded). `simulation_diagnostics(result)` returns a structured
report with series, detailed summaries, performance, validity and encounter flags.
See [Diagnostics](DIAGNOSTICS.md) for the API, equations and assumptions. The
selected-run Diagnostics tab uses this report, including for old saved runs.

The requested timestep must divide the duration within floating-point tolerance;
the underlying solver uses `duration / round(duration / timestep)`. The Studio
limits runs to 100,000 steps, 256 massive bodies, 2 million position values,
and 10 million pair-steps (`steps * bodies * (bodies - 1) / 2`). The pair-step
limit bounds quadratic workload; it is not a count of force evaluations (RK4
evaluates forces four times per step). Limits are checked before physics
validation allocates pairwise distances. Existing solver APIs are unaffected.
All initial conditions and fixed-step solver settings are explicit. No random
sampling is used. Timestamps and runtimes vary; floating-point trajectories are
reproducible within numerical tolerance on equivalent R/platform versions.

## Scientific run contract

`run_simulation()` is the constructor for a completed scientific run. It still
returns `simulation_result`; no second experiment wrapper or copy of the request
is needed. Its schema is now version 2:

```text
simulation_result
  id, schema_version
  request: system, integrator, parameters, duration, timestep
  model: version, force, formulation, frame, units, constants, body_roles
  time, positions, velocities, masses, body_names, units, raw
  diagnostics, diagnostic_summary
  runtime_seconds, timestamp
  timestamps: started_at, completed_at
  provenance: package, package_version, engine, R, platform, G,
              source_fingerprint, studio_schema
  lineage: parent_run_id
```

The request owns all initial conditions, model parameters and integrator
settings; the current fixed-step methods need only its existing `timestep`.
`time` is the actual saved sample grid. Model context records the implemented
force law, physical units, reference frame and each body's role. CR3BP has one
integrated test particle and normalized equations with no physical G parameter;
Sitnikov includes two prescribed primaries in its geometry. No new adjustable
force law or integrator setting is implied by these descriptors.

`studio_validate_result()` checks finite trajectory arrays, raw-state agreement, initial conditions,
time-grid consistency, diagnostic alignment and summaries, metadata and passive
data types. It returns the validated object invisibly. `print(run)` gives a short
description; `summary(run)` and `studio_run_summary(run)` return a one-row table.
Validation is structural and does not establish trajectory accuracy.

```r
request <- studio_preset("circular_two_body")
request$duration <- 5 * request$timestep
run <- run_simulation(request)
run <- studio_validate_result(run)
path <- studio_save_history(run, tags = c("baseline", "convergence"), favorite = TRUE)
saved <- studio_load_result(path)
stopifnot(identical(saved, run))
restored <- studio_result_from_json(studio_result_json(saved))
repeated <- studio_rerun(restored)
stopifnot(repeated$id != run$id, repeated$lineage$parent_run_id == run$id)
studio_set_tags(path, "reviewed")
```

Full-result JSON uses the existing typed scientific encoding at 17-digit
precision. It is distinct from request JSON and preserves dimensions, names,
NA/NaN/Inf and classes. Only passive supported data types are decoded; functions,
environments, Shiny reactive objects and worker handles cannot be persisted.
Favorites, tags and preset labels stay in authoritative history metadata and do
not alter scientific artifacts. Repeated saves produce separate archive record
IDs while retaining the same scientific `run_id`.

History schemas 1–3 load without being rewritten. Old full results gain schema-2
metadata in memory and use the historical record ID as their stable run ID.
Their trajectories, diagnostics and original provenance are retained. Unknown
start times/source identity remain unknown. A standalone legacy result has no
historical identity, so validation/import assigns an ID: retain the returned
object to keep it stable. Metadata-only histories still cannot provide an old
trajectory. Future unknown schemas are rejected explicitly.

Historical decoding skips current execution budgets; execution revalidates
them. The currently supported catalogue schemas are still required. Rerunning
checks package version and source checksums captured at checkout load or package
build. A missing/different identity requires `allow_engine_change = TRUE` and
emits a warning. A changed physical G is rejected because the existing engines
cannot execute an arbitrary historical constant. New runs always retain their
actual engine provenance and get a fresh ID with parent lineage. Source checksums
detect changes, but do not restore an old environment or certify unmodified
in-memory functions; cross-platform/R-version bitwise reproducibility is not
promised. Runtime continues to measure the solver call, not the complete workflow.

This release supplies the single-run foundation. Sweep definitions, experiment
groups, adaptive integration and additional analysis algorithms remain future
features; existing comparison and gallery workflows continue to consume results.

## Scientific interpretation

Massive systems use SI units and unsoftened point-mass gravity. The Studio does
not introduce collision regularization or adaptive stepping. Finite results can
still be inaccurate if a timestep is too large, especially at close encounters.
Use conservation plots and timestep refinement to assess a run.

- Energy, total linear momentum, and planar angular momentum apply to isolated
  massive systems. Two-body semi-major axis and eccentricity use relative state
  vectors and `G * (m1 + m2)`; these are osculating Kepler elements.
- CR3BP uses Jacobi constant `x²+y²+2((1-mu)/r1+mu/r2)-|v|²`, not inertial
  total energy or massive-system momentum. Its time unit is inverse primary
  angular speed, so the primary orbital period is `2*pi`.
- The implemented *circular* Sitnikov problem conserves particle specific energy
  `vz²/2 - 2*G*m/sqrt(radius²+z²)`. This would not be conserved for eccentric
  time-dependent primaries, which are not implemented here.
- Relative drift is `(Q(t)-Q(0))/abs(Q(0))`. It is `NA` if the initial invariant
  is zero or cancels at roundoff scale. Absolute series remain visible; this
  avoids misleading relative angular-momentum drift for figure-eight states.
- Summary `max_absolute_change` is `max(abs(Q(t)-Q(0)))`; for relative-drift
  columns it is the maximum absolute relative drift. JSON stores undefined
  metrics as `null`. Unbound Kepler trajectories can have negative semi-major
  axis; near-parabolic energy yields `NA` for the undefined finite semi-major axis.

Spatial models have x-y/x-z/y-z projections and a rotatable orthographic 3D
camera view. Plots and animation include the prescribed CR3BP primaries as
context. Pair-separation diagnostics include these primaries as geometry, while
particle invariants and exported solver states retain their original meanings.
Inertial views rotate both primaries and particle consistently; native
CR3BP views use the solved rotating coordinates. Named Earth/Moon or Sun/Jupiter
labels are explicit preset metadata, not inferred from a custom mass ratio.

Animation uses the existing canvas utility, capped at 900 frames; only its
presentation is downsampled. Camera bounds use the full trajectory extrema,
relative padding and equal spatial scale, without an arbitrary 0.02-unit minimum.
Coordinate serialization retains double precision so small librations survive
export. The compact embedded view has fit-visible, per-body fit, zoom (1–1000x),
and optional body-following controls. A focused view can put other bodies off
screen; resetting to All visible bodies restores context. Markers are not
physical radii. CR3BP animations default to an inertial view; choose rotating and
fit Test particle for small Trojan librations. Sitnikov defaults to x-z.

Playback spans the entire run in 20 wall-clock seconds at 1x, independent of
browser refresh rate, shows the simulation time and stops at the final sample.
Play then replays from the beginning. Raw data exports retain all timesteps.
No Poincare utility exists in the repository; Sitnikov phase-space plots are
provided without claiming to be Poincare sections.

## Preset validation and encounter limits

Nineteen presets span all five system families. New configurations reuse the
existing Lagrange, Euler collinear, Butterfly I, and triangular four-body
generators; barycentric Earth-Moon and equal-mass binaries use the same Kepler
initial-condition construction as Sun-Earth. Restricted additions include an L5
Trojan and an initially retrograde lunar orbit perturbed by Earth's gravity.
Sitnikov includes two amplitudes with durations long enough to see oscillations.

The Pythagorean preset now runs to dimensionless time 2 (in units of
`sqrt(AU^3/(G*M_EARTH))`) with 100,000 RK4 steps. It reaches the first close
encounter, with minimum separation below 0.02 AU. Validation compares 50,000 and
100,000 steps: measured maximum relative energy drift improves from about
3.08e-4 to 1.75e-5, with maximum position difference about 1.52e-5 AU. These
checks support this finite interval, not arbitrary longer chaotic evolution.
Simply extending the duration at fixed step count can make encounters unreliable.
The Butterfly initial conditions are approximate and use the existing example's
100,000-step resolution.

Every complete default preset is checked for conservation. The UI flags relative
energy, Jacobi, or circular-Sitnikov specific-energy drift above 1e-3 (0.1%).
Passing this heuristic does not prove trajectory accuracy; convergence under
step refinement remains necessary, especially for close encounters and chaos.

## Experiment workflow

1. **Catalogue:** browse the nineteen existing presets grouped by catalogue system,
   or search descriptions. Use preset loads its physical inputs into the composer.
2. **Composer:** choose compatible methods, edit the body table (or advanced JSON)
   and scalar parameters, resolve inline errors, then run. Selecting several integrators runs the same problem with
   each method sequentially in one background worker. Units and method order come
   from the package catalogue. Run submits immediately; keep browsing while it runs.
   Cancel unfinished runs stops this session's batch. Completed runs are preserved.
3. **Gallery:** every saved experiment has a status, ID and timestamp. Completed
   cards show actual trajectory previews, body count, timestep, duration, solver
   runtime and the applicable conservation drift. Search matches preset, system,
   integrator or ID; filters include each system, favorites, failures, cancelled and
   active runs. Page sizes are 6, 12 (default), 24 or 48. Filtering resets to page 1;
   selections remain intact across pages and filters. Completion updates the gallery
   without replacing a viewer you are inspecting.
4. **Viewer:** View opens the original saved result without rerunning it. Inspect
   physical inputs, integration metadata, initial/final invariants, conservation
   warnings, trajectory/3D plots and animation. Export request JSON, trajectory
   CSV or diagnostic CSV. Undefined drift remains NA, never a synthetic score.
5. **Reuse:** the structured request restores system, method, duration, timestep,
   masses, positions, velocities and every model-specific parameter. The composer
   shows Custom to permit edits without reapplying a preset. Preset labels in
   history identify matching physical initial conditions; they do not override
   the saved numerical request. JSON uses 17 significant digits for round-trips.
6. **Compare:** select two or more completed cards, then Compare selected runs.
   The [Integrator Lab](INTEGRATOR_LAB.md) extends this view with an explicit
   reference, state-difference metrics, dedicated energy/angular-error plots,
   shared-scale trajectory panels, constituent links, and saved comparison manifests.
   Composer batches can set timesteps per integrator and open the Lab automatically
   on completion, retaining failed/cancelled members. Conservation and cost stay
   separate; no aggregate score or automatic best method is assigned.
   A table reports actual diagnostic summaries, step counts, methods, timesteps
   and runtimes; plots overlay trajectories and any shared diagnostic. Select
   angular-momentum drift or the absolute invariant when relative drift is
   undefined. Run IDs distinguish repeated methods. Comparisons require identical
   system, physical inputs, duration, units and gravitational constant. Display
   labels may differ. Trajectory and conservation plots retain each run's original
   time grid. State-difference metrics use explicitly documented linear
   interpolation on the union of the candidate/reference time grids.
7. **Favorites:** Favorite/Unfavorite updates the record atomically and survives
   restarts. Favorites can be filtered. No records are automatically pruned, so
   favorites cannot silently age out.

## History schema and artifacts

The existing `.studio/history/` directory remains the only persistence store.
`CELESTIAL_STUDIO_HISTORY` overrides it. Schema 2 introduced `id`, `status`, `favorite`,
`preset`, warning messages and relative artifact references to the existing
request, timestamp, provenance, runtime and diagnostic summary fields.
Schema 3 introduced background runs: the same stable run ID transitions through queued,
running, completed, failed or cancelled, with an actual `stage` and timestamped
`lifecycle` entries. Requests are saved before the worker starts. Completed records
also retain `submitted_at`; their main timestamp records run completion.
New synchronous and background records use schema 4, adding `run_id`, tags and,
for completed runs, `result_schema_version` and parent-run lineage. Schemas 1–3
remain supported. Each synchronous save still creates a separate archive record;
its `run_id` identifies the unchanged scientific run. Background record and run
IDs are the same from queueing through completion.

```text
.studio/history/
  run-<unique-id>.json           # authoritative metadata and resolved request
  run-<unique-id>/
    result.json.gz              # typed JSON: original full scientific result
    preview.png                 # static trajectory, derived using package plots
  .jobs/<first-run-id>/
    stdout.log                  # worker output
    stderr.log                  # worker errors
```

Typed JSON preserves R array dimensions, special numerical values and raw solver
output without executable R deserialization. Metadata is atomically published
only after artifacts finish; failed publication cleans up that attempt's artifact
folder. Artifact access is restricted to the history directory. CSV downloads and
canvas animations are generated on demand from the stored result. Animation keeps
the existing play/pause, speed, seek/replay, projection and frame controls.
No second database or manifest is introduced.

Schema 1 records load with completed status and favorite=false by default. Their
requests and summaries remain intact. They have no original trajectory, so the
viewer explains that artifacts are unavailable and offers Reuse; it never runs
new calculations while presenting them as an old result. Favoriting a legacy
record preserves its schema and all original fields. Invalid history files are
skipped with a visible warning. The Refresh history button picks up other sessions.

## Lifecycle and limitations

The composer validates all requests before launching one `callr` R process per
session batch. The worker calls the unchanged `run_simulation()` and saves artifacts
outside Shiny's event loop. The UI polls metadata every 400 ms while a job exists;
there is no synthetic iteration percentage. Stages are queued, validating,
integrating, computing diagnostics, saving artifacts, then completed. Failed runs
keep their actual error and stage. A worker crash is detected by the controller and
unfinished records become failed; other normal solver failures do not prevent
later requests in that batch from running.
Crash handling removes unpublished artifacts only after the worker has stopped,
preserving completed results and unrelated files. If worker launch fails, each
queued request retains the original launch error in its saved history record.

Cancel unfinished runs terminates and reaps the owned worker before publishing
cancelled statuses and removing unpublished artifacts. Already published results
remain completed, including a completion that races with cancellation. Queued
requests are cancelled too. Their exact requests and cancellation reasons remain
available to View/Reuse. A session cannot submit another batch until its current
batch terminates. It can inspect history, change filters, reuse a request or
compare older results while the worker runs. Each session owns its own worker;
there is no cross-session global concurrency limit.

Closing or reloading the browser cancels unfinished work in that session. The
worker supervisor also stops child processes if the Shiny process exits. An abrupt
server crash can leave last-known queued/running metadata; those records can be
reused but are not resumed or automatically reconciled on restart. Malformed
composer inputs fail visibly before a valid request exists and are not saved.
Full result loading and interactive plotting still run in Shiny when View is
requested, so very large viewers may briefly occupy its event loop.

Gallery metadata is indexed in memory from authoritative history JSON. Only the
current page's cards and previews are rendered. PNG bytes are cached per session
with least-recently-used eviction (48 entries or 8 MiB). File size and modification/
change times invalidate changed files; missing files show an unavailable preview.
Images use a session-scoped endpoint, content-hash URLs, lazy loading and private
immutable browser caching. The endpoint serves only previews registered by that
session, never the entire history directory. Cache eviction does not delete saved
artifacts. Browsing and cache misses never rerun scientific calculations. Metadata
listing still reads the complete history; there is no persistent index/database.

History remains uncapped and full results can be large. Favorites use atomic file
replacement, not multi-user conflict resolution, and can be toggled once a run is
terminal. Runs with different durations or differently represented initial states
are conservatively rejected for comparison. No new closure metric or adaptive
scientific method is introduced. Existing physical defaults and limits are unchanged.

Background API example from a checkout:

```r
source("R/load.R")
cd_load_studio()
job <- studio_start_job(list(studio_preset("circular_two_body")),
                        root = cd_project_root())
state <- studio_poll_job(job)  # nonblocking liveness and history records
# studio_cancel_job(job)      # stop unfinished work; keep completed results
```

Installed-package callers omit `root`. The synchronous `run_simulation()` API is
unchanged and does not require callr.

The design borrows catalogue-driven settings, resolved-request reuse, artifact
cards, viewer actions and favorite semantics from
[OpenHiggsfield](https://github.com/wide-trace/open-higgsfield), inspected directly
in its composer, catalogue, gallery, viewer, history and polling modules. This
implementation stays R/Shiny and does not add generative AI or external services.
`R/studio/experiments.R` contains gallery metadata and comparison policy; numerical
integration and diagnostic calculations remain in their existing modules.

## Codespace launch and validation

From the repository root, on an image without R:

```bash
sudo apt-get update
sudo apt-get install -y r-base r-cran-shiny r-cran-jsonlite r-cran-callr
Rscript -e 'shiny::runApp("app", host="0.0.0.0", port=8765, launch.browser=FALSE)'
```

Open forwarded port 8765 in the Codespaces Ports panel. With an existing R install,
missing optional dependencies can instead be installed with:

```bash
Rscript -e 'install.packages(c("shiny", "jsonlite", "callr"), repos="https://cloud.r-project.org")'
```

Validation commands:

```bash
Rscript tests/run_all_tests.R
Rscript tests/validate_studio_experiments.R
Rscript tests/validate_studio_background.R
Rscript tests/validate_studio_gallery.R
R CMD build . --no-build-vignettes --no-manual
R CMD check CelestialDynamicsIterationMethods_0.1.0.tar.gz --no-manual --ignore-vignettes
```

No R linting or formatting configuration is currently defined. Existing source
style is retained. Scientific checks, server smoke tests and experiment persistence
tests are part of the full validation script.
