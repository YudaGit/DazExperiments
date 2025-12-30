# Sub-Experiment 3: Step 6 - Visual Mask Implementation

## What Was Implemented

### Modified `confidencewheel.js` Plugin

**Added Parameters:**
- `show_mask` - Boolean to enable visual mask display (for retention interval)
- `mask_data` - Object to store pre-generated mask data (for reuse)

**Added Methods:**
1. `generateVisualMask()` - Generates random colored orientation bars for mask
2. `colorAngleToRGB()` - Converts color angle to RGB (uses color wheel palette)
3. `drawVisualMask()` - Draws the visual mask on canvas

## Visual Mask Specifications

### Mask Design
- **Shape**: Circle covering entire stimulus display area
- **Coverage**: Fully covers maximal range of possible stimuli display
- **Size**: Larger than visible circle (accounts for bars extending outside circle)
- **Mask radius**: `patchradius + barLength` (ensures full coverage)

### Mask Content
- **Bars**: Random colored orientation bars (same style as stimuli)
- **Bar dimensions**: Same as stimulus bars (length = patch diameter, width = length/7)
- **Density**: ~200 bars for dense coverage
- **Colors**: Random colors from 360° color wheel
- **Orientations**: Random orientations (0-180°)

### Mask Generation
- **Pre-rendering**: Mask data is generated once and reused
- **Storage**: Stored in `trial.mask_data` for efficiency
- **Positioning**: Random positions within mask circle
- **Boundary check**: Ensures all bars stay within mask circle

## Code Structure

### Mask Display Logic
```javascript
if (trial.show_mask == true) {
    // Calculate mask radius
    var barLength = 2 * indiv_patch_radius;
    var maskRadius = patchradius + barLength;
    
    // Draw visual mask
    this.drawVisualMask(ctx, trial, midx, midy, maskRadius, indiv_patch_radius);
}
```

### Mask Generation Algorithm
1. Generate random positions within mask circle
2. Ensure bars stay within circle boundaries
3. Generate random colors (0-360°)
4. Generate random orientations (0-180°)
5. Store all data for reuse

### Color Conversion
- Uses `highRGBs` array if available (from color wheel)
- Falls back to HSV-to-RGB conversion if needed
- Ensures consistent color space with stimuli

## Usage

To display the visual mask during retention interval:
```javascript
var retention_interval = {
    type: jsConfidenceWheel,
    trial_duration: 750,  // Retention interval duration
    draw_wheel: false,
    show_mask: true,  // Enable visual mask
    // mask_data will be auto-generated and cached
}
```

## Benefits

1. **Pre-rendering**: Mask generated once, reused for all trials
2. **Efficient**: Cached mask data reduces computation
3. **Consistent**: Same mask style as stimuli (colored orientation bars)
4. **Full coverage**: Mask radius ensures complete stimulus area coverage

## Next Steps

- Step 7: Integrate everything in exp.html timeline
  - Add Sub-Experiment 3 timeline
  - Use visual mask for retention intervals
  - Use orientation bar response for response phase

