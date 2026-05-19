# tdtr

[![R-CMD-check](https://github.com/nimh-dsst/tdtr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/nimh-dsst/tdtr/actions/workflows/R-CMD-check.yaml)
[![R-universe version](https://nimh-dsst.r-universe.dev/tdtr/badges/version)](https://nimh-dsst.r-universe.dev/tdtr)
[![R-universe status](https://nimh-dsst.r-universe.dev/tdtr/badges/checks)](https://nimh-dsst.r-universe.dev/tdtr)

`tdtr` is an R package for working with Tucker-Davis Technologies (TDT)
tank/block data from R. It reads raw TDT data with Python's `tdt` package
through `reticulate`, then provides R-friendly accessors, summaries, event
helpers, and explicit collection functions.

The package deliberately does **not** implement TDT binary parsing in R. Python
`tdt` is the raw-data backend. The R package adds the interface that R users
need around that backend:

- Python-backed block objects for inspecting large recordings without copying
  every stream into R;
- clean R accessors for block metadata, streams, and epocs/events;
- explicit collection helpers that materialize selected data into ordinary R
  matrices, lists, and tibbles;
- range and event-window helpers for bounded reads and analysis windows;
- memory profiling diagnostics for comparing read/collection strategies.

Out of scope for the core package: Synapse API work, live acquisition, native R
binary parsing, lab-specific tank naming rules, and broad tidyverse dependency
stacks.

## Installation

Install the release build from the NIMH-DSST R-universe:

```r
install.packages(
  "tdtr",
  repos = c(
    nimhdsst = "https://nimh-dsst.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)
```

If you prefer `pak`, use the same repository configuration:

```r
install.packages("pak")
options(repos = c(
  nimhdsst = "https://nimh-dsst.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))
pak::pkg_install("tdtr")
```

## Python backend

`tdtr` follows the reticulate package guidance for Python dependencies. On load
it declares:

```r
reticulate::py_require("tdt>=0.7.3")
```

Python is not initialized just because the R package is attached, so users can
still configure their Python environment before the first Python-backed call.
For ordinary users, reticulate can create and manage a Python environment that
contains `tdt>=0.7.3` when Python is first initialized. If a user forces a
specific Python environment with reticulate, Conda, Pixi, or environment
variables, then that Python environment must already provide `tdt>=0.7.3`.

Backend entry points fail with explicit diagnostics when Python `tdt` cannot be
used.

## Quick start

See the hosted getting-started vignette:

<https://nimh-dsst.r-universe.dev/tdtr/doc/getting-started.html>

After installation:

```r
library(tdtr)

tdt_config(initialize = TRUE)
```

## Basic use

The package includes a small raw TDT example block in `inst/extdata`. It is
stored as TDT files, not as pre-collected R data.

```r
library(tdtr)

tdt_config(initialize = TRUE)

example_path <- tdtr_example_block_path()
block <- read_block(
  example_path,
  evtype = c("epocs", "streams"),
  t1 = 0,
  t2 = 5,
  verbose = 0
)

stream_names(block)
epoc_names(block)

events <- collect_epocs(block, store = "Tick")
signal <- collect_stream(block, "_465A")
```

`read_block()` returns a Python-backed object by default. That object is useful
for inspection and bounded workflows, but it is not durable analysis state.
Save read parameters or explicitly collected R objects when results need to
persist across R sessions.

For read-time stream filtering, `read_block()` accepts the names returned by
`stream_names()`. This includes sanitized Python names such as `_465A`; the raw
`read_block_py()` wrapper preserves Python `tdt` matching and expects the
original TDT store ID (`465A`) for that case.

## Documentation

- [Getting started](https://nimh-dsst.r-universe.dev/tdtr/doc/getting-started.html)
  covers the R-friendly inspect-and-collect workflow.
- [Advanced usage](https://nimh-dsst.r-universe.dev/tdtr/doc/advanced-usage.html)
  covers reticulate-backed
  workflows, save/reload behavior, Python-side processing, reader controls,
  store-filter naming behavior, and memory profiling.
- If the package was installed from a built source package that includes
  vignettes, the same documents are available from R with
  `vignette("getting-started", package = "tdtr")` and
  `vignette("advanced-usage", package = "tdtr")`.

## Development

This repository uses Pixi for the local development environment:

```sh
pixi run R
```

Inside R, use the source tree directly during active development:

```r
pkgload::load_all()
```

This is the same source-loading workflow exposed by `devtools::load_all()` if
you also have devtools installed.

Run the standard checks before handing off substantive changes:

```sh
pixi run document
pixi run test
pixi run check
git diff --check
```

Local source-tree sessions do not automatically expose package vignettes through
`vignette()`. To test installed-package vignette behavior, build and install a
source package with vignettes:

```sh
pixi run R CMD build .
pixi run R CMD INSTALL tdtr_*.tar.gz
```

## Releases

Releases are created by GitHub Actions. To publish a patch release, run the
`Release` workflow on `main` with the desired version, for example `0.0.1`. The
workflow updates `DESCRIPTION` and `NEWS.md`, regenerates documentation, builds
and checks the source package with vignettes, commits the release version, tags
it, and creates the GitHub Release with the source tarball attached.

```sh
gh workflow run release.yaml --ref main -f version=0.0.1
```

- [AGENTS.md](AGENTS.md) records implementation guardrails for future coding
  work in this repository.
