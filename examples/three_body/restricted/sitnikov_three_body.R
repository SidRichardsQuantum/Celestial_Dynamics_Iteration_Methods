if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/systems/three_body/sitnikov_problem.R")

T = 8 * YEAR
N = 20000

result = sitnikov_runge_kutta(
  T = T,
  N = N,
  primary_mass = M_EARTH,
  primary_radius = 0.05 * AU,
  z0 = 0.04 * AU,
  vz0 = 0
)

plot_sitnikov_result(
  result = result,
  filepath = file.path("images", "three_body", "restricted", "sitnikov_three_body.png"),
  title = sprintf("Sitnikov Restricted Three-Body Problem\nT = %.1f years, N = %d steps",
                  T / YEAR, N)
)
