source("constants.R")

source("celestial_systems/three_body/three_body_runge_kutta.R")
source("celestial_systems/three_body/plot_three_body.R")

binary_separation = 0.2 * AU
third_distance = 3 * AU

positions = rbind(
  c(-binary_separation / 2, 0),
  c(binary_separation / 2, 0),
  c(third_distance, 0)
)

binary_omega = sqrt(G * (2 * M_SUN) / binary_separation^3)
third_speed = sqrt(G * (2 * M_SUN + M_JUPITER) / third_distance)
velocities = rbind(
  c(0, -binary_omega * binary_separation / 2),
  c(0, binary_omega * binary_separation / 2),
  c(0, third_speed)
)

masses = c(M_SUN, M_SUN, M_JUPITER)
center_of_mass = colSums(positions * masses) / sum(masses)
center_of_mass_velocity = colSums(velocities * masses) / sum(masses)
positions = sweep(positions, 2, center_of_mass)
velocities = sweep(velocities, 2, center_of_mass_velocity)

T = 5 * YEAR
N = 20000

result = runge_kutta_three_body(
  T = T,
  N = N,
  m_a = M_SUN,
  m_b = M_SUN,
  m_c = M_JUPITER,
  r_ax0 = positions[1, 1], r_ay0 = positions[1, 2],
  r_bx0 = positions[2, 1], r_by0 = positions[2, 2],
  r_cx0 = positions[3, 1], r_cy0 = positions[3, 2],
  v_ax0 = velocities[1, 1], v_ay0 = velocities[1, 2],
  v_bx0 = velocities[2, 1], v_by0 = velocities[2, 2],
  v_cx0 = velocities[3, 1], v_cy0 = velocities[3, 2]
)

plot_three_body_result(
  result = result,
  filepath = file.path("images", "binary_distant_third.png"),
  title = sprintf("Binary Stars with a Distant Third Body\nT = %.1f years, N = %d steps",
                  T / YEAR, N),
  labels = c("Star 1", "Star 2", "Distant body")
)
