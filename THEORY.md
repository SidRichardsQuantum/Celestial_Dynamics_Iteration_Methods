# THEORY

## Table of Contents

- [Intro](#intro)
- [Numerical Methods](#numerical-methods)
  - [Euler Method](#euler-method)
  - [Midpoint Method](#midpoint-method)
  - [Heun's Method](#heuns-method)
  - [Runge-Kutta (RK4) Method](#runge-kutta-rk4-method)
  - [Velocity Verlet Method](#velocity-verlet-method)
- [Solutions of the Three-Body Problem](#solutions-of-the-three-body-problem)
- [General N-Body Engine](#general-n-body-engine)
- [References](#references)

## Intro

The acceleration of one body is $g = -G * m / r^2$, where $G = 6.6743 * 10^{-11} m^3Kg^{-1}s^{-2}$ is the gravitational constant, $m$ is the mass of the other body and $r$ is the distance between them.

These iteration techniques approximate the successive positions and time-derivatives after each small time increment $dt$.
Here, we use $dt = T / N$, where $T$ is the total time and $N$ is the number of steps.
Each method below has a different way of approximating the parameters, and are listed below in order of increasing accuracy.

## Numerical Methods

Only the first approximated position and speed is written below, for the $x$-coordinate only.
These equations have the same exact form in the $y$ or $z$-directions, and for all $N$ steps.
Only the discrete positions $(x_i, y_i)$ for integer $i \in [0, N]$ are plotted.
(The intermediate coordinates are not meant to be plotted.)

For our projectile example, the gravitational acceleration is constant and only non-zero in the $y$-direction; such that $a_{xi} = 0$ and $a_{yi} = g = -G m / r^2$, where $r = R + y_0$ for radius of the celestial $R$.
For our celestial system, the acceleration depends on the distance $r = (x^2 + y^2)^{0.5}$ between them, hence the acceleration is $a_{r1} = -G m / r_1^2$.

### Euler Method

Let $x_0$ be the initial $x$-coordinate, $v_{x0} = \frac{dx_0}{dt}$ be the $x$-component of the initial velocity, and $a_{x0} = \frac{dv_{x0}}{dt}$ be the $x$-component of the initial acceleration. Then the Euler method approximates these parameters at the next step:
- $x_1 = x_0 + v_{x0} dt$
- $v_{x1} = v_{x0} + a_{x0} dt$
- $a_{x1} = -G m / x_1^2$

### Midpoint Method

This method is a second-order Runge-Kutta (RK2) method, that provides significantly better accuracy than the Euler method, by evaluating the derivative at the midpoint of each time step.

Calculate midpoint estimates:
- $x_{0.5} = x_0 + v_{x0} dt / 2$
- $v_{x0.5} = v_{x0} + a_{x0} dt / 2$
- $a_{x0.5} = -G m / x_{0.5}^2$

These are then used to find the successive parameters:
- $x_1 = x_0 + v_{x0.5} dt$
- $v_{x1} = v_{x0} + a_{x0.5} dt$
- $a_{x1} = -G m / x_1^2$

### Heun's Method

Heun’s method is another RK2 technique, which is more accurate than the Euler method because it averages the initial gradient with the gradient predicted by Euler's method.

Euler's method predicts:
- $x_{pred} = x_0 + v_{x0} dt$
- $v_{xpred} = v_{x0} + a_{x0} dt$
- $a_{xpred} = -G m / x_{pred}^2$

Average the above with the initial parameters to get:
- $x_1 = x_0 + (v_{xpred} + v_{x0}) dt / 2$
- $v_{x1} = v_{x0} + (a_{xpred} + a_{x0}) dt / 2$
- $a_{x1} = -G m / x_1^2$

### Runge-Kutta (RK4) Method

RK4 is a fourth-order method that evaluates acceleration and velocity at multiple intermediate points, improving both accuracy and energy conservation.
Four intermediate estimates are calculated, and a weighted average is used to more-accurately determine the successive positions and velocities.

Startpoint gradients:
- $k_{1x} = v_{x0} dt$
- $k_{1vx} = a_{x0} dt$

Second intermediate gradients:
- $x_{1mid} = x_0 + k_{1x} / 2$
- $v_{1midx} = v_{x0} + k_{1vx} / 2$
- $a_{1midx} = -G m / x_{1mid}^2$
- $k_{2x} = v_{1midx} dt$
- $k_{2vx} = a_{1midx} dt$

Third intermediate gradients:
- $x_{2mid} = x_0 + k_{2x} / 2$
- $v_{2midx} = v_{x0} + k_{2vx} / 2$
- $a_{2midx} = -G m / x_{2mid}^2$
- $k_{3x} = v_{2midx} dt$
- $k_{3vx} = a_{2midx} dt$

Endpoint gradients:
- $x_{end} = x_0 + k_{3x}$
- $v_{endx} = v_{x0} + k_{3vx}$
- $a_{endx} = -G m / x_{end}^2$
- $k_{4x} = v_{endx} dt$
- $k_{4vx} = a_{endx} dt$

Taking weighted averages of all the gradients:
- $x_1 = x_0 + (k_{1x} + 2k_{2x} + 2k_{3x} + k_{4x}) / 6$
- $v_{x1} = v_{x0} + (k_{1vx} + 2k_{2vx} + 2k_{3vx} + k_{4vx}) / 6$
- $a_{x1} = -G m / x_1^2$

### Velocity Verlet Method

Velocity Verlet is a second-order symplectic method.
It is especially useful for orbital dynamics because it updates positions and
velocities in a way that tends to keep long-term energy error bounded rather
than letting it drift monotonically.

Using the current acceleration $a_{x0}$:
- $x_1 = x_0 + v_{x0} dt + \frac{1}{2} a_{x0} dt^2$
- $a_{x1} = -G m / x_1^2$
- $v_{x1} = v_{x0} + \frac{1}{2}(a_{x0} + a_{x1})dt$

The method is lower order than RK4, but its symplectic structure makes it an
important comparison method for long-running conservative systems.

## Solutions of the Three-Body Problem

This repository includes several special and illustrative three-body cases.
Some are analytically structured initial conditions, then RK4 is used to test whether the numerical trajectory preserves that structure over one period.
Others intentionally perturb a solution or use the restricted three-body approximation to show nearby behavior.

The figure-8 solution is generated by minimising the action which describes three identical masses that follow each other $T/3$ apart, where $T$ is the orbital period.
With correctly scaled initial positions, velocities, and period, RK4 can reproduce the figure-8 orbit over a full period.

The Lagrange solution places the three bodies at the vertices of an equilateral triangle.
The triangle rotates rigidly about its center of mass with angular speed $\omega = \sqrt{G(3m)/s^3}$, where $s$ is the side length.
Each body therefore keeps the same pairwise separation throughout the orbit.

The Euler collinear solution places three equal masses on a single rotating line.
For positions $(-r, 0)$, $(0, 0)$, and $(r, 0)$, the outer bodies require $\omega = \sqrt{5Gm/(4r^3)}$ and the central body remains at the center of mass.
The line rotates as a rigid central configuration.

These solutions are special cases, not generic outcomes.
Like other three-body trajectories, they remain sensitive to perturbations and numerical error over longer integrations.

Perturbed figure-8 and perturbed Lagrange examples start from known periodic solutions and apply a small displacement or velocity change.
These examples are not new exact solutions; they show sensitivity to initial conditions while conserving total energy numerically.

The circular restricted three-body problem (CR3BP) assumes two massive primaries on circular orbits and a third body whose mass is negligible.
In the rotating frame, the primaries are fixed and the third body obeys normalized equations with mass ratio $\mu = m_2/(m_1 + m_2)$.
This form is useful for Lagrange points, Trojan motion near L4 or L5, and small Lyapunov-like loops near L1 or L2.

The Sitnikov problem is a spatial restricted case.
Two equal primaries orbit in the plane while the third body moves along the perpendicular axis through their center of mass.
For circular primaries separated symmetrically by radius $a$, the restricted body's vertical acceleration is
$z'' = -2Gmz/(a^2 + z^2)^{3/2}$.

Hierarchical triples model a close binary plus a much more distant third body.
This is not generally periodic, but it is a common astrophysical configuration and usually remains stable when the outer orbit is much wider than the binary separation.

The Butterfly I choreography uses cataloged equal-mass periodic initial conditions with
$x_1=-1$, $x_2=0$, $x_3=1$, $v_1=v_3=(p_1,p_2)$, and $v_2=-2v_1$ in dimensionless units.
The helper scales those catalog values into SI units in the same way as the figure-8 helper.

## General N-Body Engine

The n-body engine stores positions and velocities in arrays with dimensions
`step x body x coordinate`.
For each body, acceleration is computed by summing the pairwise gravitational
contribution from every other body.
This makes the same solver usable for two, three, four, or more bodies without
duplicating the force equations for each system size.

The specialized two-body and three-body files are kept because they are easier
to read as educational derivations.
The n-body engine is a general-purpose parallel implementation for larger
examples and parity checks.

Two special four-body central configurations are included as n-body examples.
In the equal-mass square, the four bodies sit at the corners of a square and
rotate rigidly about the center. For half-side length $a$, the required angular
speed is
$\omega^2 = \frac{Gm}{a^3}\left(\frac{1}{4} + \frac{1}{8\sqrt{2}}\right)$.

The triangular central configuration places one mass at the center and three
equal outer masses at the vertices of an equilateral triangle.
The central body remains fixed by symmetry while the outer triangle rotates
rigidly around it.

## References

- [Euler Method](https://en.m.wikipedia.org/wiki/Euler_method)
- [Midpoint Method](https://en.m.wikipedia.org/wiki/Midpoint_method)
- [Heun's Method](https://en.wikipedia.org/wiki/Heun%27s_method)
- [Runge-Kutta Method](https://en.m.wikipedia.org/wiki/Runge–Kutta_methods)
- [Three-Body Problem Solutions](https://en.m.wikipedia.org/wiki/Three-body_problem)
- [Periodic Three-Body Initial Conditions](https://three-body.ipb.ac.rs/initial-conditions.pdf)

---

📘 Author: Sid Richards (SidRichardsQuantum)

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: https://www.linkedin.com/in/sid-richards-21374b30b/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
