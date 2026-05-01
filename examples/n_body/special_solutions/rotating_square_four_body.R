if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("R/constants.R")
cd_source("R/systems/n_body/four_body_initial_conditions.R")
cd_source("R/systems/n_body/n_body_runge_kutta.R")
cd_source("R/systems/n_body/plot_n_body.R")

ic = rotating_square_four_body_initial_conditions(
  half_side_real = 0.25 * AU,
  body_mass = M_EARTH
)

N = 20000
result = runge_kutta_n_body(
  T = ic$period,
  N = N,
  masses = ic$masses,
  positions = ic$positions,
  velocities = ic$velocities,
  body_names = ic$body_names
)

plot_n_body_result(
  result = result,
  filepath = file.path("images", "n_body", "special_solutions", "rotating_square_four_body.png"),
  title = sprintf("Four-Body Rotating Square\nT = %.1f years, N = %d steps",
                  ic$period / YEAR, N),
  colors = c("#d95f02", "#1b9e77", "#7570b3", "#0f766e")
)
