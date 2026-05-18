# tdtR

`tdtR` is a standalone R package for working with Tucker-Davis Technologies
(TDT) tank/block data. It wraps the Python `tdt` package through `reticulate`,
formats stream data into analysis-ready data frames, and writes per-subject
stream exports with metadata.

This package started from the TDT extraction work in the ArchiveFlow prototypes.
The reusable code has been pulled into package functions; Shiny and Streamlit UI
code is kept out of scope.

## Install dependencies

The package uses `reticulate` to call Python's `tdt` package. In a local Python
environment, install:

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
library(tdtR)

block <- tdt_read_block("/path/to/TDT/block")
tdt_stream_names(block)

info <- tdt_parse_tank_name("/data/123_M1_2-250103-001644")
info$subject_ids
```

For a known stream mapping:

```r
stream_map <- list(
  First = list(ttl_stream = "Wav1", iso_stream = "_405A", exp_stream = "_470D"),
  Second = list(ttl_stream = "Wav1", iso_stream = "_45bA", exp_stream = "_47bD")
)

tdt_extract_tank(
  tank_dir = "/path/to/TDT/block",
  output_dir = "/path/to/Analysis",
  stream_map = stream_map
)
```
