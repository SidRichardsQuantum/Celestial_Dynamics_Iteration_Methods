source("tests/helpers_three_body.R")
source("R/systems/three_body/circular_restricted_three_body.R")
source("R/systems/three_body/sitnikov_problem.R")

mu = M_MOON / (M_EARTH + M_MOON)
points = cr3bp_lagrange_points(mu)
l4_state = c(points$L4[1], points$L4[2], 0, 0, 0, 0)
l4_derivative = cr3bp_derivative(l4_state, mu)
assert_near(l4_derivative[4], 0, 1e-12, "CR3BP L4 x acceleration")
assert_near(l4_derivative[5], 0, 1e-12, "CR3BP L4 y acceleration")

sitnikov = sitnikov_runge_kutta(T = YEAR, N = 1000,
                                primary_mass = M_EARTH,
                                primary_radius = 0.05 * AU,
                                z0 = 0.04 * AU,
                                vz0 = 0)
if (any(!is.finite(sitnikov$z))) {
  stop("Sitnikov z trajectory contains non-finite values.")
}

cat("Restricted three-body validation passed.\n")
