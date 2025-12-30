# Sub-Experiment 3: Step 7 - Timeline Integration

## What Was Implemented

### Modified `templates/exp.html`

**Added Sub-Experiment 3 Timeline:**
- Replaced the fallback `else` clause with proper Sub-Experiment 3 implementation
- Added practice trials and main trials for Sub-Experiment 3
- Integrated all components: orientation bars, visual mask, orientation response

## Sub-Experiment 3 Timeline Structure

### Practice Trials
1. **Trial Advance** - Button to proceed to next practice trial
2. **Fixation** - 1 second fixation cross
3. **Orientation Bars Display** - Colored orientation bars (stimulus)
4. **Retention Interval** - Visual mask (random colored orientation bars)
5. **Orientation Response** - Orientation bar response interface

### Main Trials
1. **Trial Advance** - Feedback plot and trial counter
2. **Fixation** - 200ms fixation cross
3. **Orientation Bars Display** - Colored orientation bars (stimulus)
4. **Retention Interval** - Visual mask (random colored orientation bars)
5. **Orientation Response** - Orientation bar response interface

## Key Features

### Stimulus Display (Orientation Bars)
```javascript
stimulus_type: 'orientation_bars',
orientations: practiceOrientations, // 0-180° angles
choice_colors: practiceColors, // RGB colors
patch_positionalangle: practicePositions, // Position angles
```

### Retention Interval (Visual Mask)
```javascript
draw_wheel: false,
show_mask: true, // Enable visual mask
trial_duration: retention_duration_ms, // 750ms
```

### Response Phase (Orientation Bar)
```javascript
draw_wheel: true,
response_type: 'orientation_bar', // Use orientation bar response
target_index: practiceTrial.target, // Specify target
orientations: practiceOrientations, // For feedback
```

## Data Flow

### From Python (`expt_config.py`)
- `colors`: Color angles (0-360°)
- `orientations`: Orientation angles (0-180°)
- `positions`: Position angles (0-360°)
- `target`: Target item index
- `duration_ms`: Presentation duration
- `trial_type`: 'Baseline', 'R-cue', or 'NR-cue'
- `set_size`: Number of items (4 or 6)

### To JavaScript (`exp.html`)
- Colors converted to RGB via `convertColorAnglesToRGB()`
- Positions converted via `convertPositions()`
- Orientations used directly (already in degrees)
- All data passed to jsPsych trials

## Trial Data Recording

### Practice Trials Record:
- `trial_event`: 'practice_trial_start_event', 'practice_orientation_bars_display_event', etc.
- `trial_number`: Practice trial number
- `duration_ms`: Presentation duration
- `trial_type`: 'Baseline', 'R-cue', or 'NR-cue'
- `set_size`: Number of items
- `target`: Target item index
- `target_orientation`: Target item's orientation (for error calculation)
- `is_practice`: true

### Main Trials Record:
- `trial_event`: 'fixation', 'orientation_bars_display_event', etc.
- `trial_number`: Main trial number
- `duration_ms`: Presentation duration
- `trial_type`: 'Baseline', 'R-cue', or 'NR-cue'
- `set_size`: Number of items
- `target`: Target item index
- `target_orientation`: Target item's orientation (for error calculation)
- `is_practice`: false

## Response Data

The orientation bar response records:
- `response_orientation`: Participant's response (0-180°)
- `target_orientation`: Correct orientation (0-180°)
- `error`: Difference between response and target (wrapped to -90° to +90°)
- `points`: Accuracy score (100 - error percentage)
- `rt`: Response time
- All penalty flags (too fast, too slow, start out of center)

## Integration Checklist

✅ Sub-Experiment 3 timeline added
✅ Practice trials implemented
✅ Main trials implemented
✅ Orientation bars as stimuli
✅ Visual mask for retention interval
✅ Orientation bar response
✅ Data recording configured
✅ Feedback plot integration

## Testing

To test Sub-Experiment 3:
1. Set `subexperiment = 3` in URL: `?subexp=3`
2. Or let random assignment work (33% chance)
3. Check console for "Building Sub-Experiment 3 timeline"
4. Verify:
   - Orientation bars display correctly
   - Visual mask appears during retention interval
   - Orientation bar response works (mouse up/down to rotate, click to confirm)
   - Feedback shows white (response) and green (correct) bars

## Next Steps

- Test the complete Sub-Experiment 3 implementation
- Customize instructions for Sub-Experiment 3 (if needed)
- Verify data recording is correct
- Test all trial types (Baseline, R-cue, NR-cue)
- Test all set-sizes (4, 6)

