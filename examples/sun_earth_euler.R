# Earth-Sun system (circular orbit)
source("celestial_systems/2d_euler.R")

result = euler_2d(
  T = 365.25 * 24 * 3600,                  # 1 year
  N = 10000,                               # 10,000 steps
  m_a = M_SUN,                             # Sun
  m_b = M_EARTH,                           # Earth  
  r_ax0 = 0, r_ay0 = 0,                    # Sun at origin
  r_bx0 = AU, r_by0 = 0,                   # Earth at 1 AU
  v_ax0 = 0, v_ay0 = 0,                    # Sun at rest
  v_bx0 = 0, v_by0 = abs(V_EARTH_ORBITAL)  # Earth orbital velocity
)
