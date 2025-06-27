# THEORY

The acceleration of one body is $a = G * m / r^2$, where $G = 6.6743 * 10^{-11} m^3Kg^{-1}s^{-2}$ is the gravitational constant, $m$ is the mass of the other body and $r$ is the distance between them.

## Euler Method

For position $x_0$ and velocity $v_{x0}$, the successive position is written as $x_1 = x_0 + v_{x0} * dt$, where $dt$ is a small time-increment.
We use $dt = T / N$, where $T$ is the total time and $N$ is the number of steps.
Similarly, the successive velocity $v_{x1} = v_{x0} + a_{x0} * dt$ is also calculated, where $a_{x0}$ is the acceleration at coordinate $x_0$.

Then the acceleration is updated akin to the new approximated coordinates.
For our projectile example, there is only acceleration in the $y$-direction; such that $a_{x1} = a_{x0}$ and $a_{y1} = G * m / r_1^2$, where $r = R + y_1$ for radius of the celestial $R$.

## Midpoint Method

Similar to the Euler method, but an intermediate time-increment $(dt/2)$ is also implemented.

## Heun's Method

## Runge-Kutta Method

Four intermediate steps are calculated and their weighted average is used to more-accurately determine the succesive positions and velocities.

## References

- [Euler Method](https://en.m.wikipedia.org/wiki/Euler_method)
- [Midpoint Method](https://en.m.wikipedia.org/wiki/Midpoint_method)
- [Heun's Method](https://en.wikipedia.org/wiki/Heun%27s_method)
- [Runge-Kutta Method](https://en.m.wikipedia.org/wiki/Runge–Kutta_methods)

---

📘 Author: Sid Richards (SidRichardsQuantum)

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/linkedin/linkedin-original.svg" width="20" /> LinkedIn: https://www.linkedin.com/in/sid-richards-21374b30b/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
