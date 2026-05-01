if (!exists("cd_source", mode = "function")) source("R/load.R")
# Earth-Sun system (circular orbit)
# Midpoint method
cd_source("R/systems/two_body/two_body_midpoint.R")
cd_source("R/systems/two_body/plot_two_body.R")

# Store T and N values for use in plot title
T = 25 * YEAR # 25 years
N = 1000

result = midpoint_two_body(
  T = T,
  N = N,
  m_a = M_SUN,                            # Sun
  m_b = M_EARTH,                          # Earth
  r_ax0 = 0, r_ay0 = 0,                   # Sun at origin
  r_bx0 = AU, r_by0 = 0,                  # Earth at 1 AU
  v_ax0 = 0, v_ay0 = 0,                   # Sun at rest
  v_bx0 = 0, v_by0 = abs(V_EARTH_ORBITAL) # Earth orbital velocity
)

plot_two_body_result(
  result = result,
  filepath = file.path("images", "two_body", "sun_earth", "sun_earth_midpoint.png"),
  title = sprintf("Sun-Earth System (Midpoint Method)\nT = %.2f years, N = %d steps",
                  T / YEAR, N),
  labels = c("Sun", "Earth"),
  colors = c("red", "blue")
)
