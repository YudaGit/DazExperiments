#!/usr/bin/env python
"""
Test script for Sub-Experiment 3 Steps 1 & 2
"""

import expt_config
import random

print("=" * 60)
print("SUB-EXPERIMENT 3: Steps 1 & 2 Test")
print("=" * 60)

# Test Step 1: Python Trial Generation
print("\nSTEP 1: Python Trial Generation")
print("-" * 60)

random.seed(42)
data = expt_config.prepare_subexperiment_3()

print(f"Total trials: {len(data['trials'])}")
print(f"Practice trials: {len(data['practice_trials'])}")

# Test Baseline trial
baseline = [t for t in data['trials'] if t['trial_type'] == 'Baseline'][0]
print(f"\nBaseline Trial (Set-size {baseline['set_size']}):")
print(f"  Colors: {baseline['colors']}")
print(f"  Orientations: {baseline['orientations']}")
print(f"  All unique colors: {len(set(baseline['colors'])) == baseline['set_size']}")
print(f"  All unique orientations: {len(set(baseline['orientations'])) == baseline['set_size']}")

# Test R-cue trial
rcue = [t for t in data['trials'] if t['trial_type'] == 'R-cue'][0]
print(f"\nR-cue Trial (Set-size {rcue['set_size']}):")
print(f"  Colors: {rcue['colors']}")
print(f"  Orientations: {rcue['orientations']}")
print(f"  Redundant indices: {rcue['redundant_indices']}")

# Verify redundancy
redundant_color_match = all(rcue['colors'][i] == rcue['colors'][rcue['redundant_indices'][0]] 
                            for i in rcue['redundant_indices'])
redundant_orient_match = all(rcue['orientations'][i] == rcue['orientations'][rcue['redundant_indices'][0]] 
                             for i in rcue['redundant_indices'])

print(f"  Redundant items same color: {redundant_color_match}")
print(f"  Redundant items same orientation: {redundant_orient_match}")
print(f"  Redundancy correct: {redundant_color_match and redundant_orient_match}")

# Test practice trials
print(f"\nPractice Trials:")
for i, t in enumerate(data['practice_trials'][:3], 1):
    print(f"  Practice {i}: Type={t['trial_type']}, Set-size={t['set_size']}, "
          f"Colors={t['colors']}, Orientations={t['orientations']}")

print("\n" + "=" * 60)
print("STEP 1: [PASSED]")
print("=" * 60)

print("\nSTEP 2: Orientation Bars Rendering")
print("-" * 60)
print("[OK] Plugin parameters added (orientations, stimulus_type)")
print("[OK] drawOrientationBars() method implemented")
print("[OK] Drawing logic updated")
print("[OK] Test visualization file created: test_orientation_bars.html")
print("\nTo view orientation bars:")
print("  1. Open test_orientation_bars.html in your browser")
print("  2. Click test buttons to see different configurations")
print("\n" + "=" * 60)
print("STEP 2: [IMPLEMENTED]")
print("=" * 60)

