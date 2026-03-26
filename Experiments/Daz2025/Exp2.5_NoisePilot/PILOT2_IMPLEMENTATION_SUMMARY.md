# Pilot 2 Implementation Summary

## Completed Implementation

### Files Modified/Created:

1. **TrialMatrixSeq3way_HomoInte.m** - Completely rewritten for Pilot 2
   - Function name changed to `TrialMatrixSeq3way_HomoInte`
   - New condition structure: Baseline, Homo_Space, Homo_Time, Homo_SpaceTime
   - Handles noise levels (Low/High) as part of condition
   - Set sizes: N=2, N=6
   - For homogeneous: R = N (full redundancy)

2. **NoisePilot_HomoInte.m** - Updated design specification
   - Changed ItemNList to [2 6]
   - Added NoiseLevels = {'low', 'high'}
   - Added BaselineReps = 60, HomoReps = 20
   - Updated function call to `TrialMatrixSeq3way_HomoInte`

## Condition Implementation Details

### 1. Baseline
- **Structure**: All unique items (R=0)
- **Presentation**: Sequential ACW (N intervals)
- **Set sizes**: N=2, N=6
- **Noise**: Low, High
- **Trials**: 60 per N×Noise = 240 total

### 2. Homo_Space
- **Structure**: All same hue (R=N), simultaneous
- **Presentation**: Single interval, all items shown at once
- **Set sizes**: N=2, N=6
- **Noise**: Low, High
- **Trials**: 20 per N×Noise = 80 total
- **SegmentOrder**: `{1:N}` (one segment with all items)
- **Locations**: N evenly spaced positions

### 3. Homo_Time
- **Structure**: All same hue (R=N), sequential same location
- **Presentation**: N intervals, all items at same spatial location
- **Set sizes**: N=2, N=6
- **Noise**: Low, High
- **Trials**: 20 per N×Noise = 80 total
- **SegmentOrder**: N segments, all pointing to same location index
- **Locations**: All items at same angle

### 4. Homo_SpaceTime
- **Structure**: All same hue (R=N), sequential ACW different locations
- **Presentation**: N intervals, ACW progression
- **Set sizes**: N=2, N=6
- **Noise**: Low, High
- **Trials**: 20 per N×Noise = 80 total
- **SegmentOrder**: N segments, ACW order
- **Locations**: N evenly spaced positions, rotated

## Design Structure

The design structure now requires:
```matlab
design.ItemNList    = [2 6];
design.NoiseLevels  = {'low', 'high'};
design.BaselineReps = 60;
design.HomoReps     = 20;
design.PracticeReps = 0;
design.presDur      = 0.15;
design.retDur       = 0.75;
design.SegmentDur   = 0.15;
design.ISI          = 0.15;
```

## Trial Counts

- **Baseline**: 2 (N) × 2 (Noise) × 60 = 240 trials
- **Homo-Space**: 2 (N) × 2 (Noise) × 20 = 80 trials
- **Homo-Time**: 2 (N) × 2 (Noise) × 20 = 80 trials
- **Homo-SpaceTime**: 2 (N) × 2 (Noise) × 20 = 80 trials
- **Total**: 480 trials

## Notes

1. **NoiseLevel**: Set per trial based on condition (stored in table)
2. **Colors**: For homogeneous conditions, all items get same hue (R=N means all redundant)
3. **Cue Type**: All conditions use 'NR' (no meaningful cue distinction for homogeneous)
4. **Target**: For homogeneous, randomly select any item (all identical)
5. **Presentation**: Current code should handle simultaneous (Homo_Space) since `DrawStimulusSegment` accepts vectors

## Testing Recommendations

1. Verify trial counts match expected totals
2. Check that Homo_Space shows all items simultaneously
3. Verify noise levels are correctly assigned (Low vs High)
4. Confirm locations are evenly spaced for all conditions
5. Test that Homo_Time uses same location for all intervals

