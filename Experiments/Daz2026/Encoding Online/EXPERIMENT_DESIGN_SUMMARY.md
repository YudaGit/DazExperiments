# Experiment Design Summary: Three Sub-Experiments

## Background: Original Experiment

**Design:**
- Set-size: 6 (6 simultaneous color patches)
- Presentation durations: 50ms, 100ms, 150ms, 200ms, 250ms, 300ms, 350ms (7 levels)
- Redundancy: Always 3 redundant items within each set
- Task: Continuous VWM color report (like current example)

**Key Finding:**
- Longer encoding time did **NOT** improve performance
- Redundant items were **more precisely reported** than non-redundant ones
- **Hypothesis**: Redundancy gain is memory-centric (information integration), not encoding/perceptual

**Contrast with Prior Study:**
- Prior study found encoding precision gain
- Used different design (colored orientation bars, 2 feature dimensions)
- Used naive participants (vs. your practiced participants)

---

## Sub-Experiment 1: Practice Effect Hypothesis

### Hypothesis
Practice effects masked encoding effects. Heavily practiced participants (lab) vs. less practiced participants (online) may show different patterns.

### Design
- **Same as original experiment:**
  - Set-size: 6
  - Presentation durations: 50ms, 100ms, 150ms, 200ms, 250ms, 300ms, 350ms (7 levels)
  - Redundancy: Always 3 redundant items per set
  - Task: Continuous color report (color wheel)

- **Key difference:**
  - Online participants (less practiced)
  - Each participant contributes ~100 trials (vs. many more in lab)
  - Should reveal encoding effects if practice was masking them

### Expected Outcome
If encoding effects appear in online (less practiced) participants, this supports the practice effect hypothesis.

### Questions to Clarify:
1. How many trials per duration level? (e.g., ~14-15 trials per duration = ~100 total?)
2. Same randomization as original? (duration randomized across trials?)
3. Same practice trials? (how many?)
4. Same instructions/design as current example?

---

## Sub-Experiment 2: Context Effect Hypothesis

### Hypothesis
Precision effects change if participants know the exact stimulus context. Using multiple set-sizes and conditions prevents participants from predicting the next trial's context.

### Design
- **Set-sizes:** At least 4 and 6 (possibly more? e.g., 2, 4, 6?)
- **Conditions:**
  - Baseline: All unique items (no redundancy)
  - Redundancy: Some items are redundant (how many redundant? same as original - 3 for set-size 6?)
- **Task:** Continuous color report (color wheel)
- **Key feature:** Participants cannot predict:
  - Which set-size next trial will be
  - Whether next trial will be baseline or redundancy condition

### Expected Outcome
If context uncertainty affects encoding precision, we should see different patterns compared to original (where context was predictable).

### Questions to Clarify:
1. **Set-sizes:** Just 4 and 6? Or include 2 as well? Or more?
2. **Redundancy levels:** 
   - For set-size 4: How many redundant? (e.g., 2 redundant?)
   - For set-size 6: 3 redundant (same as original)?
   - Or vary redundancy levels?
3. **Presentation duration:** 
   - Same durations as original (50-350ms)?
   - Or fixed duration?
   - Or different durations?
4. **Trial structure:**
   - Randomize set-size across trials?
   - Randomize condition (baseline vs. redundancy) across trials?
   - Fully crossed design? (all set-sizes × all conditions)
5. **Number of trials:** How many total? Per condition?
6. **Stimuli:** Same color patches as original/Sub-exp 1?

---

## Sub-Experiment 3: Multiple Features Effect Hypothesis

### Hypothesis
The encoding precision gain reported in prior study may be specific to their design (2 feature dimensions: color + orientation).

### Design
- **Stimuli:** Colored orientation bars (different from color patches)
  - Feature 1: Color (multiple colors)
  - Feature 2: Orientation (multiple orientations)
  - No direction (just static bars)
- **Task:** 
  - Show colored orientation bars
  - Cue the **color** (which bar to report)
  - Ask participant to report the **orientation** (not the color)
- **This replicates prior study's design**

### Expected Outcome
If encoding precision gain appears with this design (but not with single-feature color patches), it suggests the effect is design-specific.

### Questions to Clarify:
1. **Set-size:** Same as original (6)? Or different?
2. **Presentation duration:** Same durations (50-350ms)? Or fixed?
3. **Redundancy:** Include redundancy conditions? Or just baseline?
4. **Cueing:** How is the color cued? (white border like current example?)
5. **Response method:** 
   - Orientation wheel (like color wheel)?
   - Or different response method?
6. **Number of trials:** How many?
7. **Stimulus generation:**
   - How many colors?
   - How many orientations?
   - How are they combined?

---

## Common Questions Across All Sub-Experiments

### Trial Structure:
1. **Fixation:** Same as current example (~200ms)?
2. **Stimulus presentation:** Duration varies (Sub-exp 1, 3) or fixed (Sub-exp 2)?
3. **Retention interval:** Same as current example (1000ms)?
4. **Response:** Same color wheel interface? (or orientation wheel for Sub-exp 3)
5. **Feedback:** Same feedback as current example? (accuracy display between trials)

### Practice Trials:
1. How many practice trials per sub-experiment?
2. Same practice structure for all 3?
3. Practice includes all conditions/durations?

### Instructions:
1. Different instructions per sub-experiment?
2. Or same basic instructions with sub-experiment-specific details?

### Data Collection:
1. What data needs to be recorded?
   - Response angle
   - Target angle
   - Error (angular difference)
   - Set-size
   - Duration (for Sub-exp 1, 3)
   - Condition (baseline vs. redundancy)
   - Redundancy status of cued item
   - Trial number
   - etc.

### Randomization:
1. How should trials be randomized?
2. Blocked by condition? Or fully randomized?
3. Counterbalancing needed?

---

## Implementation Considerations

### Similarities Across Sub-Experiments:
- All use continuous report (wheel interface)
- All are VWM tasks
- Sub-exp 1 and 2 use same color patch stimuli
- Similar trial structure (fixation → stimulus → retention → response)

### Differences:
- **Sub-exp 1:** Same as original, just less practiced participants
- **Sub-exp 2:** Multiple set-sizes, baseline vs. redundancy conditions
- **Sub-exp 3:** Different stimuli (colored orientation bars), report orientation not color

### Code Reuse:
- Can reuse color wheel plugin for Sub-exp 1 and 2
- Need orientation wheel plugin for Sub-exp 3 (or modify existing)
- Can reuse trial structure framework
- Need different stimulus generation per sub-experiment

---

## Next Steps

Please clarify:
1. **Sub-experiment 1:** Trial numbers, randomization, practice trials
2. **Sub-experiment 2:** Set-sizes, redundancy levels, durations, trial numbers
3. **Sub-experiment 3:** Set-size, durations, redundancy, cueing method, response method, stimulus parameters
4. **Common:** Practice trials, instructions, feedback, data to record

Once clarified, we can proceed with implementation!

