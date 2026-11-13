# Legacy implementation stages

These folders were moved intact from the project root on 13 November 2026, apart from updated note navigation. They preserve earlier model implementations, fitted results and figures. They are not the active workflow.

| Folder | Role |
|---|---|
| `POPCDM_Matlab` | Earlier amplitude/floor POP fits, theory constraints, noise-partition and RT diagnostics |
| `JPCDM_Matlab` | Earlier free-shape JP fits and comparisons |
| `CauchyJP` | Earlier psi=-1 JP specialization, before the active team-Cauchy core |
| `Example Fitting Package` | Supplied diffusion fitting reference package |

See the [current overview](../README.md). Run an old entry point from its own directory only when reviewing that stage. Old absolute data paths and platform build assumptions remain historical; these stages were not revalidated by the move. No inspected active script depends on the old sibling locations. Avoid adding this whole tree to MATLAB's path because model cores and helper names overlap with active files.

Old notes' H0/H1 names, rankings and next-step proposals apply to their own stage. Historical master prose may use the former root locations; prepend `Legacy/` when locating those old assets. Supplied active `POPvJPvCauchy/Examples` remains at its original path.
