# Three-Body Examples

Run these scripts from the repository root so their `source(...)` calls resolve correctly.

```bash
Rscript examples/three_body/run_all_three_body_examples.R
```

## Folders

- `general/`: full three-body simulations for physical or astrophysical systems.
- `special_solutions/`: exact or cataloged periodic equal-mass solutions.
- `perturbations/`: small changes applied to special solutions to show sensitivity.
- `restricted/`: circular restricted three-body and Sitnikov examples.

## Examples

- `general/earth_mars_sun.R`
- `general/earth_moon_spacecraft.R`
- `general/binary_distant_third.R`
- `special_solutions/three_earths.R`
- `special_solutions/lagrange_three_earths.R`
- `special_solutions/euler_collinear_three_earths.R`
- `special_solutions/butterfly_choreography.R`
- `perturbations/perturbed_figure_8.R`
- `perturbations/perturbed_lagrange_three_earths.R`
- `restricted/restricted_earth_moon_trojan.R`
- `restricted/lyapunov_near_l1.R`
- `restricted/sitnikov_three_body.R`
