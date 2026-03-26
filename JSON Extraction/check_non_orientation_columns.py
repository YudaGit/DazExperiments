"""
Check target_angle_rotated, rotation, target_angle_norotation, response_error_deg
in rows that are NOT orientation_response_event (i.e. stimulus_wheel_display_event).
"""

import pandas as pd
import numpy as np
from pathlib import Path

def parse_val(s):
    """Parse values that may be '[123.45]', '[210]', or plain numbers."""
    if pd.isna(s) or s == "" or str(s).strip() == "":
        return np.nan
    s = str(s).strip().strip("[]")
    if not s:
        return np.nan
    try:
        return float(s.split(",")[0].strip())
    except (ValueError, IndexError):
        return np.nan

def wrap_diff(a, b):
    """Signed angular difference (a - b) in [-180, 180]."""
    d = (a - b) % 360
    if d > 180:
        d -= 360
    return d

csv_path = Path("CSVresults/stimulus_wheel_and_orientation_response_rows.csv")
df = pd.read_csv(csv_path)

# Keep only rows that are NOT orientation_response_event
sub = df[df["trial_event"] != "orientation_response_event"].copy()
print("=" * 70)
print("ROWS WHERE trial_event != 'orientation_response_event'")
print("=" * 70)
print(f"Total rows: {len(sub)}")
print(f"trial_event values: {sub['trial_event'].unique()}\n")

# Parse the 4 columns
cols = ["target_angle_rotated", "rotation", "target_angle_norotation", "response_error_deg"]
for c in cols:
    if c in sub.columns:
        sub[f"{c}_num"] = sub[c].apply(parse_val)

# Numeric versions
tar_rot = sub["target_angle_rotated_num"].values if "target_angle_rotated_num" in sub.columns else sub["target_angle_rotated"].values
rot = sub["rotation_num"].values if "rotation_num" in sub.columns else sub["rotation"].apply(parse_val).values
tar_norot = sub["target_angle_norotation_num"].values if "target_angle_norotation_num" in sub.columns else sub["target_angle_norotation"].apply(parse_val).values
err = sub["response_error_deg_num"].values if "response_error_deg_num" in sub.columns else sub["response_error_deg"].apply(parse_val).values

# Correlation matrix
num_cols = ["target_angle_rotated_num", "rotation_num", "target_angle_norotation_num", "response_error_deg_num"]
available = [c for c in num_cols if c in sub.columns]
if available:
    corr_df = sub[available].dropna()
    corr_df.columns = ["target_angle_rotated", "rotation", "target_angle_norotation", "response_error_deg"][:len(available)]
    print("CORRELATION MATRIX (rows with all 4 values):")
    print("-" * 50)
    valid = corr_df.dropna(how="any")
    print(f"Rows with all 4 non-null: {len(valid)}")
    if len(valid) > 0:
        print(valid.corr().round(3).to_string())
        print()

# Summary stats
print("SUMMARY STATISTICS:")
print("-" * 50)
for c in cols:
    if c in sub.columns:
        parsed = sub[c].apply(parse_val)
        n_valid = parsed.notna().sum()
        print(f"{c}: {n_valid} non-null, unique raw values sample: {sub[c].dropna().head(3).tolist()}")

# Check relationship: target_angle_rotated vs target_angle_norotation
# If rotation is applied: target_angle_rotated = target_angle_norotation + rotation (mod 360)?
print("\n" + "=" * 70)
print("RELATIONSHIP CHECK")
print("=" * 70)

mask = ~(np.isnan(tar_rot) | np.isnan(rot) | np.isnan(tar_norot) | np.isnan(err))
if mask.sum() > 0:
    t_rot = tar_rot[mask]
    r = rot[mask]
    t_norot = tar_norot[mask]
    e = err[mask]

    # target_angle_rotated = target_angle_norotation + rotation (mod 360)?
    expected_rotated = (t_norot + r) % 360
    match_rot = np.isclose(t_rot, expected_rotated, atol=1) | np.isclose(t_rot, expected_rotated - 360, atol=1)
    print(f"\ntarget_angle_rotated vs (target_angle_norotation + rotation) mod 360:")
    print(f"  Match within 1 deg: {match_rot.sum()}/{len(t_rot)}")

    # response_error_deg: typically signed diff between response and target
    # We don't have response orientation in these rows, but we can check if
    # target_angle_norotation and target_angle_rotated relate to rotation
    print(f"\n  Sample rows:")
    for i in range(min(8, len(t_rot))):
        print(f"    tar_rot={t_rot[i]:.1f}, tar_norot={t_norot[i]:.1f}, rotation={r[i]:.1f}, "
              f"err={e[i]:.2f} | (norot+rot)%360={expected_rotated[i]:.1f}")
else:
    print("No rows with all 4 values. Checking per-column non-null:")
    for c in cols:
        n = sub[c].notna().sum()
        n_nonempty = (sub[c].astype(str).str.strip() != "").sum()
        print(f"  {c}: {n} non-null, {n_nonempty} non-empty")
