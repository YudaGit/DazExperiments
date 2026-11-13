# Reorganization completed — 13 November 2026

## Changes

- Root `README.md` replaces the master as the authoritative overview, incorporating all four H3 routes and corrected AQ H1/H2 evidence. The previous master is preserved exactly in `history`; its old path is a navigation stub. The operational stage note links to the overview and retains run history.
- Added model dictionary, current research/audit plans, decision log and manuscript foundation/evidence map. The detailed POP interpretation remains open, with the investigator's view and the distinction in Oberauer's equations recorded.
- Added an explicit 11-route canonical manifest with descriptive IDs, H aliases, layout versions, data/fit/summary hashes, correction notes and validation status. Added 55-record saved-fit comparison, historical result index, data snapshot and current source/MEX snapshot. Current hashes do not establish fit-time provenance.
- Moved four legacy/reference folders under `Legacy`, preserving internal assets and updating navigation in three route notes. Active `POPvJPvCauchy` and all fit paths remain unchanged.
- Moved previous active figures under `Figures/Exploratory` with bytes preserved. Added a provisional H3/H2 BIC candidate in PNG/PDF and a 25-row source table. Existing parameter-comparison exports remain historical until deliberately regenerated from canonical vectors.
- Replaced aggregate wildcard selection in three plotters with the canonical manifest resolver. Added exact source provenance exports and fresh timestamped replay folders, preserving development figures. Updated other figure generators for the Exploratory location.
- Replaced the missing hardcoded data default with explicit-path/environment configuration and ancestor repository discovery. Filtering, units and prepared data contents remain unchanged.

## Verification performed

- Python index regeneration checked all 55 canonical CSV/MAT scalar records to 1e-7 tolerance. HC H0's saved objective includes approximately 0.0013714 penalty; other checked objective penalties are negligible at that tolerance. No signed forward NLL was recomputed.
- Verified 435 migrated/protected tracked files against their original Git blob identities. 432 match exactly; the only three differences are intentional legacy route-note navigation changes. This includes preservation of the archived master, fit files, numerical cores, MEX binaries, prepared data and migrated figures. See `migration_manifest.csv`.
- MATLAB R2024b resolved all 11 routes by both H alias and descriptive ID. It selected the corrected H2 merged aggregate and rejected an unknown route.
- MATLAB preparation from the relocated repository raw CSV, with saving disabled, reproduced the frozen prepared data **exactly**, including all 22,460 retained trials.
- All three saved-prediction plotters completed: 5 H1 marginal figures, 5 best-H1/H2 figures and 25 QVWM figures, with three provenance CSVs. The original and corrected H2 aggregates coexist without ambiguous selection.
- MATLAB syntax checks passed for edited/new MATLAB functions; final result-selection checks followed the last cleanup. MATLAB startup required execution outside the restricted sandbox; the authorized validation completed successfully.
- Current overview, stage, dictionary, plan and manuscript navigation links were checked. Historical snapshots retain historical reference context as documented. The new H3/H2 graphic was visually inspected.

## Limits and next work

This verifies organization, saved-file consistency, exact data replay and plotting execution. It does **not** validate the C-core numerics, source/MEX equivalence, conditional-density provenance or psychological identification. Production C files and MEX binaries were not changed; no likelihood optimization or new model fits were performed.

Follow `numerical_audit.md` for measured saved-vector/core checks and `research_plan.md` for subsequent common-architecture front-end and allocation tests. Drafting can begin in parallel using the provisional evidence map. No manuscript prose was drafted in this cleanup.
