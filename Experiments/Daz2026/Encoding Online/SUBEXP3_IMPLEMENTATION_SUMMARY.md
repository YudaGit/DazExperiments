## Sub-Experiment 3 Implementation Summary

This document consolidates the Sub-Experiment 3 implementation details that were previously spread across multiple step files.

### Scope
- Stimuli: colored orientation bars (0–180° orientations)
- Task: cue color, report orientation via center bar rotation
- Design: set sizes 4 and 6; trial types Baseline, R-cue, NR-cue; durations from `expt_config.py`

### Core JS Changes (`confidencewheel.js`)
- **Stimulus type switch**: supports `stimulus_type: 'orientation_bars'` to render colored orientation bars instead of patches.
- **Orientation bar response**: supports `response_type: 'orientation_bar'`, with mouse up/down rotation and click to confirm.
- **Error calculation**: shortest-path error in 0–180° space (wrapped to -90°..+90°).
- **Feedback**: response bar (white) and target bar (green outline).
- **Visual mask**: `show_mask: true` draws a dense array of random colored orientation bars during retention.

### Visual Specifications
- **Bar length**: `2 * patchRadius`
- **Bar width**: `barLength * (1.5 / 7)`
- **Positions**: same ring as color patches (`patch_positionalangle`)
- **Orientation range**: 0–180°

### Timeline Structure (`templates/exp.html`)
**Practice trials**
1. Trial advance button
2. Fixation (1s)
3. Orientation bars display
4. Retention interval with visual mask (750ms)
5. Orientation bar response

**Main trials**
1. Trial advance / feedback plot
2. Fixation (1s)
3. Orientation bars display
4. Retention interval with visual mask (750ms)
5. Orientation bar response

### Data Recorded (key fields)
- `orientations` input array from Python (per-item orientations)
- `target_orientation` (target item)
- `response_degrees`
- `response_error_deg` (wrapped shortest path)
- `points` (accuracy score)
- `trial_condition` (Baseline / R-cue / NR-cue)

### Testing
- Run with `?subexp=3` to force assignment.
- Verify bars render, mask appears, response rotates, feedback shows correct target.
