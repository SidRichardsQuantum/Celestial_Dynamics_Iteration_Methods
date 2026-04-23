source("constants.R")
source("celestial_systems/three_body/three_body_runge_kutta.R")
source("celestial_systems/three_body/plot_three_body.R")

# Experimental search for equal-mass, symmetric, near-periodic three-body orbits.
# This is not a proof or a robust optimizer; it is a lightweight numerical
# exploration tool for finding candidate initial conditions worth inspecting.

build_candidate = function(params, distance_real = AU, body_mass = M_EARTH) {
  position_scale = distance_real / 2
  time_scale = sqrt(position_scale^3 / (G * body_mass))
  velocity_scale = position_scale / time_scale

  p1 = params[1]
  p2 = params[2]
  dimensionless_period = params[3]

  list(
    period = dimensionless_period * time_scale,
    positions = list(
      c(-1, 0) * position_scale,
      c(0, 0) * position_scale,
      c(1, 0) * position_scale
    ),
    velocities = list(
      c(p1, p2) * velocity_scale,
      c(-2 * p1, -2 * p2) * velocity_scale,
      c(p1, p2) * velocity_scale
    ),
    p1 = p1,
    p2 = p2,
    dimensionless_period = dimensionless_period
  )
}

run_candidate = function(candidate, N, body_mass = M_EARTH) {
  pos1 = candidate$positions[[1]]
  pos2 = candidate$positions[[2]]
  pos3 = candidate$positions[[3]]
  vel1 = candidate$velocities[[1]]
  vel2 = candidate$velocities[[2]]
  vel3 = candidate$velocities[[3]]

  capture.output({
    result = runge_kutta_three_body(
      T = candidate$period,
      N = N,
      m_a = body_mass,
      m_b = body_mass,
      m_c = body_mass,
      r_ax0 = pos1[1], r_ay0 = pos1[2],
      r_bx0 = pos2[1], r_by0 = pos2[2],
      r_cx0 = pos3[1], r_cy0 = pos3[2],
      v_ax0 = vel1[1], v_ay0 = vel1[2],
      v_bx0 = vel2[1], v_by0 = vel2[2],
      v_cx0 = vel3[1], v_cy0 = vel3[2]
    )
  })
  result
}

closure_score = function(result, candidate, distance_real = AU) {
  pos1 = candidate$positions[[1]]
  pos2 = candidate$positions[[2]]
  pos3 = candidate$positions[[3]]

  final1 = c(tail(result$x_a, 1), tail(result$y_a, 1))
  final2 = c(tail(result$x_b, 1), tail(result$y_b, 1))
  final3 = c(tail(result$x_c, 1), tail(result$y_c, 1))

  closure_error = sqrt(
    sum((final1 - pos1)^2) +
      sum((final2 - pos2)^2) +
      sum((final3 - pos3)^2)
  ) / distance_real

  energy_error = abs(result$energy_ratio - 1)

  closure_error + 10 * energy_error
}

evaluate_candidate = function(params, N, distance_real = AU, body_mass = M_EARTH) {
  candidate = build_candidate(params, distance_real, body_mass)

  result = tryCatch(
    run_candidate(candidate, N, body_mass),
    error = function(e) NULL
  )
  if (is.null(result) || !is.finite(candidate$period)) {
    return(list(score = Inf, candidate = candidate, result = NULL))
  }

  list(
    score = closure_score(result, candidate, distance_real),
    candidate = candidate,
    result = result
  )
}

random_neighbor = function(params, step_sizes) {
  candidate = params + rnorm(length(params), mean = 0, sd = step_sizes)
  candidate[3] = max(candidate[3], 0.5)
  candidate
}

search_three_body_solution = function(
    iterations = 5,
    N = 60000,
    seed = 1,
    start_params = c(0.306893, 0.125507, 6.234671),
    step_sizes = c(0.002, 0.002, 0.03),
    cooling = 0.97,
    distance_real = AU,
    body_mass = M_EARTH) {

  set.seed(seed)

  current_params = start_params
  current = evaluate_candidate(current_params, N, distance_real, body_mass)
  best = current

  cat("Experimental equal-mass three-body search\n")
  cat("Parameters: p1, p2, dimensionless period\n")
  cat(sprintf("Initial score: %.6g\n", current$score))

  for (iteration in 1:iterations) {
    trial_params = random_neighbor(current_params, step_sizes)
    trial = evaluate_candidate(trial_params, N, distance_real, body_mass)

    if (is.finite(trial$score) && trial$score < current$score) {
      current_params = trial_params
      current = trial
    }

    if (is.finite(trial$score) && trial$score < best$score) {
      best = trial
      cat(sprintf(
        "iteration %d: score %.6g, p1 %.9f, p2 %.9f, period %.9f\n",
        iteration, best$score, best$candidate$p1, best$candidate$p2,
        best$candidate$dimensionless_period
      ))
    }

    step_sizes = step_sizes * cooling
  }

  best
}

plot_candidate = function(search_result,
                          filepath = file.path("images", "three_body",
                                               "experiments",
                                               "candidate_solution.png")) {
  if (is.null(search_result$result)) {
    stop("No result available to plot.")
  }

  plot_three_body_result(
    result = search_result$result,
    filepath = filepath,
    title = sprintf(
      "Experimental Three-Body Candidate\nscore = %.4g, p1 = %.4f, p2 = %.4f, period = %.4f",
      search_result$score,
      search_result$candidate$p1,
      search_result$candidate$p2,
      search_result$candidate$dimensionless_period
    ),
    labels = c("Body 1", "Body 2", "Body 3")
  )
}

if (sys.nframe() == 0) {
  result = search_three_body_solution()

  cat("\nBest candidate:\n")
  cat(sprintf("score: %.12g\n", result$score))
  cat(sprintf("p1: %.12g\n", result$candidate$p1))
  cat(sprintf("p2: %.12g\n", result$candidate$p2))
  cat(sprintf("dimensionless_period: %.12g\n",
              result$candidate$dimensionless_period))
  if (!is.null(result$result)) {
    cat(sprintf("energy_ratio: %.12g\n", result$result$energy_ratio))
    plot_candidate(result)
  }
}
