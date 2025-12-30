# Sub-Experiment 3: Step 5 - Orientation Response Wheel Implementation

## What Was Implemented

### Modified `confidencewheel.js` Plugin

**Added Parameter:**
- `response_type` - String indicating response type ('color_wheel' or 'orientation_bar')

**Added Methods:**
1. `drawOrientationBarResponse()` - Draws orientation bar at center (cue and response interface)
2. `drawOrientationBarFeedback()` - Draws feedback showing response vs correct orientation

**Modified Mouse Interaction:**
- For `response_type === 'orientation_bar'`: 
  - Mouse up/down movement rotates the bar
  - Mouse click confirms response
  - Continuous animation loop for smooth rotation

## Orientation Bar Response Specifications

### Bar Display
- **Position**: Centered on fixation cross
- **Color**: Matches target item color (serves as cue)
- **Dimensions**: Same as stimulus bars (length = patch diameter, width = length/7)
- **Initial orientation**: 0° (horizontal)

### Mouse Interaction
- **Mouse down + move up**: Rotates bar counter-clockwise (CCW)
- **Mouse down + move down**: Rotates bar clockwise (CW)
- **Rotation speed**: 0.3° per pixel of vertical movement
- **Orientation range**: 0-180° (wraps around)
- **Mouse click**: Confirms response

### Response Tracking
- **Response orientation**: Current bar orientation when clicked (0-180°)
- **Target orientation**: Orientation of target item from trial data
- **Error calculation**: Shortest path difference (-90° to +90°)
- **Points calculation**: `100 - (abs(error) / 90 * 100)`

### Feedback Display
- **Response bar**: White bar showing participant's response orientation
- **Correct bar**: Green bar showing target orientation (slightly offset for visibility)
- Both bars displayed simultaneously for comparison

## Code Structure

### Response Type Detection
```javascript
if (trial.response_type === 'orientation_bar') {
    // Orientation bar response logic
} else {
    // Color wheel response logic (original)
}
```

### Mouse Event Handlers
1. **mousemove**: Tracks vertical movement when mouse is down, updates orientation
2. **mousedown**: Starts rotation tracking, checks for penalties
3. **mouseup**: Stops rotation tracking
4. **click**: Confirms response and ends trial

### Animation Loop
- Continuous `requestAnimationFrame` loop redraws bar during rotation
- Ensures smooth visual feedback
- Cancelled when trial ends

## Key Differences from Color Wheel

| Aspect | Color Wheel | Orientation Bar |
|--------|-------------|-----------------|
| **Display** | 360° color wheel | Single orientation bar at center |
| **Interaction** | Mouse position on wheel | Mouse up/down to rotate |
| **Response** | Click on wheel | Click anywhere to confirm |
| **Range** | 0-360° (colors) | 0-180° (orientations) |
| **Cue** | White border on target patch | Bar color matches target |

## Testing

To test orientation bar response:
1. Set `trial.response_type = 'orientation_bar'`
2. Set `trial.orientations` array (0-180°)
3. Set `trial.choice_colors` array (target color)
4. Set `trial.target_index` (which item is target)

Expected behavior:
- Bar appears at center, colored like target
- Mouse up/down rotates bar smoothly
- Click confirms response
- Feedback shows white (response) and green (correct) bars

## Next Steps

- Step 6: Create visual mask (random colored orientation bars)
- Step 7: Integrate everything in exp.html timeline

