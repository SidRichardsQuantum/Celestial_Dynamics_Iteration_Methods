# Particle in Earth's gravitational field
# (g varies with r)
# Midpoint method

Midpoint = function(a, b, y0, v0, theta, N) {
  r = R + y0
  g = -G * M / r^2

  # The midpoint method also requires the trajectory equation to evolve y
  y = function(x) {
    (x - a) * tan(theta) + (g * (x - a)^2) / (2 * (v0 * cos(theta))^2)
  }

  yprime = function(x, y) {
    y / (x - a) + (g * (x - a)) / (2 * (v0 * cos(theta))^2)
  }

  h = (b - a) / N
  l = c(y0)
  s = seq(a + h, b, by = h)
  Ea = 0.5 * v0^2 - G * M / r

  for (i in 0:N - 1) {
    l = c(
      l,
      l[i] + h * yprime(
        s[i] + h / 2,
        y(s[i]) + 0.5 * h * yprime(s[i], y(s[i]))
      )
    )
    r = R + l[i + 1]
    g = -G * M / r^2
  }

  v = sqrt(
    (v0 * cos(theta))^2 +
    (v0 * sin(theta) + g * (b - a) / (v0 * cos(theta)))^2
  )
  Eb = 0.5 * v^2 - G * M / r

  plot(
    s, l, type = "l", col = "purple",
    xlab = "x", ylab = "y",
    main = "Simulated trajectory of a particle in a gravitational field using the Midpoint method"
  )
  lines(
    s,
    y0 + (s - a - h) * tan(theta) +
    (g * (s - a - h)^2) / (2 * (v0 * cos(theta))^2)
  )
  legend(
    "bottomleft",
    legend = c("Calculated", "Midpoint method"),
    lty = c("solid", "solid"),
    col = c("black", "purple")
  )

  return(Eb / Ea)
}

# Example call
Midpoint(1, 50, -1000000, 10, pi / 4, 30)
