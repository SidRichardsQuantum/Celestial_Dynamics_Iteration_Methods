# THEORY

The acceleration of one body is $a = G * m / r^2$, where $G = 6.6743 * 10^{-11} m^3Kg^{-1}s^{-2}$ is the gravitational constant, $m$ is the mass of the other body and $r$ is the distance between them.

## Euler Method

For position $x_0$ and velocity $v_{x0}$, the successive position is written as $x_1 = x_0 + v_{x0} * dt$, where $dt$ is a small time-increment.
We use $dt = T / N$, where $T$ is the total time and $N$ is the number of steps.
Similarly, the successive velocity $v_{x1} = v_{x0} + a_{x0} * dt$ is also calculated, where $a_{x0}$ is the acceleration at coordinate $x_0$.

Then the acceleration is updated akin to the new approximated coordinates, for the next iteration.
For our projectile example, there is only acceleration in the $y$-direction; such that $a_{x1} = a_{x0}$ and $a_{y1} = G * m / r_1^2$, where $r = R + y_1$ for radius of the celestial $R$.
For our celestial system, the acceleration depends on the distance $r = (x^2 + y^2)^{0.5}$ between them, hence the acceleration is $a_{r1} = G * m / r_1^2$.

## Midpoint Method

This method is a second-order Runge-Kutta (RK2) method, that provides significantly better accuracy than the Euler method, by evaluating the derivative at the midpoint of each time step.

Calculate midpoint estimates:
	•	$x_{0.5} = x_0 + v_{x0} * dt / 2$
	•	$v_{x0.5} = v_{x0} + a_{x0} * dt / 2$
 • $a_{r0.5} = G * m / r_{0.5}^2$

These are then used to find the successive parameters:
	•	$x_1 = x_0 + v_{x0.5} * dt$
	•	$v_{x1} = v_{x0} + a_{x0.5} * dt$
 • $a_{r1} = G * m / r_1^2$

Only coordinates $(x_i, y_i)$ are plotted for **integers** $i \in [0, N]$.
(The intermediate midpoint coordinates aren't plotted.)

## Heun's Method

This is also an RK2 method, which is more accurate than the Euler method because it averages the initial gradient with the predicted gradient (by Euler's method).

Euler's method predicts:
	•	$x_pred = x_0 + v_{x0} * dt$
	•	$v_{xpred} = v_{x0} + a_{x0} * dt$
 • $a_{rpred} = G * m / r_1^2$

Average the above with the initial parameters to get:
	•	$x_1 = x_0 + (v_{xpred} + v_{0}) * dt / 2$
	•	$v_{x1} = v_{x0} + (a_{xpred} + a_{0}) * dt / 2$
 • $a_{r1} = G * m / r_1^2$

## Runge-Kutta (RK4) Method

Four intermediate steps are calculated and their weighted average is used to more-accurately determine the succesive positions and velocities.

Startpoint gradients:
• $k_{1x} = v_{x0} * dt$
• $k_{1v_x} = a_{x0} * dt$

Second intermediate gradients:
• $x_{mid1} = x_0 + k_{1x} / 2$
• $v_{midx1} = v_{x0} + k_{1v_x} / 2$
• $a_{midr1} = G * m / r_{mid1}^2$
• $k_{2x} = v_{midx1} * dt$
• $k_{2v_x} = a_{midr1} * dt$

Third intermediate gradients:
• $x_{mid2} = x_0 + k_{2x} / 2$
• $v_{midx2} = v_{x0} + k_{2v_x} / 2$
• $a_{midr2} = G * m / r_{mid2}^2$
• $k_{3x} = v_{midx2} * dt$
• $k_{3v_x} = a_{midr2} * dt$

Endpoint gradients:
• $x_{end} = x_0 + k_{3x}$
• $v_{endx} = v_{x0} + k_{3v_x}$
• $a_{endr} = G * m / r_{end}^2$
• $k_{4x} = v_{endx} * dt$
• $k_{4v_x} = a_{endr} * dt$

## References

- [Euler Method](https://en.m.wikipedia.org/wiki/Euler_method)
- [Midpoint Method](https://en.m.wikipedia.org/wiki/Midpoint_method)
- [Heun's Method](https://en.wikipedia.org/wiki/Heun%27s_method)
- [Runge-Kutta Method](https://en.m.wikipedia.org/wiki/Runge–Kutta_methods)

---

📘 Author: Sid Richards (SidRichardsQuantum)

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: https://www.linkedin.com/in/sid-richards-21374b30b/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
