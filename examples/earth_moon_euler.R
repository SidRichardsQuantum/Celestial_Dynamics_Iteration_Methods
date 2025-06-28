# Earth-Moon system (circular orbit)
source("celestial_systems/2d_euler.R")

result = euler_2d(
  T = LUNAR_MONTH,                       # Lunar month
  N = 10000,                             # 10,000 steps
  m_a = M_EARTH,                         # Earth
  m_b = M_MOON,                          # Moon  
  r_ax0 = 0, r_ay0 = 0,                  # Earth at origin
  r_bx0 = 0.00257 * AU, r_by0 = 0,       # Moon at 0.00257 AU
  v_ax0 = 0, v_ay0 = 0,                  # Earth at rest
  v_bx0 = 0, v_by0 = abs(V_MOON_ORBITAL) # Moon orbital velocity
)
