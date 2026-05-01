source("R/constants.R")

source("R/systems/three_body/three_body_runge_kutta.R")
source("R/systems/three_body/choreography_initial_conditions.R")
source("R/systems/three_body/plot_three_body.R")

ic = choreography_initial_conditions(
  name = "butterfly_i",
  outer_separation_real = AU,
  body_mass = M_EARTH
)

pos1 = ic$positions[[1]]
pos2 = ic$positions[[2]]
pos3 = ic$positions[[3]]
vel1 = ic$velocities[[1]]
vel2 = ic$velocities[[2]]
vel3 = ic$velocities[[3]]

T = ic$period
N = 100000

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

plot_three_body_result(
  result = result,
  filepath = file.path("images", "three_body", "special_solutions", "butterfly_choreography.png"),
  title = sprintf("%s Three-Earth Choreography\nT = %.1f years, N = %d steps",
                  ic$label, T / YEAR, N),
  labels = c("Earth 1", "Earth 2", "Earth 3")
)
