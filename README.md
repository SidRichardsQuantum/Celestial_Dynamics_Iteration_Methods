# Comparing Iteration Methods Via Celestial Dynamics
Comparing different numerical iteration techniques by tracing out gravitational dynamics of objects.
Coded entirely in R.

## Overview

**Iteration techniques include**:
- Euler method
- Midpoint method
- Heun's method
- Runge-Kutta method

Given an initial set of parameters, these iteration methods can be used to calculate the next coordinates after a short time step.
Repeating this thousands of times, while tracing the coordinates, maps the trajectories/orbits of the projectiles/celestials.
When plotting orbits for every method, eventually the bodies spiral outwards - hence the plots (and ratio of initial to final energies) directly compare the different iteration techniques.

We adapt the two-body system by introducing a third celestial, to illustrate the chaos of the three-body-problem for masses of similar sizes.

## Example Usage

## Project Structure

```
├── LICENSE                         # Project license
├── README.md                       # This file
├── THEORY.md                       # Theoretical background and equations
├── constants.R                     # Physical constants and parameters
├── celestial_systems/              # Gravitational system simulation
│   ├── three_body_problem.R        # Three massive celestials
│   └── two_body_system.R           # Two massive celestials
├── examples/
│   ├── earth_mars_sun.R            # Earth, Mars and Sun example
│   ├── earth_moon.R                # Earth and Moon example
│   └── sun_earth.R                 # Sun and Earth example
├── images/
│   ├── earth_mars_sun.png          # Earth, Mars and Sun saved plot
│   ├── earth_moon.png              # Earth and Moon saved plot
│   ├── sun_earth.png               # Sun and Earth saved plot
│   ├── euler_trajectory.png        # Sun and Earth saved plot
│   ├── midpoint_trajectory.png     # Sun and Earth saved plot
│   ├── heun_trajectory.png         # Sun and Earth saved plot
│   └── runge_kutta_trajectory.png  # Sun and Earth saved plot
└── iteration_methods/              # Trajectories of particles in a static gravitational field
    ├── euler_method.R              # Euler method
    ├── midpoint_method.R           # Midpoint method
    ├── heuns_method.R              # Heun's method
    └── runge_kutta_method.R        # Runge-Kutta (RK4) method
```

---

📘 Author: [Sid Richards]

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: [https://www.linkedin.com/in/sid-richards-21374b30b/]

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
