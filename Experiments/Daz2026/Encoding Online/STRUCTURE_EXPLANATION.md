# Project Structure: What You Modify vs. What Stays the Same

## Question 1: Is `experiment.py` Generic and Reusable?

**Answer: YES - `experiment.py` is completely generic and can be used as-is for all similar experiments.**

### What `experiment.py` Does (Generic Framework):

1. **Sets up Flask application** - Creates the web server
2. **Defines routes** - Handles different entry points:
   - `/unique-expt` - Creates new participant
   - `/expt` - Starts experiment for existing participant
   - `/mturk-expt` - For MTurk workers
   - `/prolific` - For Prolific participants
   - `/rep-expt` - For REP participants
   - `/record-task` - Receives experiment data (POST endpoint)

3. **Calls your experiment function** - The key line is:
   ```python
   data = me_expt.check_set_participant_attrs(uid, get_data(request.args), DEBUG)
   ```
   This calls `get_data()` from `expt_config.py` - **your experiment-specific function**

4. **Renders template** - Always renders `exp.html`:
   ```python
   return render_template('exp.html', uid=uid, data=json.dumps(data))
   ```

### What You DON'T Need to Change:

- ✅ All Flask routes (`@app.route` decorators)
- ✅ Participant management (creating records, checking status)
- ✅ Data saving logic (`/record-task` endpoint)
- ✅ Error handling
- ✅ Template rendering logic

### What You MIGHT Change (Rare Cases):

- ❌ If you need a different HTML template name (not `exp.html`)
- ❌ If you need additional custom routes (but these go in `expt_config.py` as a Blueprint)
- ❌ If you need different participant types (but the existing ones cover most cases)

**Bottom Line:** `experiment.py` is a **generic framework** that works for any experiment. It doesn't know or care what your experiment does - it just calls `get_data()` and renders the template.

---

## Question 2: Can Flask Setup/Functions Be Left As-Is?

**Answer: YES - All Flask setup and framework functions can be left as-is.**

### What Stays the Same (Framework Code):

#### In `experiment.py`:
- ✅ Flask app initialization
- ✅ Static file serving setup
- ✅ S3 configuration
- ✅ All route handlers
- ✅ Error handlers
- ✅ Participant management calls

#### In `MallExperiment.py`:
- ✅ `Expt` class - handles participant database operations
- ✅ `create_unique_participant()` - creates participant records
- ✅ `start_expt()` - marks participant as started
- ✅ `complete_expt()` - saves results to S3
- ✅ `get_participant()` - retrieves participant data
- ✅ `set_participant_attrs()` - updates participant attributes
- ✅ S3 file operations (`get_S3()`, `save_S3()`)

#### In `user_utils.py`:
- ✅ `@nocache` decorator - prevents browser caching
- ✅ `@restrictions` decorator - checks device/browser restrictions

### What You DON'T Need to Understand:

- ❌ How Flask routing works internally
- ❌ How SimpleDB (database) operations work
- ❌ How S3 file storage works
- ❌ How participant status tracking works

**These are all handled by the framework!**

### What You DO Need to Know:

- ✅ That `get_data()` in `expt_config.py` is called by the framework
- ✅ That your data is passed to `exp.html` template as JSON
- ✅ That results are automatically saved when experiment completes

**Bottom Line:** Think of Flask and the framework as a **black box** - you put stimuli data in (`get_data()`), and it handles everything else (participant management, data saving, etc.).

---

## Question 3: What Does "Experiment-Specific Logic" (`expt_config.py`) Entail?

**Answer: `expt_config.py` handles ALL the experimental design logic - stimuli preparation, condition assignment, randomization, trial structure - but NOT the actual display/response collection (that's in JavaScript).**

### What Goes in `expt_config.py`:

#### 1. **Stimulus Preparation** ✅
- Loading stimulus files (images, word lists, audio files, etc.)
- Reading stimulus databases
- Organizing stimuli into lists/arrays

**Example:**
```python
def get_data(opts):
    # Load word list from file
    word_list = fetch_word_list()
    
    # Load images
    images = load_images_from_folder('stimuli/')
    
    return {
        'word_list': word_list,
        'images': images
    }
```

#### 2. **Condition Design** ✅
- Assigning participants to conditions
- Creating condition-specific stimulus sets
- Setting up between-subjects or within-subjects designs

**Example:**
```python
def get_data(opts):
    # Get condition from URL parameter
    condition = opts.get('condition', '1')
    
    if condition == '1':
        stimuli = load_condition1_stimuli()
    elif condition == '2':
        stimuli = load_condition2_stimuli()
    
    return {'stimuli': stimuli, 'condition': condition}
```

#### 3. **Trial Structure/Order** ✅
- Creating trial lists
- Determining trial order
- Setting up practice vs. main trials
- Creating block structures

**Example:**
```python
def get_data(opts):
    # Create practice trials
    practice_trials = create_practice_trials(n=5)
    
    # Create main experiment trials
    main_trials = create_main_trials(n=100)
    
    # Combine in order
    all_trials = practice_trials + main_trials
    
    return {'trials': all_trials}
```

#### 4. **Randomization** ✅
- Shuffling trial order
- Randomizing stimulus assignment
- Creating counterbalanced designs
- Randomizing condition assignment

**Example:**
```python
def get_data(opts):
    import random
    
    # Shuffle trial order
    trial_order = list(range(100))
    random.shuffle(trial_order)
    
    # Randomly assign condition
    condition = random.choice(['A', 'B', 'C'])
    
    return {
        'trial_order': trial_order,
        'condition': condition
    }
```

#### 5. **Stimulus Properties** ✅
- Stimulus characteristics (size, color, position parameters)
- Stimulus metadata (difficulty, category, etc.)
- Stimulus relationships (pairs, groups, etc.)

**Example:**
```python
def get_data(opts):
    stimuli = []
    for i in range(50):
        stimuli.append({
            'image': f'stim_{i}.png',
            'size': random.choice(['small', 'large']),
            'position': random.choice(['left', 'right']),
            'category': assign_category(i),
            'difficulty': calculate_difficulty(i)
        })
    
    return {'stimuli': stimuli}
```

#### 6. **Experimental Parameters** ✅
- Number of trials per condition
- Timing parameters (if needed for stimulus selection)
- Response options (if they vary by condition)

**Example:**
```python
# Global variables in expt_config.py
n_practice_trials = 5
n_main_trials = 100
stimulus_duration = 500  # ms

def get_data(opts):
    return {
        'n_practice': n_practice_trials,
        'n_main': n_main_trials,
        'duration': stimulus_duration
    }
```

### What Does NOT Go in `expt_config.py`:

#### ❌ **Actual Stimulus Display** (Goes in JavaScript)
- How stimuli are shown on screen
- Visual presentation details
- Screen layout

#### ❌ **Response Collection** (Goes in JavaScript)
- How responses are collected
- Response interface (buttons, keyboard, mouse)
- Response validation

#### ❌ **Timing Control** (Goes in JavaScript)
- How long stimuli are displayed
- Response windows
- Inter-trial intervals

#### ❌ **Trial Execution Logic** (Goes in JavaScript)
- The actual trial-by-trial flow
- What happens when participant responds
- Feedback display

**These go in `templates/exp.html` (JavaScript/jsPsych code)!**

---

## Clear Separation: Python vs. JavaScript

### Python (`expt_config.py`) - **PREPARATION PHASE**
**Think: "What stimuli and conditions do I need?"**

- ✅ Load stimuli files
- ✅ Create trial lists
- ✅ Assign conditions
- ✅ Randomize order
- ✅ Prepare data structure

**Output:** A dictionary/JSON object with all the prepared data

### JavaScript (`templates/exp.html`) - **EXECUTION PHASE**
**Think: "How do I show stimuli and collect responses?"**

- ✅ Display stimuli on screen
- ✅ Collect responses
- ✅ Control timing
- ✅ Execute trial-by-trial flow
- ✅ Record data

**Input:** The data dictionary from Python
**Output:** Trial-by-trial data (responses, RTs, etc.)

---

## Example: Complete Flow

### Step 1: Python Prepares Data (`expt_config.py`)
```python
def get_data(opts):
    # Load images
    images = ['img1.png', 'img2.png', 'img3.png']
    
    # Randomize order
    import random
    random.shuffle(images)
    
    # Assign condition
    condition = opts.get('condition', '1')
    
    # Create trial list with properties
    trials = []
    for i, img in enumerate(images):
        trials.append({
            'image': img,
            'trial_number': i + 1,
            'condition': condition,
            'correct_response': 'f' if i % 2 == 0 else 'j'
        })
    
    return {'trials': trials}
```

### Step 2: Flask Passes Data to Template (`experiment.py`)
```python
data = get_data(request.args)  # Calls your function
return render_template('exp.html', data=json.dumps(data))
```

### Step 3: JavaScript Uses Data (`templates/exp.html`)
```javascript
// Get data from Python
var expt_data = {{data|safe}};  // {'trials': [...]}

// Build jsPsych timeline
var timeline = [];
for (var i = 0; i < expt_data.trials.length; i++) {
    var trial = {
        type: jsPsychImageKeyboardResponse,
        stimulus: expt_data.trials[i].image,  // Use Python-prepared data
        choices: ['f', 'j'],
        trial_duration: 2000,
        data: {
            trial_number: expt_data.trials[i].trial_number,
            condition: expt_data.trials[i].condition,
            correct_response: expt_data.trials[i].correct_response
        }
    };
    timeline.push(trial);
}

// Run experiment
jsPsych.run(timeline);
```

---

## Summary Table

| Component | File | What It Does | Do You Modify? |
|-----------|------|--------------|----------------|
| **Web Server** | `experiment.py` | Handles HTTP requests, routes, participant management | ❌ NO - Generic |
| **Framework Library** | `MallExperiment.py` | Database operations, S3 storage, participant tracking | ❌ NO - Generic |
| **Utilities** | `user_utils.py` | Caching, restrictions | ❌ NO - Generic |
| **Configuration** | `config.py` | Experiment ID, debug mode, paths | ✅ YES - Set your IDs |
| **Experiment Logic** | `expt_config.py` | Stimuli preparation, conditions, randomization | ✅ YES - Your experiment design |
| **Experiment Display** | `templates/exp.html` | Trial execution, stimulus display, response collection | ✅ YES - Your experiment implementation |

---

## Key Takeaway

**The framework (`experiment.py`, `MallExperiment.py`) is like a restaurant:**
- The **restaurant** (framework) handles:
  - Taking orders (routes)
  - Managing customers (participants)
  - Storing records (database)
  - Processing payments (saving data)

- **You** (experiment designer) provide:
  - The **menu** (`expt_config.py` - what stimuli/conditions)
  - The **presentation** (`exp.html` - how to show it)

The restaurant doesn't care what's on the menu - it just serves whatever you provide!

---

## What You Actually Modify for a New Experiment:

1. **`config.py`**: 
   - Change `EXPT_UID` to unique ID
   - Set `DEBUG = True` for development
   - Set `RESULTS_DIR` for where to save results

2. **`expt_config.py`**:
   - Write `get_data(opts)` function
   - Load your stimuli
   - Create your trial structure
   - Implement your randomization
   - Return data dictionary

3. **`templates/exp.html`**:
   - Build jsPsych timeline
   - Use data from `expt_config.py`
   - Implement trial display
   - Collect responses

4. **`static_*/` folder**:
   - Add your stimulus images/files
   - Add custom JavaScript plugins (if needed)
   - Add custom CSS (if needed)

**Everything else stays the same!**

