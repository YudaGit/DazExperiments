# Examples

`TeamReference` holds the supplied example material, kept separate from the
active Re2024 fitting workflow.

- `TeamReference/Scripts`: reference wrappers, model-comparison plotting
  functions, and their figure/settings helpers.
- `TeamReference/Data`: the accompanying small `.mat` example datasets.

From the `POPvJPvCauchy` folder, make the reference scripts available in a
MATLAB session with:

```matlab
addpath(fullfile(pwd, "Examples", "TeamReference", "Scripts"));
```

The Re2024 wrappers, fitting runner, MEX cores, prepared data, diagnostics,
figures, and `TestFits` remain at the project root. The shared `label.m` and
`setfig4.m` helpers also remain there because active QVWM diagnostics use them.
