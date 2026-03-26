Experiment
Task: Colour report with noisy 10×10 tile squares on a ring; set sizes 1, 2, 6; Baseline vs Homo_Space; low/high noise; odd sessions = deterministic sampling, even = statistical (Von Mises).
Main data: `<experiment folder>\Data\SvDProper_<ID>_sess<n>_<timestamp>.mat` (path from `getExperimentDataDir()` next to `NoisyPilot_SvDProper.m`) — **`expTrials`** (table), **`V`** (PTB/layout), **`P`** (noise κ, `samplingMode`, flags), **`design`** (reps, durations), **`sessionN`**, **`participantID`**, **`timestamp`** (self-contained for analysis if `V` defaults change).
Practice: 5 trials/session, template in `TrialMatrixSeq3way_SvDProper.m` → `buildPracticeSvD` (not saved); optional stimulus snaps under `Data\StimulusSnaps\...\Practice\` if enabled.
Trial table (TrialMatrixSeq3way_SvDProper.m)
CueType: 'R' for Homo_Space (RedundantN>1), 'NR' otherwise.
ArrayRotationDeg: random 0–359 per trial; StimulusLocations stay canonical; screen uses mod(canon + ArrayRotationDeg, 360).
printTrialBalance: includes CueType counts.
Stimulus / layout (adjustSquareStim, calibration)
calibrateMonitor: credit-card width → px/mm; 5° reference at CALIB_VIEWING_DISTANCE_MM = 600; pxPerDeg = VA5deg/5.
Square: STIM_SIDE_DEG = 1° (side); STIM_RING_RADIUS_DEG for centre ring (tuned for “array inside ~5°” vs earlier ~4.75° — user adjusted after testing).
Wheel annulus moved outside the stimulus ring so it doesn’t overlap squares.
V.layout.*: logs degrees used (square side, ring radius, wheel annulus, etc.).
Behaviour fixes (earlier in thread)
CueType was all 'NR' → fixed in trial matrix.
Deterministic patterns looked like a gradient → quantile order + shuffle; then per-item instanceId so redundant items don’t look identical.
Statistical session crash: ~isempty(TileRGB{1}) was true for nan → tightened precompute check; GetResponse(expTrials(ii,:)) after TargetHue update.
GetResponse orientation branch: `precision` wrap typo fixed (`precision - 360`).
Pilot script: `DebugNoPTB` / `DebugSkipInstructions` default **false** for real runs; `P.DebugDrawNoiseLevel` gates per-segment noise fprintf.
Timing (main loop `runSvDProperTrialBlock`): editable at top of script as `design.presDur` / `design.retDur` / `design.ISI`, then copied into **`V.Durations.PresentationDuration`**, **`V.Durations.RetentionDuration`**, **`V.Durations.InterSegmentInterval`** after `initiate()` (defaults also in `StimulusDurations`). Trial table **no longer** has `presDur`/`retDur` columns. Sequence: fixation `V.Durations.FixationDuration` (1 s) → per segment: `Flip` (stim) → `WaitSecs(PresentationDuration)` → optional snap → mask `Flip` → `WaitSecs(InterSegmentInterval)` if another segment → after last segment: mask `Flip` → `WaitSecs(RetentionDuration)` → response. Stimulus snaps run after presentation duration so file I/O does not lengthen on-screen time. `WaitSecs` = wall clock; legacy `V.Durations.StimulusDuration` (vector) / `MaskDuration` are not used for this pilot block.
Sampling (theory)
- **Deterministic (odd session):** same Von Mises quantile multiset for given (base hue, κ, N); spatial order shuffled deterministically per `instanceId` — reproducible across runs.
- **Statistical (even session):** independent draws per item/trial — different subsets each run for same base hue; **within-trial** mean offset ~0 in expectation; **homogeneous** trials use mean of item means → pooled mean toward shared base hue **tighter** for larger N (e.g. 6 vs 2 redundant) by averaging.
Key files
NoisyPilot_SvDProper.m — main script, runSvDProperTrialBlock, drawing, effectiveStimulusAzimuthsDeg, getArrayRotationDeg.
TrialMatrixSeq3way_SvDProper.m — design, practice block, ArrayRotationDeg, enrich, addSequenceOrderSvD.
Distinctions to remember
WheelRotation / V.color.rotation: session, colour wheel.
ArrayRotationDeg: per trial, rotates stimulus ring on screen; saved in dataframe.