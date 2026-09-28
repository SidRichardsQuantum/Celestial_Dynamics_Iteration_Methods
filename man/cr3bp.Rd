\name{cr3bp}
\alias{cr3bp}
\alias{cr3bp_mass_parameters}
\alias{cr3bp_potential}
\alias{cr3bp_potential_gradient}
\alias{cr3bp_jacobi}
\alias{cr3bp_lagrange_points}
\alias{cr3bp_initial_state}
\alias{cr3bp_derivative}
\alias{cr3bp_runge_kutta}
\alias{plot_cr3bp_result}
\title{Idealized Circular Restricted Three-Body Problem}
\description{Nondimensional rotating-frame CR3BP equations, equilibria, Jacobi invariant, initial conditions and trajectory plots using the shared dynamical model engine.}
\usage{
cr3bp_mass_parameters()
cr3bp_potential(position, mu)
cr3bp_potential_gradient(position, mu)
cr3bp_jacobi(state, mu)
cr3bp_lagrange_points(mu)
cr3bp_initial_state(mu, point = "L4", position_offset = c(0.001, 0, 0),
  velocity = c(0, 0, 0))
cr3bp_derivative(state, mu)
cr3bp_runge_kutta(T, N, mu, state0)
plot_cr3bp_result(result, filepath, title, show_lagrange_points = TRUE)
}
\arguments{
\item{mu}{Secondary mass divided by total primary mass, a finite scalar in (0, 0.5].}
\item{position}{Rotating-frame x/y/z vector or numeric matrix with three columns, one position per row.}
\item{state}{Rotating-frame x/y/z/vx/vy/vz vector. For Jacobi evaluation, also a matrix with six columns, one state per row.}
\item{point}{One of L1, L2, L3, L4, L5.}
\item{position_offset, velocity}{Three finite numbers specifying displacement from the equilibrium and rotating-frame velocity. Zero values give an equilibrium.}
\item{T, N}{Positive nondimensional duration and positive integer step count.}
\item{state0}{Initial six-component rotating-frame state.}
\item{result}{Raw result from \code{cr3bp_runge_kutta}.}
\item{filepath, title}{Output PNG path and plot title.}
\item{show_lagrange_points}{Whether to mark L1--L5 in the rotating-frame panel.}
}
\details{
The primaries are stationary at (-mu,0,0) and (1-mu,0,0). Length is measured
in primary separations, mass in total primary masses, and time in inverse
orbital angular speeds. A primary revolution takes \eqn{2\pi} time units.

Let \eqn{r_1^2=(x+\mu)^2+y^2+z^2} and
\eqn{r_2^2=(x-1+\mu)^2+y^2+z^2}. The effective potential is
\eqn{\Omega=(x^2+y^2)/2+(1-\mu)/r_1+\mu/r_2}.
The acceleration is \eqn{(\Omega_x+2v_y,\Omega_y-2v_x,\Omega_z)}.
Planar motion has z=vz=0. The Jacobi constant is
\eqn{C=2\Omega-v_x^2-v_y^2-v_z^2}; exact motion conserves C, while numerical
RK4 trajectories have timestep-dependent drift.

Collinear equilibria are solved in separate nonsingular intervals; triangular
points use their closed forms. Extremely small mu that cannot be resolved in
double precision is rejected by the equilibrium solver. Displaced initial
conditions are illustrative trajectories, not computed periodic or halo orbits.

The mass-parameter presets use rounded repository mass constants. This is the
idealized circular restricted model, not an ephemeris. Public helpers reject
primary singularities. The Studio catalogue ID remains
\code{restricted_three_body}; its diagnostics include Jacobi and signed absolute
and relative drift. The model ID is \code{cr3bp_rotating}; the existing RK4
wrapper delegates to \code{integrate_dynamics}. Velocity Verlet is incompatible
with its velocity-dependent Coriolis acceleration.
}
\value{
Mass presets return a named vector (earth_moon, sun_earth). Potential and Jacobi
return one value per input row; gradient returns a three-vector or matching
matrix. Equilibria return a named L1--L5 list of x/y vectors; initial state returns
a six-vector in x/y/z/vx/vy/vz order; derivative returns a six-vector. RK4 returns a list with
\code{t}, six-column \code{states}, and \code{mu}, preserving the legacy layout.
Plotting writes rotating and inertial trajectory panels with visible primaries.
}
\references{
Richard Fitzpatrick, Celestial Mechanics, Co-rotating frame and Lagrange points:
\url{https://farside.ph.utexas.edu/teaching/celestial/Celestial/node83.html}
and \url{https://farside.ph.utexas.edu/teaching/celestial/Celestial/node84.html}.
The potential sign convention here is Omega = -U in that reference.
}
\examples{
mu <- unname(cr3bp_mass_parameters()["sun_earth"])
state <- cr3bp_initial_state(mu, "L4")
result <- cr3bp_runge_kutta(1, 100, mu, state)
C <- cr3bp_jacobi(result$states, mu)
max(abs(C - C[1]))
cr3bp_lagrange_points(mu)
}
