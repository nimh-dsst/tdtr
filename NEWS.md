# tdtr 0.0.3

Initial reticulate-backed package direction.

* Uses Python `tdt>=0.7.3` through `reticulate` as the raw TDT tank/block
  backend.
* Adds Python-backed wrappers for `read_block()`, `read_sev()`, and
  `epoc_filter()` workflows.
* Adds R-friendly accessors for block metadata, stream names, event names, and
  individual stream/event stores.
* Adds explicit collection helpers for converting selected Python-backed data
  into ordinary R objects.
* Adds range helpers for event-aligned and bounded reads.
* Normalizes high-level `read_block()` store filters so sanitized stream names
  such as `_465A` can be used for read-time selection.
* Adds `profile_tdt_memory()` for local memory/copy diagnostics.
* Includes a small raw TDT example block under `inst/extdata`, accessed with
  `tdtr_example_block_path()`.
* Adds getting-started and advanced-usage vignettes.
* Keeps Synapse API work, live acquisition, native R binary parsing, and
  lab-specific analysis conventions out of scope for the core package.
