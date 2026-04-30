source("constants.R")
source("celestial_systems/two_body/two_body_euler.R")
source("celestial_systems/two_body/two_body_midpoint.R")
source("celestial_systems/two_body/two_body_heuns.R")
source("celestial_systems/two_body/two_body_runge_kutta.R")
source("celestial_systems/two_body/two_body_velocity_verlet.R")

two_body_method_registry = function() {
  list(
    Euler = list(
      label = "Euler",
      func = euler_two_body,
      color = "#d95f02",
      expected_order = 1
    ),
    Midpoint = list(
      label = "Midpoint",
      func = midpoint_two_body,
      color = "#1b9e77",
      expected_order = 2
    ),
    Heun = list(
      label = "Heun",
      func = heuns_two_body,
      color = "#7570b3",
      expected_order = 2
    ),
    RK4 = list(
      label = "RK4",
      func = runge_kutta_two_body,
      color = "#222222",
      expected_order = 4
    ),
    Verlet = list(
      label = "Verlet",
      func = velocity_verlet_two_body,
      color = "#0f766e",
      expected_order = 2,
      symplectic = TRUE
    )
  )
}

two_body_method_functions = function(registry = two_body_method_registry()) {
  setNames(lapply(registry, function(method) method$func), names(registry))
}

two_body_method_colors = function(registry = two_body_method_registry()) {
  vapply(registry, function(method) method$color, character(1))
}

two_body_method_expected_orders = function(registry = two_body_method_registry()) {
  vapply(registry, function(method) method$expected_order, numeric(1))
}

sun_earth_two_body_parameters = function(T, N) {
  list(
    T = T,
    N = N,
    m_a = M_SUN,
    m_b = M_EARTH,
    r_ax0 = 0, r_ay0 = 0,
    r_bx0 = AU, r_by0 = 0,
    v_ax0 = 0, v_ay0 = 0,
    v_bx0 = 0, v_by0 = abs(V_EARTH_ORBITAL)
  )
}

run_two_body_method = function(method_func, parameters, quiet = FALSE) {
  if (quiet) {
    capture.output({
      result = do.call(method_func, parameters)
    })
  } else {
    result = do.call(method_func, parameters)
  }
  result
}

run_sun_earth_two_body_method = function(method_func, T = 25 * YEAR,
                                         N = 1000, quiet = FALSE) {
  run_two_body_method(method_func, sun_earth_two_body_parameters(T, N), quiet)
}

two_body_final_position_error = function(result, reference_point,
                                         body = "b", distance_scale = AU) {
  if (body == "a") {
    final_point = c(tail(result$x_a, 1), tail(result$y_a, 1))
  } else if (body == "b") {
    final_point = c(tail(result$x_b, 1), tail(result$y_b, 1))
  } else {
    stop("body must be either 'a' or 'b'.")
  }

  sqrt(sum((final_point - reference_point)^2)) / distance_scale
}
