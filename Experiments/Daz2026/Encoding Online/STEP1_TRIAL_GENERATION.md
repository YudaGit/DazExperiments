# Step 1: Trial Generation Implementation - COMPLETE ✅

## What Was Implemented

### Overview
Implemented the Python backend trial generation system for Sub-Experiment 1. This matches the logic from your Matlab `TrialMatrix.m` function.

---

## Changes Made to `expt_config.py`

### 1. Modified `prepare_subexperiment_1()` Function

**Before:** Returned placeholder structure
**After:** Now generates actual trial data

**What it does:**
1. Sets design parameters (set-size=6, redundant_n=3, 7 durations, 2 cue types)
2. Calls `generate_trials_subexp1()` to create 140 main trials
3. Calls `generate_practice_trials_subexp1()` to create 5 practice trials
4. Returns complete trial structure

**Key Parameters:**
- `set_size = 6` (fixed)
- `redundant_n = 3` (always 3 redundant items)
- `durations_ms = [50, 100, 150, 200, 250, 300, 350]` (7 levels)
- `cue_types = ['R-cue', 'NR-cue']` (2 types)
- `n_trials_per_condition = 10`
- `n_practice_trials = 5`

---

### 2. Added `generate_trials_subexp1()` Function

**Purpose:** Creates all trial combinations and randomizes order

**How it works:**
1. Creates all combinations: `itertools.product(durations_ms, cue_types)`
   - 7 durations × 2 cue types = 14 conditions
2. Repeats each condition 10 times = 140 trials
3. Shuffles all trials randomly
4. Adds trial numbers (1-140)

**Returns:** List of 140 trial dictionaries

---

### 3. Added `generate_single_trial_subexp1()` Function

**Purpose:** Generates one trial with random colors, positions, and target

**What it generates:**
- **Colors:** 6 colors with redundancy (3 same, 3 unique, ≥30° spacing)
- **Positions:** 6 evenly spaced positions on ring (shuffled)
- **Target:** Selected based on cue type:
  - R-cue: Randomly picks from redundant items
  - NR-cue: Randomly picks from non-redundant items

**Returns:** Dictionary with all trial properties

---

### 4. Added `generate_colors_with_redundancy()` Function

**Purpose:** Generates colors matching Matlab logic

**How it works:**
1. Chooses one random color for redundant items (0-359°)
2. Generates unique colors for non-redundant items:
   - Each must be ≥30° from redundant color
   - Each must be ≥30° from other unique colors
3. Randomly assigns which 3 positions get redundant color
4. Assigns unique colors to remaining 3 positions

**Constraints:**
- Minimum spacing: 30° between all colors (matches Matlab `minDist = 30`)
- Maximum attempts: 100 (to avoid infinite loops)

**Returns:** List of 6 color angles (0-359)

---

### 5. Added `generate_positions_evenly_spaced()` Function

**Purpose:** Generates evenly spaced positions on ring

**How it works:**
1. Calculates spacing: 360° / set_size = 60° per item
2. Random starting angle (0 to spacing-1)
3. Creates evenly spaced positions
4. Shuffles order (but maintains spacing)

**Returns:** List of 6 position angles (0-359)

---

### 6. Added `get_redundant_indices()` Function

**Purpose:** Finds which items have redundant colors

**How it works:**
1. Counts frequency of each color
2. Finds color that appears `redundant_n` times (should be 3)
3. Returns all indices with that color

**Returns:** List of indices (e.g., [0, 2, 5])

---

### 7. Added `min_circular_distance()` Function

**Purpose:** Calculates minimum circular distance between angles

**How it works:**
- Calculates both clockwise and counter-clockwise distances
- Returns the smaller one (0-180°)

**Example:**
- `min_circular_distance(10, 350)` = 20° (not 340°)

---

### 8. Added `generate_practice_trials_subexp1()` Function

**Purpose:** Generates 5 practice trials

**How it works:**
1. Uses subset of durations: [100, 200, 300]ms
2. Randomly selects duration and cue type for each practice trial
3. Uses same trial generation logic as main trials
4. Marks trials as practice (`is_practice = True`)

**Returns:** List of 5 practice trial dictionaries

---

## Data Structure

Each trial dictionary contains:

```python
{
    'duration_ms': 250,              # Presentation duration (50-350ms)
    'cue_type': 'NR-cue',            # 'R-cue' or 'NR-cue'
    'set_size': 6,                   # Always 6
    'redundant_n': 3,                # Always 3
    'colors': [115, 219, 287, 318, 115, 115],  # 6 color angles (0-359)
    'positions': [278.0, 98.0, 218.0, 38.0, 158.0, 338.0],  # 6 position angles
    'target': 3,                     # Index of target item (0-5)
    'is_redundant_target': False,    # Whether target is redundant
    'redundant_indices': [0, 4, 5],  # Which indices are redundant
    'trial_number': 1                # Trial number (1-140)
}
```

---

## Verification

✅ **Test Results:**
- Total trials: 140 (correct: 14 conditions × 10 reps)
- Practice trials: 5 (correct)
- Trial structure: All required fields present
- Color generation: Working with spacing constraints
- Position generation: Evenly spaced, shuffled
- Target selection: Correct based on cue type

---

## Comparison with Matlab

| Matlab Function | Python Function | Status |
|----------------|-----------------|--------|
| `TrialMatrix()` | `generate_trials_subexp1()` | ✅ Implemented |
| `enrichRows()` | `generate_single_trial_subexp1()` | ✅ Implemented |
| `randColors()` | `generate_colors_with_redundancy()` | ✅ Implemented |
| Position generation | `generate_positions_evenly_spaced()` | ✅ Implemented |
| `circDist()` | `min_circular_distance()` | ✅ Implemented |

---

## Next Steps

**Step 2:** Modify JavaScript (`templates/exp.html`) to:
1. Extract trial data from Python
2. Build jsPsych timeline using trial data
3. Display color patches with correct colors and positions
4. Implement variable duration display
5. Implement R-cue vs NR-cue target selection

---

## Files Modified

1. ✅ `expt_config.py`
   - Modified `prepare_subexperiment_1()`
   - Added 8 new functions for trial generation

2. ✅ `expt_config_trial_functions.py` (temporary helper file)
   - Contains function definitions (can be deleted)

3. ✅ `append_functions.py` (temporary helper script)
   - Used to append functions (can be deleted)

---

## Key Concepts Learned

1. **Trial Generation:** Create all combinations, repeat, shuffle
2. **Color Constraints:** Minimum spacing ensures colors are distinguishable
3. **Redundancy:** Same color assigned to multiple positions
4. **Target Selection:** Based on cue type (R vs NR)
5. **Position Spacing:** Evenly spaced on ring, then shuffled

---

## Testing

To test trial generation:
```python
import expt_config
import random
random.seed(42)  # For reproducible testing
data = expt_config.prepare_subexperiment_1()
print(f"Total trials: {len(data['trials'])}")
print(f"Practice trials: {len(data['practice_trials'])}")
print(f"First trial: {data['trials'][0]}")
```

Expected output:
- Total trials: 140
- Practice trials: 5
- Each trial has all required fields

