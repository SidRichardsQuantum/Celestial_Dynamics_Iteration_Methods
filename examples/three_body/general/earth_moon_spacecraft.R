if (!exists("cd_source", mode = "function")) source("R/load.R")
# Earth-Moon-Spacecraft system (three-body problem)
# Runge-Kutta method
cd_source("R/systems/three_body/three_body_runge_kutta.R")
cd_source("R/systems/three_body/plot_three_body.R")

# Store T and N values for use in plot title
T = 5 * LUNAR_MONTH # 5 lunar months
N = 10000           # High number of steps to show "more-accurate" chaos

M_SPACECRAFT = 1000
masses = c(M_EARTH, M_MOON, M_SPACECRAFT)
positions = rbind(
  c(0, 0),
  c(0.00257 * AU, 0),
  c(0.00200 * AU, 0)
)
velocities = rbind(
  c(0, 0),
  c(0, V_MOON_ORBITAL),
  c(0, 1500)
)

center_of_mass = colSums(positions * masses) / sum(masses)
center_of_mass_velocity = colSums(velocities * masses) / sum(masses)
positions = sweep(positions, 2, center_of_mass)
velocities = sweep(velocities, 2, center_of_mass_velocity)

result = runge_kutta_three_body(
  T = T,
  N = N,
  m_a = M_EARTH,
  m_b = M_MOON,
  m_c = M_SPACECRAFT,
  r_ax0 = positions[1, 1], r_ay0 = positions[1, 2],
  r_bx0 = positions[2, 1], r_by0 = positions[2, 2],
  r_cx0 = positions[3, 1], r_cy0 = positions[3, 2],
  v_ax0 = velocities[1, 1], v_ay0 = velocities[1, 2],
  v_bx0 = velocities[2, 1], v_by0 = velocities[2, 2],
  v_cx0 = velocities[3, 1], v_cy0 = velocities[3, 2]
)

filename = "earth_moon_spacecraft.png"
filepath = file.path("images", "three_body", "general", filename)

plot_three_body_result(
  result = result,
  filepath = filepath,
  title = sprintf("Earth-Moon-Spacecraft System (Runge-Kutta Method)\nT = %.1f years, N = %d steps",
                  T / YEAR, N),
  labels = c("Earth", "Moon", "Spacecraft")
)
