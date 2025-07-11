# Comparing Iteration Methods Via Celestial Dynamics
Comparing different numerical iteration techniques by tracing out gravitational dynamics of objects.
Coded entirely in R.

See [THEORY.md](THEORY.md) for complete descriptions of each iteration technique.

See [RESULTS.md](RESULTS.md) for results, conclusions and evaluations.

## Overview

**Iteration Techniques Include**:
- Euler method
- Midpoint method
- Heun's method
- Runge-Kutta method

Given an initial set of parameters, these iteration methods can be used to approximate the next coordinates after a short time step.
Repeating this thousands of times, while tracing the coordinates, we illustrate the trajectories/orbits of the projectiles/celestials.
When plotting orbits for every method, eventually the bodies spiral outwards - hence the plots (and ratio of initial to final energies) directly compare the different iteration techniques.

An example for a projectile being fired on Earth's surface is given - with analysis on the accuracies of different iteration methods.
More examples include the Sun and Earth's orbital plot, and similarly a Earth and Moon system plot.

We adapt the two-body system by introducing a third celestial, to illustrate the chaos of the three-body-problem for masses of similar sizes.

## Project Structure

```
Celestial_Dynamics_Iteration_Methods/
├── LICENSE                           # MIT license
├── README.md                         # This file
├── THEORY.md                         # Theoretical background and equations
├── RESULTS.md                        # Results, conclusions, and evaluation
├── constants.R                       # Physical constants
├── iteration_methods/                # Numerical integration methods directory
├── celestial_systems/                # Massive body system dynamics
│   ├── three_body/                   # Three massive celestial chaos
│   │   ├── figure_8_solution.py      # Generates the initial conditions for figure-8 solution
│   │   └── three_body_runge_kutta.R  # Evolves three masses using the RK4 method only
│   └── two_body/                     # Celestial pair dynamics using each method
├── images/                           # Visual outputs and plots for all examples
└── examples/                         # Simulation examples
    ├── projectile_trajectories/
    │   └── projectile_example.R      # Runs all methods for the same projectile example
    ├── three_body_examples/          # Simple three-body system examples
    │   ├── earth_mars_sun.R
    │   ├── earth_moon_spacecraft.R
    │   └── three_earths.R            # Attempt at generating the figure-8 solution
    └── two_body_examples/
        ├── earth_moon_examples/      # Earth and Moon examples for each method
        └── sun_earth_examples/       # Sun and Earth examples for each method
```

## Installation

```bash
# Clone and run
git clone https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods.git
cd Celestial_Dynamics_Iteration_Methods
```

### Example Usages

```r
# Projectile trajectory on Earth
# Approximated trajectory plotted alongside the real trajectory
# Returns a plot for each method
source("examples/projectile_trajectories/projectile_example.R")
```
![Euler Method Trajectory](images/euler_trajectory.png)

```r
# Compare methods for Earth-Moon system using the Euler method
source("examples/two_body_examples/earth_moon_examples/earth_moon_euler.R")
```
![Earth and Moon](images/earth_moon_euler.png)

---

📘 Author: Sid Richards (SidRichardsQuantum)

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: https://www.linkedin.com/in/sid-richards-21374b30b/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
