# Orbital diagnostics

`simulation_diagnostics(result)` evaluates normalized trajectories outside Shiny.
It extends the existing diagnostics data frame and leaves legacy solver functions,
`studio_diagnostics(result)` and `studio_diagnostic_summary(diagnostics)` available.
No new package dependency is required.

```r
source("R/load.R")
cd_load_studio()  # unnecessary when using the installed package
request <- studio_preset("figure_eight")
result <- run_simulation(request)
report <- simulation_diagnostics(result, near_collision_distance = 1e9)
report$series                      # time plus numeric metric columns
report$registry                    # names, kinds, units and definitions
report$summary                     # initial/final/minimum/maximum, etc.
report$performance                 # runtime, completed steps, force evaluations
report$validity                    # shape/time/mass checks, NA/NaN/Inf counts
report$flags                       # encounter flags and thresholds
report$unavailable                 # reasons for unavailable diagnostics
```

The input is the existing `simulation_result`, or a normalized list with `time`,
`positions`, `velocities`, `request` and, for massive systems, `masses`. Arrays have
shape **time × body × coordinate**. A request identifies the physical model and
its parameters. The supplied arrays are the diagnostic source; `raw` is not used.
This allows inspection of failed or externally assembled trajectories. Full
persistence validation remains the separate `studio_validate_result()` API.

New runs retain the numeric `diagnostics` data frame and the original
`diagnostic_summary` layout. They additionally record `diagnostic_registry` and
`solver_statistics`. These fields are optional for old schema-2 runs; loading an
old run does not rewrite its saved diagnostics. Calling `simulation_diagnostics`
recomputes the extended report. The catalog's existing diagnostic lists remain
the required compatibility subset, while the report registry lists all metrics.

## Quantities and numerical definitions

For closed, planar Newtonian point-mass systems, let
$r_{ij}=|\mathbf r_i-\mathbf r_j|$ and $M=\sum_i m_i$.

| Quantity | Definition | Units |
|---|---|---|
| `energy` | $E=K+U=\tfrac12\sum_i m_i|\mathbf v_i|^2-G\sum_{i<j}m_im_j/r_{ij}$ | J |
| `momentum_x`, `momentum_y` | Components of $\mathbf P=\sum_i m_i\mathbf v_i$ | kg m/s |
| `angular_momentum` | $L_z=\sum_i m_i(x_i v_{yi}-y_i v_{xi})$, about the coordinate origin | kg m²/s |
| `centre_of_mass_x`, `centre_of_mass_y` | Components of $\mathbf R=\sum_i m_i\mathbf r_i/M$ | m |
| `centre_of_mass_velocity_x`, `centre_of_mass_velocity_y` | Components of $\mathbf V=\mathbf P/M$ | m/s |
| `minimum_pairwise_separation` | $\min_{i<j}r_{ij}$ at each stored time | position units |
| `maximum_pairwise_separation` | $\max_{i<j}r_{ij}$ at each stored time | position units |

`energy_drift` and `angular_momentum_drift` are signed $q(t)-q(0)$.
`momentum_drift_x/y` are signed components of $\mathbf P(t)-\mathbf P(0)$;
`momentum_drift` is its Euclidean norm. This detects a change in momentum direction
as well as magnitude.

`centre_of_mass_drift` is
$|\mathbf R(t)-\mathbf R(0)-(t-t_0)\mathbf V(0)|$.
A physically moving barycentre should follow this straight line. Subtracting only
its initial position would incorrectly flag uniform motion as numerical error.
`centre_of_mass_velocity_drift` is $|\mathbf V(t)-\mathbf V(0)|$.

Scalar `*_relative_drift` is the signed relative conservation error
$(q(t)-q(0))/|q(0)|$. `momentum_relative_drift` is
$|\mathbf P(t)-\mathbf P(0)|/|\mathbf P(0)|$. These are dimensionless errors from
the initial invariant, not fitted drift rates or errors against an exact trajectory.

A reference is undefined when its magnitude is at most
$100\epsilon\max(S,\mathrm{double.xmin})$. The initial cancellation scale $S$ is:

- energy: $\max(K_0,|U_0|)$;
- angular momentum: $\sum_i(|m_i x_i v_{yi}|+|m_i y_i v_{xi}|)_0$;
- momentum: $\sum_i m_i|\mathbf v_i(0)|$;
- Jacobi/specific energy: the larger absolute initial kinetic and potential term.

Undefined relative series are `NA`, including zero momentum or angular momentum
in barycentric and figure-eight examples. Absolute quantities and drifts remain
available. This scale-aware rule also handles small, nonzero quantities in other
units without imposing a fixed absolute epsilon.

Two-body osculating elements retain their existing definitions using relative
position and velocity: $a=-GM/(2e)$ and
$\mathbf e=((v^2-GM/r)\mathbf r-(\mathbf r\cdot\mathbf v)\mathbf v)/(GM)$.
The semi-major axis is `NA` when specific orbital energy cancels to roundoff
(parabolic limit); eccentricity is $|\mathbf e|$.

## Model applicability

Only the existing closed planar massive models receive total energy, momentum,
angular momentum and centre-of-mass diagnostics. An explicit modified force law,
frame or model configuration is not silently treated as Newtonian gravity.
Unrecognized models get geometry/state checks and an unavailability reason.
The report uses recorded model `G`, then provenance `G`; for older normalized
inputs lacking both, it uses the current engine `G`.

CR3BP receives the Jacobi constant in its normalized rotating frame:
$C=x^2+y^2+2[(1-\mu)/r_1+\mu/r_2]-|\mathbf v|^2$.
Circular Sitnikov receives test-particle specific energy
$e=v_z^2/2-2Gm/\sqrt{a^2+z^2}$, where $a$ is each primary's orbital radius.
These receive absolute and relative drifts, but no closed-system massive invariants.
The Sitnikov invariant relies on circular prescribed primaries; it does not apply
to general elliptic Sitnikov forcing.

Separation diagnostics cover all pairs in stored positions. For CR3BP they
explicitly include the two prescribed primaries as geometry, including the
primary-primary pair. They do not assign masses to the integrated test particle
or include prescribed bodies in total-energy/momentum calculations.

## Summaries, checks and performance

The registry distinguishes `absolute`, `absolute_drift`, `relative_error` and
`flag` metrics. Each summary row contains:

- `initial` and `final`: actual first and last values, including missing values;
- `minimum`, `maximum`, `max_absolute`: finite-sample extrema;
- `max_absolute_change`: maximum finite $|q(t)-q(0)|$, unavailable if the initial value is not finite;
- `finite_samples` and `nonfinite_samples`: coverage counts, including intentionally undefined relative/flag values.

All-unavailable extrema are `NA`, never `-Inf`. A last missing value is never
replaced by the last finite value. Inspect coverage before comparing extrema.
The legacy summary keeps its original three fields for history compatibility.

Validity checks cover matching arrays, time alignment, strictly increasing finite
time, positive finite masses of the correct length, and separate trajectory
`NA`, `NaN` and `Inf` counts. Derived `NaN`/`Inf` counts expose arithmetic overflow.
Invalid structure returns an empty series and issues; individual non-finite samples
do not discard all other samples. `state_finite` is a numeric 0/1 series.

`collision` flags minimum separation at or below `collision_distance` (default 0,
exact point overlap); singular total energy is unavailable at overlap. A positive
collision threshold represents the caller's chosen physical criterion.
`near_collision` is `NA` unless `near_collision_distance` is supplied in position
units, and then flags minimum separation at or below that threshold. There is no
universal near-collision radius for these point-mass models. Thresholds are
returned in `flags`. If any sample crosses a threshold the aggregate flag is true;
otherwise missing samples leave it unknown. Only **stored samples** are checked:
encounters between samples, solver stages and failed/aborted integrations are not
reconstructed. Existing solvers may stop before returning a colliding trajectory.

`runtime_seconds` is the existing elapsed adapter call, including its original
solver summaries and excluding the new diagnostics, plotting and persistence.
It is one wall-clock observation, not a controlled benchmark. `step_count` records
completed fixed integration steps (excluding the initial sample).
`force_evaluation_count` uses explicit solver statistics if supplied, otherwise
`NA`: current solvers do not instrument this count, and it is not guessed from
method names or the number of saved samples. Missing historical step/runtime
statistics also remain `NA`.

## Studio and validation

The selected-run Diagnostics tab uses the report registry, labels units, plots
one metric and displays its initial, final and extreme values plus performance
and validity information. Old saved runs gain these views on demand. Diagnostics
CSV contains the displayed report's numeric series. Integrator overlays remain
in the Comparison view and use shared available diagnostics.

Run `Rscript tests/validate_diagnostics.R` for analytical circular/elliptic checks,
figure-eight conservation, moving-centre-of-mass checks, vector momentum drift,
zero/cancelling references, invalid states, collisions, model applicability and
historical compatibility. `Rscript tests/run_all_tests.R` also exercises the
existing solvers, history/JSON round trips, plots and optional Shiny server tests.
Conservation alone never establishes trajectory accuracy; timestep convergence
and model-appropriate solution comparisons are still necessary.
