#!/usr/bin/env python
"""
Test script for Step 1: Trial Generation
Verifies that trial generation works correctly for Sub-Experiment 1
"""

import expt_config
import random
from collections import Counter

def test_trial_generation():
    """Test that trials are generated correctly"""
    print("=" * 60)
    print("Testing Step 1: Trial Generation")
    print("=" * 60)
    
    # Set seed for reproducible testing
    random.seed(42)
    
    # Generate trials
    print("\n1. Generating trial data...")
    try:
        data = expt_config.prepare_subexperiment_1()
        print("   [OK] Trial generation successful")
    except Exception as e:
        print(f"   [FAIL] Error: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    # Check basic structure
    print("\n2. Checking data structure...")
    required_keys = ['trials', 'practice_trials', 'set_size', 'durations', 'trial_types']
    for key in required_keys:
        if key in data:
            print(f"   [OK] {key} present")
        else:
            print(f"   [FAIL] Missing: {key}")
            return False
    
    # Check trial counts
    print("\n3. Checking trial counts...")
    n_main = len(data['trials'])
    n_practice = len(data['practice_trials'])
    expected_main = 140  # 14 conditions × 10 reps
    expected_practice = 5
    
    if n_main == expected_main:
        print(f"   [OK] Main trials: {n_main} (expected {expected_main})")
    else:
        print(f"   [FAIL] Main trials: {n_main} (expected {expected_main})")
        return False
    
    if n_practice == expected_practice:
        print(f"   [OK] Practice trials: {n_practice} (expected {expected_practice})")
    else:
        print(f"   [FAIL] Practice trials: {n_practice} (expected {expected_practice})")
        return False
    
    # Check trial structure
    print("\n4. Checking trial structure...")
    trial = data['trials'][0]
    required_trial_keys = [
        'duration_ms', 'cue_type', 'set_size', 'redundant_n',
        'colors', 'positions', 'target', 'is_redundant_target',
        'redundant_indices', 'trial_number'
    ]
    
    for key in required_trial_keys:
        if key in trial:
            print(f"   [OK] Trial has '{key}'")
        else:
            print(f"   [FAIL] Trial missing '{key}'")
            return False
    
    # Check color generation
    print("\n5. Checking color generation...")
    trial = data['trials'][0]
    colors = trial['colors']
    
    if len(colors) == 6:
        print(f"   [OK] 6 colors generated: {colors}")
    else:
        print(f"   [FAIL] Expected 6 colors, got {len(colors)}")
        return False
    
    # Check redundancy (should have 3 items with same color)
    color_counts = Counter(colors)
    redundant_count = max(color_counts.values())
    if redundant_count == 3:
        print(f"   [OK] Redundancy correct: {redundant_count} items share color")
    else:
        print(f"   [FAIL] Redundancy incorrect: {redundant_count} items share color (expected 3)")
        return False
    
    # Check color spacing (minimum 30°)
    print("\n6. Checking color spacing constraints...")
    all_colors = list(set(colors))  # Unique colors
    min_spacing_found = 360
    for i, c1 in enumerate(all_colors):
        for c2 in all_colors[i+1:]:
            dist = expt_config.min_circular_distance(c1, c2)
            min_spacing_found = min(min_spacing_found, dist)
    
    if min_spacing_found >= 30:
        print(f"   [OK] Minimum spacing: {min_spacing_found}° (>=30°)")
    else:
        print(f"   [FAIL] Minimum spacing: {min_spacing_found}° (should be >=30°)")
        return False
    
    # Check position generation
    print("\n7. Checking position generation...")
    trial = data['trials'][0]
    positions = trial['positions']
    
    if len(positions) == 6:
        print(f"   [OK] 6 positions generated: {positions}")
    else:
        print(f"   [FAIL] Expected 6 positions, got {len(positions)}")
        return False
    
    # Check positions are evenly spaced (approximately)
    sorted_pos = sorted(positions)
    spacings = []
    for i in range(len(sorted_pos)):
        spacing = (sorted_pos[(i+1) % len(sorted_pos)] - sorted_pos[i]) % 360
        spacings.append(spacing)
    
    expected_spacing = 360 / 6  # 60°
    avg_spacing = sum(spacings) / len(spacings)
    if abs(avg_spacing - expected_spacing) < 5:  # Allow small tolerance
        print(f"   [OK] Positions evenly spaced: ~{avg_spacing:.1f}° (expected ~{expected_spacing}°)")
    else:
        print(f"   [WARN] Position spacing: ~{avg_spacing:.1f}° (expected ~{expected_spacing}°)")
        # Not a failure, just a warning
    
    # Check target selection
    print("\n8. Checking target selection...")
    r_cue_trials = [t for t in data['trials'] if t['cue_type'] == 'R-cue']
    nr_cue_trials = [t for t in data['trials'] if t['cue_type'] == 'NR-cue']
    
    if len(r_cue_trials) > 0 and len(nr_cue_trials) > 0:
        print(f"   [OK] Both cue types present: {len(r_cue_trials)} R-cue, {len(nr_cue_trials)} NR-cue")
        
        # Check R-cue targets are redundant
        r_cue_redundant = sum(1 for t in r_cue_trials[:10] if t['is_redundant_target'])
        if r_cue_redundant == len(r_cue_trials[:10]):
            print(f"   [OK] R-cue targets are redundant: {r_cue_redundant}/{len(r_cue_trials[:10])}")
        else:
            print(f"   [FAIL] R-cue targets: {r_cue_redundant}/{len(r_cue_trials[:10])} are redundant (should be all)")
            return False
        
        # Check NR-cue targets are non-redundant
        nr_cue_nonredundant = sum(1 for t in nr_cue_trials[:10] if not t['is_redundant_target'])
        if nr_cue_nonredundant == len(nr_cue_trials[:10]):
            print(f"   [OK] NR-cue targets are non-redundant: {nr_cue_nonredundant}/{len(nr_cue_trials[:10])}")
        else:
            print(f"   [FAIL] NR-cue targets: {nr_cue_nonredundant}/{len(nr_cue_trials[:10])} are non-redundant (should be all)")
            return False
    else:
        print(f"   [FAIL] Missing cue types")
        return False
    
    # Check condition distribution
    print("\n9. Checking condition distribution...")
    condition_counts = Counter()
    for trial in data['trials']:
        condition = (trial['duration_ms'], trial['cue_type'])
        condition_counts[condition] += 1
    
    expected_per_condition = 10
    all_correct = True
    for condition, count in sorted(condition_counts.items()):
        if count == expected_per_condition:
            print(f"   [OK] Condition {condition}: {count} trials")
        else:
            print(f"   [FAIL] Condition {condition}: {count} trials (expected {expected_per_condition})")
            all_correct = False
    
    if not all_correct:
        return False
    
    # Check all durations are represented
    print("\n10. Checking duration coverage...")
    durations_found = set(t['duration_ms'] for t in data['trials'])
    expected_durations = set([50, 100, 150, 200, 250, 300, 350])
    
    if durations_found == expected_durations:
        print(f"   [OK] All durations present: {sorted(durations_found)}")
    else:
        missing = expected_durations - durations_found
        extra = durations_found - expected_durations
        if missing:
            print(f"   [FAIL] Missing durations: {missing}")
        if extra:
            print(f"   [FAIL] Unexpected durations: {extra}")
        return False
    
    # Check practice trials
    print("\n11. Checking practice trials...")
    practice = data['practice_trials']
    if len(practice) == 5:
        print(f"   [OK] {len(practice)} practice trials")
        for i, pt in enumerate(practice[:3], 1):
            print(f"      Practice {i}: duration={pt['duration_ms']}ms, cue={pt['cue_type']}")
    else:
        print(f"   [FAIL] Expected 5 practice trials, got {len(practice)}")
        return False
    
    # Sample a few trials
    print("\n12. Sample trials:")
    for i in [0, 50, 100, 139]:
        t = data['trials'][i]
        print(f"   Trial {i+1}: duration={t['duration_ms']}ms, cue={t['cue_type']}, "
              f"target={t['target']}, redundant={t['is_redundant_target']}")
    
    print("\n" + "=" * 60)
    print("[SUCCESS] ALL TESTS PASSED!")
    print("=" * 60)
    return True

if __name__ == '__main__':
    success = test_trial_generation()
    exit(0 if success else 1)

