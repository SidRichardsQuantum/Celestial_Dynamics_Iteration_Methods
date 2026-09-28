\name{run_lyapunov_analysis}
\alias{run_lyapunov_analysis}
\alias{studio_plot_lyapunov}
\title{Nearby-Trajectory Finite-Time Lyapunov Analysis}
\description{Measure finite-time growth of a nearby trajectory with periodic renormalisation. This directional estimate targets the maximum Lyapunov exponent; it is not a true asymptotic exponent or a chaos classifier.}
\usage{
run_lyapunov_analysis(experiment, epsilon = 1e-7, direction = NULL,
  component = NULL, renormalisation_interval = NULL, total_time = NULL,
  position_scale = 1, velocity_scale = 1)
studio_plot_lyapunov(analysis,
  view = c("separation", "log", "trajectories"), axes = c(1, 2))
}
\arguments{
\item{experiment}{A \code{simulation_request}, or a problem list returned by \code{simulation_dynamics}: model, state, integrator, duration and timestep.}
\item{epsilon}{Positive finite real perturbation magnitude in the scaled phase-space norm.}
\item{direction}{Optional finite nonzero vector in scaled coordinates, normalized internally. Order is column-major positions followed by column-major velocities; names are ignored.}
\item{component}{Alternative to direction: \code{"position[body,coordinate]"} or \code{"velocity[body,coordinate]"}, using one-based indices. Defaults to the first position component. Sitnikov coordinate 1 is z.}
\item{renormalisation_interval}{Positive integer multiple of the timestep, no longer than total time. Defaults to ten timesteps, or the whole run if shorter.}
\item{total_time}{Positive integer multiple of the timestep; defaults to experiment duration. A final partial renormalisation interval is included.}
\item{position_scale, velocity_scale}{Positive finite real characteristic scales. Distance is the Euclidean norm of position differences divided by position scale and velocity differences divided by velocity scale. Defaults of 1 use model coordinates directly; choose physical scales explicitly for dimensional systems.}
\item{analysis}{A \code{lyapunov_analysis} result.}
\item{view}{Measured separation, measured and accumulated log separation, or base/companion trajectory comparison.}
\item{axes}{Two distinct coordinate indices for trajectory projection. One-dimensional states plot position versus time instead.}
}
\details{
Base and companion use the same fixed-step integrator and model. At each
interval endpoint, accumulate \eqn{\log(d_{end})-\log(d_{start})}, then reset
the companion to epsilon along the evolved difference direction. The denominator
is the actual representable starting distance, including rounding at resets.
The final estimate is summed log growth divided by total elapsed time.
There is no final reset and no discarded transient. Absolute solver stage time
is preserved across intervals.

The state includes all integrated positions and velocities, but no prescribed
primary trajectories. Scales remain fixed. Norms use max-component scaling;
logarithms are subtracted without forming growth ratios. Cumulative growth is
never exponentiated. Unrepresentable perturbations (over 1 percent relative
vector error), collapsed separation, nonfinite states and collisions are errors.
No artificial distance floor is used. Renormalisation does not prevent failure
or nonlinear saturation within an excessively long interval.

Finite-time values depend on epsilon, direction, scales, timestep, interval and
duration. An initial direction need not align with the dominant expanding
direction. This method neither maximizes over directions nor computes a
finite-time flow-map singular value. Positive estimates alone do not establish
chaos. Check numerical convergence and parameter sensitivity. No tangent
equations, full spectrum, invariant-surface projection or adaptive error control
are implemented. Generic perturbations may change conserved quantities.

Analysis is limited to 100000 steps, 256 integrated bodies, 2 million position
values and 10 million pair-steps per trajectory. Both trajectories, velocities
and restart states are retained. Plots show pre-reset distances and separately
drawn companion segments, not an uninterrupted perturbed orbit. Small
perturbations can make the two curves visually indistinguishable.
}
\value{
\code{run_lyapunov_analysis} returns a serializable \code{lyapunov_analysis} list
with measured \code{initial_separation}, final \code{finite_time_exponent}, and
\code{series} containing time, pre-reset separation, natural log separation,
accumulated \code{log_separation_growth}, \code{cumulative_log_separation}
(log initial separation plus accumulated growth), and running finite-time
exponent (NA at time zero). Exponents have inverse model time units.

\code{renormalisation_history} records interval times/steps, starting and ending
distances, interval and cumulative log growth, reset flags and actual reset
distances. The terminal reset distance is NA. \code{base} and \code{perturbed}
contain time-by-body-by-coordinate arrays and initial states; their endpoints
precede resets. \code{restart_states} contains post-reset companion states,
with NULL at the terminal interval. Original \code{experiment}, resolved
\code{problem}, epsilon, normalized named direction and algorithm \code{metadata}
are also retained. Metadata includes scales, units, frame, timing and limitations.
\code{studio_plot_lyapunov} draws on the current device and returns its input invisibly.
}
\references{Dubeibe and Bermudez-Almanza (2014), Optimal conditions for the numerical calculation of the largest Lyapunov exponent for systems of ordinary differential equations. \url{https://arxiv.org/abs/1312.5970}.}
\examples{
experiment <- studio_preset("earth_moon_trojan")
analysis <- run_lyapunov_analysis(experiment, epsilon = 1e-7,
  component = "position[1,1]", renormalisation_interval = 0.1,
  total_time = 1, position_scale = 1, velocity_scale = 1)
analysis$finite_time_exponent
head(analysis$series)
studio_plot_lyapunov(analysis, "log")
}
