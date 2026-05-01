# Examples

Examples are executable scripts that generate representative plots and, for
orbit simulations, companion HTML animations under `images/`.

Run all examples from the repository root:

```bash
Rscript run_all_examples.R
```

Run a group directly:

```bash
Rscript examples/two_body/run_all_two_body_examples.R
Rscript examples/three_body/run_all_three_body_examples.R
Rscript examples/n_body/run_all_n_body_examples.R
```

New examples should bootstrap the project loader first:

```r
source("R/load.R")
```

Then use `cd_source()` or a module helper such as `cd_load_two_body()` instead
of hard-coding long dependency chains.
