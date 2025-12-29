# Step-by-Step Conversion Checklist

Use this checklist when converting your Matlab experiment to this online framework.

## Phase 1: Preparation

### 1.1 Understand Your Matlab Experiment
- [ ] List all stimuli types (images, text, audio, etc.)
- [ ] Identify all response types (keyboard, mouse, custom)
- [ ] Document trial structure (fixation → stimulus → response → feedback)
- [ ] List all conditions/experimental manipulations
- [ ] Document randomization requirements
- [ ] List all timing requirements (durations, delays)
- [ ] Identify what data needs to be recorded

### 1.2 Set Up Development Environment
- [ ] Ensure Python 3.x is installed
- [ ] Create/activate virtual environment: `python -m venv venv`
- [ ] Install dependencies: `pip install -r requirements.txt`
- [ ] Test Flask server runs: `python experiment.py`
- [ ] Verify you can access: `http://localhost:5000/unique-expt`

## Phase 2: Backend Setup (Python)

### 2.1 Configure Experiment
- [ ] Update `config.py`:
  - [ ] Set `EXPT_UID` to a unique identifier
  - [ ] Set `DEBUG = True` for development
  - [ ] Set `RESULTS_DIR` for where results will be saved
  - [ ] Configure any restrictions (browser, device)

### 2.2 Prepare Stimuli in `expt_config.py`
- [ ] Create `get_data(opts)` function
- [ ] Load stimuli files (images, word lists, etc.)
- [ ] Implement randomization logic
- [ ] Create condition assignments
- [ ] Structure data as dictionary to return
- [ ] Test that `get_data()` returns expected structure

**Example Structure:**
```python
def get_data(opts):
    # Load stimuli
    stimuli = load_stimuli()
    
    # Randomize
    random.shuffle(stimuli)
    
    # Create conditions
    conditions = assign_conditions(stimuli)
    
    return {
        'stimuli': stimuli,
        'conditions': conditions,
        'trial_order': list(range(len(stimuli)))
    }
```

### 2.3 Test Backend
- [ ] Add print statements in `get_data()` to verify it runs
- [ ] Check Flask logs when accessing experiment URL
- [ ] Verify data structure is correct (use `json.dumps()` to inspect)

## Phase 3: Frontend Setup (JavaScript/jsPsych)

### 3.1 Set Up Basic Template
- [ ] Copy `templates/exp.html` structure
- [ ] Load required jsPsych plugins in `{% block extra_head %}`
- [ ] Set up basic timeline structure in `{% block after_body %}`

### 3.2 Convert Trial Structure

#### 3.2.1 Instructions
- [ ] Create instruction screens
- [ ] Add comprehension checks if needed
- [ ] Test instruction flow

#### 3.2.2 Practice Trials
- [ ] Identify practice trial structure
- [ ] Convert to jsPsych trial objects
- [ ] Create practice timeline loop
- [ ] Test practice trials work correctly

#### 3.2.3 Main Experiment Trials
- [ ] Convert main trial structure
- [ ] Map Matlab functions to jsPsych plugins:
  - [ ] `Screen('DrawText')` → `jsPsychHtmlKeyboardResponse`
  - [ ] `Screen('DrawTexture')` → `jsPsychImageKeyboardResponse`
  - [ ] `KbWait()` → `choices` parameter
  - [ ] `WaitSecs()` → `trial_duration`
- [ ] Create main timeline loop
- [ ] Test main trials work correctly

### 3.3 Handle Responses
- [ ] Map response collection:
  - [ ] Keyboard → `jsPsychHtmlKeyboardResponse`
  - [ ] Mouse clicks → `jsPsychHtmlButtonResponse`
  - [ ] Sliders → `jsPsychHtmlSliderResponse`
  - [ ] Custom → Create custom plugin
- [ ] Verify responses are recorded correctly
- [ ] Check response data structure

### 3.4 Implement Timing
- [ ] Convert timing requirements:
  - [ ] Fixation duration
  - [ ] Stimulus presentation time
  - [ ] Response window
  - [ ] Inter-trial interval
- [ ] Test timing is accurate
- [ ] Remember: jsPsych uses milliseconds, not seconds!

### 3.5 Add Feedback (if needed)
- [ ] Create feedback screens
- [ ] Calculate accuracy/performance
- [ ] Display feedback appropriately
- [ ] Test feedback displays correctly

## Phase 4: Custom Components

### 4.1 Custom Plugins (if needed)
- [ ] Identify if you need custom response method
- [ ] Study example: `confidencewheel.js`
- [ ] Create custom plugin following jsPsych plugin structure
- [ ] Test custom plugin works
- [ ] Integrate into timeline

### 4.2 Custom Functions
- [ ] Identify helper functions needed
- [ ] Convert Matlab functions to JavaScript
- [ ] Test functions work correctly
- [ ] Add to appropriate JavaScript files

## Phase 5: Data Collection

### 5.1 Verify Data Recording
- [ ] Check that all responses are recorded
- [ ] Verify reaction times are captured
- [ ] Ensure custom data fields are included
- [ ] Test data structure matches expectations

### 5.2 Data Submission
- [ ] Verify `_send_task_data()` is called on completion
- [ ] Check data is sent to `/record-task` endpoint
- [ ] Verify data is saved to S3 (or local in debug mode)
- [ ] Test error handling if submission fails

## Phase 6: Testing

### 6.1 Functionality Testing
- [ ] Test complete experiment flow
- [ ] Verify all trials execute correctly
- [ ] Check randomization works
- [ ] Verify responses are collected
- [ ] Test timing is accurate
- [ ] Check data is saved correctly

### 6.2 Edge Cases
- [ ] Test with different screen sizes
- [ ] Test in different browsers
- [ ] Test with slow/fast responses
- [ ] Test error scenarios (network issues, etc.)
- [ ] Test participant re-entry (if applicable)

### 6.3 Data Validation
- [ ] Download and inspect saved data
- [ ] Verify data structure matches Matlab output
- [ ] Check all variables are present
- [ ] Validate data ranges make sense
- [ ] Compare with Matlab results (if possible)

## Phase 7: Polish

### 7.1 User Experience
- [ ] Add loading indicators
- [ ] Improve error messages
- [ ] Add progress indicators
- [ ] Ensure instructions are clear
- [ ] Test on different devices (if needed)

### 7.2 Code Quality
- [ ] Remove debug print statements
- [ ] Add comments to complex code
- [ ] Organize code logically
- [ ] Remove unused code
- [ ] Optimize performance if needed

### 7.3 Documentation
- [ ] Document experiment parameters
- [ ] Document custom functions
- [ ] Update README if needed
- [ ] Document any special setup requirements

## Phase 8: Deployment Preparation

### 8.1 Configuration
- [ ] Set `DEBUG = False` in `config.py`
- [ ] Verify AWS credentials are configured
- [ ] Test S3 bucket access
- [ ] Verify SimpleDB access

### 8.2 Final Testing
- [ ] Run complete experiment in production mode
- [ ] Verify data saves correctly
- [ ] Test participant creation
- [ ] Check researcher page access
- [ ] Test all routes work

### 8.3 Pilot Testing
- [ ] Run pilot with 1-2 participants
- [ ] Verify data collection works
- [ ] Check for any bugs
- [ ] Get feedback on user experience
- [ ] Make necessary adjustments

## Quick Reference: Common Conversions

### Stimulus Presentation
```javascript
// Text
{type: jsPsychHtmlKeyboardResponse, stimulus: 'Text here'}

// Image
{type: jsPsychImageKeyboardResponse, stimulus: 'image.png'}

// Fixation
{type: jsPsychHtmlKeyboardResponse, stimulus: '<div>+</div>', trial_duration: 500}
```

### Response Collection
```javascript
// Keyboard
{choices: ['f', 'j']}

// Buttons
{type: jsPsychHtmlButtonResponse, choices: ['Yes', 'No']}

// Slider
{type: jsPsychHtmlSliderResponse, min: 0, max: 100}
```

### Timing
```javascript
// Fixed duration (milliseconds)
{trial_duration: 2000}

// Wait for response
{response_ends_trial: true}

// No response allowed
{choices: 'NO_KEYS'}
```

### Loops
```javascript
var timeline = [];
for (var i = 0; i < nTrials; i++) {
    timeline.push({
        type: jsPsychHtmlKeyboardResponse,
        stimulus: stimuli[i]
    });
}
```

### Randomization
```javascript
function shuffle(array) {
    return array.sort(() => Math.random() - 0.5);
}
var shuffled = shuffle(original);
```

## Troubleshooting Checklist

If something doesn't work:

- [ ] Check browser console (F12) for JavaScript errors
- [ ] Check Flask server logs for Python errors
- [ ] Verify data structure matches between Python and JavaScript
- [ ] Check timing units (seconds vs milliseconds)
- [ ] Verify all images/files are loaded/preloaded
- [ ] Check that jsPsych plugins are loaded correctly
- [ ] Verify data is being sent correctly (Network tab in browser)
- [ ] Test individual components in isolation

## Getting Help

- Review `PROJECT_WALKTHROUGH.md` for architecture details
- Review `MATLAB_TO_JSPYCH_MAPPING.md` for function mappings
- Check jsPsych documentation: https://www.jspsych.org/
- Check Flask documentation: https://flask.palletsprojects.com/
- Test with simple examples first before full conversion

## Notes Section

Use this space to track issues, solutions, and reminders:

```
Issue: 
Solution: 

Issue: 
Solution: 

Reminder: 
```

