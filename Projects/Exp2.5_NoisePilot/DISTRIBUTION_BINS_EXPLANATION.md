# Understanding Histogram Bin Differences Between Noise Levels

## Your Observation

You noticed that Stage 1 (low noise) shows only ~4 bins populated in the histogram, while Stage 2 (high noise) shows many more bins populated. This is **correct and expected behavior**, not a bug or artifact.

## Why This Happens

### The Sampling Method is Identical

Both noise levels use the **exact same sampling function** (`sampleVonMisesQuantiles`):
- Same quantile generation method
- Same CDF lookup table
- Same shuffling algorithm

**The ONLY difference is the `kappa` parameter:**
- Low noise: `kappa = 50` (high concentration)
- High noise: `kappa = 3` (low concentration)

### Distribution Width Determines Bin Population

The histogram uses **20 fixed bins** spanning -180° to +180° (18° per bin).

**Low Noise (κ = 50):**
- Distribution is **narrow** (σ ≈ 8.1°)
- Most samples fall within ±15-20° of target
- Only ~4 bins (centered around 0°) get populated
- This is **correct** - the distribution is genuinely tight

**High Noise (κ = 3):**
- Distribution is **wide** (σ ≈ 33.1°)
- Samples spread across ±60-90° of target
- Many bins get populated across the range
- This is **correct** - the distribution is genuinely wide

## Visual Example

```
Low Noise (κ=50):          High Noise (κ=3):
                          
    ████                      ████████████████
    ████                      ████████████████
    ████                      ████████████████
    ████                      ████████████████
    ████                      ████████████████
    ████                      ████████████████
    ████                      ████████████████
    ████                      ████████████████
    ████                      ████████████████
    ████                      ████████████████
    
Only 4 bins                 Many bins populated
populated                   (wider spread)
```

## Why This is Good for Your Experiment

### Clean Manipulation

✅ **Single parameter difference:** Only `kappa` varies between conditions  
✅ **Same sampling method:** Ensures no methodological confounds  
✅ **True distribution difference:** Histogram reflects actual noise level  
✅ **Consistent variance:** Quantile sampling ensures same variance for same kappa  

### What This Means

The different number of populated bins is **not a confound** - it's the **direct result** of manipulating noise level. This is exactly what you want:

- **Low noise condition:** Tight distribution → few bins → consistent colors
- **High noise condition:** Wide distribution → many bins → varied colors

## Diagnostic Information

The visualization now shows:
- **95% range:** ±X° (shows effective spread)
- **Active bins:** X/20 (shows how many bins have samples)

**Expected values:**
- Low noise: 95% range ≈ ±15-20°, Active bins ≈ 3-5/20
- High noise: 95% range ≈ ±60-90°, Active bins ≈ 12-18/20

## Verification

To verify the sampling is identical:

1. **Check the code:** Both noise levels call `sampleVonMisesQuantiles()` with only `kappa` differing
2. **Check consistency:** Same kappa → same std across trials (should be very consistent)
3. **Check the histogram:** The shape should match Von Mises distribution for that kappa

## If You Want More Bins Populated in Low Noise

If you want low noise to show more bins (for visual consistency), you have two options:

### Option 1: Decrease Low Noise Kappa
```matlab
P.K_LowNoise = 30;  % Was 50, now wider (more bins)
```
**Trade-off:** Low noise becomes less "low noise"

### Option 2: Increase High Noise Kappa
```matlab
P.K_HighNoise = 5;  % Was 3, now narrower (fewer bins)
```
**Trade-off:** High noise becomes less "high noise"

**Recommendation:** Keep current settings - the difference in bin population is a **feature, not a bug**. It accurately reflects the true difference in noise levels, which is what you want for your experiment.

## Summary

✅ Different number of bins = **Expected and correct**  
✅ Reflects true distribution difference  
✅ Sampling method is identical (only kappa differs)  
✅ This is clean manipulation of noise level  

The histogram is showing you exactly what's happening: low noise has a tight distribution (few bins), high noise has a wide distribution (many bins). This is the correct behavior for your experimental manipulation.

