# Results

## Sun-Earth System

Our Sun and Earth example files in ```examples/two_body_examples``` each plot the orbit of the Earth (blue line) around the Sun (red) over $25$ years, using a different iteration method.
Our Earth starts $1AU$ on the $x$-axis away from the Sun at the origin.
We control a high number of steps $N=1000$ to maximise technique accuracy.
$25$ years is also a control variable because this is a sufficiant number of orbital periods.

### Euler Method

The Euler Method does not illustrate the full $25$ periods.
The Earth also spirals out immediately and not a lot of total energy is conserved.
Therefore, the Euler method is not an accurate technique, so methods with a higher-order or greater resolution are required to trace-out celestial dynamics better.

Output:
```
Two-Body System Simulation Euler Method Results:
Body a mass: 1.99e+30 kg
Body b mass: 5.97e+24 kg
Total simulation time: 25.00 years
Time steps: 1000
Time step size: 9.13 days
Initial separation: 1.000 AU
Final separation: 10.296 AU
Energy conservation ratio: 0.145946
```
![Euler Method, Earth and Moon system](images/sun_earth_euler.png)

### Midpoint Method

Output:
```
Two-Body System Simulation Midpoint Method Results:
Body a mass: 1.99e+30 kg
Body b mass: 5.97e+24 kg
Total simulation time: 25.00 years
Time steps: 1000
Time step size: 9.13 days
Initial separation: 1.000 AU
Final separation: 1.055 AU
Energy conservation ratio: 0.942958
```
![Midpoint Method, Earth and Moon system](images/sun_earth_midpoint.png)

### Heun's Method

Appears to be less accurate than the midpoint method as well as not conserving as much energy.
$\approx 15%$ of total energy is lost after $25$ years, compared to $\approx 6%$ for the midpoint method.

Output:
```
Two-Body System Simulation Heun's Method Results:
Body a mass: 1.99e+30 kg
Body b mass: 5.97e+24 kg
Total simulation time: 25.00 years
Time steps: 1000
Time step size: 9.13 days
Initial separation: 1.000 AU
Final separation: 1.219 AU
Energy conservation ratio: 0.849014
```
![Heun's Method, Earth and Moon system](images/sun_earth_heuns.png)

### Runge-Kutta Method

The most accurate technique by far, as the orbit shows no noticable perturbations or shifts.

Output:
```
Two-Body System Simulation Runge-Kutta Method Results:
Body a mass: 1.99e+30 kg
Body b mass: 5.97e+24 kg
Total simulation time: 25.00 years
Time steps: 1000
Time step size: 9.13 days
Initial separation: 1.000 AU
Final separation: 1.000 AU
Energy conservation ratio: 1.000422
```
![Runge-Kutta Method, Earth and Moon system](images/sun_earth_runge_kutta.png)

## Three-Body Systems

We used the RK4 method for the three-body systems for accuracy.

### Sun, Earth and Mars

Below illustrates the orbits of both the earth and mars around the sun, over a year.
As the planets are far away enough, and as the sun is a lot more massive, the orbits appear to be stable until errors in the Runge-Kutta method cause the system to spiral.

![Sun, Earth and Mars](images/earth_mars_sun.png)

### Earth, Moon and Spacecraft

Another example illustrates an orbiting spacecraft between the Earth and moon.
The spacecraft appears to have an unstable orbit because it is so much lighter than the celestials.
Making small changes in the spacecraft's initial position and velocity drastically changes its orbit.
For longer periods of time, the spacecraft eventually flies out and is lost.

![Earth, Moon and Spacecraft](images/earth_moon_spacecraft.png)

### Figure-8 Solution Attempt

A stable solution to the three-body problem exists where three identical massive bodies follow each other in a figure-8 pattern.
Each body is exactly $T/3$ in front of the next, for a period $T$, such that the bodies are in a "choreography".

We used the Python file ```examples/three_body_examples/figure_8_solution.py``` to minimise the Lagrangian describing three identical masses each $T/3$ apart - giving the required initial parameters.

Because three-body problems are extremely sensitive to perturbations in initial conditions, the masses start to derail from the figure-8 pattern almost instantly.

![Three Earths](images/three_earths.png)

## References

- [Euler Method](https://en.m.wikipedia.org/wiki/Euler_method)
- [Midpoint Method](https://en.m.wikipedia.org/wiki/Midpoint_method)
- [Heun's Method](https://en.wikipedia.org/wiki/Heun%27s_method)
- [Runge-Kutta Method](https://en.m.wikipedia.org/wiki/Runge–Kutta_methods)
- [Figure-8 Solution](https://en.m.wikipedia.org/wiki/Three-body_problem)

---

📘 Author: Sid Richards (SidRichardsQuantum)

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: https://www.linkedin.com/in/sid-richards-21374b30b/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
