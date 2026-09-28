# Dynamical models: incremental simulation-layer refactor

The numerical interface uses plain lists and matrices. A model descriptor has a
stable `id`, a `version` and numeric `parameters`; it contains no functions,
initial conditions, integration settings or presentation data.

```r
library(CelestialDynamicsIterationMethods)
model <- dynamical_model("newtonian_gravity",
  list(masses = c(2, 3), G = 1))
state <- list(positions = rbind(c(-1, 0), c(1, 0)),
              velocities = rbind(c(0, -0.2), c(0, 0.2)))
dstate_dt <- dynamics_derivative(model, time = 0, state = state)
trajectory <- integrate_dynamics(model, state, integrator = "RK4",
                                duration = 1, timestep = 0.01)

# Use an existing catalogue problem without changing its public request:
request <- studio_preset("rotating_square")
problem <- simulation_dynamics(request)
trajectory <- do.call(integrate_dynamics, problem)
```

`state$positions` and `state$velocities` are numeric matrices: rows are integrated
bodies and columns are coordinates. The derivative returns the same structure,
with velocity and acceleration respectively. Results store time-by-body-by-axis
arrays plus the model, initial state and integration settings. There are no
assumed energy formulas, plotting callbacks or body labels in the numerical core.
These low-level trajectories are not Studio `simulation_result` objects; use
`run_simulation()` for catalogue diagnostics, history, comparison and presentation.

| Model ID (version 1) | Parameters | Integrated state | Frame and units |
| --- | --- | --- | --- |
| `newtonian_gravity` | `masses`, `G` | Two or more bodies, 1–3 coordinates | Inertial, SI |
| `softened_gravity` | `masses`, `G`, positive `softening` | Two or more bodies, 1–3 coordinates | Inertial, SI |
| `cr3bp_rotating` | `mu` in (0, 0.5] | One particle, x/y/z | Rotating, normalized |
| `sitnikov_circular` | `primary_mass`, `primary_radius`, `G` | One particle, z | Inertial, SI |

`G` defaults to the package constant at construction and is then stored explicitly.
User-specified constants allow consistent alternative units; the interface does
not perform unit conversion. Softened gravity uses a Plummer denominator
`(r^2 + softening^2)^(3/2)`. The CR3BP definition includes centrifugal and Coriolis
terms. Sitnikov integrates only the vertical particle; prescribed primaries
remain the responsibility of the legacy output/presentation adapter.

All five fixed-step methods (Euler, Midpoint, Heun, RK4 and Verlet) share this
interface. Verlet requires velocity-independent acceleration, so it rejects
rotating CR3BP. Time is supplied at each numerical stage, including the endpoint
for Verlet. Duration must be an integer multiple of timestep within the existing
request tolerance; actual timestep is duration divided by the rounded step count.
The low-level solver does not impose Studio's interactive allocation budgets.

## What changed, and what stays compatible

Previously each solver coupled its integration loop directly to a force helper
using the global gravitational constant. Two- and three-body APIs used separate
scalar arguments per body. N-body used a mass vector and matrices. CR3BP used a
six-element vector; Sitnikov kept a private two-element derivative. Studio
adapted these different outputs after solving, and its `model` field described
provenance rather than an executable force interface.

This increment extracts the N-body pairwise force into `cd_gravity_acceleration`
and its RK4/Verlet loops into `integrate_dynamics`. The original
`n_body_accelerations`, `runge_kutta_n_body` and `velocity_verlet_n_body` functions
are compatibility wrappers: their signatures, labels, printed summaries, energy
calculations and return structures remain intact. Studio's N-body adapter reaches
the new engine through these wrappers. Catalogue requests, result schema, history
and `studio_run_model()` provenance metadata retain their meanings.

The two-body, three-body and Sitnikov legacy solvers remain intact. The later
[CR3BP module](CR3BP.md) also migrates its RK4 wrapper to the shared engine. `simulation_dynamics()` translates all
current catalogue systems into the new representation, allowing their integrated
trajectories to be reproduced by the shared engine without rewriting those
solvers. In particular, it separates masses/constants from positions/velocities
and integrator/time settings. Existing catalogue integrator restrictions remain
unchanged even where the lower-level engine supports additional combinations.

## Extending the interface

Add a stable ID to the code-only `cd_model_definitions()` registry with parameter
defaults and validation, state dimensions, an acceleration callback with signature
`function(time, positions, velocities, parameters)`, and a truthful
`velocity_independent` capability. The current state contract is explicitly
second-order mechanics (`dq/dt = v`); it is not a general arbitrary-state ODE API.
The softened model demonstrates reusing the whole pipeline with a different law.
A test-only time-dependent force also exercises the extension path and RK stages.
No registration side effects, serialized closures or new S3/R6 hierarchy are needed.

Keep an ID/version's interpretation stable. A changed mathematical interpretation
requires a new version and explicit decoding support; unknown IDs and versions
are rejected. Descriptors and simulation configurations round-trip through RDS
and JSON (numeric matrices as row arrays, using `jsonlite` with `digits = NA`).
A replay descriptor must retain resolved defaults such as `G`.

Adding a model to Studio still requires an explicit catalogue adapter, input
validation and applicable diagnostics/presentation metadata. In particular,
Newtonian point-mass energy diagnostics must not be reused for softened gravity.
This refactor enables shared numerical integration; it does not silently declare
new models scientifically equivalent to existing saved runs.

## Validation

Tests cover all 38 current preset/integrator combinations against the new engine,
pre-refactor N-body endpoint fixtures for both migrated methods, analytic force
values, momentum balance, 3D states, softened collisions, explicit constants,
invalid parameters/state/time, incompatible Verlet use, RDS/JSON round-trips,
and a time-dependent force with known polynomial solution. Baseline fixtures
were captured before migration after eight steps at each preset's own timestep;
hexadecimal numeric literals preserve the original floating-point values.
