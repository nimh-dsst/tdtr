A layered API is the low‑maintenance way to get both “Python speed” and “R ownership”

What you described—mirror the Python surface area and add R-first helpers—is a good framing, as long as you’re careful about what you promise to keep stable.

A clean approach is to separate the package into two (or three) layers:

Layer 0: Python-parity “compat” API (thin wrappers)

Goal: R users (and especially dual Python/R users) can translate docs/examples almost 1:1.

* Pros
    * Minimal logic in R (low maintenance)
    * Easy to keep in sync with the upstream Python package
    * Great for “I know TDT Python; let me do that from R”
* Cons
    * Not idiomatic R
    * Exposes Python-ish sharp edges (e.g., ranges shape expectations, NumPy dtype, etc.)
    * If you convert aggressively, you’ll hit the array-copy pitfalls

Implementation detail: these wrappers can mostly be reticulate calls with only small “adapter” code for argument shapes.

Layer 1: R-first “ergonomic” API (conversion + extraction tools)

Goal: make Pattern 1 feel less like “peeking through a window”, while still not forcing full conversion.

This layer is where you add:

* collect_*() / as_*() / pull_*() helpers (“give me the data, but only what I asked for”)
* photometry-friendly helpers (event-aligned slicing, downsampling, dF/F convenience, etc.)
* safer defaults that prevent users from accidentally copying gigabytes into R

Optional Layer 2: tidyverse-facing view helpers (tibbles)

Goal: make epocs/events feel like normal tidy data and integrate with dplyr workflows.

Key point: tibbles are great for epocs; dangerous for raw streams unless you downsample or window.


Pattern 1: keep arrays in Python (default for large streams)

To make this not feel like “peeking through glass”, give users:

* good print/summary methods (fs, nchan, duration, store names)
* easy “extractors” (e.g., streams(block), epocs(block), stream(block, "Wav1"))
* “compute in Python, return small result” helpers (e.g., downsampled signal or summary stats)

One important caveat from reticulate’s docs:

* NumPy → R copies always happen, and can lead to multiple copies in memory.  
    So you want Pattern 1 as a first-class workflow for big signals.

Also important for API design:

* reticulate warns that Python objects don’t persist across R sessions; if you save an R object pointing to a Python object and reload it, it becomes a null external pointer unless you “collect” it.  
    This strongly argues for an explicit collect()/materialize() escape hatch.

Pattern 2: “escape hatch” conversion (opt-in)

You’re right: R users will want this, and it’s good product design to provide it.

But because conversion is expensive, you can keep it safe by:

* making full conversion explicit (collect = TRUE, or into = "r")
* encouraging users to specify store, t1/t2 or ranges, and channels when they convert
* optionally warning (or requiring confirmation) if the object size exceeds some threshold

This is also where you can decide what “R-native” means:

* matrix (channels × samples) is the most honest representation
* or a tibble with list-column data (matrix) plus metadata

Pattern 3: selective reads / workflow-aligned extraction (often best for photometry!)

You asked when Pattern 3 is better: photometry is one of the best cases for it, because so much analysis is event-aligned.

Pattern 3 wins when:

* recordings are long (tens of minutes to hours)
* sampling rate is high enough that raw arrays are big
* analyses are per-trial / per-event (peri-event windows)
* you don’t need the full continuous signal in memory at once

What makes Pattern 3 extra compelling here is that TDT’s reader supports time filtering (t1/t2, ranges, store, channel, etc.), so you can avoid reading most of the file at all.

So yes: the interface you expose can be much more usable than “pass a weird ranges matrix”.

Example of the concept (not final API design):

* read just epocs into a tibble
* compute trial windows in R (easy with tidyverse)
* ask Python read_block(..., ranges = windows, store = "Wav1")
* return either:
    * python arrays per trial (fast, memory-light), or
    * R matrices per trial (escape hatch), or
    * a downsampled tidy tibble per trial (for plotting)




Alternative package scope/prompt:

You are a coding agent. Build an R package that wraps Tucker-Davis Technologies’ Python package `tdt` (version >= 0.7.3) for offline reading and filtering of TDT tank/block data for fiber photometry workflows.

SCOPE / GOALS
- Must-have features only:
  1) reticulate-backed wrappers for Python:
     - tdt.read_block()
     - tdt.read_sev()
     - tdt.epoc_filter()
  2) explicit conversion helpers so R users can “own” data when they want (escape hatch), without forcing giant array copies by default.
  3) light “Pattern 3” helpers to make event-aligned / time-window extraction ergonomic in R (without exposing Python’s awkward ranges shape).

NON-GOALS (do NOT implement)
- No Synapse HTTP client in this iteration.
- No UDP / APIStreamer / BH32 / PynapseUDP.
- No native binary parsing in R (do not rewrite TDTbin2py; use Python).
- No tidyverse dependency stack (no dplyr/tidyr/ggplot2/cli).
- No Rust / Rcpp.

DEPENDENCY CONSTRAINTS
- Imports: reticulate, tibble, rlang (only if needed; prefer base R).
- Suggests: testthat (and any minimal testing helper like withr if truly necessary).
- Avoid purrr unless you can justify it as “trivial and clearly beneficial”; default to base R (lapply/Map/etc).

RETICULATE BEST PRACTICES (MUST FOLLOW)
- Declare Python requirements using reticulate::py_require(), typically in .onLoad().
- Use reticulate::import(..., delay_load = TRUE) for the Python module so:
  - The R package loads even if Python / tdt is not installed.
  - Users can choose their Python before first actual use.
- Default to convert = FALSE when importing Python modules / returning Python objects (Pattern 1).
- Be robust to Python objects not persisting across sessions:
  - If you create S3 wrappers holding Python objects, protect print/summary with py_is_null_xptr().
- Tests must be skipped when Python or `tdt` is unavailable (py_module_available()).

PACKAGE STRUCTURE
- Use standard R package layout:
  - DESCRIPTION, NAMESPACE, R/*.R, tests/testthat/*, man/* (roxygen)
  - Keep code organized into: R/python.R, R/readers.R, R/collect.R, R/ranges.R, R/print.R, R/zzz.R

PYTHON MODULE LOADER (INTERNAL)
- Create a private package env (e.g., .pkg_env <- new.env(parent = emptyenv())) holding:
  - .pkg_env$tdt (the imported python module proxy)
- In .onLoad():
  - reticulate::py_require("tdt>=0.7.3")
  - .pkg_env$tdt <- reticulate::import("tdt", delay_load = TRUE, convert = FALSE)
- Implement internal helper:
  - tdt_py() -> returns .pkg_env$tdt (and errors with a helpful message if unavailable)

CORE WRAPPERS (PYTHON-PARITY “COMPAT” API)
Export these (names are tentative; keep them stable and documented):

1) read_block_py(block_path, ..., .convert = FALSE)
- Calls tdt$read_block() with arguments matching Python signature as closely as reasonable in R:
  bitwise="", channel=0, combine=NULL, headers=0, nodata=FALSE,
  ranges=NULL, store="", t1=0, t2=0, evtype=NULL, verbose=0,
  sortname="TankSort", export=NULL, scale=1, dtype=NULL, outdir=NULL,
  prefix=NULL, outfile=NULL, dmy=FALSE, noepocauto=FALSE
- Always returns a Python object (convert = FALSE), wrapped in a small S3 container:
  structure(list(py = <python_struct>, path = block_path, args = <list>),
            class = "tdt_block_py")

2) read_sev_py(sev_dir, ...)
- Mirror Python args: channel=0, event_name="", t1=0, t2=0, fs=0,
  ranges=NULL, verbose=0, just_names=FALSE, export=NULL, scale=1,
  dtype=NULL, outdir=NULL, prefix=NULL
- Return python object wrapper class "tdt_sev_py".

3) epoc_filter_py(data, epoc, values=NULL, modifiers=NULL, t=NULL, tref=FALSE, keepdata=TRUE)
- `data` should accept either:
  - a tdt_block_py wrapper, or
  - a raw python object returned by read_block_py
- Returns python object wrapper class "tdt_block_py" (filtered).

USER-FACING ESCAPE HATCHES (PATTERN 2)
Provide explicit conversion functions (do NOT silently convert big arrays by default):

A) collect_block(x, streams=TRUE, epocs=TRUE, snips=FALSE, scalars=FALSE,
                 stores=NULL, max_bytes_warn=500*1024^2, quiet=FALSE)
- Input: tdt_block_py or python object.
- Output: pure R list (safe to saveRDS) with structure:
  list(
    streams = named list of streams (each stream is list(fs=..., data=matrix/array/vector, start_time=..., name=...)),
    epocs   = named list of epocs (each epoc is tibble OR list; see below),
    info    = (optional) small metadata
  )
- Before converting any numpy array, estimate size using numpy array’s `nbytes` if accessible.
  - If > max_bytes_warn and quiet=FALSE, emit a warning explaining conversion copies data into R.
- Keep conversion deterministic and documented.

B) collect_stream(x, store, ..., as=c("matrix","numeric","list"), include_time=FALSE)
- Convert exactly ONE stream store’s data to R.
- Must accept `store` as either:
  - the sanitized key used by tdt StructType, OR
  - the original store name in the `.name` field.
- Return:
  - matrix [nchan x nsamples] when multi-channel
  - numeric vector when single channel (unless as="matrix" forces matrix)
  - include fs + start_time + channel list if available

C) collect_epocs(x, store=NULL, as=c("tibble","list"))
- Default as="tibble" (we allow tibble).
- Return a tibble with minimally: store, onset, offset, value
  - Include notes if present (as list-column or character where possible).
- If store=NULL, return either:
  - a single tibble with all epocs stacked (store column identifies), OR
  - a named list of tibbles (choose whichever is simpler and stable; document it).

PATTERN 1 “WINDOW INTO PYTHON” QUALITY OF LIFE
- Implement:
  - print.tdt_block_py(): show:
    - path
    - available store names (original `.name`), grouped by type (streams/epocs)
    - for streams: fs, nchan, approx duration if derivable from data length and fs (do not force conversion)
  - summary.tdt_block_py(): same but more verbose
- Must handle py_is_null_xptr(x$py) gracefully and print a message if stale.

PATTERN 3 (WORKFLOW HELPERS) — ERGONOMIC RANGES
The Python API expects `ranges` as a 2 x N numeric array (each column is [start; stop]).
R users will naturally have N x 2 (rows are windows) or data.frames.

Implement:
1) as_ranges(ranges)
- Accept:
  - numeric length-2 vector: c(start, stop) => 2x1 matrix
  - matrix/data.frame with columns start/stop (N x 2) => transpose to 2 x N
  - matrix already 2 x N => keep
- Validate numeric, finite where appropriate; allow Inf for stop.

2) ranges_from_epocs(epocs_tbl, pre, post, onset_col="onset", drop_negative=TRUE)
- Build 2 x N ranges aligned to each onset:
  start = onset + pre; stop = onset + pre + post
- Drop negative starts if drop_negative=TRUE
- Return 2 x N numeric matrix (R).

3) read_stream_ranges_py(block_path, store, ranges, channel=0, ...)
- Uses read_block_py(..., evtype=c("streams"), store=store, ranges=as_ranges(ranges))
- Returns a tdt_block_py wrapper.
- Users can then call collect_stream() to get:
  - if ranges has multiple windows, Python returns a list of arrays; provide a helper:
    collect_stream_windows(x, store, as="list_of_matrices")
  - Make sure this works and is documented.

TESTING (testthat)
- Provide robust skip helpers:
  - skip_if_no_python(): skip if reticulate can’t initialize python
  - skip_if_no_tdt(): skip if !py_module_available("tdt")
- Tests MUST NOT download demo data.
- Instead, create a minimal synthetic python object to test conversions:
  - Use reticulate to run small Python code that constructs a `tdt.StructType()` with:
    - streams: one store with fs=100.0 and data = numpy array shaped (2, 10)
    - epocs: one store with onset/offset/value arrays
  - Verify:
    - collect_stream returns correct dims and numeric type
    - collect_epocs returns tibble with expected columns
    - as_ranges converts Nx2 to 2xN correctly

DOCUMENTATION
- Use roxygen2 for exported functions.
- Add a README with:
  - How to pick/configure Python env (reticulate conventions)
  - Pattern 1 example (py object, summary/print)
  - Pattern 2 example (collect_stream / collect_epocs)
  - Pattern 3 example (ranges_from_epocs + read_stream_ranges + collect_stream_windows)
- Include a clear warning that converting numpy arrays into R always copies data and can be large; recommend windowing/downsampling before collecting.

DELIVERABLES / ACCEPTANCE
- Package loads cleanly even if Python/tdt not installed (because delay_load).
- When Python/tdt is installed, wrappers function and conversions work.
- R CMD check (local) should pass with tests skipped when python unavailable.
- Code should be clean, modular, and low maintenance.

You may inspect the provided Python source (tdt 0.7.3) to confirm argument names and behaviors, especially:
- `tdt/TDTbin2py.py` (read_block, read_sev)
- `tdt/TDTfilter.py` (epoc_filter)
