# Earth-Mars-Sun system
# Runge-Kutta method
source("celestial_systems/three_body/three_body_runge_kutta.R")
source("celestial_systems/three_body/plot_three_body.R")

# Store T and N values for use in plot title
T = YEAR # 1 year
N = 1000

masses = c(M_SUN, M_EARTH, M_MARS)
positions = rbind(
  c(0, 0),
  c(AU, 0),
  c(1.52 * AU, 0)
)
velocities = rbind(
  c(0, 0),
  c(0, V_EARTH_ORBITAL),
  c(0, 24130.772)
)

center_of_mass = colSums(positions * masses) / sum(masses)
center_of_mass_velocity = colSums(velocities * masses) / sum(masses)
positions = sweep(positions, 2, center_of_mass)
velocities = sweep(velocities, 2, center_of_mass_velocity)

result = runge_kutta_three_body(
  T = T,
  N = N,
  m_a = M_SUN,
  m_b = M_EARTH,
  m_c = M_MARS,
  r_ax0 = positions[1, 1], r_ay0 = positions[1, 2],
  r_bx0 = positions[2, 1], r_by0 = positions[2, 2],
  r_cx0 = positions[3, 1], r_cy0 = positions[3, 2],
  v_ax0 = velocities[1, 1], v_ay0 = velocities[1, 2],
  v_bx0 = velocities[2, 1], v_by0 = velocities[2, 2],
  v_cx0 = velocities[3, 1], v_cy0 = velocities[3, 2]
)

filename = "earth_mars_sun.png"
filepath = file.path("images", filename)

plot_three_body_result(
  result = result,
  filepath = filepath,
  title = sprintf("Earth-Mars-Sun System (Runge-Kutta Method)\nT = %.1f years, N = %d steps",
                  T / YEAR, N),
  labels = c("Sun", "Earth", "Mars")
)
