# Decisions and open interpretations

## 13 November 2026 — authorized project reorganization

- `README.md` replaces the master note as the authoritative project overview. The old master is preserved in full under `docs/history`; its former path is a navigation stub. The stage note remains operational and links to the overview.
- Maintain active `POPvJPvCauchy` and all canonical fit paths. Move prior implementation stages under `Legacy`, keeping their internal structures. Keep supplied fitting-package material separate from active analysis.
- Retain H labels as computational aliases. Introduce descriptive route names in the dictionary, manifest and reading material. Do not alter saved fit identities merely for clearer labels.
- Use explicit canonical paths in a CSV manifest. Preserve the original H2 aggregate and identify the corrected AQ-merged file explicitly. Record the later AQ H1 correction despite its older filename.
- Move development figures into `Figures/Exploratory`, updating generators. Curate provisional `ManuscriptCandidates` with source files and validation status. No existing figure becomes final through relocation.
- No production C edits, new likelihood conventions or optimization runs in this cleanup. Numerical audits and subsequent matched/allocation fits are ordered next work, with measured impact determining refits.

## Scientific framing from discussion

The memory-stage account is the central scientific question. A theoretically adequate front end should permit cleaner assessment of residual decision variability through joint error–RT fitting. Colour-dependent Ter baselines and cue deltas are promising evidence of interpretable experimental structure under Cauchy. They are not sufficient by themselves to prove the front end uniquely correct.

The investigator proposes that the psychological signal may be the log of tuning-plus-floor weights, viewing broad behavioural errors as incompatible with narrow VM variability alone. Preserve this as an open interpretation, not as an established description of Oberauer's equations.

Oberauer explicitly separates activation S from stochastic response selection. Independent Gumbel noise of scale one plus max selection gives exp(S_j)/sum exp(S_k). Current POP linear normalization w_j/sum w_k is equivalent if S_j=log(w_j), with w=VM+floor. Broad errors can arise through activation, stochastic selection or subsequent processing; their presence does not determine a unique scale or stage. The CDM composition makes that distinction scientifically relevant. Source: [Oberauer (2023), Eqs. 2–4](https://doi.org/10.1037/rev0000328).

Defer detailed POP work until the organizational changes are settled. Preserve both the implemented equation and the question of which intended comparator it represents. Do not change the core or retrospectively relabel historical fits as a different model.

## Still to decide

- Intended POP activation/selection equation and amplitude/floor parameterization.
- Numerical acceptance criteria and intended Ter/st convention after isolated audits.
- Common decision architectures for front-end comparison.
- Re2024 resource-to-dispersion law and its item/colour/multiplicity allocation.
- Validation dataset or held-out sessions and the scope of final claims.
