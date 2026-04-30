source("constants.R")
source("celestial_systems/n_body/n_body_runge_kutta.R")
source("celestial_systems/n_body/plot_n_body.R")

T = 12 * YEAR
N = 6000

masses = c(M_SUN, M_EARTH, M_MARS, M_JUPITER)
body_names = c("Sun", "Earth", "Mars", "Jupiter")

orbital_velocity = function(radius) {
  sqrt(G * M_SUN / radius)
}

positions = rbind(
  c(0, 0),
  c(AU, 0),
  c(1.524 * AU, 0),
  c(5.203 * AU, 0)
)
velocities = rbind(
  c(0, 0),
  c(0, V_EARTH_ORBITAL),
  c(0, orbital_velocity(1.524 * AU)),
  c(0, orbital_velocity(5.203 * AU))
)

result = runge_kutta_n_body(
  T = T,
  N = N,
  masses = masses,
  positions = positions,
  velocities = velocities,
  body_names = body_names
)

plot_n_body_result(
  result = result,
  filepath = file.path("images", "n_body", "sun_earth_mars_jupiter.png"),
  title = sprintf("Sun-Earth-Mars-Jupiter N-Body RK4\nT = %.1f years, N = %d steps",
                  T / YEAR, N),
  colors = c("red", "blue", "darkorange", "brown")
)
