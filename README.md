# Comparing Iteration Methods Via Celestial Dynamics

[![R validation](https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods/actions/workflows/r-validation.yml/badge.svg)](https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods/actions/workflows/r-validation.yml)
[![Deploy GitHub Pages](https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods/actions/workflows/pages.yml/badge.svg)](https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods/actions/workflows/pages.yml)

A numerical simulation suite for comparing time-stepping methods by tracing gravitational dynamics of projectiles, two-body systems, and three-body systems.
The project is implemented primarily in R, with an optional Python helper for regenerating figure-8 initial conditions.

View the generated results site:
[https://sidrichardsquantum.github.io/Celestial_Dynamics_Iteration_Methods/](https://sidrichardsquantum.github.io/Celestial_Dynamics_Iteration_Methods/)

For setup, commands, examples, and repository layout, see [USAGE.md](USAGE.md).
For method descriptions, see [THEORY.md](THEORY.md).
For generated results, evaluation, and comparison dashboards, see
[RESULTS.md](RESULTS.md).

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

`constants.R` defines `G` as positive; attraction is handled by explicit signs in the force equations.

## Quick Start

Run all validations:

```bash
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

Run only three-body checks:

```bash
Rscript tests/validate_three_body.R
```

## Repository Highlights

- `iteration_methods/`: projectile-oriented method implementations
- `celestial_systems/two_body/`: two-body solvers, method registry, and shared plotting/physics helpers
- `celestial_systems/n_body/`: general 2D n-body RK4 and Velocity Verlet engines
- `celestial_systems/three_body/`: full and restricted three-body helpers
- `examples/`: runnable examples grouped by model type, including method comparisons
- `images/`: generated plots grouped by example type
- `analysis/`: reproducible result-table, diagnostic-plot, and dashboard generation
- `tests/`: validation scripts used locally and in CI
- `.github/workflows/`: validation, plot-regeneration, and GitHub Pages deployment workflows

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).

Author: Sid Richards (SidRichardsQuantum)
