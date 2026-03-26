"""
Combine sub1, sub2, sub3 CSV files and extract rows where trial_event is
either 'stimulus_wheel_display_event' or 'orientation_response_event'.
"""

import pandas as pd
from pathlib import Path

TARGET_EVENTS = {"stimulus_wheel_display_event", "orientation_response_event"}

# Load the 3 dataframes
sub1 = pd.read_csv("sub1.csv")
sub2 = pd.read_csv("sub2.csv")
sub3 = pd.read_csv("sub3.csv")

# Add source column to track which file each row came from (optional)
sub1["source"] = "sub1"
sub2["source"] = "sub2"
sub3["source"] = "sub3"

# Combine (concatenate) the dataframes
combined = pd.concat([sub1, sub2, sub3], ignore_index=True)

print(f"sub1: {len(sub1)} rows")
print(f"sub2: {len(sub2)} rows")
print(f"sub3: {len(sub3)} rows")
print(f"Combined: {len(combined)} rows")

# Filter to rows where trial_event is one of the target events
filtered = combined[combined["trial_event"].isin(TARGET_EVENTS)]

print(f"\nFiltered (trial_event in {TARGET_EVENTS}): {len(filtered)} rows")
print(filtered["trial_event"].value_counts())

# Save
output_path = Path("combined_sub1_sub2_sub3_filtered.csv")
filtered.to_csv(output_path, index=False)
print(f"\nSaved to: {output_path}")
