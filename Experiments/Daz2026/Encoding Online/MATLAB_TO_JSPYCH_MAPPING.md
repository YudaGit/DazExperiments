# Matlab to jsPsych Conversion Quick Reference

This guide maps common Matlab Psychtoolbox functions to their jsPsych equivalents.

## Display Functions

### Screen Operations

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| `Screen('OpenWindow', ...)` | `initJsPsych()` | Initialize experiment |
| `Screen('Flip', window)` | Trial execution | Happens automatically |
| `Screen('Close', window)` | `jsPsych.endExperiment()` | End experiment |
| `Screen('DrawText', ...)` | `jsPsychHtmlKeyboardResponse` | Text stimulus |
| `Screen('DrawTexture', ...)` | `jsPsychImageKeyboardResponse` | Image stimulus |
| `Screen('FillRect', ...)` | Custom CSS/Canvas | Use HTML/CSS or Canvas |

### Stimulus Presentation

| Matlab | jsPsych | Example |
|--------|---------|---------|
| `DrawFormattedText()` | `stimulus: 'text'` | Text with formatting |
| `Screen('MakeTexture', ...)` | Preload images | Use `jsPsychPreload` |
| `Screen('DrawLine', ...)` | Canvas API | Custom drawing |

## Response Collection

### Keyboard

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| `KbWait()` | `type: jsPsychHtmlKeyboardResponse` | Wait for keypress |
| `KbCheck()` | `choices: ['f', 'j']` | Specify allowed keys |
| `KbName()` | `response` in data | Key name automatically recorded |
| `GetSecs()` | `rt` in data | Reaction time automatically recorded |

**Example:**
```javascript
// Matlab:
[secs, keyCode] = KbWait();
keyName = KbName(keyCode);

// jsPsych:
var trial = {
    type: jsPsychHtmlKeyboardResponse,
    stimulus: 'Press F or J',
    choices: ['f', 'j'],
    on_finish: function(data) {
        console.log(data.response);  // 'f' or 'j'
        console.log(data.rt);        // reaction time in ms
    }
};
```

### Mouse

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| `GetMouse()` | `jsPsychHtmlButtonResponse` | Button clicks |
| `SetMouse()` | Not needed | Browser handles |
| `GetClicks()` | `response` in data | Click coordinates recorded |

**Example:**
```javascript
// Matlab:
[x, y, buttons] = GetMouse();

// jsPsych:
var trial = {
    type: jsPsychHtmlButtonResponse,
    stimulus: 'Click a button',
    choices: ['Button 1', 'Button 2'],
    on_finish: function(data) {
        console.log(data.response);  // button index
        console.log(data.rt);        // reaction time
    }
};
```

### Custom Responses (e.g., Color Wheel)

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| Custom drawing + `GetMouse()` | Custom plugin | Create plugin like `confidencewheel.js` |

## Timing

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| `WaitSecs(duration)` | `trial_duration: duration` | Fixed duration |
| `GetSecs()` | `data.rt` or `Date.now()` | Timing data |
| `Screen('WaitBlanking', ...)` | Automatic | Browser handles refresh |

**Example:**
```javascript
// Matlab:
WaitSecs(1.5);  // Wait 1.5 seconds

// jsPsych:
var trial = {
    type: jsPsychHtmlKeyboardResponse,
    stimulus: 'Fixation',
    choices: 'NO_KEYS',
    trial_duration: 1500  // milliseconds
};
```

## Trial Structure

### Loops

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| `for trial = 1:nTrials` | `for (var i = 0; i < nTrials; i++)` | Loop syntax |
| `end` | `timeline.push(trial)` | Add to timeline |

**Example:**
```javascript
// Matlab:
for trial = 1:nTrials
    Screen('DrawText', window, stimuli{trial}, ...);
    Screen('Flip', window);
    [~, keyCode] = KbWait();
end

// jsPsych:
var timeline = [];
for (var i = 0; i < nTrials; i++) {
    var trial = {
        type: jsPsychHtmlKeyboardResponse,
        stimulus: stimuli[i],
        choices: ['f', 'j']
    };
    timeline.push(trial);
}
jsPsych.run(timeline);
```

### Conditional Trials

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| `if condition == 1` | `conditional_function` | Conditional timeline |
| `elseif` | Nested conditionals | Same logic |

**Example:**
```javascript
// Matlab:
if condition == 1
    % Show stimulus A
else
    % Show stimulus B
end

// jsPsych:
var conditional_trial = {
    timeline: [trialA, trialB],
    conditional_function: function() {
        return condition === 1;  // Show trialA if true
    }
};
```

## Randomization

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| `randperm(n)` | `shuffle(array)` | Random permutation |
| `randi(n)` | `Math.floor(Math.random() * n)` | Random integer |
| `rand()` | `Math.random()` | Random 0-1 |
| `Shuffle()` | `array.sort(() => Math.random() - 0.5)` | Shuffle array |

**Example:**
```javascript
// Matlab:
trialOrder = randperm(nTrials);
stimuli = Shuffle(stimuli);

// jsPsych:
function shuffle(array) {
    return array.sort(() => Math.random() - 0.5);
}
var trialOrder = shuffle([...Array(nTrials).keys()]);
var shuffledStimuli = shuffle(stimuli);
```

## Data Collection

| Matlab | jsPsych | Notes |
|--------|---------|-------|
| `results = []` | `jsPsych.data` | Automatic data collection |
| `results(trial, :) = [response, rt]` | Automatic | All trials recorded |
| `save('results.mat', 'results')` | `_send_task_data()` | Send to server |

**Example:**
```javascript
// Matlab:
results = [];
for trial = 1:nTrials
    [response, rt] = collect_response();
    results(trial, :) = [response, rt];
end
save('results.mat', 'results');

// jsPsych:
// Data automatically collected in jsPsych.data
// Access with:
var allData = jsPsych.data.get().json();
// Send to server:
_send_task_data(allData);
```

## Common Patterns

### Fixation Cross

**Matlab:**
```matlab
Screen('DrawText', window, '+', centerX, centerY, white);
Screen('Flip', window);
WaitSecs(0.5);
```

**jsPsych:**
```javascript
var fixation = {
    type: jsPsychHtmlKeyboardResponse,
    stimulus: '<div style="font-size:25px;">+</div>',
    choices: 'NO_KEYS',
    trial_duration: 500
};
```

### Instructions Screen

**Matlab:**
```matlab
instructions = 'Press F for left, J for right';
Screen('DrawText', window, instructions, ...);
Screen('Flip', window);
KbWait();
```

**jsPsych:**
```javascript
var instructions = {
    type: jsPsychHtmlKeyboardResponse,
    stimulus: 'Press F for left, J for right',
    choices: 'ALL_KEYS'
};
```

### Image Presentation

**Matlab:**
```matlab
imageTexture = Screen('MakeTexture', window, imageArray);
Screen('DrawTexture', window, imageTexture);
Screen('Flip', window);
KbWait();
```

**jsPsych:**
```javascript
// Preload images first:
var preload = {
    type: jsPsychPreload,
    images: ['image1.png', 'image2.png']
};

// Then show:
var trial = {
    type: jsPsychImageKeyboardResponse,
    stimulus: 'image1.png',
    choices: ['f', 'j']
};
```

### Response-Contingent Trials

**Matlab:**
```matlab
[response, rt] = collect_response();
if response == correct
    feedback = 'Correct!';
else
    feedback = 'Wrong!';
end
```

**jsPsych:**
```javascript
var trial = {
    type: jsPsychHtmlKeyboardResponse,
    stimulus: 'Stimulus here',
    choices: ['f', 'j'],
    on_finish: function(data) {
        var correct = data.response === 'f';
        var feedback = correct ? 'Correct!' : 'Wrong!';
        // Show feedback in next trial
    }
};
```

### Practice vs. Main Trials

**Matlab:**
```matlab
% Practice
for trial = 1:nPractice
    run_trial(practiceStimuli{trial});
end

% Main
for trial = 1:nMain
    run_trial(mainStimuli{trial});
end
```

**jsPsych:**
```javascript
// Practice trials
var practiceTimeline = [];
for (var i = 0; i < nPractice; i++) {
    practiceTimeline.push({
        type: jsPsychHtmlKeyboardResponse,
        stimulus: practiceStimuli[i],
        data: {phase: 'practice'}
    });
}

// Main trials
var mainTimeline = [];
for (var i = 0; i < nMain; i++) {
    mainTimeline.push({
        type: jsPsychHtmlKeyboardResponse,
        stimulus: mainStimuli[i],
        data: {phase: 'main'}
    });
}

// Combine
var fullTimeline = practiceTimeline.concat(mainTimeline);
jsPsych.run(fullTimeline);
```

## Data Structure Comparison

### Matlab
```matlab
results = struct();
results.trial = [];
results.response = [];
results.rt = [];
results.accuracy = [];

for trial = 1:nTrials
    results.trial(trial) = trial;
    results.response(trial) = response;
    results.rt(trial) = rt;
    results.accuracy(trial) = accuracy;
end
```

### jsPsych
```javascript
// Data automatically structured as:
[
    {
        trial_type: "html-keyboard-response",
        response: "f",
        rt: 523,
        accuracy: true,
        trial_index: 0,
        time_elapsed: 1523,
        // ... custom data fields
    },
    // ... more trials
]

// Access with:
var data = jsPsych.data.get();
var responses = data.select('response').values;
var rts = data.select('rt').values;
```

## Tips for Conversion

1. **Start Simple**: Convert one trial type at a time
2. **Test Frequently**: Check browser console for errors
3. **Use Browser DevTools**: Inspect elements, check network requests
4. **Timing Units**: Matlab uses seconds, jsPsych uses milliseconds
5. **Coordinate Systems**: Matlab uses screen coordinates, jsPsych uses browser pixels
6. **Randomization**: Test that randomization works as expected
7. **Data Format**: Check that data structure matches what you need

## Common Pitfalls

1. **Timing**: Remember jsPsych uses milliseconds, not seconds
2. **Async Operations**: Image loading is async, use preload
3. **Browser Differences**: Test in multiple browsers
4. **Screen Size**: Use relative sizes (%, vh, vw) not fixed pixels
5. **Data Types**: JavaScript is loosely typed, be careful with comparisons

## Getting Help

- Check jsPsych documentation: https://www.jspsych.org/
- Check browser console for errors
- Use `console.log()` for debugging
- Check Flask server logs for backend errors

