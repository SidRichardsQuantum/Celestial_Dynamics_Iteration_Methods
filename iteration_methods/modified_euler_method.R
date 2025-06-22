# Particle in Earth's gravitational field
# (g varies with r)
# Modified Euler method

Modified_Euler = function(a, b, y0, v0, theta, N) {
  r = R + y0
  g = -G * M / r^2

  y = function(x) {
    (x - a) * tan(theta) + (g * (x - a)^2) / (2 * (v0 * cos(theta))^2)
  }

  yprime = function(x, y) {
    y / (x - a) + (g * (x - a)) / (2 * (v0 * cos(theta))^2)
  }

  h = (b - a) / N
  l = c(y0)
  s = seq(a + h, b, by = h)
  Ea = 0.5 * v0^2 - G * M / r  # Initial energy per unit mass

  for (i in 0:N - 1) {
    l = c(
      l,
      l[i] + 0.5 * h * (
        yprime(s[i], y(s[i])) +
        yprime(s[i + 1], y(s[i]) + h * yprime(s[i], y(s[i])))
      )
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
    s, l, type = "l", col = "grey",
    xlab = "x", ylab = "y",
    main = "Simulated trajectory of a particle in a gravitational field using the Modified Euler method"
  )
  lines(
    s,
    y0 + (s - a - h) * tan(theta) +
    (g * (s - a - h)^2) / (2 * (v0 * cos(theta))^2)
  )
  legend(
    "bottomleft",
    legend = c("Calculated", "Simulated"),
    lty = c("solid", "solid"),
    col = c("black", "grey")
  )

  return(Eb / Ea)
}

# Example call
Modified_Euler(1, 50, -1000000, 10, pi / 4, 30)
