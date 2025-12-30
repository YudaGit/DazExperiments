# Implementation Changes: Sub-Experiment Routing Framework

## Overview

This document explains the changes made to implement the single-entry random assignment system for routing participants to 1 of 3 sub-experiments.

---

## Changes Made

### 1. File: `expt_config.py`

#### What Changed:
- **Modified `get_data()` function** to include sub-experiment assignment logic
- **Added three new functions**: `prepare_subexperiment_1()`, `prepare_subexperiment_2()`, `prepare_subexperiment_3()`

#### Detailed Changes:

**A. Modified `get_data(opts)` function:**

**Before:**
```python
def get_data(opts):
    # Setup experiment tasks
    print(opts)
    word_list = fetch_word_list()
    # ... word list processing ...
    return {
        'study_list': study_list,
        'test_list': test_list,
        'study_document_order': study_document_order
    }
```

**After:**
```python
def get_data(opts):
    # STEP 1: Determine which sub-experiment to run
    if 'subexp' in opts:
        # Manual assignment via URL parameter (?subexp=1)
        subexperiment = int(opts['subexp'])
        if subexperiment not in [1, 2, 3]:
            subexperiment = random.choice([1, 2, 3])
    else:
        # Random assignment: randomly choose 1 of 3
        subexperiment = random.choice([1, 2, 3])
    
    # STEP 2: Prepare experiment-specific data
    if subexperiment == 1:
        experiment_data = prepare_subexperiment_1()
    elif subexperiment == 2:
        experiment_data = prepare_subexperiment_2()
    else:
        experiment_data = prepare_subexperiment_3()
    
    # STEP 3: Return data structure
    return {
        'subexperiment': subexperiment,  # Always include this!
        **experiment_data  # Unpack experiment-specific data
    }
```

**Key Features:**
1. **Random Assignment**: If no URL parameter, randomly assigns to 1, 2, or 3
2. **Manual Override**: Can force assignment via URL: `?subexp=1`, `?subexp=2`, or `?subexp=3`
3. **Validation**: Checks that manual assignment is valid (1-3), falls back to random if invalid
4. **Always Returns `subexperiment`**: JavaScript needs this to know which experiment to run

**B. Added `prepare_subexperiment_1()` function:**

```python
def prepare_subexperiment_1():
    """Sub-Experiment 1: Practice Effect Hypothesis"""
    return {
        'experiment_type': 'practice_effect',
        'set_size': 6,
        'durations': [50, 100, 150, 200, 250, 300, 350],
        'trial_types': ['R-cue', 'NR-cue'],
        'n_trials_per_condition': 10,
        'n_practice_trials': 5,
        'total_trials': 140,
        'trials': []  # Placeholder - will generate later
    }
```

**Purpose:** Returns experiment parameters for Sub-Exp 1. Currently returns placeholder structure - will be filled in when we implement the full experiment.

**C. Added `prepare_subexperiment_2()` function:**

```python
def prepare_subexperiment_2():
    """Sub-Experiment 2: Context Effect Hypothesis"""
    return {
        'experiment_type': 'context_effect',
        'set_sizes': [4, 6],
        'durations': [50, 100, 200],
        'trial_types': ['Baseline', 'R-cue', 'NR-cue'],
        'n_trials_per_condition': 10,
        'n_practice_trials': 5,
        'total_trials': 180,
        'trials': []  # Placeholder
    }
```

**Purpose:** Returns experiment parameters for Sub-Exp 2.

**D. Added `prepare_subexperiment_3()` function:**

```python
def prepare_subexperiment_3():
    """Sub-Experiment 3: Multiple Features Effect Hypothesis"""
    return {
        'experiment_type': 'multiple_features',
        'set_sizes': [4, 6],
        'durations': [50, 100, 200],
        'trial_types': ['Baseline', 'R-cue', 'NR-cue'],
        'n_trials_per_condition': 10,
        'n_practice_trials': 5,
        'total_trials': 180,
        'stimulus_type': 'colored_orientation_bars',
        'trials': []  # Placeholder
    }
```

**Purpose:** Returns experiment parameters for Sub-Exp 3.

---

### 2. File: `templates/exp.html`

#### What Changed:
- **Added subexperiment extraction** from Python data
- **Added console logging** for debugging
- **Updated experiment name** to include subexperiment number
- **Added subexperiment to saved data**

#### Detailed Changes:

**A. Added subexperiment extraction (after line 58):**

**Before:**
```javascript
var expt_data = {{data|safe}};
var studyFinished = true
```

**After:**
```javascript
// STEP 1: Get data from Python (includes subexperiment assignment)
var expt_data = {{data|safe}};
var subexperiment = expt_data.subexperiment;  // 1, 2, or 3

// Log which sub-experiment was assigned (for debugging)
console.log("========================================");
console.log("Sub-Experiment Assignment:", subexperiment);
console.log("Experiment Type:", expt_data.experiment_type);
console.log("Full experiment data:", expt_data);
console.log("========================================");

var studyFinished = true
```

**Purpose:** 
- Extracts subexperiment number from Python data
- Logs assignment to browser console for debugging
- Makes subexperiment available to rest of JavaScript code

**B. Updated experiment name (around line 196):**

**Before:**
```javascript
var experiment_name = 'Daz2024_PostStimCue_REP';
var experiment_timeline = [];
```

**After:**
```javascript
// STEP 2: Set experiment name and initialize timeline
var experiment_name = 'Daz2026_Encoding_Online_SubExp' + subexperiment;
var experiment_timeline = [];

// STEP 3: Route to appropriate sub-experiment
// For now, all sub-experiments will run the current example
// Later, we'll implement specific logic for each sub-experiment

console.log("Building timeline for Sub-Experiment", subexperiment);
```

**Purpose:**
- Experiment name now includes subexperiment number (e.g., "SubExp1", "SubExp2", "SubExp3")
- Makes it easy to identify which sub-experiment data came from
- Added comment noting that routing logic will be added later

**C. Added subexperiment to saved data (around line 622):**

**Before:**
```javascript
jsPsych.data.addProperties({
    experiment: experiment_name,
    subject_id: random_id,
    // ... other properties
});
```

**After:**
```javascript
jsPsych.data.addProperties({
    experiment: experiment_name,
    subexperiment: subexperiment,  // Add subexperiment to data
    experiment_type: expt_data.experiment_type,  // Add experiment type
    subject_id: random_id,
    // ... other properties
});
```

**Purpose:**
- Saves subexperiment number in all trial data
- Saves experiment type string (e.g., "practice_effect")
- Makes it easy to filter/analyze data by sub-experiment later

---

## How It Works

### Flow Diagram:

```
Participant visits URL
    ↓
Flask calls get_data(opts)
    ↓
Python randomly assigns subexperiment (1, 2, or 3)
    OR manually assigns if ?subexp=X in URL
    ↓
Python calls prepare_subexperiment_X()
    ↓
Python returns data with 'subexperiment' key
    ↓
Flask renders exp.html with data
    ↓
JavaScript extracts subexperiment from data
    ↓
JavaScript logs assignment (for debugging)
    ↓
JavaScript builds timeline (currently same for all)
    ↓
JavaScript saves subexperiment in all trial data
```

### Example URLs:

1. **Random Assignment:**
   ```
   http://localhost:5000/unique-expt
   ```
   - Randomly assigns to 1, 2, or 3

2. **Manual Assignment:**
   ```
   http://localhost:5000/unique-expt?subexp=1
   http://localhost:5000/unique-expt?subexp=2
   http://localhost:5000/unique-expt?subexp=3
   ```
   - Forces specific sub-experiment

---

## Testing the Changes

### How to Test:

1. **Start the server:**
   ```bash
   python experiment.py
   ```

2. **Test random assignment:**
   - Visit `http://localhost:5000/unique-expt` multiple times
   - Open browser console (F12)
   - Should see different subexperiment assignments (1, 2, or 3)
   - Check console logs for assignment

3. **Test manual assignment:**
   - Visit `http://localhost:5000/unique-expt?subexp=1`
   - Should always get Sub-Experiment 1
   - Test with `?subexp=2` and `?subexp=3`

4. **Verify data saving:**
   - Complete a trial (or just check console)
   - Data should include `subexperiment` and `experiment_type` fields

### Expected Console Output:

```
========================================
Sub-Experiment Assignment: 2
Experiment Type: context_effect
Full experiment data: {subexperiment: 2, experiment_type: "context_effect", ...}
========================================
Building timeline for Sub-Experiment 2
```

---

## Current Status

### ✅ What's Working:
- Random assignment to 1 of 3 sub-experiments
- Manual assignment via URL parameter
- Subexperiment number passed to JavaScript
- Subexperiment saved in trial data
- Console logging for debugging

### ⏳ What's Next:
- **Sub-Experiment 1**: Implement full trial structure (140 trials, 7 durations × 2 cue types)
- **Sub-Experiment 2**: Implement full trial structure (180 trials, multiple set-sizes)
- **Sub-Experiment 3**: Implement colored orientation bars and rotation response

### 📝 Notes:
- Currently, all 3 sub-experiments run the same timeline (the current example)
- This is intentional - we're building the framework first
- Next step: Implement Sub-Experiment 1's specific trial structure

---

## Key Concepts

### 1. **Random vs. Manual Assignment:**
- **Random**: `get_data({})` → randomly chooses 1, 2, or 3
- **Manual**: `get_data({'subexp': '1'})` → forces Sub-Experiment 1

### 2. **Data Flow:**
- Python prepares data → Flask passes to template → JavaScript uses it
- `subexperiment` key is critical - JavaScript uses it to know which experiment to run

### 3. **Extensibility:**
- Each `prepare_subexperiment_X()` function can return different data structures
- JavaScript can check `subexperiment` and build different timelines
- Easy to add new sub-experiments later

---

## Files Modified

1. **`expt_config.py`**
   - Modified `get_data()` function
   - Added `prepare_subexperiment_1()`
   - Added `prepare_subexperiment_2()`
   - Added `prepare_subexperiment_3()`

2. **`templates/exp.html`**
   - Added subexperiment extraction
   - Added console logging
   - Updated experiment name
   - Added subexperiment to saved data

---

## Next Steps

1. ✅ Framework is in place
2. ⏭️ Test the routing works correctly
3. ⏭️ Implement Sub-Experiment 1's trial structure
4. ⏭️ Implement Sub-Experiment 2's trial structure
5. ⏭️ Implement Sub-Experiment 3's trial structure

---

## Questions?

If anything is unclear, check:
- Browser console for assignment logs
- Flask terminal for Python print statements
- Saved data files for `subexperiment` field

