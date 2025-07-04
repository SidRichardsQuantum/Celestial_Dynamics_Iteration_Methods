# Results

## Sun-Earth System

Our Sun and Earth example files in ```examples/two_body_examples``` each plot the orbit of the Earth (blue line) around the Sun (red) over $25$ years, using a different iteration method.
Our Earth starts $1AU$ on the $x$-axis away from the Sun at the origin.
We use a high number of steps $N=1000$ to maximise technique accuracy.

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

We will use the RK4 method for the three-body systems for accuracy.

### Sun, Earth and Mars

![Sun, Earth and Mars](images/earth_mars_sun.png)

### Earth, Moon and Spacecraft

![Earth, Moon and Spacecraft](images/earth_moon_spacecraft.png)

### Figure-8 Solution

A stable solution to the three-body problem exists where three identical massive bodies follow eachother in a figure-8 parrern.
Each body is exactly $T/3$ in front of the next, where $T$ is the period, hence the bodies are in a "choreography".
We used a Python file to minimise the Lagrangian describing three identical masses each $T/3$ apart.

![Three Earths](images/three_earths.png)

## References

[https://en.m.wikipedia.org/wiki/Three-body_problem]

---

📘 Author: Sid Richards (SidRichardsQuantum)

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: https://www.linkedin.com/in/sid-richards-21374b30b/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
