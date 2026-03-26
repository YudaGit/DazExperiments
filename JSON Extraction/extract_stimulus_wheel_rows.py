"""
Extract rows with 'stimulus_wheel_display_event' or 'orientation_response_event' from CSV results.
A learning-oriented script for Python data processing and plotting.

Uses pandas + matplotlib. Install with: pip install pandas matplotlib
"""

import csv
from pathlib import Path

# ---------------------------------------------------------------------------
# 1. LOADING DATA (standard library version - no pandas needed)
# ---------------------------------------------------------------------------
csv_path = Path("CSVresults/CSVresults_2026-03-10_.csv")
output_path = Path("CSVresults/prolific_data_2026-03-10.csv")

# Events to extract (either one matches)
TARGET_EVENTS = {"stimulus_wheel_display_event", "orientation_response_event"}

# Find column index for trial_event
with open(csv_path, newline="", encoding="utf-8") as f:
    reader = csv.reader(f)
    header = next(reader)
    trial_event_col = header.index("trial_event") if "trial_event" in header else None

if trial_event_col is None:
    raise ValueError("Column 'trial_event' not found in CSV")

# Read and filter rows
filtered_rows = []
total_rows = 0
with open(csv_path, newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        total_rows += 1
        if row.get("trial_event") in TARGET_EVENTS:
            filtered_rows.append(row)

print(f"Loaded {total_rows} total rows from CSV")
print(f"Found {len(filtered_rows)} rows with trial_event in {TARGET_EVENTS}")

# ---------------------------------------------------------------------------
# 2. SAVING THE FILTERED DATA
# ---------------------------------------------------------------------------
if filtered_rows:
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=filtered_rows[0].keys())
        writer.writeheader()
        writer.writerows(filtered_rows)
    print(f"Saved filtered rows to: {output_path}\n")
else:
    print("No matching rows to save.\n")

# ---------------------------------------------------------------------------
# 3. PANDAS VERSION (optional - for statistics and plotting)
# ---------------------------------------------------------------------------
