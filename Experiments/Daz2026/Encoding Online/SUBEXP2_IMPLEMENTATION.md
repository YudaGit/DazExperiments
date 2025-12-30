# Sub-Experiment 2: Context Effect Hypothesis - Implementation Summary

## Overview

Sub-Experiment 2 investigates how context uncertainty (multiple set-sizes and conditions) affects encoding precision. This document summarizes the implementation.

## Design Parameters

- **Set-sizes**: 4 and 6
- **Trial types**: 
  - Baseline: All unique items (no redundancy)
  - R-cue: Cue a redundant item for report
  - NR-cue: Cue a non-redundant item for report
- **Presentation durations**: 50ms, 100ms, 200ms (3 levels)
- **Redundancy levels**:
  - Set-size 4: 2 redundant items
  - Set-size 6: 3 redundant items
- **Conditions**: 2 set-sizes × 3 trial types × 3 durations = **18 conditions**
- **Trials per condition**: 10
- **Total trials**: 180 main trials + 5 practice trials
- **Randomization**: Fully randomized across all conditions

## Implementation Details

### Python Backend (`expt_config.py`)

#### Functions Added:

1. **`prepare_subexperiment_2()`**
   - Main function that generates all trials for Sub-Exp 2
   - Creates all 180 main trials (18 conditions × 10 reps)
   - Generates 5 practice trials with balanced distribution
   - Returns dictionary with trials, practice_trials, and metadata

2. **`generate_single_trial_subexp2(set_size, redundant_n, duration_ms, trial_type)`**
   - Generates a single trial with specified parameters
   - Handles Baseline trials (all unique colors, no redundancy)
   - Handles R-cue and NR-cue trials (with redundancy)
   - Selects target based on trial type

3. **`generate_unique_colors(set_size, min_spacing=30)`**
   - Generates all unique colors with minimum spacing constraint
   - Used specifically for Baseline trials
   - Ensures ≥30° spacing between all colors

4. **`generate_practice_trials_subexp2()`**
   - Generates 5 practice trials
   - Ensures balanced distribution:
     - 2 trials with set-size 4, 3 trials with set-size 6
     - At least one of each trial type (Baseline, R-cue, NR-cue)

### Key Differences from Sub-Exp 1

| Aspect | Sub-Exp 1 | Sub-Exp 2 |
|--------|-----------|-----------|
| **Set-sizes** | 6 only | 4 and 6 |
| **Trial types** | R-cue, NR-cue | Baseline, R-cue, NR-cue |
| **Durations** | 7 levels (50-350ms) | 3 levels (50, 100, 200ms) |
| **Baseline trials** | No | Yes (all unique colors) |
| **Total trials** | 140 | 180 |

### JavaScript Frontend (`templates/exp.html`)

#### Changes Made:

1. **Added Sub-Experiment 2 timeline building**
   - New `else if (subexperiment == 2)` block
   - Handles practice and main trials for Sub-Exp 2
   - Uses `trial_type` instead of `cue_type` (Baseline, R-cue, NR-cue)

2. **Trial Data Structure**
   - Uses `trial.trial_type` instead of `trial.cue_type`
   - Handles variable set-sizes (4 or 6)
   - Baseline trials have `redundant_n = 0` and `is_redundant_target = false`

3. **Redundancy Handling**
   - Baseline trials: `redundancy = 0` (no redundancy)
   - R-cue trials: `redundancy = 1` (target is redundant)
   - NR-cue trials: `redundancy = 0` (target is non-redundant)

## Trial Structure

### Baseline Trials
- **Colors**: All unique (no duplicates)
- **Redundancy**: None (`redundant_n = 0`)
- **Target**: Any item (all are unique)
- **Redundancy flag**: `is_redundant_target = false`

### R-cue Trials
- **Colors**: Contains redundant items (2 for set-size 4, 3 for set-size 6)
- **Redundancy**: Present
- **Target**: One of the redundant items
- **Redundancy flag**: `is_redundant_target = true`

### NR-cue Trials
- **Colors**: Contains redundant items (2 for set-size 4, 3 for set-size 6)
- **Redundancy**: Present
- **Target**: One of the non-redundant items
- **Redundancy flag**: `is_redundant_target = false`

## Verification

### Trial Counts (Verified)
- ✅ Total trials: 180
- ✅ Practice trials: 5
- ✅ Baseline trials: 60 (20 per set-size)
- ✅ R-cue trials: 60 (20 per set-size)
- ✅ NR-cue trials: 60 (20 per set-size)
- ✅ Set-size 4: 90 trials
- ✅ Set-size 6: 90 trials

### Trial Generation (Verified)
- ✅ Baseline trials have all unique colors
- ✅ Baseline trials have `redundant_n = 0`
- ✅ R-cue and NR-cue trials have correct redundancy
- ✅ Target selection matches trial type
- ✅ Color spacing constraints enforced (≥30°)
- ✅ Position spacing correct (evenly spaced)

## Testing Checklist

- [ ] Practice trials display correctly
- [ ] Main trials display correctly
- [ ] Baseline trials show all unique colors
- [ ] R-cue trials highlight redundant target
- [ ] NR-cue trials highlight non-redundant target
- [ ] Set-size 4 trials show 4 patches
- [ ] Set-size 6 trials show 6 patches
- [ ] Variable durations work (50, 100, 200ms)
- [ ] Response collection works
- [ ] Data saved includes all trial parameters

## Files Modified

1. **`expt_config.py`**
   - Added `prepare_subexperiment_2()`
   - Added `generate_single_trial_subexp2()`
   - Added `generate_unique_colors()`
   - Added `generate_practice_trials_subexp2()`

2. **`templates/exp.html`**
   - Added Sub-Experiment 2 timeline building logic
   - Handles Baseline, R-cue, and NR-cue trial types
   - Supports variable set-sizes (4 and 6)

## Next Steps

1. Test Sub-Experiment 2 in browser
2. Verify Baseline trials display correctly (all unique colors)
3. Verify R-cue and NR-cue trials work correctly
4. Verify variable set-sizes display correctly
5. Check data collection includes all fields

