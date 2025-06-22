# Celestial Dynamics Iteration Methods
Comparing different numerical iteration techniques by tracing out gravitational dynamics of objects.
Coded entirely in R.

Iteration techniques include:
- Euler method
- Midpoint method
- Modified Euler method
- Runge-Kutta method

Given an initial set of parameters, these iteration methods can be used to calculate the next coordinates after a short time step.
Repeating this thousands of times, while tracing the coordinates, maps the trajectories/orbits of the particles/celestials.
When plotting orbits for every method, eventually the bodies spiral outwards - hence the plots directly compare the different iteration techniques.

We will briefly introduce a third celestial to illustrate the chaos of the three-body-problem.

## Project Structure

```
├── LICENSE                       # Project license
├── README.md                     # This file
├── THEORY.md                     # Theoretical background and equations
├── constants.R                   # Physical constants and parameters
├── celestial_systems/            # Gravitational system simulation
│   ├── three_body_problem.R      # Three massive celestials
│   └── two_body_system.R         # Two massive celestials
├── examples/
│   ├── earth_mars_sun.R          # Earth, Mars and Sun example
│   ├── earth_moon.R              # Earth and Moon example
│   └── sun_earth.R               # Sun and Earth example
├── images/
│   ├── earth_mars_sun.png        # Earth, Mars and Sun saved plot
│   ├── earth_moon.png            # Earth and Moon saved plot
│   └── sun_earth.png             # Sun and Earth saved plot
└── iteration_methods/            # Trajectories of particles in a gravitational field
    ├── euler_method.R            # Euler method
    ├── midpoint_method.R         # Midpoint method
    ├── modified_euler_method.R   # Modified Euler method
    └── runge_kutta_method.R      # (Fourth-order) Runge-Kutta method
```
