# Circular Restricted Three-Body Problem

This module models a massless particle influenced by two point masses in prescribed
circular orbits. It is an idealized dynamical model, **not an ephemeris**: orbital
eccentricity, other gravitating bodies, radiation pressure, oblateness and
spacecraft forces are absent. The Earth–Moon and Sun–Earth mass parameters are
approximate ratios of the repository's rounded mass constants.

## Coordinates, units and equations

Let `mu = m2 / (m1 + m2)`, with the larger primary labelled 1 and
`0 < mu <= 0.5`. Choose primary separation `a` as the length unit, total primary
mass as the mass unit, and `1/n` as the time unit, where
`n = sqrt(G * (m1 + m2) / a^3)`. Velocity is measured in `a*n`.
Consequently separation, angular speed and the gravitational parameter of the
total mass are all one. A primary revolution lasts **2*pi time units**, not one.

The origin is the barycentre, the x-axis points toward primary 2, and the frame
rotates counterclockwise in the x-y plane. Primaries are fixed at
`(-mu, 0, 0)` and `(1-mu, 0, 0)`. All velocities below are rotating-frame
velocities. The six-component state is `[x, y, z, vx, vy, vz]`; planar motion is
the invariant subset `z = vz = 0`.

With distances

\[
r_1=\sqrt{(x+\mu)^2+y^2+z^2},\qquad
r_2=\sqrt{(x-1+\mu)^2+y^2+z^2},
\]

the effective potential and equations are

\[
\Omega=\frac{x^2+y^2}{2}+\frac{1-\mu}{r_1}+\frac{\mu}{r_2},
\qquad
\ddot x-2\dot y=\Omega_x,\quad
\ddot y+2\dot x=\Omega_y,\quad \ddot z=\Omega_z.
\]

In particular,

\[
\Omega_x=x-\frac{(1-\mu)(x+\mu)}{r_1^3}-\frac{\mu(x-1+\mu)}{r_2^3},
\quad
\Omega_y=y-\frac{(1-\mu)y}{r_1^3}-\frac{\mu y}{r_2^3},
\quad
\Omega_z=-\frac{(1-\mu)z}{r_1^3}-\frac{\mu z}{r_2^3}.
\]

These are the standard rotating-frame equations; the reference below uses the
opposite potential sign, `U = -Omega`.
[Richard Fitzpatrick, Co-rotating frame](https://farside.ph.utexas.edu/teaching/celestial/Celestial/node83.html).

## Jacobi invariant and numerical diagnostics

The Jacobi constant is

\[
C=2\Omega-(v_x^2+v_y^2+v_z^2).
\]

Taking its derivative gives `2*gradient(Omega) dot v - 2*v dot acceleration`.
The Coriolis contributions cancel, so `dC/dt = 0` for the exact solution.
RK4 does not preserve C exactly; decreasing timestep should reduce its error
until floating-point effects dominate. Studio reports `jacobi`, signed
`jacobi_drift = C(t)-C(0)` and `jacobi_relative_drift = (C(t)-C(0))/abs(C(0))`.
Relative drift is unavailable near a zero reference. Collision samples are
flagged with unavailable invariants, not silently regularized.

Small Jacobi drift is a useful accuracy check but does not guarantee small
trajectory error, especially near unstable equilibria. Energy and angular
momentum of the particle alone are not substituted for the Jacobi invariant.

## Equilibria and initial states

Equilibria satisfy zero rotating velocity and `gradient(Omega) = 0`.
L1 is between the primaries, L2 beyond the smaller primary, and L3 beyond the
larger primary. Their scalar equations are solved separately on intervals
excluding the primary singularities, using mass-dependent endpoint gaps and a
near-machine-precision root tolerance. Extremely small mu for which those
intervals cannot be represented in double precision is rejected explicitly.
The triangular equilibria are exactly
`L4 = (1/2-mu, sqrt(3)/2)` and `L5 = (1/2-mu, -sqrt(3)/2)`.
[Richard Fitzpatrick, Lagrange points](https://farside.ph.utexas.edu/teaching/celestial/Celestial/node84.html).

`cr3bp_initial_state()` adds an explicit position offset and rotating velocity
to any L1–L5 point. Set both to zero for an equilibrium. A nearby initial state
is **not** automatically a periodic, Lyapunov or halo orbit; those require
additional orbit computation. L1–L3 are unstable, so even an almost exact
numerical equilibrium can eventually depart through roundoff.

## Package and Studio usage

```r
library(CelestialDynamicsIterationMethods)
mu <- unname(cr3bp_mass_parameters()["earth_moon"])
cr3bp_lagrange_points(mu)
state <- cr3bp_initial_state(mu, "L4", position_offset = c(0.01, 0, 0))
raw <- cr3bp_runge_kutta(T = 10, N = 2000, mu = mu, state0 = state)
C <- cr3bp_jacobi(raw$states, mu)
max(abs(C - C[1]))
plot_cr3bp_result(raw, "earth_moon_cr3bp.png", "Idealized Earth-Moon CR3BP")

# Catalogue requests reuse the normal runner, diagnostics, history and comparisons.
request <- studio_preset("sun_earth_l1")
result <- run_simulation(request)
studio_plot_trajectories(result, frame = "native") # rotating coordinates
studio_plot_diagnostic(result, "jacobi_drift")

# The underlying numerical engine uses the same model, with no separate RK loop.
problem <- simulation_dynamics(request)
trajectory <- do.call(integrate_dynamics, problem)
```

Studio retains the `restricted_three_body` catalogue ID and RK4 integrator.
Select the Earth–Moon L1/L2/L3 or existing L4/L5 presets, or Sun–Earth L1/L4.
Mu and the full rotating state are editable. The orbit view uses rotating
coordinates with named primaries; animations also offer an inertial view.
Axes use normalized length and diagnostic time uses normalized time.
The model ID is `cr3bp_rotating`, version 1. Its velocity-dependent Coriolis
acceleration makes ordinary velocity Verlet inappropriate; the shared engine
rejects that pairing.

The standalone potential, gradient, Jacobi and equilibrium functions live in
`R/dynamics/cr3bp.R`, separate from plotting. The legacy RK4 signature and raw
`t`/`states`/`mu` result layout are preserved through a shared-engine adapter.
Public mathematical helpers reject singular primary locations. Tests cover
potential finite differences, Coriolis signs, all five equilibrium residuals,
the identity `C(L4) = C(L5) = 3-mu+mu^2`, numerical drift refinement, catalogue
presets, equal masses and small mass ratios.
