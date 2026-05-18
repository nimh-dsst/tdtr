# Package scoping: R package for TDT fiber photometry workflows

Working package name: **`tdtr`**  
Optional bridge package name: **`tdtrpy`**

This document records the current scoping decisions for an R-first package that helps scientists work with TDT fiber photometry data without committing the core package to Python, reticulate, or a homegrown binary parser.

## Decision snapshot

Build a **pure-R core package** first.

The core package should focus on:

- a stable R data model for TDT-style continuous streams and event/epoc data;
- R-native helpers for event-aligned, trial-aligned, and windowed photometry workflows;
- importers for simple/exported data formats that laboratories can generate from TDT, MATLAB, or Python;
- a small dependency footprint that keeps the package plausible for CRAN and, later, possibly Bioconductor.

Do **not** make the first package a public reticulate wrapper around the Python `tdt` package.

Reticulate remains a useful fallback, but it should be treated as an **optional import backend**, ideally in a separate package, and should return pure R objects rather than live Python pointers.

## Why this scope changed

The earlier plan centered on reticulate-backed wrappers for:

- `tdt.read_block()`
- `tdt.read_sev()`
- `tdt.epoc_filter()`

That made sense for quickly exposing existing Python functionality. However, it would also make the package conceptually dependent on Python objects, Python environments, NumPy array conversion, and non-persistent external pointers.

The new goal is different:

> Make a durable R package that can evolve toward a clean release on CRAN or Bioconductor without being irrevocably tied to a Python-centered public interface.

The core package should be useful even when users arrive with data exported from MATLAB, Python, Synapse/OpenScope tooling, or a future compiled reader.

## Scientific premise

Most fiber photometry users do **not** need full parity with every low-level TDT binary reader option.

They usually need clean ways to:

- represent continuous photometry streams;
- represent events, TTLs, stimulation epochs, notes, behavioral state changes, and trial metadata;
- align continuous streams to events;
- extract peri-event windows;
- compute trial-level or condition-level summaries;
- move from raw or exported TDT data into a reproducible R analysis workflow.

This package should lead with those workflows.

## Core principles

### 1. Stable R objects first

The package should define ordinary R objects that can be inspected, saved, restored, tested, and passed through common R workflows.

Preferred structures:

- `list`
- `matrix`
- `numeric`
- `data.frame` / `tibble`
- S3 classes

Avoid using live foreign-language pointers as public objects in the core package.

### 2. Importers return pure R

Any importer, whether native R, compiled-code backed, or Python-backed, should return the same R class:

```r
class(block) == c("tdt_block", "list")
```

Not:

```r
class(block) == "tdt_block_py"
```

The user should not need to know whether the import came from a CSV export, MATLAB export, Python bridge, or future compiled reader.

### 3. No homegrown full binary parser

Do **not** implement a native R parser for the full TDT block ecosystem.

In particular, do not attempt to fully parse/maintain:

- TSQ
- TEV
- TBK
- TNT
- SEV fallback behavior inside blocks
- chunked/strobed stream reconstruction
- all edge cases in TDT tank/block metadata

That is a serious binary-parser maintenance burden. Silent alignment or sampling-rate bugs would be scientifically harmful.

### 4. Native R or compiled reader only if credible

If a mature, maintained, license-compatible compiled C/C++ reader exists, wrapping it from R could be valuable.

But do not assume such a project exists. Treat this as a future investigation item with strict requirements:

- actively maintained or at least stable and understandable;
- compatible license;
- cross-platform;
- can read the actual TDT formats needed by fiber photometry users;
- has enough fixtures/tests to validate sampling rates, event times, stream lengths, and channel ordering;
- can be wrapped without dragging in a large or fragile dependency stack.

If no credible compiled reader exists, do not build one from scratch.

### 5. Reticulate is a fallback, not the public model

Reticulate can still serve scientists well when they need to import arbitrary existing TDT blocks, because TDT’s Python reader already handles many tricky binary and metadata cases.

But if reticulate is used:

- isolate it in an optional backend or companion package;
- return pure R `tdt_block` objects;
- do not expose Python objects as the primary public API;
- do not make users manage Python just to use analysis helpers;
- do not require Python for the core package to load or test.

### 6. Small dependency footprint

Core package dependencies should remain minimal.

Likely acceptable:

- base R
- `tibble`
- `rlang`, only where it meaningfully improves a data-masking or non-standard-evaluation interface
- `testthat` in `Suggests`

Avoid unless clearly justified:

- `dplyr`
- `tidyr`
- `purrr`
- `ggplot2`
- `cli`
- reticulate in the core package

Base R tools like `lapply()`, `Map()`, `split()`, and explicit loops are fine.

### 7. No unnecessary UI layer

Do not add a command-line UI framework or messaging system.

Use ordinary R errors, warnings, and messages. Prefer simple, testable behavior over polish.

## Recommended package split

### `tdtr`: pure-R core package

This is the main package.

Responsibilities:

- define the R data model;
- validate block objects;
- provide accessors;
- import simple/exported formats;
- perform stream/event alignment;
- provide trial/window extraction helpers;
- document practical “how to get data into R” routes from TDT, MATLAB, and Python.

This package should remain plausible for CRAN and possibly Bioconductor.

### `tdtrpy`: optional Python bridge

This is a possible companion package, not the core.

Responsibilities:

- use `reticulate` to call Python `tdt`;
- import raw TDT blocks when the pure-R core cannot;
- convert results immediately into `tdtr::tdt_block` objects;
- hide Python implementation details from ordinary users.

Possible public functions:

```r
read_tdt_block_python()
read_tdt_sev_python()
```

These should return `tdt_block`, not Python objects.

### Why two packages may be better than one

A two-package design keeps the core package clean:

- `tdtr` can be installed and checked without Python.
- `tdtr` can focus on analysis and object semantics.
- `tdtrpy` can absorb reticulate environment complexity.
- Users with hard import needs can install the bridge.
- Users who only need exported data do not pay the Python cost.

A one-package design with `reticulate` in `Suggests` is possible, but it risks blurring the core package’s identity.

## Proposed R data model

Use an S3 class around a list.

```r
tdt_block <- list(
  info = list(
    source = NULL,
    block_path = NULL,
    subject = NULL,
    experiment = NULL,
    start_time = NULL,
    duration = NULL
  ),
  streams = list(
    StoreName = list(
      name = "StoreName",
      data = matrix(numeric(), nrow = 0, ncol = 0),
      fs = numeric(1),
      t0 = 0,
      channels = NULL,
      units = NULL,
      metadata = list()
    )
  ),
  epocs = tibble::tibble(
    store = character(),
    onset = numeric(),
    offset = numeric(),
    value = numeric()
  )
)
class(tdt_block) <- c("tdt_block", "list")
```

### Stream orientation

Choose one R-native orientation and enforce it.

Recommended default:

```r
nrow(data) == number of samples
ncol(data) == number of channels
```

That is convenient for R because:

- rows correspond to time/sample observations;
- columns correspond to channels;
- it maps naturally to data-frame/tibble views;
- single-channel streams can be represented as a one-column matrix or numeric vector by explicit helper.

This may differ from Python or MATLAB conventions. Importers should transpose when needed and document that all `tdtr` streams are samples-by-channels.

### Time conventions

Use seconds relative to block start.

- `onset`: seconds from block start
- `offset`: seconds from block start
- `t0`: stream start time, seconds from block start
- `fs`: samples per second
- sample indices exposed to R users should be 1-based if returned as indices

Avoid storing hidden file offsets or binary-reader-specific coordinates in user-facing objects.

### Epocs/events

Represent epocs/events as a tibble or data frame with at least:

```r
store
onset
offset
value
```

Additional columns may include:

```r
label
condition
trial
notes
metadata
```

Keep values flexible: numeric values are common, but some event sources may be textual or coded.

## Core exported functions

The exact names can change, but this is the intended surface area.

### Constructors and validators

```r
new_tdt_block(info = list(), streams = list(), epocs = NULL)
validate_tdt_block(x)
is_tdt_block(x)
```

### Accessors

```r
block_info(x)
streams(x)
stream_names(x)
stream(x, name)
epocs(x)
epoc_names(x)
epoc(x, store)
```

### Importers for exported/simple formats

```r
read_tdt_export(path, ...)
read_stream_csv(path, fs, name, channels = NULL, t0 = 0, ...)
read_epocs_csv(path, ...)
read_stream_binary(path, fs, shape, name, dtype = "float32", t0 = 0, ...)
```

Potentially later:

```r
read_sev(path, ...)
```

Only implement `read_sev()` if the scope is narrow, validated, and testable. Do not let `read_sev()` silently expand into a full block parser.

### Coercion and table views

```r
as_tdt_block(x, ...)
as_tibble_epocs(x, store = NULL)
as_tibble_stream(x, stream, window = NULL, downsample = NULL)
```

Avoid making huge long-form tibbles by accident. If `as_tibble_stream()` could create a very large table, require the user to specify a window, downsampling, or an explicit override.

### Ranges and trial helpers

```r
as_ranges(x)
ranges_from_epocs(epocs, pre, post, onset_col = "onset", drop_negative = TRUE)
slice_stream(x, stream, range, channels = NULL)
slice_trials(x, stream, ranges, channels = NULL)
align_to_events(x, stream, events, pre, post, channels = NULL)
```

These helpers are central. They are more important than imitating Python reader signatures.

### Photometry-oriented helpers

Potential early additions:

```r
baseline_correct(x, baseline)
summarize_trials(x, fun = mean, ...)
downsample_stream(x, stream, factor = NULL, fs = NULL)
```

Be cautious with domain-specific calculations such as dF/F, isosbestic correction, and regression correction. They are scientifically important, but the package should avoid embedding a single lab’s analysis assumptions too early.

## Import strategy

### First-class route: exported data into R

The package should help users get into R quickly from whatever import route they already trust.

Document simple snippets for:

- Python `tdt.read_block()` exports;
- MATLAB `TDTbin2mat()` exports;
- TDT/Synapse/OpenScope CSV or ASCII export, where available.

The R package can then read the exported stream/event files and provide a good analysis workflow.

### Why this is acceptable

This package does not need to solve every binary import problem on day one.

A useful first version can provide:

- clear object model;
- reliable event alignment;
- trial extraction;
- simple importers;
- examples showing users how to export into those simple importers.

That is enough for many labs to adopt the package for analysis while preserving the option of better import backends later.

## Example export snippets to document

These are not necessarily package code. They are documentation snippets to help users move data into R.

### Python to CSV, small or moderate streams

```python
import tdt
import pandas as pd

block_path = "path/to/block"
store = "Wav1"

data = tdt.read_block(block_path, evtype=["streams", "epocs"], store=store)

s = data.streams[store]

# Convert to samples x channels for tdtr.
# Python tdt stream arrays are often channel x samples.
stream_df = pd.DataFrame(s.data.T)
stream_df.to_csv(f"{store}_stream.csv", index=False)

# Example epoc export.
# Replace "EpocStore" with the actual event store name.
e = data.epocs["EpocStore"]
epoc_df = pd.DataFrame({
    "store": "EpocStore",
    "onset": e.onset,
    "offset": e.offset,
    "value": e.data
})
epoc_df.to_csv("epocs.csv", index=False)
```

R side:

```r
block <- new_tdt_block(
  streams = list(
    Wav1 = read_stream_csv("Wav1_stream.csv", fs = 1017.252, name = "Wav1")
  ),
  epocs = read_epocs_csv("epocs.csv")
)
```

### Python to binary plus metadata, larger streams

For larger streams, CSV may be too slow and too large. A binary file plus JSON/CSV metadata can be more practical.

```python
import json
import tdt
import numpy as np

block_path = "path/to/block"
store = "Wav1"

data = tdt.read_block(block_path, evtype=["streams"], store=store)
s = data.streams[store]

# samples x channels
arr = np.asarray(s.data.T, dtype="float32")
arr.tofile(f"{store}_stream_f32.bin")

with open(f"{store}_stream_meta.json", "w") as f:
    json.dump({
        "name": store,
        "fs": float(s.fs),
        "n_samples": int(arr.shape[0]),
        "n_channels": int(arr.shape[1]),
        "dtype": "float32",
        "orientation": "samples_x_channels"
    }, f, indent=2)
```

R side:

```r
stream <- read_stream_binary(
  "Wav1_stream_f32.bin",
  fs = 1017.252,
  shape = c(n_samples = 100000, n_channels = 2),
  name = "Wav1",
  dtype = "float32"
)
```

### MATLAB to CSV

```matlab
block_path = 'path/to/block';
data = TDTbin2mat(block_path, 'TYPE', {'streams', 'epocs'}, 'STORE', 'Wav1');

% TDT/MATLAB stream data may be channels x samples.
% Transpose to samples x channels for tdtr.
writematrix(data.streams.Wav1.data', 'Wav1_stream.csv');

onset = data.epocs.EpocStore.onset(:);
offset = data.epocs.EpocStore.offset(:);
value = data.epocs.EpocStore.data(:);
store = repmat("EpocStore", numel(onset), 1);

T = table(store, onset, offset, value);
writetable(T, 'epocs.csv');
```

R side:

```r
stream <- read_stream_csv("Wav1_stream.csv", fs = 1017.252, name = "Wav1")
events <- read_epocs_csv("epocs.csv")

block <- new_tdt_block(
  streams = list(Wav1 = stream),
  epocs = events
)
```

## Tidyverse stance

Use `tibble` where it helps represent tabular event data.

Do not require the rest of the tidyverse.

Good uses of tibbles:

- epoc/event tables;
- block summaries;
- trial metadata;
- small/downsampled stream views;
- list-column trial outputs.

Bad uses of tibbles:

- automatically expanding raw high-frequency streams into one row per sample per channel;
- forcing all analysis into long-format tables;
- introducing `dplyr`/`tidyr` dependencies for small transformations that base R can handle.

Use plain functions and explicit arguments rather than NSE when possible. Use `rlang` only when it clearly simplifies a user-facing data-masking interface.

## CRAN/Bioconductor posture

Design the core package so it can plausibly pass CRAN checks:

- no Python required;
- no internet required in tests;
- no downloads during installation;
- small dependency tree;
- deterministic examples;
- tests using small fixtures and synthetic data.

Bioconductor may become appropriate later if the package adopts Bioconductor-style containers or workflows, but do not force that in the first version.

Avoid decisions that would make either path harder.

## Testing strategy

Use small, synthetic fixtures first.

Test invariants:

- `new_tdt_block()` produces valid structure;
- stream matrices are samples x channels;
- event onsets/offsets are numeric seconds;
- `ranges_from_epocs()` returns expected windows;
- `slice_stream()` returns expected samples;
- `slice_trials()` preserves trial order and dimensions;
- conversion from CSV/binary fixtures preserves shape and values.

No tests should depend on:

- internet access;
- live TDT hardware;
- Python;
- MATLAB;
- large raw TDT binary blocks.

If an optional bridge package is created, it can have separate tests that skip cleanly when Python or `tdt` is unavailable.

## Future optional Python bridge

If a Python bridge is added, prefer a companion package:

```r
tdtrpy
```

Bridge design principles:

- import Python `tdt` with reticulate;
- call Python only inside importer functions;
- immediately convert into `tdtr::tdt_block`;
- never expose live Python objects as the standard return value;
- avoid making the user manage Python unless they explicitly choose that route;
- skip tests when Python or the Python `tdt` package is unavailable.

Possible functions:

```r
read_tdt_block_python(path, store = NULL, t1 = 0, t2 = 0, ...)
read_tdt_sev_python(path, ...)
```

These functions should be framed as import conveniences, not as the center of the package.

## Future optional compiled backend

If a credible compiled TDT reader exists, consider wrapping it.

Possible integration options:

- Rcpp;
- cpp11;
- system library wrapper;
- separate backend package.

Do not implement the binary reader yourself unless the project scope changes dramatically.

A compiled backend should still return the same `tdt_block` object as every other importer.

## Non-goals for version 0.1

Do not implement:

- full TDT block binary parsing in R;
- Python function parity;
- public reticulate-backed Python object wrappers;
- Synapse HTTP client;
- UDP interfaces;
- real-time acquisition;
- BH32/APIStreamer/PynapseUDP equivalents;
- a plotting package;
- a full photometry statistical-analysis framework;
- a mandatory tidyverse pipeline.

## Initial development phases

### Phase 0: package scaffold

- `DESCRIPTION`
- `NAMESPACE`
- `R/constructors.R`
- `R/accessors.R`
- `R/import-csv.R`
- `R/import-binary.R`
- `R/ranges.R`
- `R/slice.R`
- `R/summary.R`
- `tests/testthat/`

### Phase 1: data model and importers

Implement:

```r
new_tdt_block()
validate_tdt_block()
read_stream_csv()
read_epocs_csv()
read_stream_binary()
```

### Phase 2: workflow helpers

Implement:

```r
as_ranges()
ranges_from_epocs()
slice_stream()
slice_trials()
align_to_events()
as_tibble_epocs()
as_tibble_stream()
```

### Phase 3: documentation examples

Write README examples for:

- Python export to R;
- MATLAB export to R;
- CSV/binary import;
- trial-aligned extraction;
- event-aligned summary.

### Phase 4: optional import backend decision

Decide whether to pursue:

- `tdtrpy` reticulate bridge;
- compiled reader wrapper;
- narrow native `read_sev()` only;
- no raw binary backend yet.

Do not start Phase 4 until the R data model is stable enough that every backend can target it.

## Codex guidance

When using Codex, keep tasks narrow.

Good prompts:

- “Implement `new_tdt_block()` and `validate_tdt_block()` according to `package-scoping.md`.”
- “Add `read_stream_csv()` and tests for samples-by-channels orientation.”
- “Implement `ranges_from_epocs()` and `slice_stream()` with tests.”
- “Write README snippets for Python/MATLAB export into `tdtr`.”

Bad prompts:

- “Port the TDT Python package to R.”
- “Implement `read_block()`.”
- “Match Python function signatures.”
- “Add reticulate wrappers for everything.”
- “Build a full photometry analysis package.”

## External context to keep in mind

TDT’s official MATLAB offline tools include `TDTbin2mat`, `TDTfilter`, and `SEV2mat`. The docs describe reading block files, selecting event types/stores/channels, using time windows, applying epoc filters, and reading SEV files. This supports the idea that import/filter/window workflows are central to TDT analysis.

TDT’s fiber photometry documentation points users to MATLAB and Python import routes and workbook examples, and also notes CSV/ASCII export resources. This supports documenting practical export-to-R snippets rather than trying to own every binary import path in version 0.1.

A quick ecosystem scan did not reveal an obvious, mature, standalone C++ TDT block reader ready to wrap. Existing third-party readers can have edge cases; for example, a public issue in `python-neo` described incorrect sampling rates/durations/no data for a particular SEV-backed TDT block. Treat any non-official parser as something to validate carefully before depending on it.

## One-sentence summary

Build `tdtr` as a small, pure-R, event-alignment and data-model package for TDT-style fiber photometry data; support exported/simple import paths first; keep reticulate or compiled raw-block readers as optional future backends that return the same pure R objects.
