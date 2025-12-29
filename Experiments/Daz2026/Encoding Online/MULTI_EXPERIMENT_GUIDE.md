# Implementing Multiple Sub-Experiments: Guide

## Overview

You have 3 sub-experiments to implement. The framework supports **both approaches**, but one is significantly easier.

## Approach Comparison

### Option 1: Single Entry Link with Random Assignment ⭐ **RECOMMENDED**

**How it works:**
- One URL: `http://localhost:5000/unique-expt`
- Participants randomly assigned to 1 of 3 sub-experiments
- All data stored in one place
- Easy to manage and analyze

**Pros:**
- ✅ Easier to implement (modify `get_data()` only)
- ✅ Single experiment to manage
- ✅ Automatic condition tracking
- ✅ Balanced assignment (can ensure equal N per condition)
- ✅ One set of results files
- ✅ Easier data analysis

**Cons:**
- ⚠️ Can't manually assign specific participants to specific conditions
- ⚠️ All conditions share same experiment ID

---

### Option 2: Three Separate Experiments

**How it works:**
- Three URLs:
  - `http://localhost:5000/unique-expt?subexp=1`
  - `http://localhost:5000/unique-expt?subexp=2`
  - `http://localhost:5000/unique-expt?subexp=3`
- Or create 3 separate experiment projects

**Pros:**
- ✅ Can manually control which participants get which experiment
- ✅ Separate experiment IDs
- ✅ Can run them independently

**Cons:**
- ❌ More complex setup
- ❌ Need to manage 3 separate experiments
- ❌ Harder to ensure balanced assignment
- ❌ More files to maintain
- ❌ Results stored separately

---

## Recommendation: **Option 1 (Single Entry with Random Assignment)**

The framework is **already designed** for this! It's much simpler and more flexible.

---

## Implementation: Option 1 (Recommended)

### Step 1: Modify `expt_config.py`

The `get_data(opts)` function already receives URL parameters. You can:

**Option A: Random Assignment (Automatic)**
```python
def get_data(opts):
    import random
    
    # Randomly assign to one of 3 sub-experiments
    # This ensures balanced assignment over time
    subexperiment = random.choice([1, 2, 3])
    
    # Or use participant number for deterministic assignment
    # (ensures exactly balanced)
    # participant_n = get_participant_number()  # Would need to implement
    # subexperiment = (participant_n % 3) + 1
    
    # Prepare stimuli based on sub-experiment
    if subexperiment == 1:
        stimuli = prepare_subexperiment_1()
        trial_structure = get_trial_structure_1()
    elif subexperiment == 2:
        stimuli = prepare_subexperiment_2()
        trial_structure = get_trial_structure_2()
    else:  # subexperiment == 3
        stimuli = prepare_subexperiment_3()
        trial_structure = get_trial_structure_3()
    
    return {
        'subexperiment': subexperiment,
        'stimuli': stimuli,
        'trial_structure': trial_structure,
        # ... other data
    }
```

**Option B: URL Parameter Assignment (Manual Control)**
```python
def get_data(opts):
    # Allow manual assignment via URL: ?subexp=1
    # But default to random if not specified
    if 'subexp' in opts:
        subexperiment = int(opts['subexp'])
        if subexperiment not in [1, 2, 3]:
            subexperiment = random.choice([1, 2, 3])
    else:
        # Random assignment if no parameter
        subexperiment = random.choice([1, 2, 3])
    
    # ... rest of code
```

**Option C: Balanced Assignment (Recommended for Experiments)**
```python
def get_data(opts):
    import random
    
    # Get condition from URL if provided, otherwise random
    if 'subexp' in opts:
        subexperiment = int(opts['subexp'])
    else:
        # For balanced assignment, you could:
        # 1. Check existing participant counts (requires DB query)
        # 2. Use simple random (easiest)
        subexperiment = random.choice([1, 2, 3])
    
    # Store condition for tracking
    # The framework automatically stores this in participant record
    
    # Prepare experiment-specific data
    if subexperiment == 1:
        # Sub-experiment 1 logic
        pass
    elif subexperiment == 2:
        # Sub-experiment 2 logic
        pass
    else:
        # Sub-experiment 3 logic
        pass
    
    return {
        'subexperiment': subexperiment,
        # ... your data
    }
```

### Step 2: Modify `templates/exp.html`

Use the `subexperiment` value from Python to control JavaScript behavior:

```javascript
// Get data from Python
var expt_data = {{data|safe}};
var subexperiment = expt_data.subexperiment;  // 1, 2, or 3

// Build timeline based on sub-experiment
var timeline = [];

if (subexperiment === 1) {
    // Build timeline for sub-experiment 1
    timeline = build_subexperiment_1_timeline(expt_data);
} else if (subexperiment === 2) {
    // Build timeline for sub-experiment 2
    timeline = build_subexperiment_2_timeline(expt_data);
} else {
    // Build timeline for sub-experiment 3
    timeline = build_subexperiment_3_timeline(expt_data);
}

// Run experiment
jsPsych.run(timeline);
```

### Step 3: Track Condition in Data

The framework **automatically** stores the condition in the participant record. You can also include it in your experiment data:

```javascript
// In exp.html, add to data properties
jsPsych.data.addProperties({
    subexperiment: expt_data.subexperiment,
    // ... other properties
});
```

---

## Implementation: Option 2 (Three Separate Experiments)

If you really need separate experiments, you have two sub-options:

### Sub-Option 2A: Same Codebase, Different URLs

**Modify `expt_config.py`:**
```python
def get_data(opts):
    # Get sub-experiment from URL parameter
    subexp = opts.get('subexp', '1')  # Default to 1
    
    if subexp == '1':
        # Sub-experiment 1
        pass
    elif subexp == '2':
        # Sub-experiment 2
        pass
    else:
        # Sub-experiment 3
        pass
```

**Use different URLs:**
- `http://localhost:5000/unique-expt?subexp=1`
- `http://localhost:5000/unique-expt?subexp=2`
- `http://localhost:5000/unique-expt?subexp=3`

### Sub-Option 2B: Completely Separate Projects

Create 3 separate project folders:
- `Experiment1/`
- `Experiment2/`
- `Experiment3/`

Each with its own:
- `config.py` (different `EXPT_UID`)
- `expt_config.py`
- `templates/exp.html`
- `static_*/` folder

**This is more work and not recommended unless you have specific requirements.**

---

## Recommended Implementation Pattern

Here's a clean pattern for Option 1:

### `expt_config.py` Structure:

```python
def get_data(opts):
    import random
    
    # Determine sub-experiment
    if 'subexp' in opts:
        # Manual assignment via URL
        subexperiment = int(opts['subexp'])
        if subexperiment not in [1, 2, 3]:
            subexperiment = random.choice([1, 2, 3])
    else:
        # Random assignment
        subexperiment = random.choice([1, 2, 3])
    
    # Prepare data based on sub-experiment
    experiment_data = prepare_subexperiment(subexperiment)
    
    return {
        'subexperiment': subexperiment,
        **experiment_data  # Unpack all experiment-specific data
    }

def prepare_subexperiment(subexp_num):
    """Prepare stimuli and structure for a specific sub-experiment"""
    if subexp_num == 1:
        return {
            'stimuli': load_stimuli_type_1(),
            'trial_structure': get_structure_1(),
            'parameters': get_params_1(),
        }
    elif subexp_num == 2:
        return {
            'stimuli': load_stimuli_type_2(),
            'trial_structure': get_structure_2(),
            'parameters': get_params_2(),
        }
    else:  # subexp_num == 3
        return {
            'stimuli': load_stimuli_type_3(),
            'trial_structure': get_structure_3(),
            'parameters': get_params_3(),
        }
```

### `templates/exp.html` Structure:

```javascript
var expt_data = {{data|safe}};
var subexp = expt_data.subexperiment;

// Common setup
var timeline = [];
timeline.push(preload);
timeline.push(instructions);
timeline.push(consent);

// Sub-experiment specific trials
if (subexp === 1) {
    timeline = timeline.concat(build_trials_subexp1(expt_data));
} else if (subexp === 2) {
    timeline = timeline.concat(build_trials_subexp2(expt_data));
} else {
    timeline = timeline.concat(build_trials_subexp3(expt_data));
}

// Common ending
timeline.push(debrief);

jsPsych.run(timeline);
```

---

## Condition Tracking

The framework **automatically tracks conditions**:

1. **In Participant Record**: The `trial` field stores the condition
2. **In Experiment Data**: You include it in your data structure
3. **In Results**: Both are saved together

You can query results by condition later for analysis.

---

## Example: Complete Implementation

Here's a minimal working example:

### `expt_config.py`:
```python
import random

def get_data(opts):
    # Random assignment (or use opts.get('subexp') for manual)
    subexp = random.choice([1, 2, 3])
    
    # Example: Different stimuli per sub-experiment
    if subexp == 1:
        stimuli = ['stim1a.png', 'stim1b.png', 'stim1c.png']
        n_trials = 20
    elif subexp == 2:
        stimuli = ['stim2a.png', 'stim2b.png', 'stim2c.png']
        n_trials = 30
    else:
        stimuli = ['stim3a.png', 'stim3b.png', 'stim3c.png']
        n_trials = 25
    
    return {
        'subexperiment': subexp,
        'stimuli': stimuli,
        'n_trials': n_trials
    }
```

### `templates/exp.html`:
```javascript
var expt_data = {{data|safe}};
var subexp = expt_data.subexperiment;
var stimuli = expt_data.stimuli;

var timeline = [];

// Common parts
timeline.push(instructions);
timeline.push(consent);

// Sub-experiment specific trials
for (var i = 0; i < stimuli.length; i++) {
    timeline.push({
        type: jsPsychImageKeyboardResponse,
        stimulus: stimuli[i],
        choices: ['f', 'j'],
        data: {
            subexperiment: subexp,
            trial: i + 1
        }
    });
}

timeline.push(debrief);

jsPsych.run(timeline);
```

---

## Testing Your Implementation

### Test Random Assignment:
1. Visit `http://localhost:5000/unique-expt` multiple times
2. Check browser console: `console.log(expt_data.subexperiment)`
3. Should see different values (1, 2, or 3)

### Test Manual Assignment:
1. Visit `http://localhost:5000/unique-expt?subexp=1`
2. Should always get sub-experiment 1
3. Test with `?subexp=2` and `?subexp=3`

### Verify Data:
- Check that `subexperiment` is saved in results
- Verify correct stimuli/trials for each sub-experiment

---

## Summary

**Recommended Approach: Single Entry with Random Assignment**

✅ **Easiest to implement** - Just modify `get_data()` and `exp.html`
✅ **Framework already supports it** - Condition tracking built-in
✅ **Better for experiments** - Balanced assignment, easier analysis
✅ **Flexible** - Can still manually assign via URL if needed

**Implementation Steps:**
1. Modify `get_data()` in `expt_config.py` to assign sub-experiment
2. Prepare different stimuli/structure based on sub-experiment
3. Modify `exp.html` to use sub-experiment value
4. Test with multiple participants

**That's it!** The framework handles the rest (participant tracking, data saving, etc.)

