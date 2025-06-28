# Earth-Sun system (circular orbit)
source("celestial_systems/two_body/two_body_euler.R")

result = euler_two_body(
  T = YEAR,                               # 1 year
  N = 10000,                              # 10,000 steps
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
filename = "sun_earth_euler.png"
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
     main="Sun-Earth System (Euler Method)")
lines(x_a_au, y_a_au, col="red", lwd=2)

# Add starting positions
points(result$initial_conditions$r_ax0 / AU, result$initial_conditions$r_ay0 / AU, 
       pch=19, col="red", cex=1.5)
points(result$initial_conditions$r_bx0 / AU, result$initial_conditions$r_by0 / AU, 
       pch=19, col="blue", cex=1.5)

# Add legend
legend("topright", legend=c("Sun", "Earth"),
       lty=c("solid", "solid"), col=c("red", "blue"), lwd=c(2, 2))

# Add grid for better readability
grid(col = "gray", lty = "dotted")

# Close the PNG device
dev.off()

cat(sprintf("Plot saved to: %s\n", filepath))
