# Solutions for Non-Uniform Perceptual Color Space Issue

## Problem
The OKLab color wheel has **perceptual non-uniformity**: equal angular distances don't correspond to equal perceptual differences. For example:
- Blues appear more similar (smaller perceptual steps per degree)
- Reds/Yellows appear more distinct (larger perceptual steps per degree)
- This causes kappa=1 vs kappa=20 to look similar in some color regions

## Solution Approaches (No Clipping)

### **Option 1: Adaptive Kappa Based on Hue Region** ⭐ Recommended
**Concept**: Adjust kappa based on the target hue to compensate for perceptual non-uniformity.

**Implementation**:
- Pre-compute perceptual step sizes for each hue region
- Scale kappa inversely with perceptual step size
- Blues (small steps) → use higher effective kappa
- Reds (large steps) → use lower effective kappa

**Pros**: 
- Simple to implement
- Maintains Von Mises distribution properties
- No clipping needed

**Cons**:
- Requires calibration data for perceptual step sizes

### **Option 2: Sample in Perceptually Uniform Space (LAB)**
**Concept**: Sample colors directly in LAB space using multivariate normal, then convert to RGB.

**Implementation**:
- Convert target hue to LAB coordinates
- Sample LAB values using multivariate normal distribution
- Convert sampled LAB → RGB
- This naturally gives perceptually uniform spread

**Pros**:
- Truly perceptually uniform
- No clipping needed
- Mathematically clean

**Cons**:
- More complex implementation
- Need to handle gamut boundaries
- May need to constrain to constant lightness/chroma

### **Option 3: Hue-Space Warping**
**Concept**: Pre-warp the hue circle so equal angular distances = equal perceptual distances.

**Implementation**:
- Create a lookup table mapping "perceptual hue" → "physical hue angle"
- Sample in perceptual hue space (uniform)
- Map back to physical hue angles
- Use existing color wheel

**Pros**:
- Works with existing color wheel
- Maintains circular structure

**Cons**:
- Requires calibration
- More complex sampling

### **Option 4: Multi-Dimensional Noise (Hue + Saturation)**
**Concept**: Add controlled saturation variation that scales with noise level.

**Implementation**:
- Low noise: Only hue variation (tight saturation)
- High noise: Hue + saturation variation (wider saturation spread)
- This makes high noise "messier" perceptually

**Pros**:
- Simple to add
- Increases perceptual difference
- No clipping needed

**Cons**:
- Changes the noise model (not pure hue noise)

## Recommended Approach: Option 1 + Option 4 Hybrid

**Phase 1**: Implement adaptive kappa scaling based on hue region
- Create a simple lookup table for perceptual step sizes
- Scale kappa by inverse of step size

**Phase 2**: Add saturation variation for high noise
- Only for high noise condition
- Makes it clearly "messier"

This gives you:
- Perceptually consistent noise levels across colors
- Clear visual distinction between low/high noise
- No clipping needed
- Maintains Von Mises properties

## Implementation Notes

### For Option 1 (Adaptive Kappa):
```matlab
% Perceptual step size lookup (approximate, needs calibration)
% Values represent degrees of hue per JND (just noticeable difference)
perceptualStepSize = [
    240:270, 1.2;  % Blues: small steps (1.2° per JND)
    0:60,    2.5;  % Reds: large steps (2.5° per JND)
    60:120,  2.0;  % Yellows: medium-large
    120:180, 1.8;  % Greens: medium
    180:240, 1.5;  % Cyans: medium-small
];

% Scale kappa inversely with step size
effectiveKappa = kappa * (meanStepSize / perceptualStepSize(targetHue));
```

### For Option 4 (Saturation Noise):
```matlab
% In makeNoisyPattern, after hue sampling:
if kappa == P.kappaHighNoise
    % Add saturation variation
    hsv = rgb2hsv(rgb01);
    satNoise = (rand(nTiles,1) - 0.5) * 0.2;  % ±10% saturation
    hsv(:,2) = max(0, min(1, hsv(:,2) + satNoise));
    rgb01 = hsv2rgb(hsv);
end
```

## Next Steps

Which approach would you like to try first?
1. **Option 1** (adaptive kappa) - most theoretically sound
2. **Option 4** (saturation noise) - easiest to implement
3. **Option 2** (LAB sampling) - most perceptually accurate but complex
4. **Hybrid** (Option 1 + 4) - best of both worlds

I recommend starting with **Option 4** (saturation noise) as it's quick to test, then adding **Option 1** if needed.

