# Step 2: JavaScript Implementation for Sub-Experiment 1

## Overview

This document explains the JavaScript implementation that connects the Python trial data to the jsPsych experiment timeline for Sub-Experiment 1.

## Changes Made

### 1. Modified `confidencewheel.js` Plugin

**File**: `static_06d9bffc703f14305bb7357074cf1eb6/confidencewheel.js`

**Changes**:
- Added `target_index` parameter to allow direct specification of target item
- Modified target selection logic to use `target_index` if provided, otherwise fall back to redundancy-based selection

**Why**: The Python code generates the exact target index for each trial, so we need to pass it directly rather than relying on the plugin's automatic detection.

```javascript
// Added parameter
target_index: {
    type: jspsych.ParameterType.INT,
    pretty_name: "Target Index",
    default: null,
}

// Modified target selection
if (trial.target_index !== null && trial.target_index !== undefined) {
    targetN = trial.target_index;
} else if (trial.redundancy == 1) {
    targetN = this.findTargetIndex(trial.choice_colorangles, true);
} else {
    targetN = this.findTargetIndex(trial.choice_colorangles, false);
}
```

### 2. Added Helper Functions in `exp.html`

**File**: `templates/exp.html`

**Functions Added**:

#### `convertColorAnglesToRGB(colorAngles)`
- **Purpose**: Converts Python color angles (0-359) to RGB arrays using the `highRGBs` palette
- **Input**: Array of color angles from Python (e.g., `[115, 219, 287]`)
- **Output**: Array of RGB arrays (e.g., `[[240, 48, 112], [239, 50, 109], ...]`)
- **Why**: Python generates color angles, but jsPsych needs RGB values for display

#### `convertPositions(positions)`
- **Purpose**: Validates and normalizes position angles from Python
- **Input**: Array of position angles (0-359)
- **Output**: Array of normalized position angles
- **Why**: Ensures positions are in valid range [0, 360)

### 3. Implemented Sub-Experiment 1 Timeline

**File**: `templates/exp.html`

**Structure**:
- Checks if `subexperiment == 1`
- If yes, builds Sub-Exp 1 timeline using Python trial data
- If no, uses original example experiment (for Sub-Exp 2 & 3)

**Timeline Components**:

#### Practice Trials Loop
For each practice trial from `expt_data.practice_trials`:
1. **Trial Advance**: Button to proceed to next practice trial
2. **Fixation**: 1 second (1000ms) fixation cross
3. **Color Patches**: Display stimuli with variable duration from Python
4. **Retention Interval**: 750ms blank screen (mask)
5. **Response Wheel**: Color wheel for response with target highlighting

#### Main Trials Loop
For each main trial from `expt_data.trials`:
1. **Trial Advance**: Feedback plot showing progress
2. **Fixation**: 1 second (1000ms) fixation cross
3. **Color Patches**: Display stimuli with variable duration (50-350ms)
4. **Retention Interval**: 750ms blank screen (mask)
5. **Response Wheel**: Color wheel for response with target highlighting

## Data Flow

### Python → JavaScript
```
expt_data = {
    subexperiment: 1,
    trials: [
        {
            duration_ms: 250,
            cue_type: 'NR-cue',
            colors: [115, 219, 287, 318, 115, 115],  // Angles
            positions: [278.0, 98.0, 218.0, 38.0, 158.0, 338.0],  // Angles
            target: 3,  // Index
            is_redundant_target: false,
            ...
        },
        ...
    ],
    practice_trials: [...]
}
```

### JavaScript Processing
1. **Color Conversion**: `convertColorAnglesToRGB(trial.colors)` → RGB arrays
2. **Position Validation**: `convertPositions(trial.positions)` → Validated angles
3. **Redundancy Flag**: `trial.is_redundant_target ? 1 : 0` → Plugin parameter
4. **Target Index**: `trial.target` → Direct target specification

### jsPsych Plugin Parameters
```javascript
{
    choice_colors: [RGB arrays],           // From convertColorAnglesToRGB()
    choice_colorangles: [angles],           // Direct from Python
    patch_positionalangle: [angles],        // From convertPositions()
    trial_duration: duration_ms,            // Variable from Python
    redundancy: 0 or 1,                     // From is_redundant_target
    target_index: target,                   // Direct from Python
    wheel_rotation: sessionWheelRotation,   // Random rotation
    color_palette: highRGBs                 // Color palette
}
```

## Trial Structure

Each trial follows this sequence:

1. **Fixation** (1000ms)
   - White "+" in center
   - Prepares participant for trial

2. **Stimulus Display** (Variable: 50-350ms)
   - 6 color patches displayed
   - Colors and positions from Python
   - Duration varies by condition

3. **Retention Interval** (750ms)
   - Blank screen (mask)
   - Prevents afterimages

4. **Response** (Up to 60s)
   - Color wheel displayed
   - Target item highlighted with white border
   - Participant clicks to report color
   - Feedback shown (red line = response, green line = correct)

5. **Inter-trial Feedback** (After response)
   - Progress plot
   - Accuracy by set-size
   - Click to continue

## Key Differences from Original Example

| Aspect | Original Example | Sub-Experiment 1 |
|--------|-----------------|-----------------|
| **Trial Data Source** | JavaScript generation | Python generation |
| **Color Generation** | `selectRedundantColorPatches()` | Direct from Python |
| **Duration** | Fixed 400ms | Variable 50-350ms |
| **Target Selection** | Redundancy-based auto-detect | Direct index from Python |
| **Trial Count** | Variable (based on conditions) | Fixed 140 main + 5 practice |
| **Conditions** | Multiple set-sizes | Single set-size (6) |

## Testing Checklist

- [ ] Practice trials display correctly
- [ ] Main trials display correctly
- [ ] Variable durations work (50-350ms)
- [ ] Colors match Python generation
- [ ] Positions are evenly spaced
- [ ] Target highlighting works (R-cue vs NR-cue)
- [ ] Response collection works
- [ ] Feedback displays correctly
- [ ] Data saved includes all trial parameters

## Next Steps

1. Test the implementation in browser
2. Verify data collection includes all fields
3. Check timing matches Matlab version
4. Verify feedback accuracy
5. Test with different sub-experiment assignments

