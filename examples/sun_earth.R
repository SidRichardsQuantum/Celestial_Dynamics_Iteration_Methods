# Sun-Earth System Example
# Demonstrates two-body gravitational simulation

# Load required files
source("constants.R")
source("celestial_systems/two_body_system.R")

# Create images directory if it doesn't exist
if (!dir.exists("images")) {
  dir.create("images")
  cat("Created 'images' directory\n")
}

cat("Running Sun-Earth orbital simulation...\n")
cat("Period: 1 year\n")
cat("Integration steps: 1000\n\n")

# Open PNG device to save plot
png("images/sun_earth.png", width = 800, height = 600, res = 100)

cpt_2d(P = YEAR,               # Simulate for 1 full year
       N = 1000,               # Number of integration steps
       mi = M_SUN,             # Sun mass
       mj = M_EARTH,           # Earth mass
       rix = 0, riy = 0,       # Sun at origin (0, 0)
       rjx = AU, rjy = 0,      # Earth starts at 1 AU from Sun
       v0ix = 0, v0iy = 0,     # Sun initially at rest
       v0jx = 0, v0jy = V_EARTH_ORBITAL) # Earth's orbital velocity

# Close the PNG device
dev.off()

cat("Simulation complete!\n")
cat("Plot saved to: images/sun_earth.png\n")
cat("The plot shows Earth's orbit (blue) around the Sun (black dot at origin)\n")
