# Particle in Earth's gravitational field
# (g varies with r)
# Euler method

Euler = function(a, b, y0, v0, theta, N) {
  yprime = function(x) {
    tan(theta) + (g * (x - a)) / (v0 * cos(theta))^2
  }

  # Energy conservation test: energy is conserved if the ratio of initial to final energies equals 1
  h = (b - a) / N
  r = R + y0
  g = -G * M / r^2  # Initial value of g

  l = c(y0)
  s = seq(a + h, b, by = h)
  Ea = 0.5 * v0^2 - G * M / r  # Initial energy per unit mass

  for (i in 0:N - 1) {
    l = c(l, l[i] + h * yprime(s[i]))
    r = R + l[i + 1]
    g = -G * M / r^2
  }

  v = sqrt(
    (v0 * cos(theta))^2 +
    (v0 * sin(theta) + g * (b - a) / (v0 * cos(theta)))^2
  )
  Eb = 0.5 * v^2 - G * M / r  # Final energy per unit mass

  plot(
    s, l, type = "l", col = "red",
    xlab = "x", ylab = "y",
    main = "Simulated trajectory of a particle in a gravitational field using the Euler method"
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
    col = c("black", "red")
  )

  return(Eb / Ea)
}

# Example call
Euler(1, 50, -1000000, 10, pi / 4, 30)
