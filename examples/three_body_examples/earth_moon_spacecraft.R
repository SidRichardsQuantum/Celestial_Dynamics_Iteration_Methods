# Earth-Moon-Spacecraft system (three-body problem)
# Runge-Kutta method
source("celestial_systems/three_body/three_body_runge_kutta.R")

# Store T and N values for use in plot title
T = 5 * LUNAR_MONTH # 5 lunar months
N = 10000           # High number of steps to show "more-accurate" chaos

result = runge_kutta_three_body(
  T = T,
  N = N,
  m_a = M_EARTH,
  m_b = M_MOON,
  m_c = 1000,                             # 1000 kg spacecraft
  r_ax0 = 0, r_ay0 = 0,                   # Earth at origin
  r_bx0 = 0.00257 * AU, r_by0 = 0,        # Moon at usual distance
  r_cx0 = 0.00200 * AU, r_cy0 = 0,        # Spacecraft between Earth and Moon
  v_ax0 = 0, v_ay0 = 0,
  v_bx0 = 0, v_by0 = abs(V_MOON_ORBITAL), # Moon's usual initial velocity
  v_cx0 = 0, v_cy0 = 1500.                # Spacecraft with intermediate velocity
)

# Create images directory if it doesn't exist
if (!dir.exists("images")) {
  dir.create("images")
}

# Create filename and save plot
filename = "earth_moon_spacecraft.png"
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
     main=sprintf("Earth-Moon-Spacecraft System (Runge-Kutta Method)\nT = %.1f years, N = %d steps",
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
legend("topright", legend=c("Earth", "Moon", "Spacecraft"),
       lty=c("solid", "solid", "solid"), col=c("black", "blue", "red"), lwd=c(2, 2, 2))

# Add grid for better readability
grid(col = "lightgray", lty = "dotted")

# Close the PNG device
dev.off()

cat(sprintf("Plot saved to: %s\n", filepath))
