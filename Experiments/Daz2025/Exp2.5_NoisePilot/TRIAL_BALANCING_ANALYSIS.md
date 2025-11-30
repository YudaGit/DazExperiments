# Trial Balancing Analysis for Pilot 2

## Current Implementation

### Parameters:
- BaselineReps = 30
- HomoReps = 10
- ItemNList = [2 6]
- NoiseLevels = {'low', 'high'}

### Generated Trial Counts:
- **Baseline**: 120 trials (30 × 4 combinations)
  - N=2 Low: 30
  - N=2 High: 30
  - N=6 Low: 30
  - N=6 High: 30

- **Each Homo Condition**: 40 trials (10 × 4 combinations)
  - N=2 Low: 10
  - N=2 High: 10
  - N=6 Low: 10
  - N=6 High: 10

- **Total**: 240 trials

## Design Document Specification

According to PILOT_CONDITION_DESIGN.md:
- **Baseline**: 240 trials (60 × 4 combinations)
- **Each Homo Condition**: 80 trials (20 × 4 combinations)
- **Total**: 480 trials

## Analysis

### Current Balancing (240 trials):

**Pros:**
- ✅ Faster to run (half the time)
- ✅ Good for initial pilot testing
- ✅ Still balanced across conditions
- ✅ Sufficient for detecting large effects

**Cons:**
- ⚠️ Lower statistical power
- ⚠️ May miss smaller effects
- ⚠️ Less robust for noise level comparisons
- ⚠️ Comments don't match actual numbers

### Design Doc Balancing (480 trials):

**Pros:**
- ✅ Higher statistical power
- ✅ Better for detecting noise level effects
- ✅ More robust estimates
- ✅ Matches original design intent

**Cons:**
- ⚠️ Longer experiment duration (~2x)
- ⚠️ May be fatiguing for participants
- ⚠️ More data to collect

## Recommendations

### Option 1: Keep Current (240 trials) - **RECOMMENDED for initial pilot**
- **Rationale**: Good for initial testing, can always add more trials later
- **BaselineReps**: 30 (generates 120 trials)
- **HomoReps**: 10 (generates 40 each, 120 total)
- **Total**: 240 trials
- **Duration**: ~1-1.5 hours (estimate)

### Option 2: Match Design Doc (480 trials)
- **Rationale**: Better power, matches original design
- **BaselineReps**: 60 (generates 240 trials)
- **HomoReps**: 20 (generates 80 each, 240 total)
- **Total**: 480 trials
- **Duration**: ~2-3 hours (estimate)

### Option 3: Compromise (360 trials)
- **Rationale**: Balance between power and duration
- **BaselineReps**: 45 (generates 180 trials)
- **HomoReps**: 15 (generates 60 each, 180 total)
- **Total**: 360 trials
- **Duration**: ~1.5-2 hours (estimate)

## Statistical Power Considerations

For comparing noise levels (Low vs High):
- **240 trials**: ~30 per condition×noise combination
  - Power for medium effects: ~60-70%
  - Power for large effects: ~85-90%
  
- **480 trials**: ~60 per condition×noise combination
  - Power for medium effects: ~85-90%
  - Power for large effects: ~95%+

For comparing conditions (Baseline vs Homo):
- **240 trials**: Baseline=120, each Homo=40
  - Uneven comparison (3:1 ratio)
  - May want to balance better
  
- **480 trials**: Baseline=240, each Homo=80
  - Better balance (3:1 ratio maintained)
  - More comparable

## Suggested Improvements

### 1. Fix Comments
Update comments in NoisePilot_HomoInte.m to match actual values:
```matlab
design.BaselineReps = 30;  % 30 trials per N×Noise combination (120 total)
design.HomoReps     = 10;  % 10 trials per N×Noise combination per condition (40 each, 120 total)
```

### 2. Consider Balanced Design
If comparing Baseline vs Homo conditions is important, consider:
- Baseline: 40 reps (160 trials)
- Each Homo: 20 reps (80 each, 240 total)
- Total: 400 trials
- Better balance: 2:1 ratio instead of 3:1

### 3. Power Analysis
Before finalizing, consider:
- What effect sizes are you expecting?
- What's the minimum detectable effect?
- How many participants will you run?

## Final Recommendation

**For initial pilot**: Keep current (240 trials)
- Fast enough to test feasibility
- Can always expand if needed
- Good balance for initial exploration

**For main experiment**: Consider 360-480 trials
- Better power for noise level comparisons
- More robust estimates
- Better for publication

