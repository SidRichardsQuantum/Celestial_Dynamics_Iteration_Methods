# Three Earths system (three-body problem)
# Runge-Kutta method
source("celestial_systems/three_body/three_body_runge_kutta.R")

# Store T and N values for use in plot title
T = 5 * YEAR # 5 years
N = 1000     # High precision needed

result = runge_kutta_three_body(
  T = T,
  N = N,
  m_a = M_EARTH,
  m_b = M_EARTH,
  m_c = M_EARTH,
  r_ax0 = 0 * AU, r_ay0 = 0.1 * AU,
  r_bx0 = 0.1 * AU, r_by0 = 0 * AU,
  r_cx0 = -0.1 * AU, r_cy0 = 0 * AU,
  v_ax0 = 0, v_ay0 = -100,
  v_bx0 = -75, v_by0 = 50,
  v_cx0 = 150, v_cy0 = 50
)

# Create images directory if it doesn't exist
if (!dir.exists("images")) {
  dir.create("images")
}

# Create filename and save plot
filename = "three_earths.png"
filepath = file.path("images", filename)

# Open PNG device
png(filepath, width = 800, height = 600, res = 100)

# Convert to AU for plotting
x_a_au = result$x_a / AU
y_a_au = result$y_a / AU
x_b_au = result$x_b / AU
y_b_au = result$y_b / AU
x_c_au = result$x_c / AU
y_c_au = result$y_c / AU

# Determine plot limits to show all trajectories
all_x = c(x_a_au, x_b_au, x_c_au)
all_y = c(y_a_au, y_b_au, y_c_au)
xlim_range = range(all_x)
ylim_range = range(all_y)

# Create single 2D plot showing all three orbits with T and N in title
plot(x_a_au, y_a_au, type="l", col="black", lwd=2,
     xlim=xlim_range, ylim=ylim_range,
     xlab="x (AU)", ylab="y (AU)",
     main=sprintf("Three Earths System (Runge-Kutta Method)\nT = %.1f years, N = %d steps",
                  T / YEAR, N))
lines(x_b_au, y_b_au, col="blue", lwd=2)
lines(x_c_au, y_c_au, col="red", lwd=2)

# Add final positions (end of trajectories)
points(tail(x_a_au, 1), tail(y_a_au, 1),
       pch=19, col="black", cex=1.5)
points(tail(x_b_au, 1), tail(y_b_au, 1),
       pch=19, col="blue", cex=1.5)
points(tail(x_c_au, 1), tail(y_c_au, 1),
       pch=19, col="red", cex=1.5)

# Add legend
legend("topright", legend=c("Earth 1", "Earth 2", "Earth 3"),
       lty=c("solid", "solid", "solid"), col=c("black", "blue", "red"), lwd=c(2, 2, 2))

# Add grid for better readability
grid(col = "lightgray", lty = "dotted")

# Close the PNG device
dev.off()

cat(sprintf("Plot saved to: %s\n", filepath))
