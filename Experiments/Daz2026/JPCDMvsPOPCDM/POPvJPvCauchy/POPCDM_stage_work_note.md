# POPvJPvCauchy Stage Work Note

## Project Stage

This folder contains a new team-provided model asset package for comparing POP, Jones-Pewsey, and Cauchy front ends attached to a circular diffusion model (CDM) core. The immediate goal is to understand the provided fitting assets, learn the wrapper/fitting workflow, and then implement comparable wrappers for the Daz VWM continuous recall dataset.

For now, the C cores are left as provided, except that `vjp300rot.c` has already been updated manually to use `atan2` for the drift-angle vector function. Further C-core edits should wait until the total-mass indexing issue is clarified with the team.

## Contents And Roles

- `vpop300rot.c`: POP / population-code front end with fixed amplitude and Gumbel noise parameter `xi`.
- `vjp300rot.c`: Jones-Pewsey front end with free `psi`.
- `vcau300rot.c`: Wrapped Cauchy front end.
- `pgpop1.m`: POP likelihood wrapper for small range, `M = [1, 2, 3, 4]`.
- `pgpop1a.m`: POP likelihood wrapper for large range, `M = [1, 2, 4, 6]`.
- `vwmjp61.m`: JP likelihood wrapper for small range, `M = [1, 2, 3, 4]`.
- `vwmjp61a.m`: JP likelihood wrapper for large range, `M = [1, 2, 4, 6]`.
- `mvwm23.m`, `mvwm23a.m`: Marginal angle and RT plotting for four-condition fits.
- `qvwm23.m`: RT quantile-by-error diagnostic plot.
- `pgcomp26.m`: Comparison plot for two prediction structures.
- `setfig*.m`: Figure layout helpers.
- `pg32.mat`, `pg34.mat`: Saved JP/Cauchy-style fit assets from the team.
- `pgp2.mat`, `pgp4.mat`: Saved POP fit assets from the team.
- `Paul26a.mat`: Team dataset asset.
- `DazSecondTranche.txt`: Team notes and example commands/results.
- `totalmassDemo1.m`: Local demonstration script for checking C linear indexing.

## Data Mapping

The team notes identify Paul's multirange replication data as:

- `pga4`: small range experiment, corresponding to `M = [1, 2, 3, 4]`.
- `pga6`: large range experiment, corresponding to `M = [1, 2, 4, 6]`.

The likely wrappers are:

- `pgpop1.m` fits POP to `pga4`.
- `pgpop1a.m` fits POP to `pga6`.
- `vwmjp61.m` fits JP/Cauchy-style JP front-end models to `pga4`.
- `vwmjp61a.m` fits JP/Cauchy-style JP front-end models to `pga6`.

The `.mat` files appear to store example fitted parameter vectors and predictions:

- `pg32.mat`: JP/Cauchy constrained fit for small range.
- `pg34.mat`: JP/Cauchy constrained or free-Psi fit for large range.
- `pgp2.mat`: POP fit for small range.
- `pgp4.mat`: POP fit for large range.

This mapping should be verified by loading each `.mat` file and inspecting variable names before using these assets as templates.

## C-Core Architecture Notes

All three C cores share the same broad CDM architecture:

1. Approximate the front-end angular distribution using `njsteps = 21` latent drift-angle grid points.
2. Convert each latent angle into a 2D CDM drift vector.
3. Evaluate the CDM over a response/error grid with `nw = 50` angular bins plus one wraparound row.
4. Evaluate RT over `sz = 300` time bins.
5. Mix the CDM predictions across the 21 weighted latent drift directions.

The 21 latent drift-angle points are not random samples and are not the same as the 50 response-angle bins. They are an evenly spaced quadrature-like approximation to the front-end distribution.

The response grid has `nw + 1` stored rows because the final row duplicates the first row to close the circular domain for interpolation. This duplicate row should not be double-counted when integrating over unique angular bins.

## Important Numerical Clarifications

### `noise`

The `noise` argument in `bessel2` is not a psychological Gumbel/noise parameter. It is a numerical threshold for stitching together two approximations to the zero-drift first-passage-time density:

- `dhamana`: Bessel/eigenvalue-series solution.
- `dserafin`: short-time asymptotic approximation.

The code uses `dserafin` while the Bessel-series density is below the threshold, then switches to `dhamana`.

### `sz`

`sz` is the number of RT/time bins in the C core. In these files, `sz = 300`.

## Potential C-Core Issues To Revisit

### Total-Mass Indexing

The C code writes `Gt` as a matrix with `(nw + 1)` rows and `sz` columns:

```c
Gt[(nw + 1) * k + i] = ...
```

But in the `totalmass` block, it currently reads:

```c
Gt[nw * k + i]
```

The team correctly noted that the wraparound row should not be double-counted. That is handled by looping only over `i < nw`. The separate issue is the column stride. Since each stored time column has `nw + 1` rows, the column offset should still use `(nw + 1) * k` even when integrating only the first `nw` unique rows.

This should be clarified with the team before editing the model cores.

### Bounds Check In `while`

The current pattern:

```c
while (Gth[i] < noise && i < sz)
```

is not ideal because `Gth[i]` is evaluated before checking `i < sz`. A defensive version would be:

```c
while (i < sz && Gth[i] < noise)
```

This is probably not an active fitting problem if `noise` is tiny and `Gth` crosses it normally, but it is safer C.

## Wrapper Lessons For Daz Implementation

When writing the new Daz POPCDM wrapper:

- Keep parameter order explicit.
- Unpack named parameters immediately after building each condition vector.
- Preserve comparable condition structure across POP, JP, and Cauchy.
- Make sure `delta`, `Ter`, and `st` are read from their intended positions.
- Keep set-size-based RT parameterization in view, because earlier diagnostics showed RT is better organized by set size than by cue type or unique colour count.
- Treat team POP wrappers as useful learning examples, but do not copy their parameter indexing without checking.

## Suggested Learning Path

The best starting point for learning is `pgpop1.m`, because it is the POP wrapper for the simpler small-range case and has the same overall likelihood structure as `pgpop1a.m`.

After understanding `pgpop1.m`, compare it with `vwmjp61.m` to see which parts are generic CDM wrapper structure and which parts are POP-specific. Then adapt the pattern to the Daz dataset.
