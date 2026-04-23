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

Regenerate two-body plots only:

```bash
Rscript examples/two_body_examples/run_all_two_body_examples.R
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

## Project Structure

```text
Celestial_Dynamics_Iteration_Methods/
├── README.md
├── USAGE.md
├── THEORY.md
├── RESULTS.md
├── constants.R
├── run_all_examples.R
├── .github/
│   └── workflows/
│       ├── r-validation.yml
│       └── regenerate-plots.yml
├── celestial_systems/
│   ├── two_body/
│   │   ├── plot_two_body.R
│   │   ├── two_body_helpers.R
│   │   ├── two_body_euler.R
│   │   ├── two_body_heuns.R
│   │   ├── two_body_midpoint.R
│   │   └── two_body_runge_kutta.R
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
The `Regenerate plots` workflow is manual; it runs `run_all_examples.R`, validates the outputs, and uploads the regenerated `images/` directory as an artifact.
