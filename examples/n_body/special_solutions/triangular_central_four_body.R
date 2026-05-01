source("R/constants.R")
source("R/systems/n_body/four_body_initial_conditions.R")
source("R/systems/n_body/n_body_runge_kutta.R")
source("R/systems/n_body/plot_n_body.R")

ic = triangular_central_four_body_initial_conditions(
  radius_real = 0.5 * AU,
  outer_mass = M_EARTH,
  central_mass = M_EARTH
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
  filepath = file.path("images", "n_body", "special_solutions", "triangular_central_four_body.png"),
  title = sprintf("Four-Body Triangular Central Configuration\nT = %.1f years, N = %d steps",
                  ic$period / YEAR, N),
  colors = c("black", "#d95f02", "#1b9e77", "#7570b3")
)
