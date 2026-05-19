# tdtr 0.0.0.9000

* Adds a layered reticulate-backed interface for Python `tdt>=0.7.3`.
* Adds Python-backed wrappers, generic accessors, explicit collection helpers,
  range helpers, and simple CSV/binary importers.
* Removes lab-specific extraction workflows from the exported package surface.
* Adds a vignette explaining which interface layer to use and reticulate gotchas.
* Adds optional development scripts for downloading the official TDT demo data
  and profiling R/Python memory behavior during collection.
* Adds `tdtr_example_block`, a small materialized package dataset derived from
  the official TDT example data.
