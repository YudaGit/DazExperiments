# Cauchy-CDM modelling route

This folder contains a nine-condition wrapped-Cauchy circular diffusion model for the Redundancy 2024 data. It preserves the current POPCDM decision skeleton while replacing the POP/Gumbel front layer with across-trial wrapped-Cauchy variability in latent drift direction.

## Fixed theoretical specification

- Jones–Pewsey shape is **compiled at ψ = −1** in `vjp300rot.c`.
- The compiled MEX interface has no ψ argument and therefore cannot estimate another shape accidentally.
- σ is fixed at 1.
- η₂ is fixed at `exp(−6)` by the H0 model.
- Three drift norms are grouped by set size: S2, S4, and S6.
- η₁, boundary a, ter, and st are shared across all conditions.
- Nine κ values are condition-specific.

H0 has 16 free parameters:

`v_S2, v_S4, v_S6, η1, a, ter, κ_1 ... κ_9, st`

Bounds follow the supplied JP-CDM example rather than the POPCDM boxes: v `[0,7.5]`, κ `[0,7.5]`, η₁ `[0.01,4]`, a `[0.5,5]`, ter `[0,1.5]`, and st `[0,0.7]`. The example's formal η lower bound is zero; this implementation uses `0.01` because the forward model applies that numerical floor internally.

## Build environment

- MATLAB R2024b
- Microsoft Visual C++ 2022 Build Tools
- GSL 2.8 installed by vcpkg under `C:\vcpkg`
- Static libraries from the `x64-windows-static` triplet

Build or rebuild:

```matlab
cd CauchyJP
mex -setup C
build_cauchycdm_mex
validate_cauchycdm
```

GSL is GPL-3.0-or-later. The local static-linked MEX is suitable for this research workspace, but redistribution of the binary must comply with GSL’s license.

## When recompilation is required

Recompile after changing:

- `vjp300rot.c`;
- compiled ψ or the wrapped-Cauchy formula;
- fixed grid constants such as 50 angular rows, 300 time points, or 21 latent phase-angle steps;
- compiler or linked GSL libraries.

Do **not** recompile when changing fitted runtime parameters: vnorm, κ, η₁, η₂, phase, σ, boundary, ter, or st. MATLAB passes those values to the existing MEX binary on every model call.

## Fitting

Smoke test:

```matlab
output = run_cauchycdm_fit("smoke");
```

Full fit:

```matlab
output = run_cauchycdm_fit("full");
```

or edit and run `cauchy_fit_H0.m`.

Full mode uses the POPCDM settings: 16 custom bounded `fmincon` starts, interior-point algorithm, 2,000 maximum iterations, 20,000 maximum function evaluations, and `1e−6` stopping tolerances. The target IDs are AQ, ES, HC, PG, and YL; trials with missing response error or RT outside 300–3000 ms are removed.

Starts run across seven workers when Parallel Computing Toolbox is available, the largest process pool verified to start reliably on this machine. Optimization Toolbox supplies `fmincon`; Global Optimization Toolbox is installed but the fitter retains the same explicit custom-start procedure used by the POPCDM route.

The MATLAB wrapper operates on the complete angle-by-RT density matrix. Uniform nondecision-time convolution uses `conv2` across all response-angle rows in one operation, while trial likelihoods are obtained by one vectorized `interp2` call per condition. Parameter expansion in the repeated H0 objective uses numeric indexing; labelled tables are created only for saved reports. On AQ at the H0 starting vector, a complete nine-condition objective evaluation takes approximately 0.104 s, of which the compiled diffusion core accounts for about 82%. Further MATLAB-only vectorization therefore has limited potential without changing the numerical model or its grid.

The results file is checkpointed after every participant. Rerunning the same fit resumes from completed participants after verifying that the saved parameter names and bounds match the current model.

## Diagnostics

Full fits automatically save four figures and a proportion CSV per participant:

- observed/model response-error densities;
- observed/model RT densities;
- central, shoulder, and tail angle proportions;
- RT proportions in fixed bins from 0.3 to 3 seconds.

Replay a saved fit without optimization:

```matlab
plot_saved_cauchycdm_results
plot_saved_cauchycdm_results( ...
    "CauchyFits/cauchycdm_H0_full_results.mat", "YL")
```

`validate_cauchycdm.m` checks MEX availability, finite and near-unit joint mass, symmetry, expected κ/tail ordering, matrix-convolution equivalence to the supplied row-wise implementation, rejection of the obsolete ψ input, and cached-call speed.

`ensure_cauchycdm_mex.m` runs automatically before fitting and validation. It rebuilds when the MEX file is missing or older than `vjp300rot.c`, preventing stale compiled assumptions from entering a fit.
