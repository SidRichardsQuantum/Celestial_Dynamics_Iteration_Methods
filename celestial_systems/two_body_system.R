# Pair of massive bodies interacting in 2D
# Modified Euler Method
source("constants.R")

cpt_2d <- function(P, N, mi, mj, rix, riy, rjx, rjy, v0ix, v0iy, v0jx, v0jy) {
  # Initial position vectors
  ri <- c(rix, riy)
  rj <- c(rjx, rjy)
  
  # Initial velocity vectors
  v0i <- c(v0ix, v0iy)
  v0j <- c(v0jx, v0jy)
  
  # Calculate initial separation vector and distance
  rij <- ri - rj
  modrij <- sqrt(sum(rij^2))
  
  # Initialize position arrays for plotting
  xi <- c(rix)
  yi <- c(riy)
  xj <- c(rjx)
  yj <- c(rjy)
  
  # Numerical integration loop
  for(i in 1:N) {
    # Update positions using kinematic equations
    ri <- (G * mj * rij / modrij^3) * ((P/N)^2) / 2 + v0i * (P/N) + ri
    rj <- (-G * mi * rij / modrij^3) * ((P/N)^2) / 2 + v0j * (P/N) + rj
    
    # Update velocities using gravitational acceleration
    v0i <- (G * mj * rij / modrij^3) * (P/N) + v0i
    v0j <- (-G * mi * rij / modrij^3) * (P/N) + v0j
    
    # Store positions for plotting
    xi <- c(xi, ri[1])
    yi <- c(yi, ri[2])
    xj <- c(xj, rj[1])
    yj <- c(yj, rj[2])
    
    # Recalculate separation for next iteration
    rij <- ri - rj
    modrij <- sqrt(sum(rij^2))
  }
  
  # Create single 2D plot showing both orbits
  xi_au <- xi / AU
  yi_au <- yi / AU
  xj_au <- xj / AU
  yj_au <- yj / AU
  
  plot(xj_au, yj_au, type="l", col="blue", xlab="x (AU)", ylab="y (AU)", 
       main="Two-Body Gravitational System (2D)")
  lines(xi_au, yi_au, col="black")
  legend("topright", legend=c("Body i", "Body j"), 
         lty=c("solid", "solid"), col=c("black", "blue"))
  
  # Add starting positions
  points(rix/AU, riy/AU, pch=19, col="black", cex=1.2)
  points(rjx/AU, rjy/AU, pch=19, col="blue", cex=1.2)
}
