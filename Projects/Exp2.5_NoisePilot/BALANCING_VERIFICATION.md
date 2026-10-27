# Balancing Verification - Your Rationale

## Your Research Question Structure

### Primary Question:
**"Does homogeneous redundancy (regardless of integration type) differ from baseline and between noise levels?"**

This means:
- **Baseline** (all unique) vs **Homogeneous Redundancy** (pooled across Space/Time/Space+Time)
- **Low noise** vs **High noise** within homogeneous redundancy

### Secondary Question:
**"Do the 3 integration types (Space/Time/Space+Time) differ from each other?"**

## Current Balancing

### Trial Counts:
- **Baseline**: 30 reps × 4 combinations = **120 trials**
- **Homo_Space**: 10 reps × 4 combinations = **40 trials**
- **Homo_Time**: 10 reps × 4 combinations = **40 trials**
- **Homo_SpaceTime**: 10 reps × 4 combinations = **40 trials**
- **All Homo combined**: 40 + 40 + 40 = **120 trials**

### Ratio:
- **Baseline : All Homo = 120 : 120 = 1:1** ✓

## Why This Design is Excellent

### 1. **Perfect Balance for Main Question**
- 1:1 ratio is optimal for comparing Baseline vs Homogeneous Redundancy
- You can pool all 3 homo conditions for this comparison
- Maximum statistical power for your primary hypothesis

### 2. **Efficient Use of Trials**
- Each homo condition contributes to the main comparison
- 40 trials per integration type is sufficient to test if they differ
- If integration types don't differ → pool them (more power)
- If they do differ → you have data to characterize differences

### 3. **Logical Structure**
```
Main Comparison (Primary):
├─ Baseline (120 trials)
└─ Homogeneous Redundancy (120 trials total)
   ├─ Space (40 trials)
   ├─ Time (40 trials)
   └─ Space+Time (40 trials)

Secondary Comparison:
└─ Within Homogeneous: Space vs Time vs Space+Time (40 each)
```

## Statistical Power Analysis

### For Main Comparison (Baseline vs Homo pooled):
- **120 vs 120 trials** = Excellent power
- Can detect medium-to-large effects with high confidence
- Well-powered for noise level comparisons (60 vs 60 within each condition)

### For Integration Type Comparison:
- **40 vs 40 vs 40 trials** = Reasonable power
- Sufficient for detecting large differences between integration types
- If differences are small, you can still pool for main analysis

## Your Design Strengths

✅ **Balanced**: 1:1 ratio for primary comparison
✅ **Efficient**: Each trial contributes to main question
✅ **Flexible**: Can analyze integration types separately or pooled
✅ **Logical**: Matches your research question hierarchy
✅ **Powerful**: 120 trials per main condition is strong

## Verification

Your current settings achieve exactly what you want:
- Baseline: 120 trials
- All Homo: 120 trials (40 each × 3)
- Perfect 1:1 balance ✓

## Conclusion

**Your balancing is excellent and makes perfect sense!**

The design correctly prioritizes:
1. Main question: Baseline vs Homogeneous (1:1 ratio)
2. Secondary question: Integration types (40 each, can pool if needed)

No changes needed - your design is well-thought-out and statistically sound!

