# Exp3 additional colour mapping session

Run `Exp1_Encoding2nd_Final.m` in MATLAB with Psychtoolbox installed, with
`Enc_mapping` as the current folder. The entry filename is retained from the
copied Exp3 script; it now runs mapping only.

## Pilot settings

Edit the `config` block near the top of the script:

- `DecayEnabled = true`: cumulative random pixel removal; set false for stable.
- `DecayDuration = 3.0`: linear removal, fully gone at three seconds. This is
  an initial pilot setting, not a fitted or empirically selected decay rate.
- `MainReps = 15`: 540 scheduled main trials, 15 for each of 36 hues.
- `PracticeReps = 1`: 36 practice trials, saved separately.
- `ResponseDeadline = 5.0`: unanswered trials terminate with a two-second
  too-slow feedback display. There is no too-fast penalty.

Target and wheel appear together. The mouse starts centrally; as in Exp3,
the first sampled cursor crossing of the inner wheel radius finalises the
response (no click). Target location is independently randomised around the
original stimulus ring on each trial; wheel rotation is independently random
on each trial. The original OKLab map, gamut clipping, stimulus radius,
eccentricity, wheel dimensions, and fixation are retained. No sample/mask/
retention stages occur. Ctrl+L aborts; SPACE advances instructions and breaks.

The target is an integer-pixel disk. Its pixels are randomly ordered once
per trial. Each refresh draws only the surviving suffix in one DrawDots call;
removed pixels stay at the background colour. No colour interpolation or
pixel resampling is used. Decay is based on elapsed display time. Check the
appearance and missed-frame counts on the lab apparatus before collecting data.

## Saved data

`MappingData/mapping_ID_sN_TIMESTAMP.mat` is updated after every completed
trial, using a temporary MAT file before replacing the checkpoint. It contains
`practiceTrials`, `expTrials`, `config`, and `sessionComplete`. An interrupted
trial is left uncompleted. Unrun rows remain present with `Completed = false`.

Trial columns:

- `Trial`, `TargetHueDeg`, `TargetLocationDeg`, `WheelRotationDeg`, `DecaySeed`.
- `TargetX`, `TargetY`: actual integer screen coordinates.
- `OnsetSecs`: Psychtoolbox onset timestamp.
- `ResponseTimeMs`: time from simultaneous onset; 5000 for timeout.
- `ResponseScreenAngleDeg`, `ResponseHueDeg`: raw screen angle and angle
  corrected once for wheel rotation.
- `SignedErrorDeg`: **target minus response**, wrapped to [-180, 180), as in
  Exp3. Hue zero is the first entry in the original colour map.
- `VisibleFraction`: fraction of target pixels on the last displayed frame.
- `MissedFrames`: number of late flips during the response loop.
- `TimedOut`, `Completed`: distinguish timeouts, valid responses, and unrun rows.

Participant/session metadata, apparatus, RGB map, configuration, source code,
and initial random-generator state are saved once in `config`. The removal
ordering can be recreated from each trial's `DecaySeed`. No orientation,
redundancy, set-size, cue-type, sample/retention-duration, demographic, or
mouse-trajectory columns remain. Timeouts are retained, not automatically
repeated: 15 scheduled presentations need not give 15 usable responses.
