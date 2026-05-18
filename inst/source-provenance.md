# Source Provenance

The initial package API was derived from the reusable TDT extraction work in:

* `/Users/johnlee/code/ArchiveFlowR/legacy/R/photometry_helpers.R`
* `/Users/johnlee/code/ArchiveFlowR/legacy/R/mod_manual_extraction.R`
* `/Users/johnlee/code/ArchiveFlowR/legacy/R/mod_experiment_status.R`
* `/Users/johnlee/code/initial-archiveflowr/R/photometry_helpers.R`
* `/Users/johnlee/code/initial-archiveflowr/R/mod_manual_extraction.R`
* `/Users/johnlee/code/initial-archiveflowr/R/mod_experiment_status.R`
* `/Users/johnlee/code/ArchiveFlow-1-pixi/ArchiveFlowR/R/mod_manual_extraction.R`
* `/Users/johnlee/code/ArchiveFlow-1-pixi/ArchiveFlowR/R/mod_experiment_status.R`
* `/Users/johnlee/code/ArchiveFlow-1/archiveflow/tejeda_schemas.py`
* `/Users/johnlee/code/ArchiveFlow-1/archiveflow/app_extraction.py`
* `/Users/johnlee/code/ArchiveFlow-1/pages/2_Experiment_Status_and_Batch_Processing.py`
* `/Users/johnlee/code/ArchiveFlow-1/pages/3_Manual_Extraction.py`

The ArchiveFlow R helper files in `ArchiveFlowR/legacy/R` and
`initial-archiveflowr/R` were identical at extraction time. The Python
Streamlit implementation was used to cross-check behavior for tank parsing,
completed tank detection, stream formatting, and batch extraction.
