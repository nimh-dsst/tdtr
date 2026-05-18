# Package Scoping: tdtr

Working package name: **`tdtr`**

This document records the current scope for `tdtr`: an R package that gives
scientists a clean R interface for working with Tucker-Davis Technologies (TDT)
tank/block data while avoiding a high-maintenance native R binary parser.

## Decision Snapshot

Build a **single R package** with:

- Python `tdt`/`reticulate` as the practical raw TDT backend for the
  foreseeable future;
- an explicit Python-backed compatibility layer for users who need control over
  large data and reticulate conversion behavior;
- R-friendly accessors, summaries, and collection helpers layered on top of
  Python-backed objects;
- ordinary R objects for materialized streams, epocs/events, metadata, and
  bounded table views;
- event-aligned, trial-aligned, and windowed analysis helpers for downstream R
  workflows;
- simple importers for exported CSV/binary data;
- a small dependency footprint where feasible.

Do **not** implement full TDT binary parsing in R unless the project scope
changes substantially.

Do **not** add Synapse HTTP/API client work, UDP interfaces, live acquisition,
or lab-specific extraction workflows to the core package.

## Naming

Use `tdtr`.

The all-lowercase name is easier to type, works cleanly in URLs and filesystem
paths, and follows common modern R package conventions.

Use clean public function names. Normal use will look like:

```r
tdtr::read_block()
tdtr::stream_names()
tdtr::epocs()
tdtr::collect_stream()
```

The package namespace is enough to avoid ambiguity; do not make every R-facing
function name cumbersome solely to repeat `tdt`.

For direct Python-compatibility wrappers, prefer names that make the return type
obvious. If a high-level R helper and a Python-parity wrapper would otherwise
share a name, use a `_py` suffix for the Python-backed wrapper:

```r
read_block()
read_block_py()
read_sev_py()
epoc_filter_py()
```

If a Python `tdt` function can be exposed directly without creating ambiguity,
matching the Python function name is acceptable.

## Public Interface Philosophy

The public API should be layered. It should let an R user work productively
without learning reticulate internals, while still letting Python/R developers
avoid unnecessary NumPy-to-R copies and build pipelines that keep large arrays
in Python until they intentionally collect them.

### Layer 0: Python-Backed Compatibility

This layer exposes selected Python `tdt` functionality through reticulate with
minimal R adaptation.

Expected early functions:

```r
read_block_py()
read_sev_py()
epoc_filter_py()
```

These functions return small S3 wrappers around Python objects, such as
`tdt_block_py`, rather than aggressively converting streams into R memory.
Print and summary methods must be useful and must handle stale Python external
pointers gracefully.

### Layer 1: R-Friendly Accessors

This layer works on Python-backed wrappers and collected R objects:

```r
block_info()
stream_names()
streams()
stream()
epocs()
epoc_names()
epoc()
```

Accessors should return small R values where practical, but they must avoid
silently copying large stream arrays into R.

### Layer 2: Explicit Collection And Views

This layer materializes data into ordinary R objects when the user asks for it:

```r
collect_block()
collect_stream()
collect_epocs()
as_tdt_block()
as_tibble_epocs()
as_tibble_stream()
```

Collection should be explicit, documented, and guarded with size-aware warnings
where large NumPy arrays would be copied into R.

Good public return values:

- `tdt_block_py` S3 wrappers around live Python objects for low-level work;
- `tdt_block` S3 objects;
- lists;
- matrices;
- numeric vectors;
- data frames/tibbles for events, summaries, and bounded table views.

Avoid accidental or ambiguous return values such as:

- unwrapped `python.builtin.object` values from high-level helpers;
- unwrapped `python.builtin.dict` values from high-level helpers;
- NumPy arrays that users need to handle directly unless they explicitly asked
  for the Python-backed layer;
- hidden full-stream conversion in convenience functions.

Python objects are allowed as part of the explicit compatibility layer. R-native
objects remain required for saved analysis state, downstream R workflows, and
users who want to own the data in R.

## Relationship To Python `tdt`

Python `tdt` is the intended near-term backend for raw tank/block import.

Reasons:

- TDT binary formats have enough edge cases that a homegrown parser would be a
  large maintenance burden.
- The available development effort is better spent on clean R objects,
  validation, accessors, and analysis workflows.
- Users need useful access to tank data now, not a long binary-parser project.

Implementation rules:

- Use Python `tdt >= 0.7.3`.
- Follow current reticulate package guidance:
  - declare the Python requirement with `reticulate::py_require("tdt>=0.7.3")`,
    typically in `.onLoad()`;
  - import `tdt` with `reticulate::import("tdt", delay_load = TRUE,
    convert = FALSE)`;
  - let `library(tdtr)` load before Python is initialized so users can configure
    their Python environment before first use.
- Python-backed functions should fail early with clear diagnostics if Python,
  reticulate, or Python `tdt` cannot be used.
- The package should not feel like a working installation with missing core
  functionality. Provide explicit availability checks, diagnostic helpers, and
  direct error messages for Python-backed entry points.
- Default to `convert = FALSE` for Python imports and wrappers.
- Avoid converting NumPy arrays into R unless the user calls an explicit
  collection or view helper.
- The repository pixi environment is the supported dependency-management path
  during early development.
- Error messages should clearly explain how to install/configure Python `tdt`.

## No Companion Package For Now

Do not create a separate `tdtrpy` package at this stage.

A split package might become useful later, but it would add coordination and
user-facing complexity before there is enough user feedback to justify it.
Keeping one package is acceptable as long as the Python-backed layer is explicit
and the R-friendly layer does not force users to handle reticulate objects
unless they choose that level of control.

## Core Data Model

Use S3 classes around ordinary R structures.

```r
tdt_block <- list(
  info = list(
    source = NULL,
    block_path = NULL,
    subject = NULL,
    experiment = NULL,
    start_time = NULL,
    duration = NULL,
    metadata = list()
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

This object model is the target for materialized R data:

- `collect_block()` / `as_tdt_block()` from a Python-backed block;
- CSV/binary export import;
- future compiled reader import, if one becomes credible.

It is not required that every read operation immediately materialize this full
object, because doing so can force expensive array copies for large streams.

## Stream Orientation

Use one R-native orientation everywhere:

```r
nrow(data) == number of samples
ncol(data) == number of channels
```

This differs from some Python/MATLAB conventions, but it is natural for R:

- rows are observations over time;
- columns are channels;
- bounded table views can be created predictably;
- sample indices exposed to users should be 1-based.

Importers should transpose data when needed and record source metadata when
useful.

## Time Conventions

Use seconds relative to block start.

- `onset`: seconds from block start
- `offset`: seconds from block start
- `t0`: stream start time, seconds from block start
- `fs`: samples per second

Avoid exposing binary-reader-specific file offsets or hidden coordinates as
ordinary user-facing fields.

## Epocs And Events

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

Values should remain flexible. Numeric values are common, but textual or coded
events should not be ruled out.

## In Scope

### Constructors And Validators

```r
new_tdt_block(info = list(), streams = list(), epocs = NULL)
validate_tdt_block(x)
is_tdt_block(x)
```

### Accessors

Use clean names. Package namespacing handles ambiguity for normal use.

```r
block_info(x)
streams(x)
stream_names(x)
stream(x, name)
epocs(x)
epoc_names(x)
epoc(x, store)
```

### Tank/Block Import

Public tank/block import is in scope.

The friendly default read path should avoid accidental full conversion. A
reasonable target is:

```r
read_block(path, ..., collect = FALSE)
```

where `collect = FALSE` returns a Python-backed `tdt_block_py` wrapper and
`collect = TRUE` returns a materialized `tdt_block`.

The explicit Python-parity wrapper should remain available:

```r
read_block_py(path, ...)
```

Both paths call Python `tdt.read_block()` through `reticulate`.

The wrapper should match Python argument names as closely as is reasonable in R,
including store, channel, time range, event type, and export arguments. R-only
helpers should make common workflows easier without obscuring the underlying
Python behavior.

### Python `tdt` Coverage

Expose as much offline Python `tdt` functionality as practical when it can be
wrapped thinly and tested.

Early targets:

```r
read_block_py()
read_sev_py()
epoc_filter_py()
```

Additional Python functions can be added when they are stable, offline, and do
not pull the package toward Synapse APIs, live streaming, UDP, hardware control,
or a broad maintenance promise for the entire Python package.

### Tank Extraction

Tank extraction is in scope when it is generic.

Generic extraction means:

- read a block/tank;
- select stores by name/type/channel/time;
- return an R object or write a documented R-friendly export;
- avoid lab-specific directory structures, naming rules, and subject conventions.

Not generic:

- project-specific analysis directories;
- lab-specific subject parsing;
- hard-coded TTL/isobestic/experimental store assumptions;
- writing `DO_NOT_USE.json` markers as a package-level behavior.

Possible interfaces:

```r
extract_stores(block, stores, ...)
write_tdt_export(block, path, ...)
```

If an extraction function reads directly from disk, it should still return or
write R-native structures rather than exposing Python objects.

Initial write formats should support simple, durable outputs first:

- RDS for lossless R-native objects and metadata;
- CSV/JSON for interoperability and inspection.

Apache Arrow/Parquet may be valuable for larger continuous streams because it is
columnar, efficient, and cross-language. Treat Arrow as a format to evaluate,
not as a required core dependency until there is a clear need. If added, prefer
keeping `arrow` in `Suggests` and making Arrow export optional.

### Importers For Exported/Simple Formats

```r
read_tdt_export(path, ...)
read_stream_csv(path, fs, name, channels = NULL, t0 = 0, ...)
read_epocs_csv(path, ...)
read_stream_binary(path, fs, shape, name, dtype = "float32", t0 = 0, ...)
```

These importers are important because some users will arrive with data exported
from Python, MATLAB, Synapse/OpenScope, or another trusted route.

### Coercion And Table Views

```r
as_tdt_block(x, ...)
collect_block(x, ...)
collect_stream(x, store, ...)
collect_epocs(x, store = NULL, ...)
as_tibble_epocs(x, store = NULL)
as_tibble_stream(x, stream, window = NULL, downsample = NULL, max_rows = NULL)
```

Avoid accidentally expanding huge high-frequency streams. If a conversion could
create a very large table, require a window, downsampling, or an explicit
override.

### Ranges And Trial Helpers

```r
as_ranges(x)
ranges_from_epocs(epocs, pre, post, onset_col = "onset", drop_negative = TRUE)
slice_stream(x, stream, range, channels = NULL)
slice_trials(x, stream, ranges, channels = NULL)
align_to_events(x, stream, events, pre, post, channels = NULL)
```

These are central to the package. They are more important than matching Python
function signatures.

### Conservative Photometry Helpers

Potential early additions:

```r
baseline_correct(x, baseline)
summarize_trials(x, fun = mean, ...)
downsample_stream(x, stream, factor = NULL, fs = NULL)
```

Be cautious with dF/F, isosbestic correction, regression correction, and other
scientific analysis choices. They are important, but the package should avoid
embedding a single lab's analysis assumptions too early.

## Out Of Scope

Do not implement:

- full TDT block binary parsing in R;
- blind Python function parity for the whole `tdt` package;
- Synapse HTTP client;
- UDP interfaces;
- real-time acquisition;
- live streaming;
- BH32/APIStreamer/PynapseUDP equivalents;
- plotting as a core package responsibility;
- full photometry statistical-analysis framework;
- mandatory tidyverse pipelines;
- project-specific extraction workflows;
- lab-specific tank-name parsing in the core API.

## Dependency Posture

Keep dependencies small where practical.

Likely acceptable:

- base R;
- `tibble`;
- `reticulate` in `Imports` for Python-backed tank/block import;
- `rlang` only where it improves errors or a user-facing interface enough to
  justify the dependency;
- `jsonlite` only for JSON metadata/export helpers that remain in scope;
- `testthat` in `Suggests`.

Avoid unless clearly justified:

- `dplyr`;
- `tidyr`;
- `purrr`;
- `ggplot2`;
- `cli`.

Potential optional dependencies:

- `arrow`, if large-stream export/import benefits justify the dependency and
  installation cost.

Use base R for straightforward transformations.

## CRAN/Bioconductor Posture

The package is not targeting CRAN or Bioconductor in the near term because
Python `tdt` is an essential runtime dependency for raw tank/block access. It
should still follow CRAN/Bioconductor conventions where practical: ordinary R
objects, deterministic tests, small examples, clear errors, and no installation
side effects.

Design rules:

- follow reticulate's `py_require()` and `delay_load` pattern so package load
  does not initialize Python prematurely;
- Python-backed functions may require Python and Python `tdt`;
- tests that require Python `tdt` should skip cleanly when unavailable;
- installation should not download data;
- examples should be deterministic and small;
- binary import examples should be guarded or documentation-only unless fixtures
  are small and reliable;
- materialized analysis objects should be ordinary R objects that can be saved
  and restored;
- Python-backed wrapper objects should document reticulate's stale external
  pointer behavior and offer explicit collection for durable state.

Bioconductor may become appropriate later if the package adopts
Bioconductor-style containers or workflows. Do not force that in the first
version.

## Testing Strategy

Use small synthetic fixtures first.

Test invariants:

- `new_tdt_block()` produces valid structure;
- Python-backed import returns a valid `tdt_block_py` wrapper;
- explicit collection returns `tdt_block`, not unwrapped Python objects;
- stream matrices are samples x channels;
- event onsets/offsets are numeric seconds;
- accessors return stable structures;
- `ranges_from_epocs()` returns expected windows;
- `slice_stream()` returns expected samples;
- `slice_trials()` preserves trial order and dimensions;
- CSV/binary import preserves shape and values;
- Python-backed code fails clearly when Python `tdt` is unavailable;
- print/summary methods handle stale Python external pointers.

Use a two-tier fixture strategy:

- synthetic Python objects created in tests for fast, deterministic conversion
  and accessor coverage;
- one or more small real TDT datasets, if a license-compatible public fixture
  can be found from DANDI, TDT, or another reliable source.

Add targeted profiling before committing to helpers that might copy large stream
arrays across the R/Python boundary.

No required tests should depend on:

- internet access;
- live TDT hardware;
- MATLAB;
- large raw TDT binary blocks.

## Development Phases

The exact order can change when implementation details make another path more
natural, but the package should converge on this shape.

### Phase 0: Scope And Scaffold

- update package documentation to this scope;
- remove or internalize public project-specific and lab-specific assumptions;
- decide which existing code is retained as internal backend code.

### Phase 1: R Data Model

Implement:

```r
new_tdt_block()
validate_tdt_block()
is_tdt_block()
print.tdt_block()
summary.tdt_block()
```

### Phase 2: Python-Backed Import Layer

Implement:

```r
read_block()
read_block_py()
read_sev_py()
epoc_filter_py()
tdt_available()
tdt_config()
```

Use reticulate `py_require()` and delayed imports.

### Phase 3: R Collection And Simple Importers

Implement:

```r
collect_block()
collect_stream()
collect_epocs()
read_stream_csv()
read_epocs_csv()
read_stream_binary()
```

Collection functions materialize ordinary R objects and should warn before
large copies when sizes can be estimated.

### Phase 4: Accessors And Views

Implement:

```r
block_info()
streams()
stream_names()
stream()
epocs()
epoc_names()
epoc()
as_tibble_epocs()
as_tibble_stream()
```

### Phase 5: Workflow Helpers

Implement:

```r
as_ranges()
ranges_from_epocs()
slice_stream()
slice_trials()
align_to_events()
```

### Phase 6: Documentation Examples

Write examples for:

- reading a TDT block through the package;
- Python-backed import diagnostics;
- keeping large arrays in Python until explicit collection;
- Python export to R;
- MATLAB export to R;
- CSV/binary import;
- event-aligned extraction;
- trial-level summaries.

## External Source Context

Developers may keep a local copy of Python `tdt` source under `external/` for
reference while designing converters and import behavior. Treat it as untracked
local reference material, not package code.

Do not vendor or execute that source as part of the R package unless a later
decision explicitly changes this.

## One-Sentence Summary

Build `tdtr` as a reticulate-backed R package for TDT tank/block access:
explicit Python-backed wrappers for control and scale, R-friendly helpers for
normal use, and ordinary R objects whenever users intentionally collect data.
