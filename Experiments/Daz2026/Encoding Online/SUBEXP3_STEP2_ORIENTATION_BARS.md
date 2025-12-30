# Sub-Experiment 3: Step 2 - Orientation Bars Implementation

## What Was Implemented

### Modified `confidencewheel.js` Plugin

**Added Parameters:**
1. `orientations` - Array of orientation angles (0-180°) for each bar
2. `stimulus_type` - String indicating stimulus type ('color_patches' or 'orientation_bars')

**Added Method:**
- `drawOrientationBars(ctx, trial, centerX, centerY, patchradius, patchRadius)` - Draws colored orientation bars

### Bar Specifications

- **Bar Length**: Equal to color patch diameter = `2 * patchRadius`
  - `patchRadius = Math.round(window.outerHeight * 0.024)` (same as color patch radius)
  - So bar length = `2 * window.outerHeight * 0.024`

- **Bar Width**: Length / 7 (maintains 1:7 width:length ratio)
  - `barWidth = barLength / 7`

- **Bar Position**: Same as color patches
  - Positioned on ring at distance `patchradius` from center
  - `patchradius = browser_window_height * 0.1`

- **Bar Orientation**: Rotated to specified angle (0-180°)
  - Converted to radians: `orientationRad = orientations[ii] * Math.PI / 180`
  - Canvas rotation applied before drawing

- **Bar Color**: Same RGB color system as color patches
  - Uses `trial.choice_colors[ii]` array

### Drawing Process

1. For each bar:
   - Calculate center position using `patch_positionalangle`
   - Get color from `choice_colors`
   - Get orientation from `orientations`
   
2. Canvas operations:
   - Save context state
   - Translate to bar center position
   - Rotate to bar orientation
   - Draw rectangle (centered at origin)
   - Restore context state

3. Rectangle drawing:
   - Centered at (0, 0) after translation/rotation
   - Width: `barLength`, Height: `barWidth`
   - Filled and stroked with bar color

## Code Changes

### Modified Section in `confidencewheel.js`:

**Before:**
```javascript
if (trial.draw_wheel == false){
    // Draw Colored Patches
    for (var ii = 0; ii < trial.patch_positionalangle.length; ii++){
        // ... draw circles ...
    }
}
```

**After:**
```javascript
if (trial.draw_wheel == false){
    if (trial.stimulus_type === 'orientation_bars' && trial.orientations) {
        // Draw Colored Orientation Bars
        this.drawOrientationBars(ctx, trial, midx, midy, patchradius, indiv_patch_radius);
    } else {
        // Draw Colored Patches (default)
        // ... existing circle drawing code ...
    }
}
```

## Testing

To test orientation bars rendering:
1. Set `trial.stimulus_type = 'orientation_bars'`
2. Provide `trial.orientations` array (e.g., `[45, 90, 135, 0]`)
3. Provide `trial.choice_colors` array (same as before)
4. Provide `trial.patch_positionalangle` array (same as before)

## Next Steps

- Step 3: Create orientation response wheel (replace color wheel)
- Step 4: Create visual mask (random colored orientation bars)
- Step 5: Integrate everything in exp.html timeline

