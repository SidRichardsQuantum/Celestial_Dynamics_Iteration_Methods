# Convergence studies

Use one physical problem and duration, varying the fixed timestep of one
integrator. Each timestep must divide the duration into an integer step count.

```r
library(CelestialDynamicsIterationMethods)
request <- studio_preset("circular_two_body")
request$duration <- request$duration / 4
study <- run_convergence_study(request, integrator = "RK4",
  timesteps = request$duration / c(20, 40, 80, 160),
  reference = "analytic")
summary(study)                         # runtime, steps, errors and diagnostics
study$estimate_table                   # fitted slopes and number of fit points
study$estimates$final_position_error    # local slopes and excluded samples
studio_plot_convergence(study, log_log = FALSE)
studio_plot_convergence(study)
restored <- studio_load_convergence_study(study$path)
```

Explicitly choose a reference:

- `analytic`: closed-form circular two-body orbit, evaluated in floating point.
  Unsupported initial conditions are rejected before execution.
- `finest`: smallest-timestep member of the study. Its own state difference is
  zero and is excluded from state-order fits. A failed finest run leaves state
  differences unavailable; no replacement reference is chosen.
- `numerical`: supply `reference_run` as a completed result or saved history path.
  Choose a suitably accurate integrator and resolution for the same physical
  problem and duration. Its method and timestep are recorded and displayed;
  accuracy is not certified and it is never labelled exact.

Position and velocity remain separate because they have different units.
Final-state errors use endpoint differences; trajectory errors are maxima over
candidate stored times and integrated bodies. Numerical reference trajectories
are interpolated linearly, so interpolation and reference errors may dominate
at fine resolutions. Conservation errors are drift from initial invariants,
independent of the reference. Unavailable diagnostics stay `NA`.

Empirical orders use positive finite errors from valid completed runs. Inspect
fit ranges and adjacent slopes before interpreting a global fit; roundoff and
coarse timesteps can distort it. Theoretical integrator order is metadata,
not a fit constraint. Set `estimate_order = FALSE` to disable fitting.
Timings are individual solver calls, not repeated performance benchmarks.

In Studio, configure the physical experiment in the composer, open
**Convergence**, choose the integrator, timesteps and explicit reference, then
run the study. The existing background job handles progress and cancellation.
The panel provides linear and log-log plots, order estimates, a metrics table,
CSV download, saved studies and links to each run. **Open runs in Integrator Lab**
uses the shared comparison architecture. Study manifests link ordinary history
records and trajectories; keep those files together when retaining a study.
