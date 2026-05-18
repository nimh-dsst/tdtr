# tdtr

`tdtr` is a standalone R package for working with Tucker-Davis Technologies
(TDT) tank/block data from R. It uses Python's `tdt` package through
`reticulate`, with a layered interface:

- Python-backed wrappers for large-data workflows where unwanted array copies
  matter;
- R-friendly accessors, summaries, and event/window helpers;
- explicit collection helpers that materialize streams, epocs/events, and
  metadata into ordinary R objects.

The current scope is documented in [docs/package-scoping.md](docs/package-scoping.md).
Lab-specific extraction workflows are out of scope for the core package.

## Install dependencies

This phase of the package requires R, `reticulate`, Python, and Python's `tdt`
package. The package should follow reticulate's package guidance: declare
`tdt>=0.7.3` with `py_require()`, delay-load Python imports, and fail clearly
when Python-backed functionality is used without a working Python `tdt`
installation.

In a local Python environment, install:

```sh
python -m pip install tdt
```

This repository also includes a pixi environment for R package development:

```sh
pixi run test
pixi run document
pixi run check
```

## Basic use

```r
library(tdtr)

block <- read_block("/path/to/TDT/block")
stream_names(block)

events <- collect_epocs(block)
signal <- collect_stream(block, "Wav1")
```

The implementation is being realigned around generic TDT functionality. Lab-
specific extraction workflows, Synapse API work, and native R binary parsing are
out of scope.
