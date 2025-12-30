# Matlab Code Analysis: Original Encoding Study

## Overview

The original experiment (`Exp1_Encoding_1.m`) is a continuous color-report task with:
- **Set-size:** 6 color patches
- **Redundancy:** 3 redundant items (same color)
- **Cue types:** R (redundant) or NR (non-redundant)
- **Durations:** 50, 100, 150, 200, 250, 300, 350ms (7 levels)
- **Design:** 2 cue types × 7 durations = 14 conditions
- **Reps:** 30 per condition in original (we'll use 10 per condition = 140 trials)

---

## Key Components

### 1. Trial Generation (`TrialMatrix.m`)

**Function:** `TrialMatrix(design, sessionN, participantID, age, timestamp)`

**What it does:**
1. Creates all combinations of factors (Cartesian product)
2. Repeats each combination N times (practice vs main)
3. Shuffles trials within block
4. Enriches each trial with:
   - Random colors (with spacing constraints)
   - Random positions (evenly spaced on ring)
   - Target selection (based on cue type)
   - Response collection columns

**Key Logic:**
- **Color generation:** 
  - One duplicate color for redundant items
  - Unique colors for non-redundant items
  - Minimum 30° spacing between all colors
- **Position generation:**
  - Evenly spaced on invisible ring
  - Random starting angle
  - Shuffled order
- **Target selection:**
  - R-cue: Target is one of the redundant items
  - NR-cue: Target is one of the non-redundant items

### 2. Trial Structure (from `Exp1_Encoding_1.m`)

**Practice Loop:**
```
For each practice trial:
  1. Fixation (1.0s)
  2. Draw Stimulus
  3. Wait (PresDur - varies by trial)
  4. Mask (0.75s)
  5. Get Response (color wheel)
  6. Speed Check
  7. Draw Feedback
  8. Wait (feedback duration or penalty)
  9. Neutral Wheel (0.005s - retinal reset)
  10. Inter-trial Feedback
```

**Main Loop:**
```
Same as practice, but:
- No instructions between trials
- Inter-trial feedback shows progress
```

### 3. Stimulus Generation

**Colors:**
- 360 possible colors (from color wheel)
- Redundant items: same color
- Non-redundant items: unique colors
- Minimum spacing: 30° between all colors

**Positions:**
- 6 items evenly spaced on ring
- Random starting angle
- Shuffled order

**Target:**
- R-cue: Randomly select from redundant positions
- NR-cue: Randomly select from non-redundant positions

### 4. Response Collection

**Method:**
- Color wheel displayed
- Mouse movement tracked
- Response when mouse leaves inner annulus
- Records: mouse X/Y, angles, distances, time, response angle, precision

**Speed Checks:**
- Too fast: < 150ms to leave center
- Too slow: > 50s to leave center
- Trial too slow: > 3000ms total

### 5. Feedback

**Trial Feedback:**
- Shows color wheel
- Red line: participant's response
- Green line: correct answer
- Green arc: shortest path between them
- Speed penalty messages if applicable

**Inter-trial Feedback:**
- Bar plot showing precision per trial
- Progress indicator
- Click to continue

---

## Implementation Mapping

### Matlab → Python/jsPsych

| Matlab | Python/jsPsych |
|--------|----------------|
| `TrialMatrix()` | `prepare_subexperiment_1()` in `expt_config.py` |
| `DrawStimulus()` | Custom jsPsych plugin (color patches) |
| `GetResponse()` | `jsConfidenceWheel` plugin |
| `DrawWheelFeedback()` | Built into `jsConfidenceWheel` |
| `DrawIntertrialFeedbackFast()` | `jsAdvPlot` plugin |
| `Mask()` | Blank screen or mask |
| `fixation()` | Simple HTML/CSS fixation |

---

## Key Parameters

### Design Parameters:
- `ItemN = 6` (set-size)
- `RedundantN = 3` (number of redundant items)
- `CueType = {'R', 'NR'}` (2 types)
- `presDurList = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35]` (7 durations in seconds)
- `retDurList = 0.75` (retention/mask duration)

### Timing:
- Fixation: 1.0s
- Stimulus: Variable (50-350ms)
- Mask: 0.75s
- Response: Up to 10s
- Feedback: 0.75s (or 2.0s if penalty)
- Retinal reset: 0.005s

### Constraints:
- Color spacing: ≥30° between all colors
- Position spacing: Evenly spaced on ring
- Target selection: Based on cue type

---

## Trial Generation Logic

### Step-by-Step:

1. **Create all combinations:**
   - ItemN (6) × RedundantN (3) × CueType (R, NR) × PresDur (7) = 14 conditions

2. **Repeat each condition:**
   - 10 times per condition = 140 trials total

3. **Shuffle:**
   - Randomize order within block

4. **For each trial:**
   - Generate colors (1 duplicate + 5 unique, ≥30° apart)
   - Generate positions (evenly spaced, shuffled)
   - Select target (R-cue: from redundant, NR-cue: from non-redundant)
   - Store trial parameters

---

## Next Steps for Implementation

1. **Step 1:** Implement trial generation in Python (`expt_config.py`)
2. **Step 2:** Modify JavaScript to use trial data
3. **Step 3:** Implement proper trial structure (fixation → stimulus → mask → response)
4. **Step 4:** Add feedback and inter-trial displays
5. **Step 5:** Test and verify against Matlab version

