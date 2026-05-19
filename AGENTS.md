# AGENTS.md

This repository is an R package for working with Tucker-Davis Technologies
(TDT) tank/block data through Python `tdt` and `reticulate`.

## Current Scope

Build and maintain `tdtr` as a generic TDT package for R users:

- raw TDT data are read by Python `tdt>=0.7.3`;
- R provides accessors, summaries, event/range helpers, explicit collection, and
  memory diagnostics;
- Python-backed objects are allowed for advanced workflows;
- collected data should be ordinary R objects that can be saved and restored.

Do not add:

- native R parsing of TDT binary files;
- Synapse API clients, UDP/live-acquisition paths, or hardware-control code;
- lab-specific tank naming, subject parsing, or analysis assumptions;
- `dplyr`, `tidyr`, `ggplot2`, or other broad dependencies without a specific
  documented reason.

## Reticulate Rules

- Follow reticulate package guidance: declare Python requirements with
  `reticulate::py_require("tdt>=0.7.3")`.
- Delay-load Python imports and keep `convert = FALSE` for backend objects.
- Let `library(tdtr)` load before Python is initialized so users can configure
  Python before first backend use.
- Backend entry points should fail clearly when Python `tdt` is unavailable.
- Do not silently convert NumPy arrays into R. Data movement into R should
  happen through explicit collection/view helpers.

## Data And Documentation

- The packaged fixture is a raw TDT block at
  `inst/extdata/Subject1-211115-094936`, exposed by
  `tdtr_example_block_path()`.
- Vignettes should exercise the reticulate-backed reader against that raw
  fixture. Do not reintroduce pre-collected `.rda` example data.
- The advanced vignette should remain explicit about Python-session state,
  save/reload behavior, Python-side processing, store-filter naming behavior,
  and profiling limitations.

## Verification

Before handing off substantive changes, run:

```sh
pixi run document
pixi run test
pixi run check
git diff --check
```

If a change affects vignettes, render or check them through the package build
and verify they do not contain local absolute paths or stale R-only example
wording.
