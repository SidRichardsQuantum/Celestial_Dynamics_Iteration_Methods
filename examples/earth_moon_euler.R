# Earth-Moon system (circular orbit)
source("celestial_systems/2d_euler.R")

result = euler_2d(
  T = LUNAR_MONTH, # Lunar month
  N = 10000, # 10,000 steps
  m_a = M_EARTH, # Earth
  m_b = M_MOON, # Moon
  r_ax0 = 0, r_ay0 = 0, # Earth at origin
  r_bx0 = 0.00257 * AU, r_by0 = 0, # Moon at 0.00257 AU
  v_ax0 = 0, v_ay0 = 0, # Earth at rest
  v_bx0 = 0, v_by0 = abs(V_MOON_ORBITAL) # Moon orbital velocity
)

# Create images directory if it doesn't exist
if (!dir.exists("images")) {
  dir.create("images")
}

# Create filename and save plot
filename = "earth_moon_euler.png"
filepath = file.path("images", filename)

# Open PNG device
png(filepath, width = 800, height = 600, res = 100)

# Convert to AU for plotting
x_a_au = result$x_a / AU
y_a_au = result$y_a / AU
x_b_au = result$x_b / AU
y_b_au = result$y_b / AU

# Create single 2D plot showing both orbits
plot(x_b_au, y_b_au, type="l", col="gray", lwd=2,
     xlab="x (AU)", ylab="y (AU)",
     main="Earth-Moon System (Euler Method)")
lines(x_a_au, y_a_au, col="blue", lwd=2)

# Add starting positions
points(result$initial_conditions$r_ax0 / AU, result$initial_conditions$r_ay0 / AU, 
       pch=19, col="blue", cex=1.5)
points(result$initial_conditions$r_bx0 / AU, result$initial_conditions$r_by0 / AU, 
       pch=19, col="gray", cex=1.5)

# Add legend
legend("topright", legend=c("Earth", "Moon"),
       lty=c("solid", "solid"), col=c("blue", "gray"), lwd=c(2, 2))

# Add grid for better readability
grid(col = "lightgray", lty = "dotted")

# Close the PNG device
dev.off()

cat(sprintf("Plot saved to: %s\n", filepath))
