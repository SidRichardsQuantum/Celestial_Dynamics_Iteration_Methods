# install.packages("reticulate")
library(reticulate)
source_python("examples/three_body_examples/figure_8_solution.py")
source("constants.R")

# Three Earths system (three-body problem)
# Runge-Kutta method
source("celestial_systems/three_body/three_body_runge_kutta.R")

# Store T and N values for use in plot title
T = 60 * YEAR # 60 years
N = 10000     # High precision needed

# Choose the real-world distance between outer bodies
distance_real = AU   # 1 AU

# Real-world period in seconds
T_real = 2 * pi * sqrt( (distance_real^3) / (abs(G) * M_EARTH) )

# Scaling factors
a = 0.97000436
position_scale = distance_real / (2 * a)
velocity_scale = position_scale / (T_real / (2 * pi))

# Call the Python function
ic = get_initial_conditions()
pos1 = as.numeric(ic[[1]]) * position_scale
pos2 = as.numeric(ic[[2]]) * position_scale
pos3 = as.numeric(ic[[3]]) * position_scale
vel1 = as.numeric(ic[[4]]) * velocity_scale
vel2 = as.numeric(ic[[5]]) * velocity_scale
vel3 = as.numeric(ic[[6]]) * velocity_scale

# Run simulation using values from Python
result = runge_kutta_three_body(
  T = T,
  N = N,
  m_a = M_EARTH,
  m_b = M_EARTH,
  m_c = M_EARTH,
  r_ax0 = pos1[1], r_ay0 = pos1[2],
  r_bx0 = pos2[1], r_by0 = pos2[2],
  r_cx0 = pos3[1], r_cy0 = pos3[2],
  v_ax0 = vel1[1], v_ay0 = vel1[2],
  v_bx0 = vel2[1], v_by0 = vel2[2],
  v_cx0 = vel3[1], v_cy0 = vel3[2]
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
