from __future__ import print_function
from builtins import range
from MallExperiment import Expt
from user_utils import nocache
from random import shuffle
import random
from flask import render_template, Blueprint, request
import copy
import config
import json
import requests
# If you are developing your experiment
# then set the DEBUG flag to True
DEBUG = config.DEBUG

s3_results_key = config.RESULTS_DIR + "/{}.json" # Must have formatting space ({}) for Participant Unique ID 

# Every experiment needs a unique ID
expt_uid = config.EXPT_UID

#########################################################################
### (0) Get condition parameters
#########################################################################
## >> the parts for all combinations
##  theCondition = {1:'interleaved', 2:'block-fam', 3:'block-novel'}
### but we aren't using the above dictionary.....!!!



#########################################################################
### (1) Server stuff - don't touch!
#########################################################################


# Other global Experimental Variables
study_list_length = 5
test_list_length = 10

stimulus_file = "word-list.json.gz"




# Using Expt to fetch stimulus data from S3
me_expt = Expt()

# Flask Blueprints can be used to add routes for custom_code
custom_code = Blueprint('expt_custom_code', __name__)
@custom_code.route('/debrief', methods=['post'])
@nocache
def debrief():
    data = request.form.get('data')
    uid = request.form.get('uid')
    mturk = request.form.get('mturk')
    prolific = request.form.get('prolific')

    mturk_survey_code = None
    if mturk:
        if DEBUG:
            mturk_survey_code = 9999
        else:
            mturk_survey_code = me_expt.get_mturk_survey_code(uid, 'mall_experiments_participants')

    prolific_completion_code = None
    if prolific:
        prolific_completion_code = config.PROLIFIC_COMPLETION_CODE

    return render_template(
        'debrief-short.html',
        mturk_survey_code=mturk_survey_code,
        prolific_completion_code=prolific_completion_code
        )


@custom_code.route('/full-debrief', methods=['get'])
@nocache
def full_debrief():
    return render_template(
            'debrief-long.html'
            )
# All experiments must provide a 'get_data' function that
# returns any stimulus data which will be used in the HTML templates  
# 
# opts: a dictionary of parameters that were passed in the GET request
#       e.g., https://yourexpt/expt?condition=1&debug=0
#             opts = {
#                'condition': '1',
#                'debug': '0'
#                }



#########################################################################
### (2) Organize stimuli
#  The only thing we need is get_data()
#########################################################################


def get_data(opts):
    """
    1. Determines which sub-experiment to run (random assignment or manual)
    2. Prepares stimuli and trial structure based on sub-experiment
    3. Returns data dictionary for JavaScript
    
    Returns:
        Dictionary with experiment data including 'subexperiment' key
    """
    
    # ============================================================
    # STEP 1: Determine which sub-experiment to run
    # ============================================================
    
    # Check if sub-experiment is manually specified via URL parameter
    # e.g., http://localhost:5000/unique-expt?subexp=1
    if 'subexp' in opts:
        # Manual assignment via URL parameter
        try:
            subexperiment = int(opts['subexp'])
            # Validate: must be 1, 2, or 3
            if subexperiment not in [1, 2, 3]:
                print(f"Warning: Invalid subexp={subexperiment}, using random assignment")
                subexperiment = random.choice([1, 2, 3])
        except (ValueError, TypeError):
            # If conversion fails, use random assignment
            print(f"Warning: Could not parse subexp={opts.get('subexp')}, using random assignment")
            subexperiment = random.choice([1, 2, 3])
    else:
        # Random assignment: randomly choose 1 of 3 sub-experiments
        subexperiment = random.choice([1, 2, 3])
    
    print(f"Assigned participant to Sub-Experiment {subexperiment}")
    
    # ============================================================
    # STEP 2: Prepare experiment-specific data
    # ============================================================
    
    # For now, we'll prepare placeholder data for all sub-experiments
    # Later, each sub-experiment will have its own preparation function
    
    if subexperiment == 1:
        # Sub-Experiment 1: Practice Effect Hypothesis
        # Set-size 6, 7 durations, R-cue vs NR-cue
        experiment_data = prepare_subexperiment_1()
        
    elif subexperiment == 2:
        # Sub-Experiment 2: Context Effect Hypothesis
        # Set-sizes 4 & 6, 3 durations, Baseline/R-cue/NR-cue
        experiment_data = prepare_subexperiment_2()
        
    else:  # subexperiment == 3
        # Sub-Experiment 3: Multiple Features Effect Hypothesis
        # Set-sizes 4 & 6, colored orientation bars, report orientation
        experiment_data = prepare_subexperiment_3()
    
    # ============================================================
    # STEP 3: Return data structure
    # ============================================================
    
    # Always include subexperiment number so JavaScript knows which to run
    return {
        'subexperiment': subexperiment,
        **experiment_data  # Unpack all experiment-specific data
    }


def prepare_subexperiment_1():
    """
    Prepare data for Sub-Experiment 1: Practice Effect Hypothesis
    
    Design:
    - Set-size: 6 (fixed)
    - Durations: 50, 100, 150, 200, 250, 300, 350ms (7 levels)
    - Trial types: R-cue, NR-cue (2 types)
    - Conditions: 7 × 2 = 14 conditions
    - Trials per condition: 10
    - Total: 140 trials + 5 practice
    
    Returns:
        Dictionary with experiment parameters and trial structure
    """
    # Design parameters
    set_size = 6
    redundant_n = 3  # Always 3 redundant items
    durations_ms = [50, 100, 150, 200, 250, 300, 350]  # 7 durations
    cue_types = ['R-cue', 'NR-cue']  # 2 trial types
    n_trials_per_condition = 10
    n_practice_trials = 5
    
    # Generate all trial combinations
    trials = generate_trials_subexp1(
        set_size=set_size,
        redundant_n=redundant_n,
        durations_ms=durations_ms,
        cue_types=cue_types,
        n_trials_per_condition=n_trials_per_condition
    )
    
    # Generate practice trials
    practice_trials = generate_practice_trials_subexp1(
        set_size=set_size,
        redundant_n=redundant_n,
        n_practice_trials=n_practice_trials
    )
    
    return {
        'experiment_type': 'practice_effect',
        'set_size': set_size,
        'durations': durations_ms,
        'trial_types': cue_types,
        'n_trials_per_condition': n_trials_per_condition,
        'n_practice_trials': n_practice_trials,
        'total_trials': len(trials),
        'trials': trials,
        'practice_trials': practice_trials
    }


def prepare_subexperiment_2():
    """
    Prepare data for Sub-Experiment 2: Context Effect Hypothesis
    
    Design:
    - Set-sizes: 4 and 6
    - Durations: 50, 100, 200ms (3 levels)
    - Trial types: Baseline, R-cue, NR-cue (3 types)
    - Conditions: 2 × 3 × 3 = 18 conditions
    - Trials per condition: 10
    - Total: 180 trials + 5 practice
    
    Returns:
        Dictionary with experiment parameters and trial structure
    """
    return {
        'experiment_type': 'context_effect',
        'set_sizes': [4, 6],
        'durations': [50, 100, 200],  # 3 durations in ms
        'trial_types': ['Baseline', 'R-cue', 'NR-cue'],  # 3 trial types
        'n_trials_per_condition': 10,
        'n_practice_trials': 5,
        'total_trials': 180,
        'trials': []  # Will be populated later
    }


def prepare_subexperiment_3():
    """
    Prepare data for Sub-Experiment 3: Multiple Features Effect Hypothesis
    
    Design:
    - Set-sizes: 4 and 6
    - Durations: 50, 100, 200ms (3 levels)
    - Trial types: Baseline, R-cue, NR-cue (3 types)
    - Conditions: 2 × 3 × 3 = 18 conditions
    - Trials per condition: 10
    - Total: 180 trials + 5 practice
    - Stimuli: Colored orientation bars
    
    Returns:
        Dictionary with experiment parameters and trial structure
    """
    return {
        'experiment_type': 'multiple_features',
        'set_sizes': [4, 6],
        'durations': [50, 100, 200],  # 3 durations in ms
        'trial_types': ['Baseline', 'R-cue', 'NR-cue'],  # 3 trial types
        'n_trials_per_condition': 10,
        'n_practice_trials': 5,
        'total_trials': 180,
        'stimulus_type': 'colored_orientation_bars',
        'trials': []  # Will be populated later
    }


# ============================================================
# Legacy functions (from original example - keeping for reference)
# ============================================================

def fetch_word_list():
    #word_list = me_expt.get_S3(s3_data_bucket, s3_data_key)
    word_list = me_expt.get_file(stimulus_file)
    return word_list


def get_word_list(word_list, list_length, study_list=None):
    skip_words = {}
    mylist = []
    # If we have a study list
    # then create a test list that
    # contains the study list words
    # and then add distractor words in
    # the while loop below
    if study_list:
        for x in study_list:
            skip_words[x['token']] = 1
        mylist = copy.deepcopy(study_list)


    # Shuffle words and
    # Get an balanced number of high and low frequency words
    words = copy.deepcopy(word_list)
    shuffle(words)
    last_freq = ""
    while len( mylist ) < list_length and words:
        w = words.pop()
        if w['token'] not in skip_words and last_freq != w['frequency']:
            mylist.append(w)
            last_freq = w['frequency']

    # Shuffle the test list
    if study_list:
        shuffle(mylist)

    return mylist

def fetch_word_list():
    #word_list = me_expt.get_S3(s3_data_bucket, s3_data_key)
    word_list = me_expt.get_file(stimulus_file)
    return word_list


def get_word_list(word_list, list_length, study_list=None):
    skip_words = {}
    mylist = []
    # If we have a study list
    # then create a test list that
    # contains the study list words
    # and then add distractor words in
    # the while loop below
    if study_list:
        for x in study_list:
            skip_words[x['token']] = 1
        mylist = copy.deepcopy(study_list)


    # Shuffle words and
    # Get an balanced number of high and low frequency words
    words = copy.deepcopy(word_list)
    shuffle(words)
    last_freq = ""
    while len( mylist ) < list_length and words:
        w = words.pop()
        if w['token'] not in skip_words and last_freq != w['frequency']:
            mylist.append(w)
            last_freq = w['frequency']

    # Shuffle the test list
    if study_list:
        shuffle(mylist)

    return mylist



# ============================================================
# Sub-Experiment 1: Trial Generation Functions
# ============================================================

import itertools
from collections import Counter



def generate_trials_subexp1(set_size, redundant_n, durations_ms, cue_types, n_trials_per_condition):
    """
    Generate all trials for Sub-Experiment 1.
    
    Creates all combinations of:
    - Durations (7 levels)
    - Cue types (R-cue, NR-cue)
    - Repeats each combination n_trials_per_condition times
    - Randomizes order
    
    Returns:
        List of trial dictionaries
    """
    # Create all combinations of factors
    all_combinations = list(itertools.product(durations_ms, cue_types))
    
    # Repeat each combination
    trials = []
    for duration, cue_type in all_combinations:
        for rep in range(n_trials_per_condition):
            # Generate trial-specific properties
            trial = generate_single_trial_subexp1(
                set_size=set_size,
                redundant_n=redundant_n,
                duration_ms=duration,
                cue_type=cue_type
            )
            trials.append(trial)
    
    # Randomize order
    random.shuffle(trials)
    
    # Add trial numbers
    for i, trial in enumerate(trials):
        trial['trial_number'] = i + 1
    
    return trials


def generate_single_trial_subexp1(set_size, redundant_n, duration_ms, cue_type):
    """
    Generate a single trial with random colors, positions, and target.
    """
    # Generate colors with spacing constraints
    colors = generate_colors_with_redundancy(set_size, redundant_n, min_spacing=30)
    
    # Generate positions (evenly spaced on ring)
    positions = generate_positions_evenly_spaced(set_size)
    
    # Select target based on cue type
    redundant_indices = get_redundant_indices(colors, redundant_n)
    if cue_type == 'R-cue':
        # Target is one of the redundant items
        target_pool = redundant_indices
    else:  # NR-cue
        # Target is one of the non-redundant items
        target_pool = [i for i in range(set_size) if i not in redundant_indices]
    
    target = random.choice(target_pool)
    is_redundant_target = target in redundant_indices
    
    return {
        'duration_ms': duration_ms,
        'cue_type': cue_type,
        'set_size': set_size,
        'redundant_n': redundant_n,
        'colors': colors,
        'positions': positions,
        'target': target,
        'is_redundant_target': is_redundant_target,
        'redundant_indices': redundant_indices
    }


def generate_colors_with_redundancy(set_size, redundant_n, min_spacing=30):
    """
    Generate colors for a trial with redundancy.
    """
    max_attempts = 100
    
    for attempt in range(max_attempts):
        # Choose one color for redundant items
        redundant_color = random.randint(0, 359)
        
        # Generate unique colors for non-redundant items
        unique_colors = []
        unique_needed = set_size - redundant_n
        
        while len(unique_colors) < unique_needed:
            candidate = random.randint(0, 359)
            
            # Check spacing from redundant color
            if min_circular_distance(candidate, redundant_color) < min_spacing:
                continue
            
            # Check spacing from other unique colors
            if unique_colors:
                distances = [min_circular_distance(candidate, uc) for uc in unique_colors]
                if min(distances) < min_spacing:
                    continue
            
            unique_colors.append(candidate)
        
        # Assign colors to positions
        colors = [0] * set_size
        
        # Randomly choose which positions are redundant
        redundant_positions = random.sample(range(set_size), redundant_n)
        
        # Assign redundant color
        for pos in redundant_positions:
            colors[pos] = redundant_color
        
        # Assign unique colors to remaining positions
        unique_positions = [i for i in range(set_size) if i not in redundant_positions]
        for i, pos in enumerate(unique_positions):
            colors[pos] = unique_colors[i]
        
        return colors
    
    # If we couldn't find valid colors, return a fallback
    print('Warning: Could not generate colors with spacing constraints, using fallback')
    colors = [i * 60 for i in range(set_size)]  # Evenly spaced fallback
    return colors


def generate_positions_evenly_spaced(set_size):
    """
    Generate evenly spaced positions on a ring.
    """
    # Evenly spaced positions
    spacing = 360 / set_size
    start_angle = random.randint(0, int(spacing) - 1)  # Random starting angle
    
    positions = []
    for i in range(set_size):
        angle = (start_angle + i * spacing) % 360
        positions.append(angle)
    
    # Shuffle order
    shuffled = positions[:]
    random.shuffle(shuffled)
    
    return shuffled


def get_redundant_indices(colors, redundant_n):
    """
    Find which indices have redundant colors.
    """
    # Find the color that appears redundant_n times
    color_counts = Counter(colors)
    
    # Find color that appears redundant_n times
    for color, count in color_counts.items():
        if count == redundant_n:
            # Return all indices with this color
            return [i for i, c in enumerate(colors) if c == color]
    
    # Fallback: return first redundant_n indices
    return list(range(redundant_n))


def min_circular_distance(angle1, angle2):
    """
    Calculate minimum circular distance between two angles (0-359).
    """
    diff = abs(angle1 - angle2)
    return min(diff, 360 - diff)


def generate_practice_trials_subexp1(set_size, redundant_n, n_practice_trials):
    """
    Generate practice trials for Sub-Experiment 1.
    Ensures balanced distribution of cue types.
    """
    # Use a subset of durations for practice
    practice_durations = [100, 200, 300]  # 3 durations
    cue_types = ['R-cue', 'NR-cue']
    
    # Ensure balanced cue type distribution
    # For 5 trials: 3 of one type, 2 of the other (or 2.5 each, rounded)
    n_r_cue = n_practice_trials // 2
    n_nr_cue = n_practice_trials - n_r_cue
    
    # Create balanced list of cue types
    balanced_cue_types = ['R-cue'] * n_r_cue + ['NR-cue'] * n_nr_cue
    random.shuffle(balanced_cue_types)
    
    trials = []
    for i in range(n_practice_trials):
        duration = random.choice(practice_durations)
        cue_type = balanced_cue_types[i]  # Use balanced distribution
        
        trial = generate_single_trial_subexp1(
            set_size=set_size,
            redundant_n=redundant_n,
            duration_ms=duration,
            cue_type=cue_type
        )
        trial['trial_number'] = i + 1
        trial['is_practice'] = True
        trials.append(trial)
    
    return trials


