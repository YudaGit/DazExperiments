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
import os
from expt_queue import poll_queue, update_queue, update_return_queue
from MallExperiment import Expt, Record, QuerySelect, DATESTRING_FORMAT
from datetime import datetime
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


# Subexperiment allocation quotas (set to 1 for testing)
ALLOCATION_QUOTAS = {1: 1, 2: 1, 3: 1}
ALLOCATION_STATE_FILE = "subexp_allocation_counts.json"


def _allocation_state_path():
    return os.path.join(os.path.dirname(__file__), ALLOCATION_STATE_FILE)


def _load_allocation_state():
    path = _allocation_state_path()
    if not os.path.isfile(path):
        return {
            "counts": {str(k): 0 for k in ALLOCATION_QUOTAS},
            "quotas": {str(k): ALLOCATION_QUOTAS[k] for k in ALLOCATION_QUOTAS},
        }
    try:
        with open(path, "r", encoding="utf-8") as fp:
            data = json.load(fp)
        if "counts" not in data:
            data["counts"] = {}
        if "quotas" not in data:
            data["quotas"] = {str(k): ALLOCATION_QUOTAS[k] for k in ALLOCATION_QUOTAS}
        return data
    except Exception:
        return {
            "counts": {str(k): 0 for k in ALLOCATION_QUOTAS},
            "quotas": {str(k): ALLOCATION_QUOTAS[k] for k in ALLOCATION_QUOTAS},
        }


def _save_allocation_state(state):
    path = _allocation_state_path()
    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as fp:
        json.dump(state, fp, indent=2, sort_keys=True)
    os.replace(tmp_path, path)


def _get_allocation_quotas(state):
    quotas = state.get("quotas", {})
    if not quotas:
        return ALLOCATION_QUOTAS
    # Ensure int keys with int values
    out = {}
    for k, v in quotas.items():
        try:
            out[int(k)] = int(v)
        except Exception:
            continue
    return out or ALLOCATION_QUOTAS


def increment_subexperiment_count(subexp):
    if subexp not in ALLOCATION_QUOTAS:
        return
    state = _load_allocation_state()
    counts = state.get("counts", {})
    counts[str(subexp)] = counts.get(str(subexp), 0) + 1
    state["counts"] = counts
    _save_allocation_state(state)


def _allocate_subexperiment():
    state = _load_allocation_state()
    counts = state.get("counts", {})
    quotas = _get_allocation_quotas(state)
    available = [k for k in quotas if counts.get(str(k), 0) < quotas[k]]
    if not available:
        return random.choice(list(quotas.keys()))
    return random.choice(available)


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
    # if 'subexp' in opts:
    #     # Manual assignment via URL parameter (does not consume quota)
    #     try:
    #         subexperiment = int(opts['subexp'])
    #         # Validate: must be 1, 2, or 3
    #         if subexperiment not in [1, 2, 3]:
    #             print(f"Warning: Invalid subexp={subexperiment}, using quota-based assignment")
    #             subexperiment = _allocate_subexperiment()
    #     except (ValueError, TypeError):
    #         # If conversion fails, use quota-based assignment
    #         print(f"Warning: Could not parse subexp={opts.get('subexp')}, using quota-based assignment")
    #         subexperiment = _allocate_subexperiment()
    # else:
    #     # Quota-based random assignment across available sub-experiments
    #     subexperiment = _allocate_subexperiment()

    subexperiment = None
    if 'subexp' not in opts.keys():
        if config.DEBUG: # Running locally in debug mode
            subexperiment = _allocate_subexperiment()
        else: # Running on AWS
            subexperiment = int( poll_queue() )
    else:
        subexperiment = int(opts['subexp'])

    

    # When all quotas are filled, still allow random assignment
    
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
         '_participant_attrs':{   # Set these attributes in the DB
             'subexperiment': str(subexperiment),
         },        
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
    - Trials per condition: 20
    - Total: 280 trials + 5 practice
    
    Returns:
        Dictionary with experiment parameters and trial structure
    """
    # Design parameters
    set_size = 6
    redundant_n = 3  # Always 3 redundant items
    durations_ms = [50, 100, 150, 200, 250, 300, 350]  # 7 durations
    cue_types = ['R-cue', 'NR-cue']  # 2 trial types
    n_trials_per_condition = 25
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
    - Trial types: Baseline (no redundancy), R-cue, NR-cue
    - Durations: 50ms, 100ms, 200ms (3 levels)
    - Conditions: 2 set-sizes × 3 trial types × 3 durations = 18 conditions
    - Trials per condition: 20
    - Total trials: 360
    - Practice trials: 5
    
    Returns:
        Dictionary with trials, practice_trials, and metadata
    """
    # Design parameters
    set_sizes = [4, 6]
    durations_ms = [50, 150, 250]  # 3 durations
    trial_types = ['Baseline', 'R-cue', 'NR-cue']
    n_trials_per_condition = 20
    
    # Redundancy levels: set-size 4 has 2 redundant, set-size 6 has 3 redundant
    redundancy_by_set_size = {4: 2, 6: 3}
    
    # Generate all main trials
    all_trials = []
    for set_size in set_sizes:
        redundant_n = redundancy_by_set_size[set_size]
        
        for duration_ms in durations_ms:
            for trial_type in trial_types:
                # Generate 20 trials for this condition
                for rep in range(n_trials_per_condition):
                    trial = generate_single_trial_subexp2(
                        set_size=set_size,
                        redundant_n=redundant_n,
                        duration_ms=duration_ms,
                        trial_type=trial_type
                    )
                    all_trials.append(trial)
    
    # Randomize order
    random.shuffle(all_trials)
    
    # Add trial numbers
    for i, trial in enumerate(all_trials):
        trial['trial_number'] = i + 1
    
    # Generate practice trials
    practice_trials = generate_practice_trials_subexp2()
    
    return {
        'trials': all_trials,
        'practice_trials': practice_trials,
        'set_size': set_sizes,  # List of set-sizes used
        'durations': durations_ms,
        'trial_types': trial_types,
        'experiment_type': 'Context Effect Hypothesis'
    }


def prepare_subexperiment_3():
    """
    Prepare data for Sub-Experiment 3: Multiple Features Effect Hypothesis
    
    Design:
    - Set-sizes: 4 and 6
    - Trial types: Baseline (no redundancy), R-cue, NR-cue
    - Durations: 50ms, 100ms, 200ms (3 levels)
    - Conditions: 2 set-sizes × 3 trial types × 3 durations = 18 conditions
    - Trials per condition: 20
    - Total trials: 360
    - Practice trials: 5
    - Stimuli: Colored orientation bars (color + orientation)
    - Task: Cue color, report orientation
    
    Returns:
        Dictionary with trials, practice_trials, and metadata
    """
    # Design parameters
    set_sizes = [4, 6]
    durations_ms = [50, 150, 250]  # 3 durations
    trial_types = ['Baseline', 'R-cue', 'NR-cue']
    n_trials_per_condition = 20
    
    # Redundancy levels: set-size 4 has 2 redundant, set-size 6 has 3 redundant
    redundancy_by_set_size = {4: 2, 6: 3}
    
    # Generate all main trials
    all_trials = []
    for set_size in set_sizes:
        redundant_n = redundancy_by_set_size[set_size]
        
        for duration_ms in durations_ms:
            for trial_type in trial_types:
                # Generate 20 trials for this condition
                for rep in range(n_trials_per_condition):
                    trial = generate_single_trial_subexp3(
                        set_size=set_size,
                        redundant_n=redundant_n,
                        duration_ms=duration_ms,
                        trial_type=trial_type
                    )
                    all_trials.append(trial)
    
    # Randomize order
    random.shuffle(all_trials)
    
    # Add trial numbers
    for i, trial in enumerate(all_trials):
        trial['trial_number'] = i + 1
    
    # Generate practice trials
    practice_trials = generate_practice_trials_subexp3()
    
    return {
        'trials': all_trials,
        'practice_trials': practice_trials,
        'set_size': set_sizes,  # List of set-sizes used
        'durations': durations_ms,
        'trial_types': trial_types,
        'experiment_type': 'Multiple Features Effect Hypothesis',
        'stimulus_type': 'colored_orientation_bars'
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



# ============================================================
# Sub-Experiment 2: Trial Generation Functions
# ============================================================
    """
    Generate a single trial for Sub-Experiment 2.
    
    Args:
        set_size: Number of items (4 or 6)
        redundant_n: Number of redundant items (2 for set-size 4, 3 for set-size 6)
        duration_ms: Presentation duration
        trial_type: 'Baseline', 'R-cue', or 'NR-cue'
    
    Returns:
        Trial dictionary
    """
    if trial_type == 'Baseline':
        # Baseline: All unique colors, no redundancy
        colors = generate_unique_colors(set_size, min_spacing=30)
        positions = generate_positions_evenly_spaced(set_size)
        
        # Target can be any item (all are unique)
        target = random.randint(0, set_size - 1)
        is_redundant_target = False
        redundant_indices = []
        
    else:  # R-cue or NR-cue
        # Generate colors with redundancy
        colors = generate_colors_with_redundancy(set_size, redundant_n, min_spacing=30)
        positions = generate_positions_evenly_spaced(set_size)
        
        # Select target based on cue type
        redundant_indices = get_redundant_indices(colors, redundant_n)
        if trial_type == 'R-cue':
            # Target is one of the redundant items
            target_pool = redundant_indices
        else:  # NR-cue
            # Target is one of the non-redundant items
            target_pool = [i for i in range(set_size) if i not in redundant_indices]
        
        target = random.choice(target_pool)
        is_redundant_target = target in redundant_indices
    
    return {
        'duration_ms': duration_ms,
        'trial_type': trial_type,
        'set_size': set_size,
        'redundant_n': redundant_n if trial_type != 'Baseline' else 0,
        'colors': colors,
        'positions': positions,
        'target': target,
        'is_redundant_target': is_redundant_target,
        'redundant_indices': redundant_indices
    }


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
    max_inner_attempts = 2000
    
    for attempt in range(max_attempts):
        # Choose one color for redundant items
        redundant_color = random.randint(0, 359)
        
        # Generate unique colors for non-redundant items
        unique_colors = []
        unique_needed = set_size - redundant_n
        
        inner_attempts = 0
        while len(unique_colors) < unique_needed:
            inner_attempts += 1
            if inner_attempts > max_inner_attempts:
                break
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

        if len(unique_colors) < unique_needed:
            continue
        
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



# ============================================================
# Sub-Experiment 2: Trial Generation Functions
# ============================================================

def generate_single_trial_subexp2(set_size, redundant_n, duration_ms, trial_type):
    """
    Generate a single trial for Sub-Experiment 2.
    
    Args:
        set_size: Number of items (4 or 6)
        redundant_n: Number of redundant items (2 for set-size 4, 3 for set-size 6)
        duration_ms: Presentation duration
        trial_type: 'Baseline', 'R-cue', or 'NR-cue'
    
    Returns:
        Trial dictionary
    """
    if trial_type == 'Baseline':
        # Baseline: All unique colors, no redundancy
        colors = generate_unique_colors(set_size, min_spacing=30)
        positions = generate_positions_evenly_spaced(set_size)
        
        # Target can be any item (all are unique)
        target = random.randint(0, set_size - 1)
        is_redundant_target = False
        redundant_indices = []
        
    else:  # R-cue or NR-cue
        # Generate colors with redundancy
        colors = generate_colors_with_redundancy(set_size, redundant_n, min_spacing=30)
        positions = generate_positions_evenly_spaced(set_size)
        
        # Select target based on cue type
        redundant_indices = get_redundant_indices(colors, redundant_n)
        if trial_type == 'R-cue':
            # Target is one of the redundant items
            target_pool = redundant_indices
        else:  # NR-cue
            # Target is one of the non-redundant items
            target_pool = [i for i in range(set_size) if i not in redundant_indices]
        
        target = random.choice(target_pool)
        is_redundant_target = target in redundant_indices
    
    return {
        'duration_ms': duration_ms,
        'trial_type': trial_type,
        'set_size': set_size,
        'redundant_n': redundant_n if trial_type != 'Baseline' else 0,
        'colors': colors,
        'positions': positions,
        'target': target,
        'is_redundant_target': is_redundant_target,
        'redundant_indices': redundant_indices
    }


def generate_unique_colors(set_size, min_spacing=30):
    """
    Generate all unique colors with minimum spacing constraint.
    Used for Baseline trials where there's no redundancy.
    """
    max_attempts = 100
    max_inner_attempts = 2000
    
    for attempt in range(max_attempts):
        colors = []
        
        inner_attempts = 0
        while len(colors) < set_size:
            inner_attempts += 1
            if inner_attempts > max_inner_attempts:
                break
            candidate = random.randint(0, 359)
            
            # Check spacing from all existing colors
            if colors:
                distances = [min_circular_distance(candidate, c) for c in colors]
                if min(distances) < min_spacing:
                    continue
            
            colors.append(candidate)

        if len(colors) < set_size:
            continue
        
        return colors
    
    # Fallback: evenly spaced colors
    print('Warning: Could not generate unique colors with spacing constraints, using fallback')
    spacing = 360 / set_size
    colors = [int(i * spacing) for i in range(set_size)]
    return colors


def generate_practice_trials_subexp2():
    """
    Generate practice trials for Sub-Experiment 2.
    Ensures balanced distribution across set-sizes and trial types.
    """
    set_sizes = [4, 6]
    practice_durations = [100, 200]  # 2 durations for practice
    trial_types = ['Baseline', 'R-cue', 'NR-cue']
    n_practice_trials = 5
    
    redundancy_by_set_size = {4: 2, 6: 3}
    
    # Create balanced distribution
    # For 5 trials: mix of set-sizes and trial types
    # Let's do: 2 trials with set-size 4, 3 trials with set-size 6
    practice_set_sizes = [4, 4, 6, 6, 6]
    # Mix trial types: at least one of each type
    practice_trial_types = ['Baseline', 'R-cue', 'NR-cue', 'R-cue', 'NR-cue']
    random.shuffle(practice_trial_types)
    
    trials = []
    for i in range(n_practice_trials):
        set_size = practice_set_sizes[i]
        trial_type = practice_trial_types[i]
        duration = random.choice(practice_durations)
        redundant_n = redundancy_by_set_size[set_size]
        
        trial = generate_single_trial_subexp2(
            set_size=set_size,
            redundant_n=redundant_n,
            duration_ms=duration,
            trial_type=trial_type
        )
        trial['trial_number'] = i + 1
        trial['is_practice'] = True
        trials.append(trial)
    
    return trials


# ============================================================
# Sub-Experiment 3: Trial Generation Functions
# ============================================================

def generate_single_trial_subexp3(set_size, redundant_n, duration_ms, trial_type):
    """
    Generate a single trial for Sub-Experiment 3.
    
    Args:
        set_size: Number of items (4 or 6)
        redundant_n: Number of redundant items (2 for set-size 4, 3 for set-size 6)
        duration_ms: Presentation duration
        trial_type: 'Baseline', 'R-cue', or 'NR-cue'
    
    Returns:
        Trial dictionary with colors, orientations, positions, and target
    """
    if trial_type == 'Baseline':
        # Baseline: All unique colors AND orientations, no redundancy
        colors = generate_unique_colors(set_size, min_spacing=30)
        orientations = generate_unique_orientations(set_size, min_spacing=30)
        positions = generate_positions_evenly_spaced(set_size)
        
        # Target can be any item (all are unique)
        target = random.randint(0, set_size - 1)
        is_redundant_target = False
        redundant_indices = []
        
    else:  # R-cue or NR-cue
        # Generate colors with redundancy
        colors = generate_colors_with_redundancy(set_size, redundant_n, min_spacing=30)
        positions = generate_positions_evenly_spaced(set_size)
        
        # Generate orientations with redundancy (same as colors)
        # Redundant items must have SAME color AND orientation
        orientations = generate_orientations_with_redundancy(
            set_size, redundant_n, colors, min_spacing=20
        )
        
        # Select target based on cue type
        redundant_indices = get_redundant_indices(colors, redundant_n)
        if trial_type == 'R-cue':
            # Target is one of the redundant items
            target_pool = redundant_indices
        else:  # NR-cue
            # Target is one of the non-redundant items
            target_pool = [i for i in range(set_size) if i not in redundant_indices]
        
        target = random.choice(target_pool)
        is_redundant_target = target in redundant_indices
    
    return {
        'duration_ms': duration_ms,
        'trial_type': trial_type,
        'set_size': set_size,
        'redundant_n': redundant_n if trial_type != 'Baseline' else 0,
        'colors': colors,
        'orientations': orientations,  # NEW: orientations in degrees (0-180)
        'positions': positions,
        'target': target,
        'is_redundant_target': is_redundant_target,
        'redundant_indices': redundant_indices
    }


def generate_unique_orientations(set_size, min_spacing=30):
    """
    Generate all unique orientations with minimum spacing constraint.
    Orientations are in degrees, range 0-180.
    Used for Baseline trials where there's no redundancy.
    """
    max_attempts = 200
    max_inner_attempts = 2000
    
    for attempt in range(max_attempts):
        orientations = []
        
        inner_attempts = 0
        while len(orientations) < set_size:
            inner_attempts += 1
            if inner_attempts > max_inner_attempts:
                break
            candidate = random.randint(0, 180)
            
            # Check spacing from all existing orientations
            if orientations:
                distances = [min_linear_distance(candidate, o) for o in orientations]
                if min(distances) < min_spacing:
                    continue
            
            orientations.append(candidate)

        if len(orientations) < set_size:
            continue
        
        return orientations
    
    # Fallback: evenly spaced orientations
    print('Warning: Could not generate unique orientations with spacing constraints, using fallback')
    spacing = 180 / set_size
    orientations = [int(i * spacing) for i in range(set_size)]
    return orientations


def min_linear_distance(value1, value2):
    """
    Calculate minimum linear distance between two values.
    For orientations (0-180), this is just absolute difference.
    """
    return abs(value1 - value2)


def generate_orientations_with_redundancy(set_size, redundant_n, colors, min_spacing=30):
    """
    Generate orientations with redundancy matching colors.
    Redundant items (same color) must also have the same orientation.
    
    Args:
        set_size: Number of items
        redundant_n: Number of redundant items
        colors: List of colors (redundant items have same color)
        min_spacing: Minimum spacing between unique orientations (degrees)
    
    Returns:
        List of orientations matching the color redundancy pattern
    """
    max_attempts = 200
    max_inner_attempts = 2000
    
    for attempt in range(max_attempts):
        # Find redundant color and indices
        redundant_indices = get_redundant_indices(colors, redundant_n)
        
        # Generate unique orientations needed
        # For set-size 4 with 2 redundant: need 3 unique orientations (2+1+1)
        # For set-size 6 with 3 redundant: need 4 unique orientations (3+1+1+1)
        unique_orientations_needed = set_size - redundant_n + 1
        
        unique_orientations = []
        inner_attempts = 0
        while len(unique_orientations) < unique_orientations_needed:
            inner_attempts += 1
            if inner_attempts > max_inner_attempts:
                break
            candidate = random.randint(0, 180)
            
            # Check spacing from existing unique orientations
            if unique_orientations:
                distances = [min_linear_distance(candidate, uo) for uo in unique_orientations]
                if min(distances) < min_spacing:
                    continue
            
            unique_orientations.append(candidate)

        if len(unique_orientations) < unique_orientations_needed:
            continue
        
        # Assign orientations to items
        orientations = [0] * set_size
        
        # Assign redundant orientation to redundant items
        redundant_orientation = unique_orientations[0]
        for idx in redundant_indices:
            orientations[idx] = redundant_orientation
        
        # Assign unique orientations to non-redundant items
        unique_indices = [i for i in range(set_size) if i not in redundant_indices]
        for i, idx in enumerate(unique_indices):
            orientations[idx] = unique_orientations[i + 1]  # Skip first (redundant)
        
        return orientations
    
    # Fallback: evenly spaced orientations
    print('Warning: Could not generate orientations with redundancy, using fallback')
    spacing = 180 / set_size
    orientations = [int(i * spacing) for i in range(set_size)]
    return orientations


def generate_practice_trials_subexp3():
    """
    Generate practice trials for Sub-Experiment 3.
    Ensures balanced distribution across set-sizes and trial types.
    """
    set_sizes = [4, 6]
    practice_durations = [100, 200]  # 2 durations for practice
    trial_types = ['Baseline', 'R-cue', 'NR-cue']
    n_practice_trials = 5
    
    redundancy_by_set_size = {4: 2, 6: 3}
    
    # Create balanced distribution
    # For 5 trials: mix of set-sizes and trial types
    practice_set_sizes = [4, 4, 6, 6, 6]
    # Mix trial types: at least one of each type
    practice_trial_types = ['Baseline', 'R-cue', 'NR-cue', 'R-cue', 'NR-cue']
    random.shuffle(practice_trial_types)
    
    trials = []
    for i in range(n_practice_trials):
        set_size = practice_set_sizes[i]
        trial_type = practice_trial_types[i]
        duration = random.choice(practice_durations)
        redundant_n = redundancy_by_set_size[set_size]
        
        trial = generate_single_trial_subexp3(
            set_size=set_size,
            redundant_n=redundant_n,
            duration_ms=duration,
            trial_type=trial_type
        )
        trial['trial_number'] = i + 1
        trial['is_practice'] = True
        trials.append(trial)
    
    return trials


def prolific_returned(data):
    print("prolific_returned")
    prolific_id = data.get('prolific_id')
    if not prolific_id:
        return {'error': 'No prolific_id provided'}
    study_id = data.get('study_id')
    if not study_id:
        return {'error': 'No Study_id provided'}
    submission_id = data.get('submission_id')
    if not submission_id:
        return {'error': 'No Submission_id provided'}

    qs = QuerySelect()
    query = f"SELECT prolific_id, study_id, session_id, uid, subexperiment FROM mall_experiments_participants WHERE prolific_id = '{prolific_id}' AND study_id = '{study_id}' AND prolific_returned IS NULL "
    res = list(qs.sql(query))

    print(res)

    if res and res[0].get('subexperiment'):
        # Put condition back on the queue
        update_return_queue(res[0]['subexperiment'])

        # Update the Participant DB
        participant = Record(domain=config.SDB_EXPERIMENTS_PARTICIPANTS, key=res[0]['uid'])

        attrs = {
            'prolific_returned': datetime.utcnow().strftime(DATESTRING_FORMAT),
        }
        participant.set_attributes(attrs, True)
        participant.update()