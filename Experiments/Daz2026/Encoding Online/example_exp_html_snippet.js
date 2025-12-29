// Example JavaScript code for templates/exp.html
// This shows how to use the subexperiment data from Python

// ============================================================
// STEP 1: Get data from Python (already in your template)
// ============================================================
var expt_data = {{data|safe}};
var subexperiment = expt_data.subexperiment;  // 1, 2, or 3
var stimuli = expt_data.stimuli;
var trial_structure = expt_data.trial_structure;

console.log("Running sub-experiment:", subexperiment);

// ============================================================
// STEP 2: Build timeline based on sub-experiment
// ============================================================

var timeline = [];

// Common parts (same for all sub-experiments)
timeline.push(preload);
timeline.push(fullscreen);
timeline.push(instructions);
timeline.push(consent);

// Sub-experiment specific trials
if (subexperiment === 1) {
    // Build trials for sub-experiment 1
    for (var i = 0; i < stimuli.length; i++) {
        timeline.push({
            type: jsPsychImageKeyboardResponse,
            stimulus: stimuli[i],
            choices: trial_structure.response_options,
            trial_duration: trial_structure.trial_duration,
            data: {
                subexperiment: subexperiment,
                trial_number: i + 1,
                condition: 'A'  // or whatever label you want
            }
        });
    }
    
} else if (subexperiment === 2) {
    // Build trials for sub-experiment 2
    for (var i = 0; i < stimuli.length; i++) {
        timeline.push({
            type: jsPsychImageKeyboardResponse,
            stimulus: stimuli[i],
            choices: trial_structure.response_options,
            trial_duration: trial_structure.trial_duration,
            data: {
                subexperiment: subexperiment,
                trial_number: i + 1,
                condition: 'B'
            }
        });
    }
    
} else {
    // Build trials for sub-experiment 3
    for (var i = 0; i < stimuli.length; i++) {
        timeline.push({
            type: jsPsychImageKeyboardResponse,
            stimulus: stimuli[i],
            choices: trial_structure.response_options,
            trial_duration: trial_structure.trial_duration,
            data: {
                subexperiment: subexperiment,
                trial_number: i + 1,
                condition: 'C'
            }
        });
    }
}

// Common ending
timeline.push(debrief);

// ============================================================
// STEP 3: Run experiment
// ============================================================
const jsPsych = initJsPsych({
    on_finish: function() {
        // Add subexperiment to data properties
        jsPsych.data.addProperties({
            subexperiment: subexperiment,
            // ... other properties
        });
        
        // Save data
        var all_data = jsPsych.data.get().json();
        _send_task_data(all_data);
    }
});

jsPsych.run(timeline);


// ============================================================
// Alternative: More organized approach using functions
// ============================================================

function build_subexperiment_timeline(subexp, expt_data) {
    var timeline = [];
    
    // Common setup
    timeline.push(preload);
    timeline.push(instructions);
    
    // Sub-experiment specific
    switch(subexp) {
        case 1:
            timeline = timeline.concat(build_trials_subexp1(expt_data));
            break;
        case 2:
            timeline = timeline.concat(build_trials_subexp2(expt_data));
            break;
        case 3:
            timeline = timeline.concat(build_trials_subexp3(expt_data));
            break;
    }
    
    // Common ending
    timeline.push(debrief);
    
    return timeline;
}

function build_trials_subexp1(data) {
    var trials = [];
    for (var i = 0; i < data.stimuli.length; i++) {
        trials.push({
            type: jsPsychImageKeyboardResponse,
            stimulus: data.stimuli[i],
            choices: ['f', 'j'],
            data: {subexperiment: 1, trial: i + 1}
        });
    }
    return trials;
}

function build_trials_subexp2(data) {
    // Similar structure for sub-experiment 2
    var trials = [];
    // ... build trials
    return trials;
}

function build_trials_subexp3(data) {
    // Similar structure for sub-experiment 3
    var trials = [];
    // ... build trials
    return trials;
}

// Then use:
// var timeline = build_subexperiment_timeline(subexperiment, expt_data);
// jsPsych.run(timeline);

