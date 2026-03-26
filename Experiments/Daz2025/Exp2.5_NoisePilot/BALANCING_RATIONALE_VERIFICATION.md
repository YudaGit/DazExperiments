# Balancing Rationale Verification

## Research Question Hierarchy

### Primary Question:
**Does homogeneous redundancy (pooled across integration types) differ between:**
1. High noise vs Low noise
2. Homogeneous redundancy vs Baseline

### Secondary Question:
**Within homogeneous redundancy, do integration types differ?**
- Space-only vs Time-only vs Space+Time

## Current Balancing Logic

### Design Intent:
- **Baseline**: All unique items (control)
- **Homogeneous (pooled)**: All 3 integration types combined
- **Balance**: Baseline trials = All Homo trials combined (1:1 ratio)

### Current Implementation:
- BaselineReps = 30 → **120 trials** (30 × 4 combinations)
- HomoReps = 10 → **40 trials per condition**
  - Homo_Space: 40 trials
  - Homo_Time: 40 trials  
  - Homo_SpaceTime: 40 trials
  - **Total Homo: 120 trials** ✓

### Verification:
- Baseline : All Homo = 120 : 120 = **1:1 ratio** ✓
- This allows direct comparison: Baseline vs Homogeneous Redundancy
- Within Homo: 40 trials each is sufficient for comparing integration types

## Why This Makes Sense

### 1. Main Comparison (Baseline vs Homogeneous)
- **1:1 ratio** is optimal for statistical power
- Pooling 3 homo conditions gives you 120 trials for homogeneous redundancy
- This matches 120 baseline trials perfectly

### 2. Secondary Comparison (Within Homo)
- 40 trials per integration type is reasonable for:
  - Detecting large differences between integration types
  - Testing if Space/Time/Space+Time integration differ
- If integration types don't differ, you can pool them for main analysis
- If they do differ, you have enough data to characterize the differences

### 3. Statistical Power
- **Main comparison** (Baseline vs Homo pooled): 120 vs 120 = good power
- **Noise comparison** (Low vs High within Homo): 60 vs 60 per condition = reasonable
- **Integration type comparison**: 40 vs 40 vs 40 = sufficient for large effects

## Design Strengths

✅ **Balanced for primary question**: Baseline = Homo (pooled)
✅ **Efficient**: Each homo condition contributes to main comparison
✅ **Flexible**: Can analyze integration types separately or pooled
✅ **Powerful**: 120 trials per main condition is good for detecting effects

## Potential Considerations

### If Integration Types Matter:
- Current design allows testing if Space/Time/Space+Time differ
- If they don't differ, pool for main analysis (more power)
- If they do differ, you can characterize how

### If You Want More Power for Integration Type Comparison:
- Could increase to 60 trials each (180 total homo, but then need 180 baseline)
- But this may be overkill if main question is Baseline vs Homo

## Recommendation

**Your current balancing is excellent for your research question!**

The 1:1 Baseline:Homo (pooled) ratio is optimal for testing:
- Does homogeneous redundancy improve precision vs baseline?
- Does noise level affect homogeneous redundancy?

The 40 trials per integration type is sufficient for:
- Testing if integration types differ
- Characterizing differences if they exist

**Keep current design** - it's well-balanced for your hypotheses!

