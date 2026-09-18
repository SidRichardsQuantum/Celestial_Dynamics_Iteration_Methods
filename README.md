# Comparing Iteration Methods Via Celestial Dynamics

[![R validation](https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods/actions/workflows/r-validation.yml/badge.svg)](https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods/actions/workflows/r-validation.yml)
[![Deploy GitHub Pages](https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods/actions/workflows/pages.yml/badge.svg)](https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods/actions/workflows/pages.yml)
[![R-universe version](https://sidrichardsquantum.r-universe.dev/CelestialDynamicsIterationMethods/badges/version)](https://sidrichardsquantum.r-universe.dev/CelestialDynamicsIterationMethods)
[![R-universe checks](https://sidrichardsquantum.r-universe.dev/CelestialDynamicsIterationMethods/badges/checks)](https://sidrichardsquantum.r-universe.dev/CelestialDynamicsIterationMethods)

A numerical simulation suite for comparing time-stepping methods by tracing gravitational dynamics of projectiles, two-body systems, and three-body systems.
The project is implemented primarily in R, with an optional Python helper for regenerating figure-8 initial conditions.

**Website:**
[https://sidrichardsquantum.github.io/Celestial_Dynamics_Iteration_Methods/](https://sidrichardsquantum.github.io/Celestial_Dynamics_Iteration_Methods/)

**R-universe:**
[https://sidrichardsquantum.r-universe.dev/CelestialDynamicsIterationMethods](https://sidrichardsquantum.r-universe.dev/CelestialDynamicsIterationMethods)

## Overview

This project compares:

- Euler method
- Midpoint method
- Heun's method
- Runge-Kutta (RK4) method
- Velocity Verlet method

The simulations generate trajectories and energy-conservation diagnostics for:

- projectile motion near Earth's surface
- same-system comparisons across all implemented methods
- Sun-Earth and Earth-Moon two-body systems
- general n-body systems
- special four-body central configurations
- general three-body systems
- special three-body solutions, including figure-8, Lagrange, Euler collinear, and Butterfly I
- restricted three-body examples, including CR3BP and Sitnikov cases

`R/constants.R` defines `G` as positive; attraction is handled by explicit signs in the force equations.

## Installation

Install the development package directly from GitHub:

```r
install.packages("remotes")
remotes::install_github("SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods")
```

After R-universe has built the package, install from R-universe:

```r
options(repos = c(
  sidrichardsquantum = "https://sidrichardsquantum.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))
install.packages("CelestialDynamicsIterationMethods")
```

R-universe setup notes and the registry details are in
[docs/R_UNIVERSE.md](docs/R_UNIVERSE.md).

## Common Commands

Install the optional Studio dependencies to run the full validation suite:

```bash
Rscript -e 'install.packages(c("shiny", "jsonlite", "callr"), repos="https://cloud.r-project.org")'
Rscript tests/run_all_tests.R
```

Regenerate every example plot:

```bash
Rscript run_all_examples.R
```

Regenerate analysis tables, diagnostics, and the dashboard:

```bash
Rscript analysis/generate_results.R
```

For source checkouts, example-specific commands, optional Python setup, and
generated artifact details, see [docs/USAGE.md](docs/USAGE.md).

## Documentation

- [Usage](docs/USAGE.md): setup, commands, examples, repository layout, and generated artifacts
- [Theory](docs/THEORY.md): method descriptions and numerical context
- [Results](docs/RESULTS.md): generated results, evaluation, and comparison dashboards
- [R-universe setup](docs/R_UNIVERSE.md): package registry and install details

## Repository Highlights

- `DESCRIPTION` and `NAMESPACE`: lightweight R package metadata
- `R/load.R`: project-root-aware loading helpers used by scripts and tests
- `R/methods/`: projectile-oriented method implementations
- `R/systems/two_body/`: two-body solvers, method registry, and shared plotting/physics helpers
- `R/systems/n_body/`: general 2D n-body RK4 and Velocity Verlet engines
- `R/systems/three_body/`: full and restricted three-body helpers
- `examples/`: runnable examples grouped by model type, including method comparisons
- `images/`: generated plots grouped by example type
- `analysis/`: reproducible result-table, diagnostic-plot, and dashboard generation
- `docs/`: usage, theory, and canonical results narrative
- `tests/`: validation scripts used locally and in CI
- `.github/workflows/`: validation, plot-regeneration, and GitHub Pages deployment workflows

## Celestial Dynamics Studio

An optional interactive R Shiny app wraps the existing numerical physics with a
simulation catalog, editable initial conditions, integrator comparisons,
diagnostics, animations, exports, and local run history. Shiny keeps the app in
the same language as the solvers and reuses the repository's plotting utilities.

From a source checkout with R 4.1 or newer:

```bash
Rscript -e 'install.packages(c("shiny", "jsonlite", "callr"), repos="https://cloud.r-project.org")'
Rscript -e 'shiny::runApp("app", launch.browser=TRUE)'
```

`shiny`, `jsonlite` and `callr` are optional `Suggests` dependencies. Existing
solvers and the synchronous simulation API need none of them. JSON history needs
`jsonlite`; background jobs need `callr`.
The entry point is `app/app.R`.

| Simulation | Compatible integrators | Units |
| --- | --- | --- |
| Two-body (2D) | Euler, Midpoint, Heun, RK4, Verlet | SI |
| General three-body (2D) | RK4 | SI |
| N-body (2D) | RK4, Verlet | SI |
| Restricted three-body / CR3BP (3D) | RK4 | Normalized rotating frame |
| Circular Sitnikov (3D geometry) | RK4 | SI |

Nineteen presets include circular/eccentric Sun-Earth, Earth-Moon and equal-mass
binaries, figure-eight, Lagrange triangle, Euler collinear, Butterfly I,
Pythagorean, Earth-Moon L4/L5 Trojans, a retrograde lunar test particle,
Sun-Jupiter test particle, Solar System, binary stars with a companion,
square/triangular four-body configurations, and two Sitnikov amplitudes.
Pythagorean runs through its first close encounter using 100,000 RK4 steps;
its default is checked for conservation and timestep convergence. Select multiple compatible integrators to compare
the same initial conditions, trajectories, applicable conservation errors, and
elapsed runtimes. These timings are illustrative, not rigorous benchmarks.
All methods use fixed timesteps; duration must be an integer multiple of timestep.
The composer provides a body table for masses, positions and velocities, with
explicit units and add/remove controls for N-body systems. Advanced JSON editing
remains available and stays synchronized with the table. Live validation shows
the step count and inline input errors; Run is enabled only for valid configurations.
Runs with relative energy/Jacobi drift above 0.1% display a conservation warning.

Restricted-system animations include the named primaries and default to an inertial
view. Switch to the rotating frame and fit **Test particle** to inspect Trojan
libration. All animations offer fit, zoom, body following, time display and
replay; Sitnikov defaults to x-z so its vertical motion is visible.

```r
source("R/load.R")
cd_load_studio()
request <- studio_preset("circular_two_body")
result <- run_simulation(request)
comparison <- compare_integrators(request, c("RK4", "Verlet"))
studio_plot_diagnostic(comparison, "energy_relative_drift")
```

The studio now follows **catalogue → composer → run → gallery → viewer → reuse → compare**.
Browse presets by system, inspect scientific trajectory cards, search by preset or
integrator, and keep favorites across sessions. The gallery shows 12 runs per page
(choose 6, 12, 24 or 48); comparison selections survive page and filter changes.
Scientific PNG previews use bounded server caching and private browser caching.
Select at least two completed
runs for trajectory and conservation comparisons; physical inputs and duration
must match, while integrator and timestep may differ.

History metadata lives in `.studio/history/<run-id>.json`. New runs also save
`<run-id>/preview.png` and `<run-id>/result.json.gz`, preserving the original
scientific result for viewing, animation and export without recomputation.
Reuse restores the saved numerical request into the composer. Older metadata-only
records still load and can be reused. Favorites persist in metadata; there is no
automatic deletion policy. Failed solver runs retain their request and error.

Run submits a batch to a separate R process so the studio stays responsive. The
newest cards show queued/running stages; **Cancel unfinished runs** stops that
session's worker and retains cancelled requests for reuse. Already completed runs
remain completed. Closing or reloading the browser session cancels its unfinished
batch. Background records use schema 3 with timestamped lifecycle events; schema
1 and 2 records remain readable. See the gallery for results when a batch finishes.
Set `CELESTIAL_STUDIO_HISTORY` to change the local history directory.
See [Studio workflow and persistence](docs/STUDIO.md) for details.

From a fresh Codespace terminal at the repository root:

```bash
# If R is absent from the Codespace image:
sudo apt-get update
sudo apt-get install -y r-base r-cran-shiny r-cran-jsonlite r-cran-callr
Rscript -e 'shiny::runApp("app", host="0.0.0.0", port=8765, launch.browser=FALSE)'
```

Open port **8765** from the Codespaces **Ports** panel. If R is already installed
but optional packages are missing, use:

```bash
Rscript -e 'install.packages(c("shiny", "jsonlite", "callr"), repos="https://cloud.r-project.org")'
```

```mermaid
flowchart LR
    UI[Shiny UI] --> Request[Simulation request]
    Request --> Catalog[Catalog validation]
    Catalog --> Solver[Existing solver / integrator]
    Solver --> Result[Trajectory result]
    Result --> Diagnostics[Applicable diagnostics]
    Diagnostics --> Output[Plots / history]
    Result --> Output
```

See [Studio architecture, API and scientific conventions](docs/STUDIO.md) for the
repository audit, result schema, units, diagnostics, reproducibility, and limits.
Run all validation with `Rscript tests/run_all_tests.R`.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).

Author: Sid Richards (SidRichardsQuantum)
