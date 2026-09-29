# Optional natural-language experiment planning

The planner translates a description into a reviewable experiment specification.
It never supplies numerical trajectories or replaces the physics engine:

```text
description -> provider -> untrusted plan JSON -> strict validation
            -> clarification / user review -> ordinary simulation_request(s)
            -> existing engine -> existing diagnostics and plots
```

This first version supplies a provider-neutral contract, an explicit typed R
schema, a JSON decoder/validator, a deterministic mock and a small opt-in review
panel. It does not bundle a vendor, network client, conversational agent, tools,
or generated-results explanation. Normal Studio works without any provider,
API key or planning configuration.

## Programmatic contract

```r
source("R/load.R")
cd_load_experiment_planning()
# Installed package users instead load CelestialDynamicsIterationMethods.

schema <- experiment_plan_schema()
provider <- mock_experiment_provider(paste(readLines(
  "examples/planning/figure_eight_plan.json"), collapse = "\n"))
review <- plan_experiment(
  "Compare Verlet and RK4 for the figure-eight using n_body for 20 preset periods, with dt = 0.001 preset periods; plot relative energy drift.",
  provider
)
review$status
review$preview
review$clarifications

# After checking the resolved inputs:
requests <- experiment_plan_requests(review$plan)
# Explicit caller action, outside the planner:
# results <- lapply(requests, run_simulation)
# studio_plot_diagnostic(results, "energy_relative_drift")
```

The mock returns fixed JSON for every prompt; it is a test fixture, not a language
interpreter. Run `Rscript examples/planning/mock_plan.R` for the offline example.

A real adapter is trusted host application code with this signature:

```r
provider <- function(prompt, schema) {
  # Call a host-selected service using its own client and explicit timeout.
  # Credentials come from Sys.getenv("YOUR_PROVIDER_API_KEY") or a secret store.
  # Give the service the schema and ask for one JSON object, without prose.
  # Return only that response text. Do not execute tool calls or generated code.
}
```

There is no global provider lookup in the programmatic API. The caller passes an
adapter explicitly. The adapter receives only the submitted prompt and the
public schema, not application state, files, credentials, solver callbacks or
existing numerical results. Credential access belongs inside the host adapter;
do not put keys in prompts, plans or source code. Provider exceptions return a
generic `provider_error` to avoid exposing headers, tokens or service responses.

The JSON decoder uses `jsonlite::parse_json()` on literal bounded text. It never
passes model output to R's `parse`, `eval`, `source`, a shell, URL loader or file
loader. Only `jsonlite` is needed for JSON; typed-list validation works without
that optional package. Invalid JSON, code fences and prose are not repaired or
executed.

## Version-one experiment-plan schema

`experiment_plan_schema()` is the authoritative **typed R schema**, not a JSON
Schema document. It includes current IDs, per-system parameter types, method
compatibility, diagnostic IDs, units, reference periods and limits. The strict
validator implements these rules. Every object rejects unknown and duplicate
fields; actual registries remain authoritative at each validation.

| Field | Type and constraints |
| --- | --- |
| `schema_version` | Required number `1`. Other/missing protocol versions are invalid. |
| `kind` | `simulate` for one integrator, `compare` for two or more distinct integrators. |
| `system` | Existing Studio catalogue ID. |
| `model` | Existing dynamical-model ID with an adapter for the selected system. |
| `preset` | Existing preset ID, or explicit `null` to supply custom initial conditions. |
| `parameters` | Optional object containing only registered system parameters. Overrides preset values; otherwise uses declared catalogue defaults. |
| `integrators` | Nonempty array of distinct canonical IDs compatible with the system. |
| `duration`, `timestep` | Objects containing only `value` (positive finite number) and `unit` (`model_time` or `preset_periods`). |
| `plots` | Array of supported diagnostic IDs and/or `trajectory`. Empty array explicitly means no plots. |

Missing/null essential draft values produce `needs_clarification`. Missing
required custom initial parameters also produce clarification. A null parameter
override requires clarification instead of falling back silently. The exception
is `preset: null`, which explicitly selects custom inputs. An omitted preset
field asks the user to choose. Registered optional parameter defaults are allowed;
duration, timestep, units, model, system, integrators and plot intent are not guessed.

Parameter scalars must be finite numbers, vectors must contain the declared
element type, and matrices must be rectangular arrays of numeric row arrays.
There are no expressions or callable parameter values. Typed R plans use plain
lists and unnamed atomic vectors; matrix parameters use lists of row lists.
For R, `setNames(list(), character())` represents an empty object and `list()` an
empty array. JSON arrays must be arrays even when they contain one item.

A complete, explicitly clarified example is in
[`figure_eight_plan.json`](../examples/planning/figure_eight_plan.json).

### Why the original example requires clarification

> Compare leapfrog and RK4 for the figure-eight orbit for 20 periods using
> dt = 0.001 and plot their relative energy errors.

The provider should return an incomplete proposal and ask for the missing
meaning, rather than silently accepting this as a runnable instruction:

- `leapfrog` is not an integrator ID. The existing related method is velocity
  Verlet, ID `Verlet`. The user must review that interpretation.
- The `three_body` figure-eight backend supports only RK4. The existing
  `n_body` backend supports both RK4 and Verlet with the same initial masses,
  positions and velocities. Selecting it is explicit in the proposed plan.
- The figure-eight preset is SI-scaled. `dt = 0.001` could mean seconds, a
  fraction of its period, or another normalization. Leave `timestep.unit` null
  until clarified. This layer supports model time and fractions of a documented
  preset period; it does not invent a normalized model.
- The completed fixture explicitly chooses `0.001 preset_periods`, yielding
  20,000 steps per method. This is a clarified example, not an automatic
  interpretation of the original sentence.
- `energy_relative_drift` measures change relative to initial energy, not
  error against an exact trajectory. Values come from numerical diagnostics.

`preset_periods` is available only for the known-period presets named by the
schema. Arbitrary catalogue durations are not periods. Parameter overrides
invalidate use of the preset period; supply explicit `model_time` instead.
The validator never rounds timesteps, relaxes budgets or substitutes a method.

## Validation and conversion

`validate_experiment_plan(plan)` validates plain R data. `parse_experiment_plan(text)`
decodes JSON and applies the same rules. `plan_experiment(prompt, provider)` calls
the adapter once and feeds the response into that boundary. Each returns:

- `status`: `ready`, `needs_clarification`, `invalid` or `provider_error`;
- `errors` / `clarifications`: field and message tables;
- `plan`: the data-only draft when valid or incomplete;
- `requests` / `preview`: present **only** when ready.

`experiment_plan_requests(plan)` revalidates every time and returns ordinary
named `simulation_request` objects. It does not trust a class, previous status,
or provider assertion of validity. Existing validators check initial-state
shapes, collisions, parameters, integrator compatibility and resource budgets.
The existing dynamics adapter verifies the model ID. All integration and
diagnostic calculations happen later in the existing engine.

Limits include 64 KiB JSON, 256 KiB typed R data, 12 nesting levels, bounded
strings/arrays, the normal 100,000-step/body/storage/pair-step budgets per request,
and 500,000 steps across a plan. These are submission limits, not accuracy
guarantees. Poor numerical choices can still yield inaccurate experiments.

## Optional Studio review panel

Enable explicitly before starting the app:

```r
Sys.setenv(CELESTIAL_STUDIO_PLANNING = "1")
# Optional: use a trusted host adapter configured outside the repository.
options(celestial.experiment_provider = provider)
shiny::runApp("app")
```

The **Experiment planner** panel has a description box, a provider request
button, editable JSON and a validation preview. With no adapter it supports
manual JSON review and explains that natural-language planning is unavailable.
No network call is made at startup or by ordinary simulation workflows.

Missing essential fields appear as clarification requests and block approval.
The resolved preview shows numerical time units, step counts and methods;
expanded text shows exact initial conditions and requests. The user checks an
approval box, then confirms that exact plan. Edits to the description or JSON
invalidate approval, as does revalidation or a new provider response. Approval
is single use and the current JSON is revalidated at confirmation.

Confirmation only populates the ordinary composer. The normal **Run** button
starts the existing numerical engine. Requested plot IDs remain visible in the
review and handoff status; use the existing Viewer diagnostics or Integrator Lab
plots after the run. This first layer does not automatically navigate plots,
implement chat history, or generate explanations of results.

When the environment flag is absent, the panel and its module are not loaded.
The optional provider is never called. Remove the flag to return to normal
Studio; no requests or history formats change.

## Trust boundary

| Component | Authority |
| --- | --- |
| User description and provider response | Untrusted text/data. No execution authority. |
| Host adapter | Trusted installed application code. Responsible for network timeouts, secret handling and service selection. It is not a sandbox for untrusted R functions. |
| Schema and local validator | Decide which IDs, shapes, units and resources can become requests. |
| User review | Resolves missing intent and confirms exact settings. Validation alone cannot verify the provider understood the user. |
| Existing request/runner/model code | Sole authority for physics, integration, diagnostics and scientific artifacts. |
| Future explanation adapter | May explain provided computed results; must never author or overwrite scientific arrays or diagnostics. Not implemented here. |

There is no accepted field for R code, shell commands, tools, paths, API keys,
trajectories or generated diagnostics. Provider text is rendered as escaped
text, not HTML. No generated code is evaluated, parsed as R, sourced or executed.
Normal numerical histories contain the resulting validated requests and engine
outputs, not provider credentials or raw exceptions. This planner does not
persist prompts or raw provider replies.

Keep credentials in environment variables, a secret store, or a home-directory
configuration outside source control. Conventional `.env*` and `.Renviron*`
files are ignored by Git and excluded from package builds. This does not protect
secrets already tracked or placed in arbitrary files: never place them in source,
example plans, request JSON or shared screenshots.

Tests cover valid and malformed proposals, unknown/duplicate fields, incompatible
IDs, ambiguous units, missing essentials, malicious strings, non-data R objects,
resource limits, mock/provider failures, conversion into actual engine runs,
disabled UI, stale approvals and composer handoff:

```sh
Rscript tests/validate_experiment_plans.R
Rscript tests/validate_planner_app.R
Rscript tests/run_all_tests.R
```
