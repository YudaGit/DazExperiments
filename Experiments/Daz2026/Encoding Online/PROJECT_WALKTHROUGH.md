# Online Experiment Project Walkthrough

## Overview

This is a Flask-based web application for running online psychology experiments using jsPsych (JavaScript library for running behavioral experiments in a browser). The project implements a visual working memory (VWM) continuous recall study where participants view color patches and recall them using a color wheel.

---

## Project Architecture

### High-Level Flow

```
Participant visits URL → Flask routes → Python prepares data → HTML/JS renders experiment → jsPsych runs trials → Data sent back to Flask → Saved to S3
```

---

## Backend Structure (Python/Flask)

### 1. **`experiment.py`** - Main Flask Application
This is the entry point and orchestrates the entire experiment server.

**Key Components:**
- **Flask App Setup**: Creates the Flask application with static file serving
- **Routes**: Multiple entry points for different participant types:
  - `/unique-expt` - Creates a new unique participant
  - `/expt` - Starts experiment for existing participant (by uid)
  - `/mturk-expt` - For Amazon Mechanical Turk workers
  - `/prolific` - For Prolific participants
  - `/rep-expt` - For REP (Research Experience Program) participants
  - `/record-task` - Receives and saves experiment data (POST endpoint)

**Key Functions:**
```python
@app.route('/unique-expt', methods=['GET'])
def unique_start_exp():
    # Creates a new participant record
    (uid, error) = me_expt.create_unique_participant(...)
    # Gets experiment data from expt_config.py
    data = get_data(request.args)
    # Renders the HTML template with data
    return render_template('exp.html', uid=uid, data=json.dumps(data))
```

**Data Flow:**
1. Participant visits URL
2. Flask creates/retrieves participant record in SimpleDB
3. Calls `get_data()` from `expt_config.py` to prepare stimuli
4. Passes data as JSON to HTML template
5. HTML template renders and JavaScript executes

### 2. **`config.py`** - Configuration File
Contains experiment-specific settings:
- `EXPT_UID`: Unique identifier for this experiment
- `DEBUG`: Development vs production mode
- `RESULTS_DIR`: Where to save results in S3
- `RESTRICTIONS`: Browser/device restrictions (mobile, tablet, etc.)
- AWS and database settings

### 3. **`expt_config.py`** - Experiment-Specific Logic
**This is where you'll write most of your experiment logic!**

**Required Variables:**
- `expt_uid`: Experiment unique ID
- `s3_results_key`: Format string for where to save results
- `DEBUG`: Debug mode flag

**Required Function:**
```python
def get_data(opts):
    """
    opts: Dictionary of URL parameters (e.g., ?condition=1&debug=0)
    Returns: Dictionary of data to pass to JavaScript
    """
    # Your code here to prepare stimuli, conditions, etc.
    return {
        'study_list': study_list,
        'test_list': test_list,
        # ... any other data your experiment needs
    }
```

**Optional:**
- `custom_code`: Flask Blueprint for custom routes (e.g., debrief pages)

**In this example:**
- Fetches word list from file
- Creates study and test lists
- Shuffles document order
- Returns data structure for JavaScript

### 4. **`MallExperiment.py`** - Experiment Framework Library
Provides reusable functions for managing experiments:

**Key Classes:**
- `Expt`: Main class for experiment management

**Key Methods:**
- `create_unique_participant()`: Creates new participant record
- `start_expt()`: Marks participant as started
- `complete_expt()`: Saves results to S3 and marks as completed
- `get_participant()`: Retrieves participant data
- `set_participant_attrs()`: Updates participant attributes
- `get_S3()` / `save_S3()`: S3 file operations

**Participant Status Codes:**
- `NOT_ACCEPTED = 0`
- `ALLOCATED = 1`
- `STARTED = 2`
- `COMPLETED = 3`
- `SUBMITTED = 4`
- `CREDITED = 5`

### 5. **`user_utils.py`** - Utility Functions
- `@nocache`: Decorator to prevent browser caching
- `@restrictions`: Decorator to check device/browser restrictions

---

## Frontend Structure (JavaScript/jsPsych)

### 1. **`templates/experiment_wrapper.html`** - Base Template
Provides common functionality:
- jQuery and utility scripts
- Data submission function (`_send_task_data()`)
- Loading indicators
- REP/MTurk/Prolific integration
- Global variables: `_uid`, `_mturk`, `_prolific`, etc.

**Key Function:**
```javascript
async function _send_task_data(expt_data, compressed=false) {
    // Collects timing data
    // Sends POST request to /record-task
    // Handles success/error
}
```

### 2. **`templates/exp.html`** - Experiment Template
**This is where you build your experiment timeline!**

**Structure:**
```html
{% extends "experiment_wrapper.html" %}
{% block extra_head %}
    <!-- Load jsPsych and plugins -->
    <!-- Load custom JavaScript files -->
{% endblock %}

{% block after_body %}
    <script>
        // 1. Get data from Python
        var expt_data = {{data|safe}};
        
        // 2. Initialize jsPsych timeline
        var experiment_timeline = [];
        
        // 3. Create trial objects
        var trial1 = {
            type: jsPsychPluginName,
            // ... parameters
        };
        
        // 4. Add trials to timeline
        experiment_timeline.push(trial1);
        
        // 5. Initialize and run jsPsych
        const jsPsych = initJsPsych({
            on_finish: function() {
                // Save data and redirect
                _send_task_data(jsPsych.data.get().json());
            }
        });
        jsPsych.run(experiment_timeline);
    </script>
{% endblock %}
```

**jsPsych Timeline:**
- **Timeline**: Array of trial objects executed sequentially
- **Trial Object**: Defines what happens in one step (stimulus, response, timing, etc.)
- **Plugins**: jsPsych provides many plugins (html-keyboard-response, image-button-response, etc.)

**In this example experiment:**
1. Preload images
2. Fullscreen mode
3. Instructions with comprehension checks
4. Consent form
5. Demographics
6. Practice trials (loop)
7. Main experiment trials (loop)
8. Debrief

### 3. **Custom JavaScript Files** (in `static_*/` directory)

**`confidencewheel.js`**: Custom jsPsych plugin
- Displays color patches
- Shows color wheel for response
- Records mouse movements and responses
- Calculates accuracy

**`adv_plot.js`**: Custom plugin for displaying performance feedback

**`patchselector.js`**: Functions for selecting color patches

**`saturationtask.js`**: Additional task logic

---

## Data Flow: Complete Example

### 1. Participant Arrives
```
URL: http://localhost:5000/unique-expt
```

### 2. Flask Processing (`experiment.py`)
```python
@app.route('/unique-expt')
def unique_start_exp():
    # Create participant record in SimpleDB
    (uid, error) = me_expt.create_unique_participant(request, ...)
    
    # Call your experiment config function
    data = get_data(request.args)  # From expt_config.py
    
    # Render HTML template with data
    return render_template('exp.html', uid=uid, data=json.dumps(data))
```

### 3. HTML Template Renders (`exp.html`)
```javascript
// Data from Python is injected as JSON
var expt_data = {
    "study_list": [...],
    "test_list": [...],
    "study_document_order": [0, 2, 1]
};

// JavaScript uses this data to build trials
for (var i = 0; i < expt_data.study_list.length; i++) {
    var trial = {
        type: jsPsychHtmlKeyboardResponse,
        stimulus: expt_data.study_list[i].word,
        // ...
    };
    experiment_timeline.push(trial);
}
```

### 4. jsPsych Runs Experiment
- Executes trials in timeline order
- Collects responses and timing data
- Stores data in `jsPsych.data`

### 5. Experiment Completes
```javascript
on_finish: function() {
    // Get all collected data
    var all_data = jsPsych.data.get().json();
    
    // Send to server
    _send_task_data(all_data);
}
```

### 6. Data Saved (`experiment.py`)
```python
@app.route('/record-task', methods=['POST'])
def record_task():
    # Receives data from JavaScript
    results = request.form['results']
    uid = request.form['uid']
    
    # Saves to S3
    me_expt.complete_expt(request, uid=uid, ...)
    
    # Updates participant status to COMPLETED
```

---

## Key Concepts for Converting Matlab Experiments

### 1. **Stimulus Preparation** (Python)
**Matlab:** You might have arrays/matrices of stimuli
**Python:** Prepare stimuli in `expt_config.py` → `get_data()`
```python
def get_data(opts):
    # Load stimuli
    stimuli = load_stimuli()
    
    # Randomize
    random.shuffle(stimuli)
    
    # Create conditions
    conditions = create_conditions()
    
    return {
        'stimuli': stimuli,
        'conditions': conditions,
        'trial_order': trial_order
    }
```

### 2. **Trial Structure** (JavaScript)
**Matlab:** You might use `for` loops with `Screen('Flip')` and `KbWait`
**JavaScript:** Create trial objects and add to timeline
```javascript
// Instead of Matlab's:
// for trial = 1:nTrials
//     Screen('Flip', window);
//     [key, time] = KbWait();
// end

// Use jsPsych:
var timeline = [];
for (var i = 0; i < nTrials; i++) {
    var trial = {
        type: jsPsychHtmlKeyboardResponse,
        stimulus: stimuli[i],
        choices: ['f', 'j'],
        trial_duration: 2000
    };
    timeline.push(trial);
}
jsPsych.run(timeline);
```

### 3. **Response Collection**
**Matlab:** `KbWait()`, `GetMouse()`, `GetClicks()`
**JavaScript:** jsPsych plugins handle responses:
- `jsPsychHtmlKeyboardResponse` - keyboard
- `jsPsychHtmlButtonResponse` - buttons
- `jsPsychHtmlSliderResponse` - sliders
- Custom plugins (like `confidencewheel.js`) - custom responses

### 4. **Timing**
**Matlab:** `WaitSecs()`, `GetSecs()`
**JavaScript:** 
- `trial_duration`: Fixed duration
- `response_ends_trial`: Wait for response
- `on_finish`: Callback with timing data

### 5. **Data Storage**
**Matlab:** Save to `.mat` or `.csv` files
**JavaScript:** jsPsych automatically records:
- Response
- RT (reaction time)
- Trial type
- Custom data fields
- All stored in `jsPsych.data`

### 6. **Randomization**
**Matlab:** `randperm()`, `Shuffle()`
**JavaScript:** 
```javascript
// Shuffle array
function shuffle(array) {
    return array.sort(() => Math.random() - 0.5);
}

// Random selection
var randomItem = array[Math.floor(Math.random() * array.length)];
```

---

## File Organization

```
project/
├── experiment.py          # Main Flask app (routes, server logic)
├── config.py              # Configuration (experiment ID, debug mode)
├── expt_config.py         # YOUR EXPERIMENT LOGIC (stimuli, conditions)
├── MallExperiment.py      # Framework library (don't modify)
├── user_utils.py          # Utilities (don't modify)
│
├── templates/
│   ├── experiment_wrapper.html  # Base template (common functions)
│   ├── exp.html                 # YOUR EXPERIMENT TEMPLATE
│   └── debrief.html             # Debrief pages
│
├── static_<expt_uid>/     # Static files (images, JS, CSS)
│   ├── jspsych7/          # jsPsych library
│   ├── images/            # Stimulus images
│   ├── js/                # Custom JavaScript
│   └── html/              # Instruction/consent HTML
│
└── results/               # Local results (if debugging)
```

---

## Steps to Convert Your Matlab Experiment

### Step 1: Understand Your Matlab Experiment
- What stimuli do you present?
- What responses do you collect?
- What's the trial structure?
- What's randomized?
- What data do you record?

### Step 2: Prepare Stimuli (Python)
In `expt_config.py`:
```python
def get_data(opts):
    # Load your stimuli (images, words, etc.)
    # Create trial lists
    # Randomize conditions
    # Return as dictionary
    return {
        'stimuli': your_stimuli,
        'conditions': your_conditions,
        # ... other data
    }
```

### Step 3: Build Trial Timeline (JavaScript)
In `templates/exp.html`:
```javascript
// Get data from Python
var expt_data = {{data|safe}};

// Build timeline
var timeline = [];

// Instructions
timeline.push({
    type: jsPsychHtmlKeyboardResponse,
    stimulus: 'Instructions here...'
});

// Trials
for (var i = 0; i < expt_data.stimuli.length; i++) {
    timeline.push({
        type: jsPsychImageKeyboardResponse,
        stimulus: expt_data.stimuli[i].image,
        choices: ['f', 'j'],
        // ... other parameters
    });
}

// Run experiment
jsPsych.run(timeline);
```

### Step 4: Test Locally
```bash
# Activate virtual environment
source venv/bin/activate  # or venv\Scripts\activate on Windows

# Run Flask server
FLASK_APP=experiment.py flask run
# or
python experiment.py

# Visit: http://localhost:5000/unique-expt
```

### Step 5: Customize as Needed
- Create custom jsPsych plugins if needed (like `confidencewheel.js`)
- Add custom routes in `expt_config.py` if needed
- Modify templates for your UI needs

---

## Common jsPsych Plugins You'll Use

1. **`jsPsychHtmlKeyboardResponse`**: Text stimulus + keyboard response
2. **`jsPsychImageKeyboardResponse`**: Image stimulus + keyboard response
3. **`jsPsychHtmlButtonResponse`**: Text/image + button clicks
4. **`jsPsychHtmlSliderResponse`**: Slider responses
5. **`jsPsychExternalHtml`**: Load HTML from file (instructions, consent)
6. **`jsPsychPreload`**: Preload images/audio
7. **`jsPsychFullscreen`**: Enter fullscreen mode
8. **`jsPsychCallFunction`**: Run custom JavaScript functions
9. **`jsPsychSurveyText`**: Text input
10. **`jsPsychSurveyMultiChoice`**: Multiple choice questions

---

## Debugging Tips

1. **Check Browser Console**: F12 → Console tab
2. **Check Flask Logs**: Terminal where Flask is running
3. **Use `DEBUG = True`**: In `config.py` for development
4. **Inspect jsPsych Data**: 
   ```javascript
   console.log(jsPsych.data.get());
   ```
5. **Test Individual Trials**: Comment out parts of timeline
6. **Check Network Tab**: See if data is being sent correctly

---

## Next Steps

1. Review your Matlab experiment code
2. Identify stimuli, responses, and trial structure
3. Map Matlab functions to jsPsych plugins
4. Start with a simple version, then add complexity
5. Test thoroughly before deploying

---

## Resources

- **jsPsych Documentation**: https://www.jspsych.org/
- **Flask Documentation**: https://flask.palletsprojects.com/
- **This Project's README**: See `README` file

---

## Questions to Consider for Your Conversion

1. What type of stimuli? (images, text, audio, video)
2. What type of responses? (keyboard, mouse, slider, custom)
3. What timing constraints? (fixed duration, response-terminated, etc.)
4. What randomization? (trial order, condition assignment, etc.)
5. What data to record? (responses, RTs, accuracy, custom measures)
6. What instructions/consent needed?
7. What practice trials needed?
8. What feedback to show?

Answering these will help you map your Matlab experiment to this framework!

---

## Implementation Details (Merged)

### Step 1: Trial Generation (Python)
- Implemented in `expt_config.py` to mirror Matlab `TrialMatrix.m`.
- Subexp1 design: set size 6, redundant 3, durations 50–350ms, cue types R/NR.
- Trials generated by `generate_trials_subexp1()` and `generate_single_trial_subexp1()`.
- Color constraints: minimum 30° circular distance for all colors.
- Positions: evenly spaced around ring, then shuffled.

### Step 2: JavaScript Integration (jsPsych)
- `confidencewheel.js` accepts a direct `target_index` from Python.
- `exp.html` converts color angles to RGB via `convertColorAnglesToRGB()` and normalizes positions via `convertPositions()`.
- Subexp1 timeline built from `expt_data.trials` and `expt_data.practice_trials`.
- Trial sequence: fixation (1000ms) → stimulus (50–350ms) → retention (750ms) → response.

### Data Flow Summary
1. Python prepares trial dictionaries (colors, positions, target, duration).
2. HTML template injects `expt_data` and builds the jsPsych timeline.
3. Custom plugins draw stimuli and collect responses.
4. Data saved via `_send_task_data()` to `/record-task`.

