"""
Pandas DataFrame Inspection & Plotting Walkthrough

Walkthrough for:
1. Checking total number of rows
2. Counting rows matching specific conditions (multiple columns)
3. Plotting mean, 95% CI error bars, and jitter distribution

Run: python3 inspect_dataframe_walkthrough.py
Requires: pip install pandas matplotlib
Optional: scipy for exact 95% CI (otherwise uses 1.96*SEM)
"""

import pandas as pd
import numpy as np
from pathlib import Path

# ---------------------------------------------------------------------------
# LOAD THE DATA
# ---------------------------------------------------------------------------
# Load the extracted stimulus_wheel_display rows into a DataFrame
csv_path = Path("CSVresults/stimulus_wheel_and_orientation_response_rows.csv")
df = pd.read_csv(csv_path)

# ---------------------------------------------------------------------------
# 1. CHECK TOTAL NUMBER OF ROWS
# ---------------------------------------------------------------------------
print("=" * 60)
print("1. CHECK TOTAL NUMBER OF ROWS")
print("=" * 60)

# Method A: len() - most common
n_rows = len(df)
print(f"Total rows: {n_rows}")

# Method B: .shape - returns (rows, columns)
print(f"DataFrame shape: {df.shape}  -> (rows={df.shape[0]}, cols={df.shape[1]})")

# Method C: .info() - overview including row count
print("\nQuick overview with .info():")
df.info()

# ---------------------------------------------------------------------------
# 2. COUNT ROWS MATCHING SPECIFIC CONDITIONS
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("2. COUNT ROWS MATCHING SPECIFIC CONDITIONS")
print("=" * 60)

# First, ensure numeric columns are actually numeric (CSV often loads as strings)
for col in ["rt", "response_RT", "response_error_deg", "correct", "trial_number"]:
    if col in df.columns:
        df[col] = pd.to_numeric(df[col], errors="coerce")

# Example: Single condition
n_r_cue = (df["cue_type"] == "R-cue").sum()
print(f"Rows where cue_type == 'R-cue': {n_r_cue}")

# Example: Multiple conditions with & (AND)
# Syntax: df[(condition1) & (condition2) & (condition3)]
# Use | for OR, ~ for NOT
mask = (df["cue_type"] == "R-cue") & (df["trial_number"] <= 10)
n_match = mask.sum()
print(f"Rows where cue_type=='R-cue' AND trial_number<=10: {n_match}")

# Example: Three or more conditions (use columns that have data)
# Note: 'correct' may be empty in this dataset; use cue_type, trial_number, etc.
mask = (
    (df["cue_type"] == "R-cue") &
    (df["trial_number"] >= 1) &
    (df["trial_number"] <= 10)
)
print(f"Rows where cue_type=='R-cue' AND trial_number 1-10: {mask.sum()}")

# Alternative: use .query() for readable conditions
n_query = df.query("cue_type == 'R-cue' and trial_number <= 5").shape[0]
print(f"Rows where cue_type=='R-cue' AND trial_number<=5 (via .query()): {n_query}")

# Get the actual filtered rows (not just count)
filtered = df[(df["cue_type"] == "R-cue") & (df["trial_number"] <= 5)]
print(f"\nFiltered DataFrame has {len(filtered)} rows. Preview:")
print(filtered[["cue_type", "trial_number", "response_RT", "response_error_deg"]].head())

# Count by category (useful for multiple values)
print("\nCount by cue_type:")
print(df["cue_type"].value_counts())

# ---------------------------------------------------------------------------
# 3. PLOT: MEAN, 95% CI ERROR BAR, AND JITTER DISTRIBUTION
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("3. PLOT: MEAN, 95% CI, AND JITTER")
print("=" * 60)

try:
    import matplotlib.pyplot as plt

    # Optional: scipy for exact t-distribution CI; fallback to 1.96*SEM for large n
    try:
        from scipy import stats
        def ci_95(vals):
            n = len(vals)
            return stats.t.ppf(0.975, n - 1) * stats.sem(vals) if n > 1 else 0
    except ImportError:
        def ci_95(vals):
            n = len(vals)
            return 1.96 * np.std(vals, ddof=1) / np.sqrt(n) if n > 1 else 0

    # Parse columns that store numbers as "[123.45]" strings
    def parse_list_str(val):
        if pd.isna(val) or val == "":
            return np.nan
        s = str(val).strip("[]")
        try:
            return float(s.split(",")[0]) if s else np.nan
        except (ValueError, IndexError):
            return np.nan

    # Build numeric column for plotting (response_error_deg or response_RT often stored as "[val]")
    df["response_error_num"] = df["response_error_deg"].apply(parse_list_str)
    df["response_RT_num"] = df["response_RT"].apply(parse_list_str)

    value_col = "response_error_num"  # or "response_RT_num", "time_elapsed", "trial_number"
    group_col = "cue_type"

    plot_df = df[[group_col, value_col]].dropna()

    groups = plot_df[group_col].dropna().unique()
    values_by_group = [plot_df.loc[plot_df[group_col] == g, value_col].values for g in groups]

    # Compute mean and 95% CI for each group
    # 95% CI = mean ± (t * SEM), where t from t-distribution (df = n-1)
    means = []
    ci_half_widths = []
    for vals in values_by_group:
        vals = np.array(vals, dtype=float)
        vals = vals[~np.isnan(vals)]
        if len(vals) == 0:
            means.append(0)
            ci_half_widths.append(0)
            continue
        means.append(np.mean(vals))
        ci_half_widths.append(ci_95(vals))

    # Create figure
    fig, ax = plt.subplots(figsize=(8, 6))

    x_pos = np.arange(len(groups))
    bar_width = 0.35

    # 1. Bar plot: mean with 95% CI error bars
    ax.bar(x_pos - bar_width / 2, means, bar_width, yerr=ci_half_widths,
           capsize=5, color="steelblue", alpha=0.7, label="Mean ± 95% CI",
           error_kw={"elinewidth": 2, "capthick": 2})

    # 2. Jitter: overlay individual points with random x-offset (so they don't overlap)
    np.random.seed(42)
    jitter_width = 0.25
    for i, vals in enumerate(values_by_group):
        jitter_x = np.random.uniform(-jitter_width, jitter_width, size=len(vals))
        ax.scatter(x_pos[i] + jitter_x, vals, alpha=0.4, s=30, c="orangered",
                   edgecolors="black", linewidths=0.5, zorder=5,
                   label="Individual (jitter)" if i == 0 else "")

    ax.set_xticks(x_pos)
    ax.set_xticklabels(groups)
    ax.set_ylabel(value_col)
    ax.set_title(f"{value_col} by {group_col}\nMean ± 95% CI with jittered individual points")

    # Deduplicate legend entries (scatter adds same label for each group)
    handles, labels = ax.get_legend_handles_labels()
    seen = {}
    uniq_h, uniq_l = [], []
    for h, l in zip(handles, labels):
        if l not in seen:
            seen[l] = h
    ax.legend(seen.values(), seen.keys(), loc="upper right")

    plt.tight_layout()
    output_path = Path("CSVresults/mean_ci_jitter_plot.png")
    plt.savefig(output_path, dpi=150)
    plt.close()
    print(f"Plot saved to: {output_path}")

except ImportError as e:
    print(f"Install matplotlib for plotting: pip install matplotlib")
    print(f"  ({e})")

print("\nDone!")
