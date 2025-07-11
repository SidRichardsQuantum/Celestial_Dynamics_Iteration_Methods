# Earth-Sun system (circular orbit)
# Heun's method
source("celestial_systems/two_body/two_body_heuns.R")

# Store T and N values for use in plot title
T = 25 * YEAR # 25 years
N = 1000

result = heuns_two_body(
  T = T,
  N = N,
  m_a = M_SUN,                            # Sun
  m_b = M_EARTH,                          # Earth
  r_ax0 = 0, r_ay0 = 0,                   # Sun at origin
  r_bx0 = AU, r_by0 = 0,                  # Earth at 1 AU
  v_ax0 = 0, v_ay0 = 0,                   # Sun at rest
  v_bx0 = 0, v_by0 = abs(V_EARTH_ORBITAL) # Earth orbital velocity
)

# Create images directory if it doesn't exist
if (!dir.exists("images")) {
  dir.create("images")
}

# Create filename and save plot
filename = "sun_earth_heuns.png"
filepath = file.path("images", filename)

# Open PNG device
png(filepath, width = 800, height = 600, res = 100)

# Convert to AU for plotting
x_a_au = result$x_a / AU
y_a_au = result$y_a / AU
x_b_au = result$x_b / AU
y_b_au = result$y_b / AU

# Create single 2D plot showing both orbits
plot(x_b_au, y_b_au, type="l", col="blue", lwd=2,
     xlab="x (AU)", ylab="y (AU)",
     main=sprintf("Sun-Earth System (Heun's Method)\nT = %.2f years, N = %d steps", 
                  T / (365.25 * 24 * 3600), N))
lines(x_a_au, y_a_au, col="red", lwd=2)

# Add final positions (end of trajectories)
points(tail(x_a_au, 1), tail(y_a_au, 1), 
       pch=19, col="red", cex=1.5)
points(tail(x_b_au, 1), tail(y_b_au, 1), 
       pch=19, col="blue", cex=1.5)

# Add legend
legend("topright", legend=c("Sun", "Earth"),
       lty=c("solid", "solid"), col=c("red", "blue"), lwd=c(2, 2))

# Add grid for better readability
grid(col = "gray", lty = "dotted")

# Close the PNG device
dev.off()

cat(sprintf("Plot saved to: %s\n", filepath))
