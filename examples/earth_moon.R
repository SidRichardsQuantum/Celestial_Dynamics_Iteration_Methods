# Earth-Moon System Simulation
# Simple example of two-body gravitational interaction

# Load required files
source("constants.R")
source("celestial_systems/two_body_system.R")

# Create images directory if it doesn't exist
if (!dir.exists("images")) {
  dir.create("images")
  cat("Created 'images' directory\n")
}

cat("Simulating Earth-Moon system...\n")
cat("Period: 27.3 days\n")
cat("Moon distance: 384,400 km\n")
cat("Moon orbital velocity: 1,022 m/s\n\n")

# Open PNG device to save plot
png("images/earth_moon.png", width = 800, height = 600, res = 100)

cpt_2d(P = LUNAR_MONTH,        # 27.3 days
       N = 2000,               # Integration steps
       mi = M_EARTH,           # Earth mass
       mj = M_MOON,            # Moon mass
       rix = 0, riy = 0,       # Earth at origin
       rjx = 3.844e8, rjy = 0, # Moon at 384,400 km
       v0ix = 0, v0iy = 0,     # Earth stationary
       v0jx = 0, v0jy = V_MOON_ORBITAL) # Moon orbital velocity

# Close the PNG device
dev.off()

cat("Simulation complete!\n")
cat("Plot saved to: images/earth_moon.png\n")
cat("The plot shows the Earth (black) and Moon (blue) orbits.\n")
cat("Note: Earth wobbles slightly due to Moon's gravitational pull.\n")
