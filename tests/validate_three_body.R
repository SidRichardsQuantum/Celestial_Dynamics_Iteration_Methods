if (!exists("cd_source", mode = "function")) source("R/load.R")
source(cd_path("tests/validate_special_solutions.R"))
source(cd_path("tests/validate_restricted_three_body.R"))

cat("Three-body validation passed.\n")
