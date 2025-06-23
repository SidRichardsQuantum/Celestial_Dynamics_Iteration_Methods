# THEORY

The acceleration of one body is $a = G * m / r^2$, where $G = 6.6743 * 10^{-11} m^3Kg^{-1}s^{-2}$ is the gravitational constant, $m$ is the mass of the other body and $r$ is the distance between them.

## Euler Method

For position $x_0$ and velocity $v_0$, the successive position is written as $x_1 = x_0 + v_0 * dt$, where $dt$ is a small time-increment.
Similarly, $v_1 = v_0 + a_0 * dt$, where $a_0$ is the acceleration at coordinate $(x_0, y_0)$.
Then the new acceleration is $a_1 = G * m / r_1^2$.

## Midpoint Method

## Heun's Method

## Runge-Kutta Method

## References

- [Euler Method](https://en.m.wikipedia.org/wiki/Euler_method)
- [Midpoint Method](https://en.m.wikipedia.org/wiki/Midpoint_method)
- [Heun's Method](https://en.wikipedia.org/wiki/Heun%27s_method)
- [Runge-Kutta Method](https://en.m.wikipedia.org/wiki/Runge–Kutta_methods)
