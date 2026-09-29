\name{shoot_periodic_orbit}
\alias{shoot_periodic_orbit}
\alias{periodic_orbit_components}
\alias{cd_load_periodic_orbits}
\title{Experimental Single-Shooting Periodic-Orbit Correction}
\description{Locally correct a candidate initial state and period using the full return residual. This experimental analysis is independent of the simulation runner and does not establish discovery of an orbit.}
\usage{
cd_load_periodic_orbits()
periodic_orbit_components(state)
shoot_periodic_orbit(model, state, period, free_components = character(),
  vary_period = FALSE, period_bounds = period * c(0.5, 1.5),
  steps = 1000L, position_scale = 1, velocity_scale = 1,
  tolerance = 1e-7, max_iterations = 20L, jacobian_step = 1e-5,
  damping = 1e-8, trust_radius = 0.1, max_backtracks = 12L,
  max_evaluations = 1000L)
}
\arguments{
\item{model}{A validated \code{dynamical_model} descriptor.}
\item{state}{Initial positions and velocities matrices, bodies by coordinates.}
\item{period}{Positive candidate period in model time units.}
\item{free_components}{Unique names from \code{periodic_orbit_components(state)}, such as \code{"velocity[1,2]"}. All other initial components remain exactly fixed. Empty permits period-only correction.}
\item{vary_period}{Whether to correct the period. At least one state component or the period must be free.}
\item{period_bounds}{Two increasing positive finite bounds containing the candidate period. Default: half to one and a half times the supplied period.}
\item{steps}{Fixed RK4 step count per shooting integration, 4 to 100000. Timestep is period divided by steps, including for perturbed periods.}
\item{position_scale, velocity_scale}{Positive characteristic scales for residuals and state corrections. Defaults of one use model coordinates directly. Set physical scales for dimensional models.}
\item{tolerance}{Positive absolute tolerance on the full scaled Euclidean return residual.}
\item{max_iterations}{Maximum correction iterations, 0 to 100; zero evaluates the seed only.}
\item{jacobian_step}{Relative finite-difference increment in scaled offset coordinates; default \code{1e-5}.}
\item{damping}{Positive Levenberg regularization parameter in squared singular-value units.}
\item{trust_radius}{Maximum Euclidean correction length in scaled state and relative-period coordinates.}
\item{max_backtracks}{Maximum step halvings per correction, 0 to 30.}
\item{max_evaluations}{Maximum integrations, including Jacobian probes, rejected trials and refinement, 2 to 10000.}
}
\details{
The objective includes every position and velocity component of
\eqn{F(x_0,T)=x(T;x_0)-x_0}, even when only some initial components are free.
Position differences are divided by position scale and velocity differences by
velocity scale. The period variable is a relative offset from the supplied period.
All integrations start at time zero. Central finite differences use one-sided
fallback when one probe fails or crosses a period bound. Perturbations with
more than one percent representation error fail explicitly.

Base R's LAPACK-backed \code{svd} solves a regularized Gauss-Newton correction:
singular-direction weights are \eqn{d/(d^2+\lambda)}. Singular values at most
\eqn{10^{-10}} times the largest are discarded. The correction is limited by
the trust radius, then halved until the residual strictly decreases. A step
that cannot decrease the residual fails; a small step alone is not convergence.
Rank and condition estimates are diagnostic and depend on finite-difference noise.

After shooting meets tolerance, an independent integration with twice as many
steps checks the corrected state. \code{converged} is true only if both grids
meet tolerance. This refinement is not a rigorous error bound. Numerical
failures preserve the last accepted state, trajectory and residual; no failed
trial replaces them. Invalid arguments raise errors before iteration.

Autonomous phase freedom, translations, rotations and conserved quantities may
make the Jacobian singular. Hold appropriate components fixed; a unique solution
is not promised. There is no explicit phase condition, continuation, multiple
shooting, adaptive integration, collision regularization or stability analysis.
Long unstable trajectories can make single shooting ill-conditioned. Equilibria
and repeated traversals also close, so the algorithm cannot determine minimal
period or certify a nontrivial periodic orbit. Check multiple step counts,
scales and difference increments. Corrections can change conserved quantities.

The refinement grid is limited to two million position values, 256 bodies and
ten million pair-steps. Total work also depends on the number of free variables
and integration evaluation budget. Checkout users explicitly call
\code{cd_load_periodic_orbits()}; the core runner never invokes this workflow.
}
\value{
\code{periodic_orbit_components} returns labels in column-major position order,
then column-major velocity order. \code{shoot_periodic_orbit} returns a serializable
\code{periodic_orbit_search} list with \code{status}, \code{message},
\code{converged}, \code{numerical_converged} (shooting grid only),
\code{corrected_state}, \code{period}, full named native-unit \code{residual},
scaled \code{residual_norm}, and \code{raw_residual_norm}. The raw norm mixes
position and velocity units and is not used for stopping.

\code{trajectory} is the last accepted shooting-grid integration, or NULL if
the initial integration failed. \code{history} contains the initial evaluation
and every correction trial, including rejected trials, with iteration, attempt,
acceptance, norms, period, scaled step length, damping, step fraction, Jacobian
rank/condition, cumulative evaluations and integration failure message.
\code{iterates} stores corresponding parameters, states and residual vectors.
Jacobian probes are counted in evaluations but are not correction-history rows.
\code{verification} contains the finer-grid norm, residual, steps and failure
message. Inputs, model, controls, iteration/evaluation counts and limitations
are retained for reproducibility.

Statuses are \code{converged}, \code{max_iterations}, \code{stalled},
\code{evaluation_limit}, \code{integration_failed}, \code{jacobian_failed},
\code{verification_failed}, or \code{discretization_limit}. Failed results must
not be treated as periodic solutions. No discovery claim is made.
}
\references{R base SVD documentation: \url{https://stat.ethz.ch/R-manual/R-devel/library/base/html/svd.html}.}
\examples{
model <- dynamical_model("newtonian_gravity", list(masses = c(1, 1), G = 1))
state <- list(positions = rbind(c(-0.5, 0), c(0.5, 0)),
  velocities = rbind(c(0, -sqrt(0.5)), c(0, sqrt(0.5))))
result <- shoot_periodic_orbit(model, state, 2 * pi / sqrt(2) * 1.0001,
  vary_period = TRUE, steps = 500)
result$status
result$period
result$history
}
