# Particle in Earth's gravitational field
# (g varies with r)
# Runge-Kutta method

Runge_Kutta = function(a, b, y0, v0, theta, N) {
  r = R + y0
  g = -G * M / r^2

  y = function(x) {
    (x - a) * tan(theta) + (g * (x - a)^2) / (2 * (v0 * cos(theta))^2)
  }

  yprime = function(x, y) {
    tan(theta) + (g * (x - a)) / ((v0 * cos(theta))^2)
  }

  h = (b - a) / N
  s = seq(a, b, by = h)
  l = c(y0)
  Ea = 0.5 * v0^2 - G * M / r  # Initial energy per unit mass

  # Runge-Kutta method loop
  for (i in 1:N) {
    K1 = h * yprime(s[i], y(s[i]))
    K2 = h * yprime(s[i] + h / 2, y(s[i]) + K1 / 2)
    K3 = h * yprime(s[i] + h / 2, y(s[i]) + K2 / 2)
    K4 = h * yprime(s[i] + h, y(s[i]) + K3)

    l = c(
      l,
      y0 + y(s[i]) + (K1 + 2 * K2 + 2 * K3 + K4) / 6
    )

    r = R + l[i + 1]
    g = -G * M / r^2
  }

  v = sqrt(
    (v0 * cos(theta))^2 +
    (v0 * sin(theta) + g * (b - a) / (v0 * cos(theta)))^2
  )
  Eb = 0.5 * v^2 - G * M / r  # Final energy per unit mass

  plot(
    s, l, type = "l", col = "pink",
    xlab = "x", ylab = "y",
    main = "Simulated trajectory of a particle in a gravitational field using the Runge-Kutta method"
  )
  lines(
    s,
    y0 + (s - a) * tan(theta) +
    (g * (s - a)^2) / (2 * (v0 * cos(theta))^2)
  )
  legend(
    "bottomleft",
    legend = c("Calculated", "Runge-Kutta method"),
    lty = c("solid", "solid"),
    col = c("black", "pink")
  )

  return(Eb / Ea)
}

# Example call
Runge_Kutta(1, 50, -1000000, 10, pi / 4, 30)
