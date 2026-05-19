# tdtr

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

## Quick start

Use the getting-started vignette to get started.

```r
vignette("getting-started", package = "tdtr")
```

## Python backend

`tdtr` follows the reticulate package guidance for Python dependencies. On load
it declares:

```r
reticulate::py_require("tdt>=0.7.3")
```

Python is not initialized just because the R package is attached, so users can
still configure their Python environment before the first Python-backed call.
When Python `tdt` cannot be used, backend entry points fail with explicit
diagnostics.

For a local Python environment:

```sh
python -m pip install "tdt>=0.7.3"
```

For development in this repository:

```sh
pixi run test
pixi run document
pixi run check
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

## Documentation

- `vignette("getting-started", package = "tdtr")` covers the R-friendly
  inspect-and-collect workflow, including Python configuration with Pixi.
- `vignette("advanced-usage", package = "tdtr")` covers reticulate-backed
  workflows, save/reload behavior, Python-side processing, reader controls,
  store-filter naming behavior, and memory profiling.
- [AGENTS.md](AGENTS.md) records implementation guardrails for future coding
  work in this repository.
