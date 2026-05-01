if (!exists("cd_source", mode = "function")) source("R/load.R")
# Earth-Moon system (circular orbit)
# Midpoint method
cd_source("R/systems/two_body/two_body_midpoint.R")
cd_source("R/systems/two_body/plot_two_body.R")

# Store T and N values for use in plot title
T = 10 * LUNAR_MONTH # 10 lunar months
N = 1000

result = midpoint_two_body(
  T = T,
  N = N,
  m_a = M_EARTH,
  m_b = M_MOON,
  r_ax0 = 0, r_ay0 = 0,                  # Earth at origin
  r_bx0 = 0.00257 * AU, r_by0 = 0,       # Moon at 0.00257 AU
  v_ax0 = 0, v_ay0 = 0,                  # Earth at rest
  v_bx0 = 0, v_by0 = abs(V_MOON_ORBITAL) # Moon orbital velocity
)

plot_two_body_result(
  result = result,
  filepath = file.path("images", "two_body", "earth_moon", "earth_moon_midpoint.png"),
  title = sprintf("Earth-Moon System (Midpoint Method)\nT = %.1f lunar months, N = %d steps",
                  T / LUNAR_MONTH, N),
  labels = c("Earth", "Moon"),
  colors = c("blue", "gray")
)
