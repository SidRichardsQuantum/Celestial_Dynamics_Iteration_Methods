# Three massive bodies interacting in 2D
# Modified Euler method
source("constants.R")

cmt = function(P, N, mi, mj, mk,
               rix, riy,
               rjx, rjy,
               rkx, rky,
               v0ix, v0iy,
               v0jx, v0jy,
               v0kx, v0ky) {
  
  # Initial positions and velocities
  ri = c(rix, riy)
  rj = c(rjx, rjy)
  rk = c(rkx, rky)

  v0i = c(v0ix, v0iy)
  v0j = c(v0jx, v0jy)
  v0k = c(v0kx, v0ky)

  # Initial angular momenta
  L0i = mi * (rix * v0iy - riy * v0ix)
  L0j = mj * (rjx * v0jy - rjy * v0jx)
  L0k = mk * (rkx * v0ky - rky * v0kx)

  # Initial linear momenta
  p0i = mi * v0i
  p0j = mj * v0j
  p0k = mk * v0k

  # Distance vectors
  rij = ri - rj
  rik = ri - rk
  rjk = rj - rk

  modrij = sqrt(sum(rij^2))
  modrik = sqrt(sum(rik^2))
  modrjk = sqrt(sum(rjk^2))

  # Trajectory storage
  xi = c(rix); yi = c(riy)
  xj = c(rjx); yj = c(rjy)
  xk = c(rkx); yk = c(rky)

  for (i in 1:N) {
    dt = P / N

    # Position updates
    ri = ((G * mj * rij / modrij^3) + (G * mk * rik / modrik^3)) * (dt^2) / 2 + v0i * dt + ri
    rj = ((-G * mi * rij / modrij^3) + (G * mk * rjk / modrjk^3)) * (dt^2) / 2 + v0j * dt + rj
    rk = ((-G * mi * rik / modrik^3) + (-G * mj * rjk / modrjk^3)) * (dt^2) / 2 + v0k * dt + rk

    # Velocity updates
    v0i = ((G * mj * rij / modrij^3) + (G * mk * rik / modrik^3)) * dt + v0i
    v0j = ((-G * mi * rij / modrij^3) + (G * mk * rjk / modrjk^3)) * dt + v0j
    v0k = ((-G * mi * rik / modrik^3) + (-G * mj * rjk / modrjk^3)) * dt + v0k

    # Store new positions
    xi = c(xi, ri[1]); yi = c(yi, ri[2])
    xj = c(xj, rj[1]); yj = c(yj, rj[2])
    xk = c(xk, rk[1]); yk = c(yk, rk[2])

    # Recalculate distances
    rij = ri - rj
    rik = ri - rk
    rjk = rj - rk

    modrij = sqrt(sum(rij^2))
    modrik = sqrt(sum(rik^2))
    modrjk = sqrt(sum(rjk^2))
  }

  # Final angular momentum and linear momentum
  Li = mi * (ri[1] * v0i[2] - ri[2] * v0i[1])
  Lj = mj * (rj[1] * v0j[2] - rj[2] * v0j[1])
  Lk = mk * (rk[1] * v0k[2] - rk[2] * v0k[1])

  pi = mi * v0i
  pj = mj * v0j
  pk = mk * v0k

  # Plot trajectories in the xy-plane
  plot(xk, yk, type = "l", col = "red", xlab = "x", ylab = "y", main = "Three-Body Orbit (2D)")
  lines(xj, yj, col = "blue")
  lines(xi, yi, col = "black")
  legend("bottomleft", legend = c("Body i", "Body j", "Body k"),
         col = c("black", "blue", "red"), lty = 1)

  return(c((Li + Lj + Lk) / (L0i + L0j + L0k),
           sum(pi + pj + pk) / sum(p0i + p0j + p0k)))
}
