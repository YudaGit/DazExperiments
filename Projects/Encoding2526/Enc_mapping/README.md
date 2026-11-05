# Additional colour mapping session

Run Exp1_Encoding2nd_Final.m from Enc_mapping in MATLAB/Psychtoolbox.
The reference is Enc_smallN_2nd/Exp1_Encoding2nd_Final.m.

## Settings

At the top of the script:

- design.PracticeTrialN = 36: total practice trials.
- design.MainTrialN = 540: total main trials.
- design.SeedHues = 0:10:350: nominal target labels.
- design.DecayEnabled = true: pixel decay; false gives the stable original oval.

Counts are direct totals. Hues are balanced equally where possible; for totals
not divisible by 36, counts differ by at most one, with extra hues randomised.
Use zero practice trials to skip practice trials.

As in the original, edit timing in StimulusDurations(v), apparatus/colour
settings in initiate(), and visual-angle geometry in adjustStim(). All timing
values are seconds. Current defaults are unchanged: fixation 1, feedback 0.75,
timeout penalty 2, response deadline 5, decay 3, practice colour reset 0.005.

## Controls and saved data

Left click advances instructions and the original per-trial performance plot.
Ctrl+L aborts. Responses end on the first sampled inner-wheel crossing.

MappingData/mapping_ID_sN_TIMESTAMP.mat contains practiceTrials, expTrials,
config and sessionComplete. config stores session information, Design,
Display and the two source scripts. Timing is in config.Display.Durations.
No reference hashes or extra provenance fields are used.

The original one-based palette lookup is preserved. Nominal label 10 displays
RGB hue 9; nominal 0 corresponds to original label 360 and displays hue 359.
TargetRGBHueDeg records that physical palette hue. Earlier zero-based mapping
pilots differ by one degree and should not be silently pooled.

Stable mode uses original oval rendering and approximately 10-ms polling.
Decay mode uses integer pixels and refresh-driven redraws. The existing
Study 2 display-sync bypass is retained. MATLAB/lab testing remains required.
