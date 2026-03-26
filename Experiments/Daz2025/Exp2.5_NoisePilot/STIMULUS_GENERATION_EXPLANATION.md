# Stimulus Generation Pipeline: Detailed Explanation

## Overview
Each stimulus is a **12×12 grid** (B=12) of colored tiles, where each tile's color is sampled from a **Von Mises distribution** centered on a target hue.

## Step-by-Step Generation Process

### 1. **Grid Setup** (`buildTileRects`)
- **Grid size**: B = 12, so **144 tiles total** (12×12)
- Each tile is a small square within the larger stimulus square
- Tiles are arranged in a regular grid pattern

### 2. **Hue Sampling** (`sampleVonMisesDegrees`)
- **Distribution**: Von Mises (circular normal distribution)
- **Parameters**:
  - `muDeg`: Target hue (0-360°), randomly chosen per stimulus
  - `kappa`: Concentration parameter
    - **Low noise (Stage 1,3,5,6)**: kappa = **12** (narrow distribution)
    - **High noise (Stage 2,4)**: kappa = **2** (wide distribution)
  - `n`: Number of samples = **144** (one per tile)

**Von Mises Distribution Properties**:
- Higher kappa = narrower distribution = colors cluster tightly around target
- Lower kappa = wider distribution = colors spread more around target
- kappa → 0 approaches uniform distribution
- kappa → ∞ approaches delta function (all same color)

**Sampling Method**: Rejection sampling algorithm (Best & Fisher, 1979)

### 3. **Circular Clipping** (`circClipToWindow`)
- **Parameter**: `limitDeg = 10°`
- **Effect**: Any hue sample outside ±10° from target is **clamped** back to ±10°
- **Purpose**: Prevents extreme outliers that might look like completely different colors

**Important**: This clipping happens **AFTER** Von Mises sampling, so:
- For kappa=12: Most samples already within ±10°, clipping has minimal effect
- For kappa=2: Many samples outside ±10°, so they get clipped to ±10° boundary

### 4. **Color Mapping** (`wheelRGB01_fromDegrees`)
- Each sampled hue (0-360°) is mapped to RGB via the OKLab color wheel
- Color wheel has 360 entries (one per degree)
- Result: 144 RGB triplets (one per tile), each in [0,1] range

### 5. **Rendering** (`presentNoisySquareAt`)
- Each tile is drawn as a filled rectangle with its assigned RGB color
- All 144 tiles are drawn simultaneously to form the complete stimulus

## Why kappa=2 vs kappa=12 Might Look Similar

### The Problem: Circular Clipping is Masking the Difference

**Current parameters**:
- `limitDeg = 10°` (hard clipping boundary)
- kappa = 2 (high noise)
- kappa = 12 (low noise)

**What happens**:

1. **For kappa=12 (low noise)**:
   - Von Mises distribution is narrow (standard deviation ≈ 360°/sqrt(12) ≈ 104°)
   - Actually wait, that's wrong. For Von Mises, the circular standard deviation is approximately 1/sqrt(kappa) in radians.
   - For kappa=12: σ ≈ 1/sqrt(12) ≈ 0.289 rad ≈ 16.5°
   - Most samples fall within ±16.5°, so clipping to ±10° affects many samples
   - **Result**: Distribution is artificially narrowed by clipping

2. **For kappa=2 (high noise)**:
   - σ ≈ 1/sqrt(2) ≈ 0.707 rad ≈ 40.5°
   - Many samples fall outside ±10°, so they get clipped to ±10°
   - **Result**: Distribution is artificially narrowed to ±10° maximum

**The Issue**: Both distributions end up being clipped to ±10°, making them look similar!

### Visual Impact
- **Intended**: kappa=12 should show tight color clustering, kappa=2 should show wide spread
- **Actual**: Both are constrained to ±10° maximum spread due to clipping
- **Perception**: The difference is subtle because the clipping boundary dominates

## Recommendations to Increase Perceptual Difference

### Option 1: Increase `limitDeg` for high noise
```matlab
% In stage functions for high noise:
if kappa == P.kappaHighNoise
    limitDeg = 30;  % Allow wider spread
else
    limitDeg = P.limitDeg;  % Keep 10° for low noise
end
```

### Option 2: Increase kappa difference
```matlab
P.kappaLowNoise  = 20;  % Even tighter (was 12)
P.kappaHighNoise = 1;   % Even wider (was 2)
```

### Option 3: Remove clipping for high noise
```matlab
% In makeNoisyPattern:
if kappa < 5  % High noise
    % Skip clipping, allow full Von Mises spread
else
    % Apply clipping for low noise
    huesDeg = circClipToWindow(huesDeg, hueDeg, limitDeg);
end
```

### Option 4: Use different clipping windows
```matlab
% Low noise: tight clipping (±5°)
% High noise: loose clipping (±20°)
```

## Current Distribution Characteristics

**For kappa=12 (low noise)**:
- Mean: target hue
- Effective spread: ±10° (clipped)
- Most tiles: Very similar colors, subtle variation

**For kappa=2 (high noise)**:
- Mean: target hue  
- Effective spread: ±10° (clipped)
- Most tiles: More variation, but still constrained

**The clipping is preventing the intended perceptual difference!**

## Code Flow Summary

```
stage_single() 
  → presentNoisySquareAt()
    → makeNoisyPattern()
      → sampleVonMisesDegrees(hueDeg, kappa, 144)
        → Returns 144 hue angles (0-360°)
      → circClipToWindow(huesDeg, hueDeg, 10°)
        → Clamps all hues to ±10° from target
      → wheelRGB01_fromDegrees(huesDeg, colorWheel)
        → Maps 144 hues to 144 RGB triplets
    → Screen('FillRect', window, rgb01', tileRects)
      → Draws 144 colored tiles
```

## Next Steps

Would you like me to:
1. Modify the clipping behavior to allow wider spread for high noise?
2. Increase the kappa difference?
3. Add visualization code to show the actual hue distributions?
4. Test different parameter combinations?

