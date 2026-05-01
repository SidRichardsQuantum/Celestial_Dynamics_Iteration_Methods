if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/systems/three_body/circular_restricted_three_body.R")

mu = M_MOON / (M_EARTH + M_MOON)
points = cr3bp_lagrange_points(mu)

state0 = c(points$L1[1] - 0.01, 0, 0, 0, -0.08, 0)
T = 8 * pi
N = 20000

result = cr3bp_runge_kutta(T = T, N = N, mu = mu, state0 = state0)

plot_cr3bp_result(
  result = result,
  filepath = file.path("images", "three_body", "restricted", "lyapunov_near_l1.png"),
  title = "Planar Lyapunov-Like Orbit Near Earth-Moon L1"
)
