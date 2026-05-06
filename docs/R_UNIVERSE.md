# R-universe Setup

R-universe does not read registry files from this package repository. It expects
a separate GitHub repository under the same account.

## Registry Repository

Create this public GitHub repository:

```text
SidRichardsQuantum/sidrichardsquantum.r-universe.dev
```

Add a root-level `packages.json` file with:

```json
[
  {
    "package": "CelestialDynamicsIterationMethods",
    "url": "https://github.com/SidRichardsQuantum/Celestial_Dynamics_Iteration_Methods"
  }
]
```

Then install the R-universe GitHub app for the `SidRichardsQuantum` account:

```text
https://github.com/apps/r-universe
```

R-universe should create and build the universe within about an hour. Build
status and package pages should appear at:

```text
https://sidrichardsquantum.r-universe.dev
https://sidrichardsquantum.r-universe.dev/CelestialDynamicsIterationMethods
```

## Install Command

Once the package has built, users can install it with:

```r
options(repos = c(
  sidrichardsquantum = "https://sidrichardsquantum.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))
install.packages("CelestialDynamicsIterationMethods")
```

## Maintenance Notes

- R-universe tracks the default branch unless a `branch` field is added to
  `packages.json`.
- The `package` value must match the `Package:` field in `DESCRIPTION`.
- If the package ever moves into a subdirectory, add a `subdir` field.
- Keep `URL` and `BugReports` in `DESCRIPTION` pointed at the canonical GitHub
  repository so package metadata renders correctly.
