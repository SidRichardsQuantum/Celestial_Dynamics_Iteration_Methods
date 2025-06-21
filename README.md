# Celestial Dynamics Iteration Methods
Comparing different numerical iteration techniques by tracing out the trajectories of massive celestial bodies.
Coded in R.

Iteration techniques include the Euler, Verlet and Runge-Kutta methods.
Given an initial set of parameters for the two bodies, these iteration methods can be used to calculate the bodies' next coordinates after a short time $dt$.
Repeating this for thousands of steps, while tracing the coordinates, maps the trajectories/orbits of the masses.
Eventually, for every method, the bodies spiral outwards - hence plotting trajectories directly compares the different iteration techniques.

We will briefly introduce a third celestial to illustrate the chaos of the 3-body-problem.
