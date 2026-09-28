\name{dynamical_model}
\alias{dynamical_model}
\alias{dynamics_derivative}
\alias{integrate_dynamics}
\alias{simulation_dynamics}
\title{Data-Only Dynamical Models and Shared Fixed-Step Integration}
\description{Separate force parameters, initial state, integrator and time configuration for second-order mechanical systems.}
\usage{
dynamical_model(id, parameters = list())
dynamics_derivative(model, time, state)
integrate_dynamics(model, state, integrator, duration, timestep, start_time = 0)
simulation_dynamics(request, gravitational_constant = G)
}
\arguments{
\item{id}{Stable model identifier: \code{"newtonian_gravity"}, \code{"softened_gravity"}, \code{"cr3bp_rotating"}, or \code{"sitnikov_circular"}.}
\item{parameters}{Named numeric parameters. Gravity uses a positive \code{masses} vector and \code{G}; softened gravity also requires positive \code{softening}. CR3BP requires \code{mu} in (0, 0.5]. Sitnikov requires positive \code{primary_mass}, \code{primary_radius}, and \code{G}. The gravitational constant defaults to the package constant and is recorded explicitly.}
\item{model}{A model descriptor returned by \code{dynamical_model}, containing ID, version and resolved parameters.}
\item{time}{Finite scalar time at which to evaluate the derivative.}
\item{state}{List of finite numeric \code{positions} and \code{velocities} matrices, with identical dimensions. Rows are integrated bodies, columns are coordinates. Gravity allows at least two bodies and one to three coordinates; CR3BP requires one body and three coordinates; Sitnikov requires one body and one coordinate (z).}
\item{integrator}{One of \code{"Euler"}, \code{"Midpoint"}, \code{"Heun"}, \code{"RK4"}, or \code{"Verlet"}. Verlet requires velocity-independent acceleration and rejects rotating CR3BP.}
\item{duration, timestep}{Positive finite scalars. Duration divided by timestep must be a positive integer within request tolerance.}
\item{start_time}{Finite initial time, default zero. Passed to every solver stage; returned trajectory times include this offset. Useful for segmented integration of time-dependent models.}
\item{request}{An existing catalogue \code{simulation_request}.}
\item{gravitational_constant}{Explicit gravitational constant for translating a dimensional catalogue system. Not used by normalized CR3BP.}
}
\details{
Descriptors and trajectories are plain serializable lists without callbacks.
Executable model definitions are separate from plotting and Studio presentation.
The derivative contract is second order: position derivatives equal velocity;
velocity derivatives are the model acceleration. Time and velocity are passed
at each stage, so velocity-dependent rotating-frame forces use the same RK loop.
Softened gravity uses the Plummer force denominator
\eqn{(r^2 + \epsilon^2)^{3/2}}.

Gravity and Sitnikov use SI conventions by default; CR3BP uses normalized rotating
coordinates. No unit conversion is performed. Sitnikov state contains only the
integrated vertical particle, not prescribed primary trajectories.

The low-level solver does not impose Studio allocation budgets or attach
conservation diagnostics. Its trajectories are not \code{simulation_result}
objects. Existing N-body solvers wrap this engine, preserving their interfaces
and result layouts; other legacy solvers remain available unchanged.
Unknown model IDs, versions, parameters, incompatible state shapes and
nonfinite accelerations are rejected. Saved descriptors must retain resolved
parameter defaults to avoid dependence on later global constants.
}
\value{
\code{dynamical_model} returns a list with \code{id}, \code{version} and
\code{parameters}. \code{dynamics_derivative} returns position and velocity
derivative matrices. \code{integrate_dynamics} returns the model, initial state,
integrator, duration, actual timestep, time vector and time-by-body-by-coordinate
position/velocity arrays. \code{simulation_dynamics} returns arguments suitable
for \code{do.call(integrate_dynamics, ...)} from an existing catalogue request.
}
\examples{
model <- dynamical_model("newtonian_gravity", list(masses = c(2, 3), G = 1))
state <- list(positions = rbind(c(-1, 0), c(1, 0)),
              velocities = matrix(0, 2, 2))
dynamics_derivative(model, 0, state)
trajectory <- integrate_dynamics(model, state, "RK4", 0.1, 0.01)
dim(trajectory$positions)
}
