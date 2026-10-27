# Trial Count Verification for Pilot 2

## Current Design Parameters:
- ItemNList = [2 6] → 2 set sizes
- NoiseLevels = {'low', 'high'} → 2 noise levels
- BaselineReps = 30
- HomoReps = 10

## Calculation Logic:

For each N and each NoiseLevel combination:
- Baseline: baselineReps trials
- Homo_Space: homoReps trials
- Homo_Time: homoReps trials
- Homo_SpaceTime: homoReps trials

Number of N×Noise combinations = 2 (N) × 2 (Noise) = 4

## Expected Trial Counts:

### Per N×Noise combination:
- Baseline: 30 trials
- Homo_Space: 10 trials
- Homo_Time: 10 trials
- Homo_SpaceTime: 10 trials
- **Subtotal per combination**: 60 trials

### Totals:
- **Baseline**: 2 (N) × 2 (Noise) × 30 = **120 trials**
- **Homo_Space**: 2 (N) × 2 (Noise) × 10 = **40 trials**
- **Homo_Time**: 2 (N) × 2 (Noise) × 10 = **40 trials**
- **Homo_SpaceTime**: 2 (N) × 2 (Noise) × 10 = **40 trials**
- **Total**: **240 trials**

## Comment Discrepancy:

The comments in NoisePilot_HomoInte.m say:
- Baseline: "60 trials per N×Noise combination (240 total)" 
  - But 30 reps × 4 combinations = 120, not 240
  - To get 240: need 60 reps × 4 = 240 ✓
  
- Homo: "20 trials per N×Noise combination per condition (80 each, 240 total)"
  - But 10 reps × 4 combinations = 40, not 80
  - To get 80: need 20 reps × 4 = 80 ✓

## Recommendation:

Based on the design document (PILOT_CONDITION_DESIGN.md):
- Baseline: 60 trials per N×Noise = 240 total
- Each Homo condition: 20 trials per N×Noise = 80 total each
- Total: 480 trials

But current code generates:
- Baseline: 120 trials (half of desired)
- Each Homo: 40 trials (half of desired)
- Total: 240 trials (half of desired)

## Options:

1. **Keep current (240 trials)** - Faster pilot, good for initial testing
2. **Match design doc (480 trials)** - More power, better for analysis
3. **Compromise (360 trials)** - Baseline: 40 reps, Homo: 15 reps

