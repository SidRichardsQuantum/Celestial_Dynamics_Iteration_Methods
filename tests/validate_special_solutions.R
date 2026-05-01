if (!exists("cd_source", mode = "function")) source("R/load.R")
cd_source("tests/helpers_three_body.R")
cd_source("R/systems/three_body/figure_8_initial_conditions.R")
cd_source("R/systems/three_body/lagrange_initial_conditions.R")
cd_source("R/systems/three_body/euler_collinear_initial_conditions.R")
cd_source("R/systems/three_body/choreography_initial_conditions.R")

ic = figure_8_initial_conditions(distance_real = AU, body_mass = M_EARTH)
result = run_three_body_case(ic)
assert_final_separations(result, ic, 1e-3, "figure-8")
assert_near(result$energy_ratio, 1, 1e-6, "figure-8 energy ratio")

ic = lagrange_initial_conditions(side_length_real = AU, body_mass = M_EARTH)
result = run_three_body_case(ic)
assert_final_separations(result, ic, 1e-3, "Lagrange")
assert_near(result$energy_ratio, 1, 1e-6, "Lagrange energy ratio")

ic = euler_collinear_initial_conditions(outer_separation_real = AU,
                                        body_mass = M_EARTH)
result = run_three_body_case(ic)
assert_final_separations(result, ic, 1e-3, "Euler collinear")
assert_near(result$energy_ratio, 1, 1e-6, "Euler collinear energy ratio")

ic = choreography_initial_conditions(name = "butterfly_i",
                                     outer_separation_real = AU,
                                     body_mass = M_EARTH)
assert_near(ic$positions[[3]][1] - ic$positions[[1]][1], AU, 1e-12 * AU,
            "Butterfly I outer separation")

cat("Special three-body solution validation passed.\n")
