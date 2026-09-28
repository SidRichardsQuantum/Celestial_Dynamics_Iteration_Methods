# Integrator Lab

The Lab extends the existing composer, fixed-step requests, background worker,
experiment history, compatibility checks and plotting helpers. It compares the
**same physical system, initial conditions, constants, units and duration** while
allowing integrators and timesteps to vary. Conservation, trajectory differences
and cost remain separate measurements; there is no best-integrator score.

## In Studio

1. Choose a Catalogue preset, or **Reuse** an existing Gallery experiment.
2. Select at least two available integrators in the composer. Physical inputs
   and duration are shared. Optionally enable **Set a different timestep for each
   integrator**, then enter each fixed timestep. Each must divide the duration and
   meet the existing per-run resource limits.
3. Choose the reference run for state differences. It is a numerical comparison
   baseline, not an exact solution or an automatically selected winner.
4. Press **Run simulation / comparison**. The existing background worker executes
   runs sequentially; the gallery shows the normal queued/running/completed/failed
   records. Existing cancellation works for the whole unfinished batch.
5. On completion, **Integrator Lab** opens the linked comparison, including any
   failures. It offers a compact metrics table, trajectory overlay, energy-error
   and angular-momentum-error plots, optional panels with shared coordinate
   limits, and the existing arbitrary diagnostic selector.
6. Use **Open** beside a constituent to inspect its normal Viewer page. Expand
   the detailed table or export Metrics CSV for absolute/relative conservation,
   separate position/velocity differences, validity and failure messages.
7. New batches automatically save comparison links. **Save comparison** retains
   a changed reference or a comparison assembled using **Compare selected runs**.
   **Saved comparisons → Load comparison** restores its members from history.

Models currently exposing only RK4 cannot run two distinct integrators. Their
saved runs at different timesteps can still be compared. Single runs retain the
existing composer workflow. Comparing already saved runs can also include the
same integrator with different timesteps.

## Programmatic workflow

No Shiny session is required. In a checkout, first run
`source("R/load.R"); cd_load_studio()`; installed-package users load the package.

```r
request <- studio_preset("circular_two_body")
# An existing experiment works too:
# request <- studio_load_history(existing_history_path)$request

settings <- list(Verlet = list(timestep = request$timestep / 2))
lab <- run_integrator_comparison(
  request, c("RK4", "Verlet"), settings,
  reference = "RK4", directory = ".studio/history"
)
lab$metrics
lab$members
lab$differences[[lab$members$run_id[2]]]
studio_plot_comparison(lab, "energy")
reloaded <- studio_load_comparison(lab$path)
```

`run_integrator_comparison` is synchronous and saves every attempted simulation
as ordinary history, continuing after numerical failures. File/persistence errors
are surfaced to the caller. It validates all settings and reference selection
before launching simulations. Only `timestep` can vary by integrator today;
unknown settings and attempts to override physical parameters or duration fail.

The asynchronous API reuses the existing job controller:

```r
requests <- studio_comparison_requests(request, c("RK4", "Verlet"), settings)
job <- studio_start_comparison(requests, reference = "RK4",
                              directory = ".studio/history")
# Source-checkout users also pass root = cd_project_root().
snapshot <- studio_poll_job(job)
# Later, after completion/cancellation:
lab <- studio_load_comparison(job$comparison_path)
# studio_cancel_job(job) cancels unfinished members and retains completed ones.
```

Construct a comparison from saved records with
`studio_compare_runs(c(path1, path2), reference = 1L)`. References accept an index,
scientific run ID, or unambiguous method name. To change it, call this function
with the same member paths and another reference, then save the returned object.
`studio_comparison_history(directory)` lists lightweight manifest metadata.

Existing APIs remain available:

- `compare_integrators(request, integrators, settings = list())` returns its
  original named list of completed results without writing history. A single
  method is still allowed and errors still propagate to the caller.
- `studio_comparison(results)` returns its original compatibility-checked table.
- `studio_plot_trajectories` and `studio_plot_diagnostic` retain existing calls.
  Trajectory plots additionally accept optional shared axis limits.

## Comparison object and persistence

`integrator_comparison` is a passive S3 list with:

| Field | Meaning |
|---|---|
| `schema_version`, `id`, `timestamp` | Comparison identity, currently schema 1 |
| `problem` | Shared physical request, excluding method, timestep and display-only labels |
| `reference_run_id`, `reference_status` | Explicit baseline and current status |
| `members` | Ordinary record paths, scientific run IDs, methods, timesteps, statuses and errors |
| `metrics` | One numeric/status row per attempted run |
| `differences` | Position/velocity difference time series by run ID; NULL if unavailable |
| `results`, `diagnostics` | Completed run objects and structured reports in memory; NULL for incomplete runs |
| `definitions` | Units, alignment and interpretation |
| `path` | Manifest path when saved/loaded through the workflow |

Manifests live at `<history>/.comparisons/<comparison-id>.json`. The normal
history scanner still sees only run records. A manifest stores member filenames,
run IDs, identity and reference selection; it does **not** duplicate scientific
artifacts. All members must be in the same history directory to save a comparison.
Moving that whole directory preserves relative links. Missing files, altered run
identities, incompatible physics and links escaping the history directory fail
explicitly. Duplicate records of the same scientific run cannot masquerade as
independent attempts.

Loading retrieves saved trajectories and recomputes metrics with the current
analysis code. It does not integrate again and does not rewrite member data.
Run provenance remains available in `results`; comparison metrics are not an
immutable snapshot of a historical analysis implementation.

Background batches save the manifest immediately after launch. Failed/cancelled
members remain linked. Loading an active comparison gives a status snapshot;
reload it to refresh external jobs. Studio refreshes its own batch at completion.
The existing session-close cancellation behavior remains unchanged.

## Numerical definitions

Conservation metrics reuse [the diagnostics framework](DIAGNOSTICS.md).
Column names explicitly distinguish maximum absolute drift and maximum absolute
relative drift. Centre-of-mass drift is the residual from expected uniform motion,
not displacement from the initial position. Zero/cancelling denominators produce
`NA`; absolute conservation drift remains available. CR3BP uses Jacobi drift,
and circular Sitnikov uses specific-energy drift, without closed-system energy
or angular momentum claims. The energy-error view displays those model-specific
invariants when appropriate. If relative drift is undefined, the plot uses a
common absolute drift quantity and labels it accordingly.

For candidate run A and reference B, let the comparison grid be the sorted union
of their stored time grids. Both span the same duration and share endpoints.
Interpolate each body's coordinates and velocities **piecewise-linearly** at
these times, without extrapolation, phase adjustment, body permutation or frame
transformation. At each grid point compute:

$$d_r(t)=\max_{i\in\text{integrated bodies}}\|\mathbf r_i^A(t)-\mathbf r_i^B(t)\|_2,$$
$$d_v(t)=\max_{i\in\text{integrated bodies}}\|\mathbf v_i^A(t)-\mathbf v_i^B(t)\|_2.$$

Prescribed primaries do not participate in state differences. Native frames are
retained, including rotating coordinates for CR3BP.

- `final_position_difference` and `final_velocity_difference` use the common
  endpoint's actual stored states, without interpolation error at the endpoint.
- `max_position_difference` and `max_velocity_difference` are maxima over the
  union knots, i.e. maxima of the differences between piecewise-linear interpolants.
- Position differences are in metres for SI models; velocity differences are in
  metres/second. CR3BP uses its normalized units. They are never added together.
- The reference's own differences are zero. That is a baseline definition, not
  evidence of physical accuracy.
- If the reference failed, was cancelled, or remains queued/running, all state
  differences are unavailable. A substitute is never selected silently.

On unequal grids, interpolation error can dominate numerical integration error,
especially when the reference is coarse. Use a sufficiently resolved reference and
check timestep convergence. These differences are comparisons, not validated error
bounds against the true orbit. Finite successful trajectories can still be inaccurate.

## Performance and limits

`runtime_seconds` is the existing one-shot solver adapter timing, including its
original internal summaries, excluding additional Studio diagnostics, comparison
analysis, preview generation and persistence. No statistical benchmarking or
warm-up correction is implied. `step_count` and `force_evaluation_count` come from
recorded solver statistics. Current solvers do not instrument force counts;
unavailable counts and failed-run timings remain `NA`. Older runs without step
statistics also retain `NA` in the new report.

Batches run sequentially in one worker. Each request keeps the existing 100,000
step / 256 body / 2 million position-value / 10 million pair-step limits; these
are per-run limits, not an aggregate memory budget. Comparison construction loads
all completed members and recomputes diagnostics, whose pairwise work scales as
samples × bodies². Difference analysis uses the union time grids and processes
all integrated coordinates. Results, diagnostics and differences remain in memory,
so large saved-run comparisons can be expensive. Side-by-side views become crowded
with many members; the overlay and numeric tables remain available.

Focused validation is in `tests/validate_integrator_lab.R`; Studio server coverage
is in `tests/validate_studio_app.R`. Both run through `tests/run_all_tests.R`.
Tests cover identical physical inputs, per-method timestep validation, conservation
and endpoint metrics, linear interpolation, explicit reference changes, singular
solver failure with subsequent success, save/reload and relocation, unsafe/missing
links, model applicability, zero angular momentum, background completion/cancellation,
and the existing comparison APIs.
