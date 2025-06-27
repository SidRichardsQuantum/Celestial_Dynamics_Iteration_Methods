# THEORY

The acceleration of one body is $a = G * m / r^2$, where $G = 6.6743 * 10^{-11} m^3Kg^{-1}s^{-2}$ is the gravitational constant, $m$ is the mass of the other body and $r$ is the distance between them.

These iteration techniques approximate the successive positions and time-derivatives after each small time increment $dt$.
Here, we use $dt = T / N$, where $T$ is the total time and $N$ is the number of steps.
Each method below has a different way of approximating the parameters, and are listed below from the least-accurate to the most.

Only the first approximated position, speed and acceleration are written below, for the $x$-coordinate only.
These equations have the same exact form in the $y$ or $z$-directions, and for all $N$ steps.
Only coordinates $(x_i, y_i)$ are plotted for **integers** $i \in [0, N]$.
(The intermediate coordinates are not meant to be plotted.)

## Euler Method

Let $x_0$ be the initial $x$-coordinate, $v_{x0} = \frac{dx_0}{dt}$ be the $x$-component of the initial velocity, and $a_{x0} = \frac{dv_{x0}}{dt}$ be the $x$-component of the initial acceleration. Then the Euler method approximates these parameters at the next step:
- $x_1 = x_0 + v_{x0} dt$
- $v_{x1} = v_{x0} + a_{x0} dt$
- $a_{x1} = G m / x_1^2$

For our projectile example, there is only acceleration in the $y$-direction; such that $a_{x1} = a_{x0}$ and $a_{y1} = G m / r_1^2$, where $r = R + y_1$ for radius of the celestial $R$.
For our celestial system, the acceleration depends on the distance $r = (x^2 + y^2)^{0.5}$ between them, hence the acceleration is $a_{r1} = G m / r_1^2$.

## Midpoint Method

This method is a second-order Runge-Kutta (RK2) method, that provides significantly better accuracy than the Euler method, by evaluating the derivative at the midpoint of each time step.

Calculate midpoint estimates:
- $x_{0.5} = x_0 + v_{x0} dt / 2$
- $v_{x0.5} = v_{x0} + a_{x0} dt / 2$
- $a_{x0.5} = G m / x_{0.5}^2$

These are then used to find the successive parameters:
- $x_1 = x_0 + v_{x0.5} dt$
- $v_{x1} = v_{x0} + a_{x0.5} dt$
- $a_{x1} = G m / x_1^2$

## Heun's Method

This is also an RK2 method, which is more accurate than the Euler method because it averages the initial gradient with the gradient predicted by Euler's method.

Euler's method predicts:
- $x_pred = x_0 + v_{x0} dt$
- $v_{xpred} = v_{x0} + a_{x0} dt$
- $a_{xpred} = G m / x_1^2$

Average the above with the initial parameters to get:
- $x_1 = x_0 + (v_{xpred} + v_{0}) dt / 2$
- $v_{x1} = v_{x0} + (a_{xpred} + a_{0}) dt / 2$
- $a_{x1} = G m / x_1^2$

## Runge-Kutta (RK4) Method

Four intermediate steps are calculated and their weighted average is used to more-accurately determine the succesive positions and velocities.

Startpoint gradients:
- $k_{1x} = v_{x0} dt$
- $k_{1vx} = a_{x0} dt$

Second intermediate gradients:
- $x_{1mid} = x_0 + k_{1x} / 2$
- $v_{1midx} = v_{x0} + k_{1vx} / 2$
- $a_{1midx} = G m / x_{1mid}^2$
- $k_{2x} = v_{1midx} dt$
- $k_{2vx} = a_{1midr} dt$

Third intermediate gradients:
- $x_{2mid} = x_0 + k_{2x} / 2$
- $v_{2midx} = v_{x0} + k_{2vx} / 2$
- $a_{2midx} = G m / x_{2mid}^2$
- $k_{3x} = v_{2midx} dt$
- $k_{3vx} = a_{2midr} dt$

Endpoint gradients:
- $x_{end} = x_0 + k_{3x}$
- $v_{endx} = v_{x0} + k_{3vx}$
- $a_{endx} = G m / x_{end}^2$
- $k_{4x} = v_{endx} dt$
- $k_{4vx} = a_{endr} dt$

Taking weighted averages of all the gradients:
- $x_1 = x_0 + (k_{1x} + 2k_{2x} + 2k_{3x} + k_{4x}) / 6$
- $v_{x1} = v_{x0} + (k_{1vx} + 2k_{2vx} + 2k_{3vx} + k_{4vx}) / 6$
- $a_{x1} = G m / x_1^2$

## References

- [Euler Method](https://en.m.wikipedia.org/wiki/Euler_method)
- [Midpoint Method](https://en.m.wikipedia.org/wiki/Midpoint_method)
- [Heun's Method](https://en.wikipedia.org/wiki/Heun%27s_method)
- [Runge-Kutta Method](https://en.m.wikipedia.org/wiki/Runge–Kutta_methods)

---

📘 Author: Sid Richards (SidRichardsQuantum)

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: https://www.linkedin.com/in/sid-richards-21374b30b/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
