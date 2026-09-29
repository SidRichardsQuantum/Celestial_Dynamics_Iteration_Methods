source("R/load.R")
cd_load_experiment_planning()
response = paste(readLines(cd_path("examples/planning/figure_eight_plan.json")), collapse = "\n")
provider = mock_experiment_provider(response)
# This deterministic mock does not interpret language or contact a service.
# Here the user has explicitly chosen velocity Verlet, the compatible n_body
# backend, and dt measured as a fraction of the known preset period.
review = plan_experiment(paste("Compare Verlet and RK4 for the figure-eight using n_body,",
  "for 20 preset periods with dt = 0.001 preset periods; plot relative energy drift."), provider)
stopifnot(review$status == "ready")
print(review$preview)
requests = experiment_plan_requests(review$plan)
# After review, an application may explicitly call the existing engine:
# results = lapply(requests, run_simulation)
# studio_plot_diagnostic(results$RK4, "energy_relative_drift")
# Planning itself never runs these calls or produces numerical results.
