source("constants.R")

# Three Earths system (three-body problem)
# Runge-Kutta method
source("celestial_systems/three_body/three_body_runge_kutta.R")
source("celestial_systems/three_body/figure_8_initial_conditions.R")
source("celestial_systems/three_body/plot_three_body.R")

# Choose the real-world initial distance between the two outer bodies.
distance_real = AU
ic = figure_8_initial_conditions(distance_real = distance_real, body_mass = M_EARTH)

# Store T and N values for use in plot title
T = ic$period
N = 20000     # High precision needed for the figure-8 orbit

# Standard dimensionless initial conditions for the equal-mass figure-8 orbit.
pos1 = ic$positions[[1]]
pos2 = ic$positions[[2]]
pos3 = ic$positions[[3]]
vel1 = ic$velocities[[1]]
vel2 = ic$velocities[[2]]
vel3 = ic$velocities[[3]]

# Run simulation using the figure-8 initial conditions
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

filename = "three_earths.png"
filepath = file.path("images", "three_body", "special_solutions", filename)

plot_three_body_result(
  result = result,
  filepath = filepath,
  title = sprintf("Three Earths System (Runge-Kutta Method)\nT = %.1f years, N = %d steps",
                  T / YEAR, N),
  labels = c("Earth 1", "Earth 2", "Earth 3")
)
