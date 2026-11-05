# Study 2 consistency notes

Reference: Enc_smallN_2nd/Exp1_Encoding2nd_Final.m (unchanged).

Original click-to-continue instructions, layout, per-trial precision plot,
TrackMouse, wheel/neutral-wheel drawing, OKLab conversion, gamut clipping,
fixation and feedback markers/arc are retained or adapted to mapping data.
Stable mode uses the original oval primitive and mouse-polling approach.
The original one-based palette convention is preserved.

Settings follow the original design block, StimulusDurations(v), initiate()
and adjustStim() organisation. At the user's request, mapping trial counts
are direct PracticeTrialN/MainTrialN totals, not repetitions. Defaults remain
36 practice and 540 main trials. Hashes, reference paths, version labels and
duplicate saved-setting aliases added during review have been removed.

Mapping-specific differences remain: one visible target with the wheel,
optional three-second pixel decay, five-second deadline, per-trial rotation,
no memory/mask/cue stages or initial-movement penalties, and per-trial saving.
Decay rendering can delay mouse samples; exact temporal equivalence to the
original static response screen is not claimed. Source capture and saved
session/design/display data remain for interpreting collected data.

Static checks found no changes to task routines during the settings cleanup.
Trial-count construction was checked for equal/as-equal-as-possible hue counts
at totals 0, 1, 35, 36, 37, 100 and 540. MATLAB/Psychtoolbox execution and lab
responsiveness/timing remain unverified here.
