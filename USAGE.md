# Usage

## Installation

```bash
git clone https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods.git
cd Celestial_Dynamics_Iteration_Methods
```

The R examples use base R. The optional Python helper
`celestial_systems/three_body/figure_8_solution.py` requires packages listed in
`requirements.txt`:

```bash
python -m pip install -r requirements.txt
```

## Common Commands

Run all validation checks:

```bash
Rscript tests/run_all_tests.R
```

Run three-body validation only:

```bash
Rscript tests/validate_three_body.R
```

Run two-body validation only:

```bash
Rscript tests/validate_two_body.R
```

Regenerate every example plot:

```bash
Rscript run_all_examples.R
```

Regenerate the Sun-Earth all-method comparison only:

```bash
Rscript examples/comparisons/sun_earth_all_methods.R
```

Regenerate generated result tables, energy/angular-momentum diagnostics,
convergence plots, and the method comparison dashboard:

```bash
Rscript analysis/generate_results.R
```

Regenerate two-body plots only:

```bash
Rscript examples/two_body_examples/run_all_two_body_examples.R
```

Regenerate n-body plots only:

```bash
Rscript examples/n_body_examples/run_all_n_body_examples.R
```

Regenerate three-body plots only:

```bash
Rscript examples/three_body_examples/run_all_three_body_examples.R
```

Run examples from the repository root so their `source(...)` paths resolve correctly.

Run the experimental near-periodic three-body search:

```bash
Rscript experiments/find_three_body_solution.R
```

This search is intentionally exploratory. It performs a small randomized search over symmetric equal-mass initial conditions and writes a candidate plot to `images/three_body/experiments/candidate_solution.png`.

## Example Usage

Projectile trajectory:

```r
source("examples/projectile_trajectories/projectile_example.R")
```

![Euler Method Trajectory](images/projectile/euler_trajectory.png)

Sun-Earth all-method comparison:

```r
source("examples/comparisons/sun_earth_all_methods.R")
```

![Sun-Earth All Methods](images/comparisons/sun_earth_all_methods.png)

Earth-Moon system using Euler's method:

```r
source("examples/two_body_examples/earth_moon_examples/earth_moon_euler.R")
```

![Earth and Moon](images/two_body/earth_moon/earth_moon_euler.png)

Equal-mass figure-8 three-body solution:

```r
source("examples/three_body_examples/special_solutions/three_earths.R")
```

![Three Earths](images/three_body/special_solutions/three_earths.png)

Four-body Sun-Earth-Mars-Jupiter example:

```r
source("examples/n_body_examples/sun_earth_mars_jupiter.R")
```

![Sun-Earth-Mars-Jupiter](images/n_body/sun_earth_mars_jupiter.png)

Special four-body rotating square:

```r
source("examples/n_body_examples/special_solutions/rotating_square_four_body.R")
```

![Rotating Square Four-Body](images/n_body/special_solutions/rotating_square_four_body.png)

## Project Structure

```text
Celestial_Dynamics_Iteration_Methods/
├── README.md
├── USAGE.md
├── THEORY.md
├── RESULTS.md
├── constants.R
├── run_all_examples.R
├── analysis/
│   ├── generate_results.R
│   └── generated/
│       ├── convergence_summary.csv
│       ├── method_summary.csv
│       └── method_comparison_dashboard.html
├── .github/
│   └── workflows/
│       ├── r-validation.yml
│       └── regenerate-plots.yml
├── celestial_systems/
│   ├── two_body/
│   │   ├── plot_two_body.R
│   │   ├── two_body_helpers.R
│   │   ├── two_body_method_registry.R
│   │   ├── two_body_euler.R
│   │   ├── two_body_heuns.R
│   │   ├── two_body_midpoint.R
│   │   ├── two_body_runge_kutta.R
│   │   └── two_body_velocity_verlet.R
│   ├── n_body/
│   │   ├── four_body_initial_conditions.R
│   │   ├── n_body_helpers.R
│   │   ├── n_body_runge_kutta.R
│   │   ├── n_body_velocity_verlet.R
│   │   └── plot_n_body.R
│   └── three_body/
│       ├── choreography_initial_conditions.R
│       ├── circular_restricted_three_body.R
│       ├── euler_collinear_initial_conditions.R
│       ├── figure_8_initial_conditions.R
│       ├── figure_8_solution.py
│       ├── lagrange_initial_conditions.R
│       ├── plot_three_body.R
│       ├── sitnikov_problem.R
│       └── three_body_runge_kutta.R
├── examples/
│   ├── comparisons/
│   ├── n_body_examples/
│   │   ├── run_all_n_body_examples.R
│   │   └── special_solutions/
│   ├── projectile_trajectories/
│   ├── two_body_examples/
│   │   ├── run_all_two_body_examples.R
│   │   ├── earth_moon_examples/
│   │   └── sun_earth_examples/
│   └── three_body_examples/
│       ├── README.md
│       ├── run_all_three_body_examples.R
│       ├── general/
│       ├── perturbations/
│       ├── restricted/
│       └── special_solutions/
├── images/
│   ├── analysis/
│   ├── n_body/
│   ├── projectile/
│   ├── two_body/
│   └── three_body/
├── experiments/
│   └── find_three_body_solution.R
├── iteration_methods/
└── tests/
    ├── helpers_three_body.R
    ├── run_all_tests.R
    ├── validate_plot_generation.R
    ├── validate_restricted_three_body.R
    ├── validate_special_solutions.R
    ├── validate_two_body.R
    └── validate_three_body.R
```

## Generated Images

Plots are generated artifacts, but this repository keeps representative PNGs under `images/` so the markdown result pages render directly.
If an example is changed, run the relevant example runner and then run:

```bash
Rscript tests/validate_plot_generation.R
```

The GitHub Actions workflow `R validation` runs `tests/run_all_tests.R` on pushes and pull requests.
The `Regenerate plots` workflow is manual; it runs `run_all_examples.R`, regenerates analysis artifacts, validates the outputs, and uploads regenerated image and analysis directories as artifacts.

The generated comparison dashboard is written to:

```text
analysis/generated/method_comparison_dashboard.html
```
