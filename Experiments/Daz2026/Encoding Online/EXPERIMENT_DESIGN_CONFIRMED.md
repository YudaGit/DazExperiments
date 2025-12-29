# Experiment Design: Confirmed Details

## Sub-Experiment 1: Practice Effect Hypothesis

### Design Parameters
- **Set-size:** 6 (fixed)
- **Presentation durations:** 50ms, 100ms, 150ms, 200ms, 250ms, 300ms, 350ms (7 levels)
- **Trial types:** 
  - R-cue: Cue a redundant item for report
  - NR-cue: Cue a non-redundant item for report
- **Redundancy:** Always 3 redundant items per set (set-size 6)
- **Conditions:** 7 durations × 2 cue types = **14 conditions**
- **Trials per condition:** 10
- **Total trials:** 14 × 10 = **140 trials per participant**
- **Practice trials:** 5
- **Randomization:** Fully randomized across all 14 conditions

### Task
- Continuous color report using color wheel (same as current example)
- Same color patch stimuli as current example

### Key Question
Do encoding duration effects appear in less-practiced (online) participants?

---

## Sub-Experiment 2: Context Effect Hypothesis

### Design Parameters
- **Set-sizes:** 4 and 6
- **Trial types:**
  - Baseline: All unique items (no redundancy)
  - R-cue: Cue a redundant item for report
  - NR-cue: Cue a non-redundant item for report
- **Redundancy levels:**
  - Set-size 4: 2 redundant items
  - Set-size 6: 3 redundant items
- **Presentation durations:** 50ms, 100ms, 200ms (3 levels)
- **Conditions:** 2 set-sizes × 3 trial types × 3 durations = **18 conditions**
- **Trials per condition:** 10
- **Total trials:** 18 × 10 = **180 trials per participant**
- **Practice trials:** 5
- **Randomization:** Fully randomized across all 18 conditions

### Task
- Continuous color report using color wheel
- Same color patch stimuli as Sub-exp 1
- Participants cannot predict set-size or condition of next trial

### Key Question
Does context uncertainty (multiple set-sizes and conditions) affect encoding precision?

---

## Sub-Experiment 3: Multiple Features Effect Hypothesis

### Design Parameters
- **Set-sizes:** 4 and 6
- **Presentation durations:** 50ms, 100ms, 200ms (3 levels)
- **Trial types:**
  - Baseline: All unique items (no redundancy)
  - R-cue: Cue a redundant item for report
  - NR-cue: Cue a non-redundant item for report
- **Redundancy levels:**
  - Set-size 4: 2 redundant items (exact copies: same color AND same orientation)
  - Set-size 6: 3 redundant items (exact copies: same color AND same orientation)
- **Conditions:** 2 set-sizes × 3 trial types × 3 durations = **18 conditions**
- **Trials per condition:** 10
- **Total trials:** 18 × 10 = **180 trials per participant**
- **Practice trials:** 5
- **Stimuli:** Colored orientation bars (2 feature dimensions: color + orientation)
- **Task:** Cue color, report orientation (not color)

### Stimulus Details
- **Bar dimensions:** Width:Length ratio = 1:7
- **Bar length:** Approximately equal to current color patch diameter
- **Spatial layout:** Evenly spaced on invisible ring around fixation (same as current design)
- **Orientations:** 
  - Randomly drawn between 0-180°
  - All unique orientations in each set must be ≥10° apart
  - Redundant items count as one unique orientation
- **Colors:** 
  - Same as current design (360 possible colors from color wheel)
  - All colors in each set must be ≥30° apart on color wheel

### Retention Interval
- **Visual mask:** Circle that fully covers maximal range of possible stimuli display area
  - Must be larger than visible circle (since stimuli centers are on ring, parts extend outside)
  - Mask is fully filled with random colored orientation bars (same as stimuli)
  - Pre-rendered and reused across trials

### Response Method
- **Cue:** Orientation bar centered on fixation cross
  - Bar color matches the to-be-reported item's color
  - Bar serves as both cue and response interface
- **Interaction:**
  - **Mouse up/down:** Rotate orientation bar
    - Up = Counter-clockwise rotation
    - Down = Clockwise rotation
  - **Mouse left/right:** No effect (doesn't conflict with rotation)
  - **Left mouse click:** Confirm response
- **Penalties:** Same as current example
  - Too fast response
  - Too slow response
  - Cursor outside small central circle at start of response stage

### Key Question
Does encoding precision gain appear with 2-feature design (but not with single-feature color patches)?

---

## Common Parameters

### Practice Trials
- **All sub-experiments:** 5 practice trials

### Instructions
- **Different per sub-experiment**
- Will be detailed as we implement each one

### Feedback
- **Follow current example closely**
- Accuracy display between trials
- Performance tracking by set-size (where applicable)

### Data Recording
- **To be advised later**
- Will include: response angle, target angle, error, set-size, duration, condition, redundancy status, trial number, etc.

---

## Summary Table

| Parameter | Sub-Exp 1 | Sub-Exp 2 | Sub-Exp 3 |
|-----------|-----------|-----------|-----------|
| **Set-sizes** | 6 | 4, 6 | 4, 6 |
| **Durations** | 50-350ms (7) | 50, 100, 200ms (3) | 50, 100, 200ms (3) |
| **Trial types** | R-cue, NR-cue | Baseline, R-cue, NR-cue | Baseline, R-cue, NR-cue |
| **Conditions** | 14 | 18 | 18 |
| **Trials/condition** | 10 | 10 | 10 |
| **Total trials** | 140 | 180 | 180 |
| **Practice trials** | 5 | 5 | 5 |
| **Stimuli** | Color patches | Color patches | Colored orientation bars |
| **Response** | Color wheel | Color wheel | Rotating orientation bar |
| **Cue** | Color (white border) | Color (white border) | Color (colored bar) |
| **Retention mask** | None | None | Visual mask (colored bars) |

---

## Implementation Notes

### Sub-Experiment 1
- ✅ All parameters confirmed
- ✅ Can reuse current example's color wheel plugin
- ✅ Same stimuli generation as current example
- ✅ Need to implement R-cue vs NR-cue logic

### Sub-Experiment 2
- ✅ All parameters confirmed
- ✅ Can reuse color wheel plugin
- ✅ Need to implement multiple set-sizes (4 and 6)
- ✅ Need baseline condition (all unique)
- ✅ Need R-cue and NR-cue for both set-sizes

### Sub-Experiment 3
- ✅ All parameters confirmed
- ✅ Set-sizes: 4 and 6 (same as Sub-Exp 2)
- ✅ Stimuli: Colored orientation bars (1:7 ratio, length ≈ color patch diameter)
- ✅ Redundancy: 2 for set-size 4, 3 for set-size 6 (exact object copies)
- ✅ Orientations: 0-180°, ≥10° apart
- ✅ Colors: 360 colors from wheel, ≥30° apart
- ✅ Retention mask: Pre-rendered circle filled with random colored bars
- ✅ Response: Rotating orientation bar (up/down mouse, click to confirm)
- ✅ Cue: Colored bar at fixation matches target color

---

## Next Steps

1. ✅ **Sub-Exp 1:** Ready to implement (all parameters confirmed)
2. ✅ **Sub-Exp 2:** Ready to implement (all parameters confirmed)
3. ✅ **Sub-Exp 3:** Ready to implement (all parameters confirmed)

4. ⏳ **Common:** Waiting for:
   - Data recording specifications (to be determined after testable experiments)
   - Instruction text for each sub-experiment (to be detailed during implementation)

---

## Implementation Notes for Sub-Experiment 3

### Key Differences from Sub-Exp 1 & 2:
1. **Stimuli:** Colored orientation bars instead of color patches
2. **Response method:** Rotating bar (mouse up/down) instead of color wheel (mouse movement)
3. **Retention mask:** Visual mask required (pre-rendered)
4. **Cue:** Colored bar at fixation (not white border)
5. **Redundancy:** Both color AND orientation must match (exact object copies)

### Technical Requirements:
- Need to generate colored orientation bars (canvas drawing)
- Need orientation rotation logic (mouse up/down)
- Need pre-rendered visual mask
- Need to ensure orientation spacing (≥10° apart)
- Need to ensure color spacing (≥30° apart on wheel)
- Response confirmation via mouse click

---

## Confirmation Checklist

- [x] Sub-Exp 1: All parameters confirmed
- [x] Sub-Exp 2: All parameters confirmed
- [x] Sub-Exp 3: All parameters confirmed
- [ ] Data recording: To be determined after testable experiments
- [ ] Instructions: To be detailed during implementation

**Status:** All three sub-experiments are ready for implementation. Data recording details will be determined once we have working testable experiments.

