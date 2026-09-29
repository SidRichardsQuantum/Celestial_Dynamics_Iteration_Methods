# Experimental periodic-orbit correction

This opt-in single-shooting module corrects a nearby candidate for a known
periodic solution. It does **not** claim discovery of new periodic orbits.
The implementation lives in `R/experimental/periodic_orbits.R` and calls
`integrate_dynamics()` directly. It does not change the core integrator, runner,
simulation requests, history format or background simulation queue.

From a checkout, run the reproducible figure-eight example:

```sh
Rscript examples/periodic_orbits/figure_eight.R
```

The example uses the repository's figure-eight initial conditions in normalized
units, adds a small velocity perturbation and corrects six initial velocities
and the period while holding all positions fixed. It prints status, period,
residual, independent refinement check and correction history.

## API

```r
source("R/load.R")
cd_load_periodic_orbits()
# For an installed package: library(CelestialDynamicsIterationMethods)

# model and state follow the existing dynamical_model / integrate_dynamics API.
labels <- periodic_orbit_components(state)
result <- shoot_periodic_orbit(
  model, state, period = T,
  free_components = labels[startsWith(labels, "velocity")],
  vary_period = TRUE, period_bounds = c(0.9 * T, 1.1 * T),
  steps = 1000, position_scale = 1, velocity_scale = 1,
  tolerance = 1e-7, max_iterations = 20,
  jacobian_step = 1e-5, damping = 1e-8,
  trust_radius = 0.1, max_backtracks = 12, max_evaluations = 1000
)
result$status
result$converged
result$history             # Every correction trial, including rejected steps
result$iterates            # Matching states, parameter offsets and residuals
result$corrected_state
result$trajectory          # Last accepted RK4 shooting trajectory
result$period
result$residual            # Full named return vector, in native units
result$residual_norm       # Full scaled Euclidean return norm
result$verification        # Independent integration with twice as many steps
saveRDS(result, "periodic-orbit.rds")
```

Components have names such as `position[1,2]` or `velocity[3,1]`, meaning body
and coordinate. Unselected initial values stay exactly fixed. An empty component
vector with `vary_period = TRUE` corrects only the period. With
`vary_period = FALSE`, the supplied period stays fixed. Every position and
velocity return component is included in the objective, even if only some
initial values are free. There is no hidden partial-closure criterion.

The stopping norm is
`sqrt(sum((delta_position / position_scale)^2) + sum((delta_velocity / velocity_scale)^2))`.
Choose physically meaningful scales for SI models. `raw_residual_norm` is also
returned, but it mixes position and velocity units and is not a stopping test.

The solver uses central numerical differences, with one-sided fallback when a
probe fails or crosses period bounds. Scaled state offsets and a relative period
offset form the unknowns. A regularized Gauss-Newton correction uses
[base R's LAPACK SVD](https://stat.ethz.ch/R-manual/R-devel/library/base/html/svd.html),
discarding singular values at most `1e-10` of the largest. Positive damping,
a bounded step norm, positive period bounds and step halving safeguard the
correction. A trial must strictly reduce the residual. All integrations use
RK4 with a fixed step count, so changing the period changes the timestep
continuously. No additional R numerical package is required.

## Status and history

| Status | Meaning |
| --- | --- |
| `converged` | Full scaled residual meets tolerance at both step counts. |
| `discretization_limit` | Shooting meets tolerance; the half-timestep check fails tolerance. |
| `max_iterations` | Correction iteration limit reached without closure. |
| `stalled` | No decreasing trial within the safeguards. |
| `evaluation_limit` | Integration budget exhausted, possibly during refinement. |
| `integration_failed` | Initial trajectory failed, for example at a collision. |
| `jacobian_failed` | Derivatives cannot be evaluated or resolved, or the SVD failed. |
| `verification_failed` | The finer-grid integration failed. |

Invalid arguments raise errors before the numerical search. Numerical failures
return an explicit status, message and the last accepted result. Initial
integration failure has `trajectory = NULL` and unavailable residuals.
`numerical_converged` refers only to the shooting grid; use `converged` for the
two-grid criterion. Zero iterations evaluates the candidate and, if it closes,
performs refinement.

History starts at iteration zero and records every correction trial: acceptance,
residuals, period, scaled step norm, damping, step fraction, Jacobian rank and
condition estimate, cumulative integration count and failure messages. Rejected
states remain in `iterates`, but never replace the returned accepted state.
Jacobian probes count toward the evaluation budget; they are not history rows.
The final evaluation count also includes refinement.

## Advanced Studio workflow

Choose **Three-body figure-eight** in the catalogue, then open
**Advanced: periodic orbits**. The initial candidate period defaults to the
preset duration. The panel accepts free components, fixed or variable period,
bounds, scales, resolution, tolerance and safeguards. It always uses RK4,
independently of the composer integrator selection.

The correction runs in a separate cancellable process. Results include status,
period estimate, both residual norms, residual versus accepted iteration,
corrected initial state, trajectory and every correction trial. The trajectory
plot projects coordinates 1 and 2 (or plots position against time in one
dimension). Download the full RDS for all coordinates, states, controls and
residual vectors, or CSV for the trial history. Results retain their launch
inputs when the composer changes. Completed results are not automatically
added to simulation history. The panel loads an isolated Shiny module; ordinary
simulation jobs never invoke shooting.

## Numerical limitations and validation

The rounded figure-eight seed is an approximation. With a `1e-4` velocity
perturbation and a relative period perturbation of `1e-4`, the example typically
corrects in two iterations at 1000 RK4 steps. On the development test run the
scaled residual went from `1.355e-3` to `2.066e-10`, with `1.475e-8` on 2000
steps and a normalized period estimate of `6.3259140100`.
These are measured numerical results, not exact constants or new orbits.

A 400-step test produced a shooting residual of `2.016e-8`, but a refined
residual of `7.337e-7`. The result correctly reports `discretization_limit` at
tolerance `1e-7`. A smaller shooting residual is not by itself evidence of a
more accurate periodic solution.

- This is a local method. A distant seed may stall, diverge or reach a different
  family, equilibrium or repeated traversal. It does not find the minimal period.
- Autonomous phase freedom and gravitational symmetries cause rank deficiencies.
  Hold appropriate components fixed. There is no explicit phase condition,
  continuation or uniqueness guarantee. Rank estimates depend on difference noise.
- Finite differences, roundoff and RK4 truncation limit attainable accuracy.
  Repeat with finer steps and different difference increments and scales.
  The refinement check is not a rigorous error bound.
- No adaptive error control, close-encounter regularization, multiple shooting,
  invariant constraints or stability analysis is implemented. Conserved
  quantities may change during correction.
- Long unstable trajectories can make the Jacobian unusable. Work scales with
  free-variable count, step count and correction attempts. Explicit evaluation,
  storage and per-integration pair-step budgets bound work.

Run numerical and Studio checks with:

```sh
Rscript tests/validate_periodic_orbits.R
Rscript tests/validate_periodic_app.R
Rscript tests/run_all_tests.R
```

Tests cover figure-eight fixed/variable-period correction, analytic circular
two-body closure, full residual consistency, held components, unit scaling,
period bounds, trust and damping safeguards, iteration/evaluation limits,
collision and argument failures, refinement rejection, background execution,
plots and cancellation.
