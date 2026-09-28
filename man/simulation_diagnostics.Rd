\name{simulation_diagnostics}
\alias{simulation_diagnostics}
\alias{studio_diagnostics}
\alias{studio_diagnostic_summary}
\title{Machine-readable orbital diagnostics}
\description{Evaluate supported orbital trajectories without Shiny, keeping absolute
quantities, drift, relative errors, time series, extrema and final values distinct.}
\usage{
simulation_diagnostics(result, collision_distance = 0,
                       near_collision_distance = NULL)
studio_diagnostics(result)
studio_diagnostic_summary(diagnostics)
}
\arguments{
\item{result}{A simulation_result or normalized list with time, matching numeric
positions and velocities arrays (time by body by coordinate), request model and
parameters, and masses for massive systems. Optional model, provenance,
runtime_seconds and solver_statistics supply physical constants and performance data.
Malformed or non-finite trajectories can be inspected without passing persistence validation.}
\item{collision_distance}{Nonnegative scalar distance in position units. Defaults to
zero (point-mass overlap). A positive value is a caller-defined encounter criterion.}
\item{near_collision_distance}{Optional distance at least as large as collision_distance.
NULL leaves near-collision flags unavailable: the models have no physical radii.}
\item{diagnostics}{Numeric diagnostic data frame including time.}
}
\value{simulation_diagnostics returns a passive list with version, series (numeric data
frame), summary (one row per metric), registry (metric, kind, units, definition),
performance, validity, flags, unavailable reasons and assumptions.
Summary columns include initial, final, minimum, maximum, max_absolute,
max_absolute_change, finite_samples and nonfinite_samples. Final always means the
last stored sample; extrema use finite samples. All-unavailable extrema are NA.
Performance contains runtime_seconds, step_count and force_evaluation_count;
unrecorded values are NA. Runtime measures the solver adapter call, including its
existing summaries, excluding the new diagnostics. Current solvers record fixed
steps but do not instrument force/RHS evaluations.
The compatibility function studio_diagnostics returns only series.
studio_diagnostic_summary retains its existing named-list format and initial,
final and max_absolute_change fields.}
\details{
For the supported closed planar Newtonian systems,
\deqn{E=\frac12\sum_i m_i |v_i|^2-G\sum_{i<j}\frac{m_i m_j}{|r_i-r_j|},}
\deqn{P=\sum_i m_i v_i,\quad L_z=\sum_i m_i(x_i v_{yi}-y_i v_{xi}),}
\deqn{R=\frac{\sum_i m_i r_i}{M},\quad V=\frac{P}{M},\quad M=\sum_i m_i.}
Angular momentum is measured about the coordinate origin. Scalar drift is q(t)-q(0);
momentum drift is the Euclidean norm of P(t)-P(0), with signed component drifts also
available. Centre-of-mass drift is the norm of R(t)-R(0)-(t-t0)V(0), so uniform
translation is not reported as conservation failure. Velocity drift is the norm
of V(t)-V(0).
Scalar relative drift is (q(t)-q(0))/abs(q(0)). Momentum relative drift divides
its vector drift norm by norm(P(0)). Denominators at or below 100 machine epsilons
times an initial physical scale yield NA. Energy uses max(K(0),abs(U(0)));
angular momentum uses the sum of absolute cross-product terms; momentum uses the
sum of m_i times speed_i. No fitted slope or trajectory error against an exact
solution is implied by these conservation diagnostics.
CR3BP uses only the Jacobi invariant in rotating normalized coordinates:
\deqn{C=x^2+y^2+2[(1-\mu)/r_1+\mu/r_2]-|v|^2.}
Circular Sitnikov uses particle specific energy
\deqn{e=v_z^2/2-2Gm/\sqrt{a^2+z^2}.}
Their cancellation scales use the larger absolute kinetic and potential terms.
They do not receive closed massive-system invariants. Unknown or modified models
are reported as unavailable. Recorded model G, then provenance G, takes precedence
over the current engine G. A missing model is inferred only from a supported
request formulation.
Pair separation extrema include all stored bodies and, for CR3BP, the two
prescribed primaries. Flags check only stored samples and cannot rule out
encounters between steps. Singular energy is NA at exact overlap. Near-parabolic
two-body semi-major axis is NA. Undefined relative errors are not invalid states;
NA, NaN and Inf in the trajectory are counted separately. Derived NaN and Inf
are also reported. Structural failure returns an empty series and validity issues.
A valid trajectory is not a guarantee of accuracy or convergence.
}
\examples{
request <- studio_preset("circular_two_body")
request$duration <- 10 * request$timestep
result <- run_simulation(request)
d <- simulation_diagnostics(result, near_collision_distance = 1e9)
d$summary[d$summary$metric == "energy_relative_drift", ]
d$performance
d$validity
}
