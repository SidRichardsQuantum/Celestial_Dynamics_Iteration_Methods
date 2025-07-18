# THEORY

The acceleration of one body is $g = G * m / r^2$, where $G = -6.6743 * 10^{-11} m^3Kg^{-1}s^{-2}$ is the gravitational constant, $m$ is the mass of the other body and $r$ is the distance between them.

These iteration techniques approximate the successive positions and time-derivatives after each small time increment $dt$.
Here, we use $dt = T / N$, where $T$ is the total time and $N$ is the number of steps.
Each method below has a different way of approximating the parameters, and are listed below in order of increasing accuracy.

## Numerical Methods

Only the first approximated position and speed is written below, for the $x$-coordinate only.
These equations have the same exact form in the $y$ or $z$-directions, and for all $N$ steps.
Only the discrete positions $(x_i, y_i)$ for integer $i \in [0, N]$ are plotted.
(The intermediate coordinates are not meant to be plotted.)

For our projectile example, the gravitational acceleration is constant and only non-zero in the $y$-direction; such that $a_{xi} = 0$ and $a_{yi} = g = G m / r^2$, where $r = R + y_0$ for radius of the celestial $R$.
For our celestial system, the acceleration depends on the distance $r = (x^2 + y^2)^{0.5}$ between them, hence the acceleration is $a_{r1} = G m / r_1^2$.

### Euler Method

Let $x_0$ be the initial $x$-coordinate, $v_{x0} = \frac{dx_0}{dt}$ be the $x$-component of the initial velocity, and $a_{x0} = \frac{dv_{x0}}{dt}$ be the $x$-component of the initial acceleration. Then the Euler method approximates these parameters at the next step:
- $x_1 = x_0 + v_{x0} dt$
- $v_{x1} = v_{x0} + a_{x0} dt$
- $a_{x1} = G m / x_1^2$

### Midpoint Method

This method is a second-order Runge-Kutta (RK2) method, that provides significantly better accuracy than the Euler method, by evaluating the derivative at the midpoint of each time step.

Calculate midpoint estimates:
- $x_{0.5} = x_0 + v_{x0} dt / 2$
- $v_{x0.5} = v_{x0} + a_{x0} dt / 2$
- $a_{x0.5} = G m / x_{0.5}^2$

These are then used to find the successive parameters:
- $x_1 = x_0 + v_{x0.5} dt$
- $v_{x1} = v_{x0} + a_{x0.5} dt$
- $a_{x1} = G m / x_1^2$

### Heun's Method

Heun’s method is another RK2 technique, which is more accurate than the Euler method because it averages the initial gradient with the gradient predicted by Euler's method.

Euler's method predicts:
- $x_{pred} = x_0 + v_{x0} dt$
- $v_{xpred} = v_{x0} + a_{x0} dt$
- $a_{xpred} = G m / x_{pred}^2$

Average the above with the initial parameters to get:
- $x_1 = x_0 + (v_{xpred} + v_{x0}) dt / 2$
- $v_{x1} = v_{x0} + (a_{xpred} + a_{x0}) dt / 2$
- $a_{x1} = G m / x_1^2$

### Runge-Kutta (RK4) Method

RK4 is a fourth-order method that evaluates acceleration and velocity at multiple intermediate points, improving both accuracy and energy conservation.
Four intermediate estimates are calculated, and a weighted average is used to more-accurately determine the successive positions and velocities.

Startpoint gradients:
- $k_{1x} = v_{x0} dt$
- $k_{1vx} = a_{x0} dt$

Second intermediate gradients:
- $x_{1mid} = x_0 + k_{1x} / 2$
- $v_{1midx} = v_{x0} + k_{1vx} / 2$
- $a_{1midx} = G m / x_{1mid}^2$
- $k_{2x} = v_{1midx} dt$
- $k_{2vx} = a_{1midx} dt$

Third intermediate gradients:
- $x_{2mid} = x_0 + k_{2x} / 2$
- $v_{2midx} = v_{x0} + k_{2vx} / 2$
- $a_{2midx} = G m / x_{2mid}^2$
- $k_{3x} = v_{2midx} dt$
- $k_{3vx} = a_{2midx} dt$

Endpoint gradients:
- $x_{end} = x_0 + k_{3x}$
- $v_{endx} = v_{x0} + k_{3vx}$
- $a_{endx} = G m / x_{end}^2$
- $k_{4x} = v_{endx} dt$
- $k_{4vx} = a_{endx} dt$

Taking weighted averages of all the gradients:
- $x_1 = x_0 + (k_{1x} + 2k_{2x} + 2k_{3x} + k_{4x}) / 6$
- $v_{x1} = v_{x0} + (k_{1vx} + 2k_{2vx} + 2k_{3vx} + k_{4vx}) / 6$
- $a_{x1} = G m / x_1^2$

## Solutions of the Three-Body Problem

By minimising the action which describes three identical masses that follow each other $T/3$ apart, where $T$ is the orbital period, the initial conditions required for the stable figure-8 solution are generated.
This solution is one of many, and are (almost) entirely theoretical as chances of real celestials forming these stable patterns are minuscule.
By using the most accurate iteration method above, it might be possible to simulate the figure-8 for a short time before chaos ensues.

## References

- [Euler Method](https://en.m.wikipedia.org/wiki/Euler_method)
- [Midpoint Method](https://en.m.wikipedia.org/wiki/Midpoint_method)
- [Heun's Method](https://en.wikipedia.org/wiki/Heun%27s_method)
- [Runge-Kutta Method](https://en.m.wikipedia.org/wiki/Runge–Kutta_methods)
- [Three-Body Problem Solutions](https://en.m.wikipedia.org/wiki/Three-body_problem)

---

📘 Author: Sid Richards (SidRichardsQuantum)

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: https://www.linkedin.com/in/sid-richards-21374b30b/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
