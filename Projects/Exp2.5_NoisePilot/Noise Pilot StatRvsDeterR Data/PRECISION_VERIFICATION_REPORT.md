# Precision Verification Report

## Summary

**The stored `Precision` column represents: `baseHue - ResponseAngle` (NOT `TargetHue - ResponseAngle`)**

## Verification Results

### Method Comparison
- **Method 1 (TargetHue - ResponseAngle)**: 
  - yD: 0 mismatches (perfect match)
  - yS: 680 mismatches (all yS trials)
  - Reason: For yD, meanOffset = 0, so TargetHue = baseHue, making Methods 1 and 2 equivalent

- **Method 2 (baseHue - ResponseAngle)**: 
  - **ALL trials (yS + yD): 0 mismatches (perfect match)**
  - This is what the stored Precision actually represents

### Root Cause

The bug is in `NoisyPilot_StatRvsDeterR.m`:

1. **Line 199-200**: `targetHue` is computed and stored in `expTrials.TargetHue(ii)`, but **NOT** in `tr.TargetHue`
2. **Line 217**: `GetResponse(tr, wheelTex)` is called with `tr` (the trial struct)
3. **Line 1005-1009 in GetResponse**: Checks for `trial.TargetHue`, which doesn't exist in `tr`, so it falls back to `trial.Colors{1}(trial.Target)` (the base hue)

**The fix would be to add `tr.TargetHue = targetHue;` after line 199, before calling GetResponse.**

## Implications

### For yD (Deterministic) Data:
- **No impact**: meanOffset = 0, so TargetHue = baseHue
- Stored Precision = baseHue - ResponseAngle = TargetHue - ResponseAngle ✓

### For yS (Statistical) Data:
- **Impact**: meanOffset ≠ 0, so TargetHue ≠ baseHue
- Stored Precision = baseHue - ResponseAngle ≠ TargetHue - ResponseAngle ✗
- The stored Precision does NOT account for the mean offsets that were applied to the target hue

## New Precision Columns

Given this finding:

- **Precision_Col1** = stored Precision - meanOffset = (baseHue - ResponseAngle) - meanOffset
  - This removes the meanOffset effect from the stored Precision
  - For Baseline: subtracts meanOffset of the target item
  - For Homo_Space: subtracts mean(meanOffsets) of all items

- **Precision_Col2** = baseHue - ResponseAngle
  - This is identical to the stored Precision (0 mismatches)
  - Represents response error from the true base hue

### Comparison Results
- **yD trials**: Precision_Col1 = Precision_Col2 (because meanOffset = 0)
- **yS trials**: Precision_Col1 ≠ Precision_Col2 (differ by meanOffset)
- This is expected and correct behavior

## Recommendation

The stored `Precision` column should ideally represent `TargetHue - ResponseAngle` to reflect the actual target hue that participants saw. However, since the data has already been collected, we can work with the current stored values and use `Precision_Col1` when we need to account for mean offsets.
