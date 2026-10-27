# Archived first-study analyses

The active analysis is `../s1_smallN_analysis_discrete.Rmd`. This folder
preserves older analyses and their outputs without deleting the research
record. The full notebook immediately before the 29 September 2026 cleanup
is `s1_smallN_analysis_discrete_full_2026-09-29.Rmd`.

- `s1_smallN_analysis.Rmd`, `compare_session_cont_vs_disc.R`,
  `fit_bayes_primary_*.R`, `bayes_primary/`, and the root-level `.rds` files:
  earlier absolute-error and circular-SD regressions and session structures.
- `s1_mixture_*.R`, `mixture_cells/`, `mixture_regression/`, and
  `bayes_primary_discrete/`: exploratory per-cell mixtures, bootstrap and
  κ-tied comparisons, and older circular-SD summaries.
- `s1_vm_ladder_ml.R`: earlier maximum-likelihood ladder exploration.
- `S1_analyses.R` and `current_review/`: the temporary standalone audit
  created on 29 September; its BIC and cached LOO checks informed the root
  work note. The R Markdown notebook is the main pipeline.
- `S1_analysis_workspace.RData`, `.RDataTmp`, `.Rhistory`, and `Rplots.pdf`:
  historical interactive workspace and incidental plot output.
- `WORK_NOTE_discrete_pipeline.md`: detailed September 1 analysis note.
- `descriptive_figures_previous/`: earlier PDF exports and the separate
  signed-error raw-data figure from the descriptive figure iterations.

These files retain their original relative paths and are **not** expected
to run directly from this archive directory. To reproduce an archived
pipeline, use a separate checkout or restore its scripts and output folders
to their former locations under `AnalysesR` first. No raw or model-ready
participant data were moved here.
