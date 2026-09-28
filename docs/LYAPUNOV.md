# Trajectory sensitivity and finite-time Lyapunov estimates

`run_lyapunov_analysis()` measures the divergence of a nearby companion using
periodic renormalisation. It accepts an existing `simulation_request`, including
a request restored from experiment history, or the data-only problem returned by
`simulation_dynamics()`. Physics and numerical calculations live in
`R/dynamics/lyapunov.R`; Shiny only submits work and displays results.

```r
source("R/load.R")
cd_load_studio()
experiment = studio_preset("earth_moon_trojan")
analysis = run_lyapunov_analysis(
  experiment,
  epsilon = 1e-7,
  component = "position[1,1]",
  renormalisation_interval = 0.1,
  total_time = 20,
  position_scale = 1,
  velocity_scale = 1
)
analysis$finite_time_exponent
head(analysis$series)
analysis$renormalisation_history
studio_plot_lyapunov(analysis, "separation")
studio_plot_lyapunov(analysis, "log")
studio_plot_lyapunov(analysis, "trajectories")
saveRDS(analysis, "sensitivity.rds")
```

Installed-package use starts with `library(CelestialDynamicsIterationMethods)`
instead of sourcing the loader.

## State, metric and perturbation

The state includes **all integrated positions and velocities**. Prescribed
primary orbits are excluded: CR3BP has one integrated particle in its rotating
frame; Sitnikov has one vertical position and velocity (coordinate 1 is z).
Masses and other force parameters remain fixed.

For fixed positive position scale L and velocity scale V, distance is

```
d = sqrt(sum((delta_position / L)^2) + sum((delta_velocity / V)^2)).
```

This makes epsilon a dimensionless distance. Defaults L=V=1 use the numerical
model coordinates directly; they are not a physically preferred metric. For SI
experiments, supply characteristic length and speed scales explicitly. The
Studio suggests the maximum absolute initial position and velocity, each with
a floor of 1, and exposes both scales for editing. Translation or unit changes
can affect those suggestions. Keep scales fixed when comparing results.

Choose `component = "position[body,coordinate]"` or
`"velocity[body,coordinate]"`, using one-based indices. The default is the first
position component. Alternatively, supply a nonzero finite `direction` vector
in **scaled coordinates**. Vector order is R's column-major positions followed
by column-major velocities: all bodies on coordinate 1, then coordinate 2, etc.
The vector is normalized to unit length; its names are ignored. For one CR3BP
particle, for example, `direction = c(1, 0, 0, 0, 1, 0)` selects x and vy. Do
not supply both component and direction. The resolved named unit direction is
stored in the result.

## Numerical method

1. Construct a companion at scaled distance epsilon in the chosen direction.
   Measure its actual representable initial distance, d0.
2. Integrate base and companion with the same model, fixed timestep and
   integrator for one renormalisation interval. Absolute time is passed through
   every solver stage, including after restarts.
3. Measure distance d before resetting. Add `log(d) - log(d_start)` to accumulated
   growth S, where `d_start` is the **actual** separation at this interval's start.
4. Retain the evolved difference direction and reset only the companion to
   distance epsilon around the current base state. Measure the actual reset
   separation for the next denominator. Resets do not contribute to growth.
5. Repeat to total time T and return `S / T`. A final shorter interval contributes
   its full growth and actual time. No reset is performed at the final endpoint.

Total time and renormalisation interval must be positive integer multiples of
the experiment timestep (relative integer tolerance 1e-9); the interval cannot
exceed total time. Total time need not be divisible by the interval. The default
interval is ten timesteps, or the whole run if it has fewer than ten steps.
If omitted, total time uses the experiment duration. The original experiment is
not mutated. The resolved problem and actual timestep are retained in the result.

This is a two-trajectory, Benettin-style finite-difference method, not a
variational-equation solver. Choice of epsilon and renormalisation interval can
produce spurious estimates; see the numerical investigation by
[Dubeibe and Bermudez-Almanza (2014)](https://arxiv.org/abs/1312.5970).

## Returned data and plots

- `initial_separation`: measured d0 in the scaled norm, not just requested epsilon.
- `series`: time, measured `separation`, natural `log_separation`, accumulated
  `log_separation_growth` S(t), `cumulative_log_separation = log(d0) + S(t)`,
  and running `finite_time_exponent = S(t) / t` (NA at time zero).
- `finite_time_exponent`: final S(T)/T, in inverse model time units: inverse
  seconds for SI systems and inverse normalized time for CR3BP.
- `renormalisation_history`: start/end times and step indices, actual starting
  and pre-reset distances, interval and cumulative growth, whether a reset was
  performed, and its actual separation (NA at the terminal interval).
- `base`, `perturbed`: time-by-body-by-coordinate position and velocity arrays
  and initial states. Endpoints are stored **before** reset. `restart_states`
  holds the post-reset companion states; its final entry is NULL.
- `experiment`, `problem`, `epsilon`, `direction`, `metadata`: original inputs,
  resolved model, method version, metric scales, frame, units, time settings,
  sampling convention and interpretation limits.

The measured separation curve stays near epsilon because of the resets. The
accumulated log curve preserves growth across them. Its exponential would be a
rescaling reconstruction, not the actual separation of two freely evolved
nonlinear orbits. The implementation never exponentiates it. The trajectory
comparison plots each companion segment separately, without joining across
reset jumps. It shows a two-coordinate projection (selectable via `axes`) or
position versus time for one-dimensional states. Prescribed primaries are not
included. Base and companion often overlap visually for small epsilon.

The Studio **Sensitivity** tab uses the first selected composer integrator,
offers component, epsilon, interval, duration and scale controls, displays the
two separation plots, estimate and trajectory comparison, and runs in a
cancellable background process. Download the full RDS analysis to retain all
inputs and results, or download the series as CSV. Sensitivity results are
session-local until downloaded; they are not added to normal simulation history.

## Numerical safeguards and limits

- Epsilon and both scales must be finite positive real scalars. Directions must
  be finite and nonzero. Norms are evaluated with max-component scaling to
  avoid overflow/underflow from squaring very large/small differences.
- Growth uses differences of logarithms, never products of growth factors or
  ratios that can overflow. Periodic resets control the separation magnitude.
- Every perturbation/reset must reproduce the requested scaled vector to within
  1% relative Euclidean error. Unrepresentable epsilon, collapsed separation,
  nonfinite states and collisions fail explicitly; no artificial distance floor,
  random direction replacement or fabricated exponent is used.
- Renormalisation cannot repair overflow, loss of precision or nonlinear
  saturation **within** an interval. Shorten intervals, reduce timestep and vary
  epsilon to check stability. A large epsilon can be representable but outside
  the linear regime; this is not automatically detected.
- The initial direction can take a long time to align with a dominant expanding
  direction, or remain in a different invariant subspace. This finite-time
  directional estimate targets the maximum exponent but does not maximize over
  directions or compute the largest singular value of a finite-time flow map.
- No transient is discarded. Positive finite-time growth alone does not
  establish asymptotic instability or chaos. Integrator error, scale choices,
  close encounters, total time and initial direction all affect the result.
  The API and Studio do not apply a chaos threshold or label orbits chaotic.
- The selected fixed-step method is reused; there is no adaptive error control,
  tangent dynamics, Lyapunov spectrum, confidence interval, constraint projection
  or automatic convergence study. Generic perturbations can change conserved
  quantities; restricted energy-surface analysis requires additional treatment.
- Analysis is limited to 100,000 steps, 256 integrated bodies, 2 million position
  values per trajectory and 10 million pair-steps per trajectory. Two trajectories
  plus their velocities and reset states are stored, so work and memory exceed
  one ordinary simulation at the same resolution.

## Validation

`tests/validate_lyapunov.R` uses deterministic test-only mechanical models:
exponential growth and decay with rates +1/-1, neutral harmonic rotation,
algebraic free-motion shear with an exact finite-time result, and a time-dependent
force to catch restart-time errors. Long growth/decay tests span logarithmic
growth of approximately +/-800 with epsilon 1e-250. It also tests final partial
intervals, single-interval direct integration, invalid inputs, numerical collapse,
catalogue adapters, serialization and all three plots. The Studio server test
exercises background execution, plot rendering, invalid epsilon and cancellation.

Run `Rscript tests/run_all_tests.R` for the full repository validation suite.
