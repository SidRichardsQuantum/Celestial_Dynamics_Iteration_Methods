# Analysis Artifacts

`analysis/generate_results.R` is the source of truth for generated result
tables, diagnostic plots, the Pages results narrative, and the interactive
dashboard.

Run from the repository root:

```bash
Rscript analysis/generate_results.R
```

After intentional artifact changes, update the committed size/dimension
baseline:

```bash
Rscript analysis/update_artifact_baseline.R
```

Generated files live under `analysis/generated/` and `images/`. Do not edit
numeric tables or generated HTML by hand; change the solver, example, or
analysis code and regenerate.
