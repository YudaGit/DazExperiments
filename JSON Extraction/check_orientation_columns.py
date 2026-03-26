"""
Check relationship between 4 columns when they all have values:
  response_orientation_360, target_orientation, response_orientation, response_error_deg
"""

import pandas as pd
import numpy as np
from pathlib import Path

def parse_val(s):
    """Parse values that may be '[123.45]' or plain numbers."""
    if pd.isna(s) or s == "" or str(s).strip() == "":
        return np.nan
    s = str(s).strip().strip("[]")
    if not s:
        return np.nan
    try:
        return float(s.split(",")[0].strip())
    except (ValueError, IndexError):
        return np.nan

def wrap_angle_diff(a, b):
    """Signed angular difference (a - b) in [-180, 180] degrees."""
    d = (a - b) % 360
    if d > 180:
        d -= 360
    return d

csv_path = Path("CSVresults/stimulus_wheel_and_orientation_response_rows.csv")
df = pd.read_csv(csv_path)

# Parse the 4 columns
for col in ["response_orientation_360", "target_orientation", "response_orientation", "response_error_deg"]:
    if col in df.columns:
        df[f"{col}_num"] = df[col].apply(parse_val)

# Filter to rows where ALL 4 have valid numeric values
cols = ["response_orientation_360_num", "target_orientation_num", "response_orientation_num", "response_error_deg_num"]
available = [c for c in cols if c in df.columns]

if len(available) < 4:
    print("Some columns missing. Available:", available)
else:
    sub = df[available + ["trial_event"]].dropna()
    sub.columns = ["response_orientation_360", "target_orientation", "response_orientation", "response_error_deg", "trial_event"]

    print("=" * 70)
    print("ROWS WHERE ALL 4 COLUMNS HAVE VALUES")
    print("=" * 70)
    print(f"Total such rows: {len(sub)}")
    print(f"By trial_event:\n{sub['trial_event'].value_counts()}\n")

    if len(sub) == 0:
        print("No rows with all 4 values. Checking non-null counts per column:")
        for c in ["response_orientation_360", "target_orientation", "response_orientation", "response_error_deg"]:
            n = df[c].notna() & (df[c].astype(str).str.strip() != "") & (df[c].astype(str) != "nan")
            print(f"  {c}: {n.sum()} non-empty")
    else:
        # Check relationships
        resp_360 = sub["response_orientation_360"].values
        target = sub["target_orientation"].values
        resp = sub["response_orientation"].values
        err = sub["response_error_deg"].values

        # response_error_deg = response - target (signed, wrapped to [-180,180])
        err_from_resp_target = np.array([wrap_angle_diff(r, t) for r, t in zip(resp_360, target)])
        err_from_resp_plain = np.array([wrap_angle_diff(r, t) for r, t in zip(resp, target)])

        # Are response_orientation_360 and response_orientation the same?
        same_360_vs_plain = np.isclose(resp_360, resp) | (np.abs(resp_360 - resp) < 0.01)
        print("response_orientation_360 vs response_orientation:")
        print(f"  Same (or very close): {same_360_vs_plain.sum()}/{len(sub)}")
        if not same_360_vs_plain.all():
            diff = resp_360 - resp
            print(f"  Max difference: {np.abs(diff).max():.4f} deg")
            print(f"  Sample differing rows:")
            idx = np.where(~same_360_vs_plain)[0][:3]
            for i in idx:
                print(f"    resp_360={resp_360[i]:.2f}, resp={resp[i]:.2f} -> diff={diff[i]:.2f}")

        # Does response_error_deg = response - target?
        match_360 = np.isclose(err, err_from_resp_target, atol=1) | (np.abs(err - err_from_resp_target) < 1)
        match_plain = np.isclose(err, err_from_resp_plain, atol=1) | (np.abs(err - err_from_resp_plain) < 1)
        print("\nresponse_error_deg vs (response - target):")
        print(f"  Using response_orientation_360: {match_360.sum()}/{len(sub)} match (within 1 deg)")
        print(f"  Using response_orientation:     {match_plain.sum()}/{len(sub)} match (within 1 deg)")

        # Summary stats
        print("\nSummary statistics:")
        print(sub[["response_orientation_360", "target_orientation", "response_orientation", "response_error_deg"]].describe().round(2).to_string())

        # Sample rows
        print("\nSample rows (first 5):")
        pd.set_option("display.width", 200)
        pd.set_option("display.max_columns", 10)
        print(sub[["response_orientation_360", "target_orientation", "response_orientation", "response_error_deg", "trial_event"]].head().to_string())
