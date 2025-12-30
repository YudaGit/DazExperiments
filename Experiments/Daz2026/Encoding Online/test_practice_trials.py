#!/usr/bin/env python
"""
Test script to check practice trial cue type distribution
"""

import expt_config
import random
from collections import Counter

# Test with multiple seeds to see distribution
print("Testing practice trial cue type distribution:")
print("=" * 60)

for seed in [42, 123, 456, 789, 999]:
    random.seed(seed)
    data = expt_config.prepare_subexperiment_1()
    practice = data['practice_trials']
    
    cue_types = [t['cue_type'] for t in practice]
    cue_counts = Counter(cue_types)
    
    print(f"\nSeed {seed}:")
    print(f"  R-cue: {cue_counts.get('R-cue', 0)}")
    print(f"  NR-cue: {cue_counts.get('NR-cue', 0)}")
    print(f"  Cue types: {cue_types}")

print("\n" + "=" * 60)
print("Note: With random selection, it's possible to get all R-cue or all NR-cue")
print("by chance. To ensure balanced distribution, we should modify the code.")

