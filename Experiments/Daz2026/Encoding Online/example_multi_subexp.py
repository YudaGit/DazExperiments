"""
Example: How to implement 3 sub-experiments with random assignment

This shows the pattern you would use in expt_config.py
"""

import random

def get_data(opts):
    """
    This function is called by the framework.
    opts: Dictionary of URL parameters (e.g., {'subexp': '1'} or {})
    """
    
    # ============================================================
    # STEP 1: Determine which sub-experiment to run
    # ============================================================
    
    # Option A: Random assignment (recommended for balanced design)
    if 'subexp' in opts:
        # Manual assignment via URL: ?subexp=1
        subexperiment = int(opts['subexp'])
        if subexperiment not in [1, 2, 3]:
            subexperiment = random.choice([1, 2, 3])
    else:
        # Random assignment if no parameter provided
        subexperiment = random.choice([1, 2, 3])
    
    print(f"Assigning participant to sub-experiment {subexperiment}")
    
    # ============================================================
    # STEP 2: Prepare stimuli/structure based on sub-experiment
    # ============================================================
    
    if subexperiment == 1:
        # Sub-experiment 1: e.g., Condition A
        stimuli = load_stimuli_type_1()
        trial_structure = {
            'n_trials': 20,
            'trial_duration': 1000,
            'response_options': ['f', 'j']
        }
        
    elif subexperiment == 2:
        # Sub-experiment 2: e.g., Condition B
        stimuli = load_stimuli_type_2()
        trial_structure = {
            'n_trials': 30,
            'trial_duration': 1500,
            'response_options': ['f', 'j']
        }
        
    else:  # subexperiment == 3
        # Sub-experiment 3: e.g., Condition C
        stimuli = load_stimuli_type_3()
        trial_structure = {
            'n_trials': 25,
            'trial_duration': 2000,
            'response_options': ['f', 'j', 'space']
        }
    
    # ============================================================
    # STEP 3: Return data structure
    # ============================================================
    
    return {
        'subexperiment': subexperiment,  # Important: include this!
        'stimuli': stimuli,
        'trial_structure': trial_structure,
        # ... any other data your experiment needs
    }


# ============================================================
# Helper functions (you would implement these)
# ============================================================

def load_stimuli_type_1():
    """Load stimuli for sub-experiment 1"""
    # Example: Load images, words, etc.
    return ['stim1a.png', 'stim1b.png', 'stim1c.png']

def load_stimuli_type_2():
    """Load stimuli for sub-experiment 2"""
    return ['stim2a.png', 'stim2b.png', 'stim2c.png']

def load_stimuli_type_3():
    """Load stimuli for sub-experiment 3"""
    return ['stim3a.png', 'stim3b.png', 'stim3c.png']


# ============================================================
# Alternative: More organized approach
# ============================================================

def get_data_organized(opts):
    """
    More organized version using helper function
    """
    # Determine sub-experiment
    subexperiment = determine_subexperiment(opts)
    
    # Prepare experiment data
    experiment_data = prepare_subexperiment_data(subexperiment)
    
    # Return combined data
    return {
        'subexperiment': subexperiment,
        **experiment_data  # Unpacks all keys from experiment_data
    }

def determine_subexperiment(opts):
    """Determine which sub-experiment to run"""
    if 'subexp' in opts:
        subexp = int(opts['subexp'])
        if subexp in [1, 2, 3]:
            return subexp
    return random.choice([1, 2, 3])

def prepare_subexperiment_data(subexp_num):
    """Prepare all data for a specific sub-experiment"""
    configs = {
        1: {
            'stimuli': load_stimuli_type_1(),
            'n_trials': 20,
            'trial_duration': 1000,
        },
        2: {
            'stimuli': load_stimuli_type_2(),
            'n_trials': 30,
            'trial_duration': 1500,
        },
        3: {
            'stimuli': load_stimuli_type_3(),
            'n_trials': 25,
            'trial_duration': 2000,
        }
    }
    return configs[subexp_num]

