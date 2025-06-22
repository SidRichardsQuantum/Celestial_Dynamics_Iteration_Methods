# Earth-Mars-Sun System Example (2D)

# Load dependencies
source("constants.R")
source("celestial_systems/three_body_problem.R")

# Create images directory if it doesn't exist
if (!dir.exists("images")) {
  dir.create("images")
  cat("Created 'images' directory\n")
}

cat("Running Earth-Mars-Sun 2D orbital simulation...\n")
cat("Period: 1 year\n")
cat("Integration steps: 3000\n\n")

# Open PNG device to save plot
png("images/earth_mars_sun.png", width = 800, height = 600, res = 100)

cmt(
  P = YEAR,
  N = 3000,
  mi = M_SUN,
  mj = M_EARTH,
  mk = M_MARS,
  rix = 0, riy = 0,                # Sun at origin
  rjx = AU, rjy = 0,               # Earth at 1 AU along x-axis
  rkx = 0, rky = 227.9e9,          # Mars at ~227.9 million km along y-axis
  v0ix = 0, v0iy = 0,              # Sun stationary
  v0jx = 0, v0jy = V_EARTH_ORBITAL, # Earth moving in +y direction
  v0kx = -24130.772, v0ky = 0      # Mars with initial x-velocity
)

# Close the PNG device
dev.off()

cat("Simulation complete!\n")
cat("Plot saved to: images/earth_mars_sun.png\n")
cat("The plot shows Earth (blue), Mars (red), and the Sun (black) in the 2D plane.\n")
