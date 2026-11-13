"""Refresh the explicit canonical index and saved-fit comparison, without fitting.

Run from any directory: python3 /path/to/project/tools/refresh_project_index.py
Requires scipy, h5py, numpy, matplotlib. Existing model outputs are read only.
The mapping below is curated: never infer canonical status from timestamps.
"""
from pathlib import Path
import csv
import hashlib
import json
import numpy as np
import h5py
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parents[1]
ACTIVE = ROOT / "POPvJPvCauchy"
ROUTES = [
    ("H0", "memory_cellwise_decision_shared", "Shared decision baseline", "H0_kappaCell_sharedDecision", "H0_kappaCell_sharedDecision_20260915_130513.mat", 14, "Original aggregate; HC objective includes a small soft-bound penalty."),
    ("H1_eta", "memory_cellwise_eta_cellwise", "Cellwise radial drift variability", "H1_eta", "H1_eta_20260914_165156.mat", 22, "Diagnostic release of eta."),
    ("H1_vnorm", "memory_cellwise_drift_cellwise", "Cellwise drift strength", "H1_vnorm", "H1_vnorm_20260914_174346.mat", 22, "Diagnostic release of drift strength."),
    ("H1_ter", "memory_cellwise_timing_cellwise", "Cellwise nondecision timing", "H1_ter", "H1_ter_20260914_193853.mat", 22, "AQ replaced by H3-seeded refit: NLL 2892.8773; old filename retained. YL nesting miss 0.5856 remains."),
    ("H_satDecision", "memory_cellwise_decision_saturated", "Saturated decision diagnostic", "H_satDecision", "H_satDecision_20260922_114249.mat", 38, "Diagnostic ceiling; not a final model. Predates corrected AQ H1_ter."),
    ("H2_factorial", "memory_cellwise_drift_set_eta_colour_timing_cue", "Factorized drift variability and timing", "H2_factorial", "H2_factorial_20260922_143302.mat", 20, "Set drift; colour eta; Base/R/NR timing."),
    ("H2_tsensitive", "memory_cellwise_drift_set_timing_colour_cue", "Set-size drift with colour/cue timing", "H2_tsensitive", "H2_tsensitive_20260929_AQH3warm_merged.mat", 20, "Merged aggregate replaces AQ only with H3-seeded H2 refit; AQ NLL 2895.5953."),
    ("H3_1v_tcolor", "memory_cellwise_drift_shared_timing_colour_cue", "Shared drift with colour/cue timing", "H3_1v_tcolor", "H3_1v_tcolor_20260929_170830.mat", 18, "Renamed from H3_1v without changing fitted values."),
    ("H3_1t_vset", "memory_cellwise_drift_set_cue_timing_shared", "Set-size/cue drift with shared timing", "H3_1t_vset", "H3_1t_vset_20260929_195215.mat", 18, "Renamed from H3_1t without changing fitted values."),
    ("H3_1t_vcolor", "memory_cellwise_drift_colour_cue_timing_shared", "Colour/cue drift with shared timing", "H3_1t_vcolor", "H3_1t_vcolor_20260930_095656.mat", 18, "ES BIC leader; PG 23 of 24 successful starts."),
    ("H3_1v_tset", "memory_cellwise_drift_shared_timing_set_cue", "Shared drift with set-size/cue timing", "H3_1v_tset", "H3_1v_tset_20260930_105146.mat", 18, "PG effectively tied with colour/cue timing."),
]


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_csv(path, rows):
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def scalar_results(path):
    keys = ["bestNLL", "bestObj", "ll2", "qaic", "qbic"]
    try:
        data = loadmat(path, simplify_cells=True, variable_names=["allResults"])["allResults"]
        return {uid: {k: float(data[uid + "_cauchy"][k]) for k in keys}
                for uid in ["AQ", "ES", "HC", "PG", "YL"]}
    except NotImplementedError:
        with h5py.File(path) as f:
            return {uid: {k: float(f[f"allResults/{uid}_cauchy/{k}"][()].item()) for k in keys}
                    for uid in ["AQ", "ES", "HC", "PG", "YL"]}


def main():
    data_file = ACTIVE / "Re2024_POPvJPvCauchy_prepared.mat"
    data_hash = digest(data_file)
    manifest, comparison = [], []
    for alias, route_id, label, folder, filename, n_free, correction in ROUTES:
        path = ACTIVE / "TestFits" / folder / filename
        summary = path.parent / (folder + "_summary.csv")
        saved = scalar_results(path)
        rows = list(csv.DictReader(summary.open()))
        for row in rows:
            uid = row["uid"]
            r = saved[uid]
            for field, key in [("NLL", "bestNLL"), ("minus2LL", "ll2"), ("AIC", "qaic"), ("BIC", "qbic")]:
                if abs(float(row[field]) - r[key]) > 1e-7:
                    raise ValueError(f"CSV/MAT mismatch: {alias} {uid} {field}")
            comparison.append(dict(participant=uid, alias=alias, route_id=route_id, label=label,
                                   n_free=n_free, saved_objective=r["bestObj"],
                                   saved_abs_nll=r["ll2"] / 2,
                                   objective_penalty=r["bestObj"] - r["ll2"] / 2,
                                   AIC=r["qaic"], BIC=r["qbic"],
                                   n_success=int(row["nSuccess"]),
                                   boundary_parameters=row["boundaryParams"],
                                   fit_file=str(path.relative_to(ACTIVE))))
        if alias.startswith('H3_'):
            date = '20260930' if alias in ['H3_1t_vcolor', 'H3_1v_tset'] else '20260929'
            layout = date + '_' + alias.lower() + '_vnorm_kappa_eta_a_ter_st'
        elif alias.startswith('H2_'):
            layout = '20260922_h2factor_vnorm_kappa_eta_a_ter_st'
        elif alias == 'H_satDecision':
            layout = '20260922_satDecision_vnorm_kappa_eta_a_ter_st'
        else:
            layout = '20260915_vnorm_kappa_eta_a_ter_st'
        manifest.append(dict(alias=alias, route_id=route_id, label=label, canonical=1,
                             n_free=n_free, participants="AQ|ES|HC|PG|YL",
                             parameter_layout_version=layout,
                             fit_file=str(path.relative_to(ACTIVE)), fit_sha256=digest(path),
                             summary_file=str(summary.relative_to(ACTIVE)), summary_sha256=digest(summary),
                             data_file=data_file.name, data_sha256=data_hash,
                             data_version="prepared_snapshot_20261113",
                             validation="CSV_MAT_scalars_checked; forward_numerics_pending",
                             source_provenance="current_snapshot_only; fit_time_hashes_unknown",
                             source_snapshot="../docs/source_snapshot_20261113.json",
                             correction=correction))
    best = {uid: min(r["BIC"] for r in comparison if r["participant"] == uid)
            for uid in ["AQ", "ES", "HC", "PG", "YL"]}
    for row in comparison:
        row["delta_BIC_within_participant"] = row["BIC"] - best[row["participant"]]
    write_csv(ACTIVE / "results_manifest.csv", manifest)
    write_csv(ROOT / "docs/current_cauchy_comparison.csv", comparison)
    sources = {str(p.relative_to(ROOT)): digest(p) for p in sorted(ACTIVE.iterdir())
               if p.suffix in [".m", ".c", ".mexmaca64"]}
    (ROOT / "docs/source_snapshot_20261113.json").write_text(json.dumps(dict(
        status="Current source snapshot; does not prove source/MEX agreement or fit-time provenance",
        files=sources), indent=2) + "\n")
    plot_comparison(comparison)
    print(f"Indexed {len(manifest)} canonical routes; verified {len(comparison)} CSV/MAT records.")


def plot_comparison(rows):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    aliases = ["H3_1t_vset", "H3_1t_vcolor", "H3_1v_tcolor", "H3_1v_tset", "H2_tsensitive"]
    labels = ["Drift: set + cue; timing: shared", "Drift: colour + cue; timing: shared",
              "Drift: shared; timing: colour + cue", "Drift: shared; timing: set + cue",
              "Drift: set; timing: colour + cue (H2)"]
    participants = ["AQ", "ES", "HC", "PG", "YL"]
    values = np.array([[next(r["delta_BIC_within_participant"] for r in rows
                             if r["participant"] == uid and r["alias"] == alias)
                        for uid in participants] for alias in aliases])
    fig, ax = plt.subplots(figsize=(10.8, 4.8), layout="constrained")
    im = ax.imshow(values, cmap="Blues", aspect="auto", vmin=0, vmax=100)
    ax.set_xticks(range(5), participants)
    ax.set_yticks(range(5), labels)
    for i in range(5):
        for j in range(5):
            ax.text(j, i, f"{values[i,j]:.2f}", ha="center", va="center",
                    color="white" if values[i,j] > 60 else "black")
    ax.set_title("Recorded Cauchy comparison: H3 and H2 timing candidate\n"
                 "ΔBIC from each participant's best of all 11 saved routes; lower is better", fontsize=11)
    fig.colorbar(im, ax=ax, label="ΔBIC (colour scale capped at 100)")
    fig.supxlabel("Provisional saved-fit evidence • numerical audit pending", fontsize=9)
    output = ACTIVE / "Figures/ManuscriptCandidates"
    fig.savefig(output / "H3_H2_recorded_BIC.png", dpi=180)
    fig.savefig(output / "H3_H2_recorded_BIC.pdf")
    plt.close(fig)
    write_csv(output / "H3_H2_recorded_BIC_sources.csv", [
        dict(participant=r["participant"], alias=r["alias"], BIC=r["BIC"],
             delta_BIC=r["delta_BIC_within_participant"], fit_file=r["fit_file"])
        for r in rows if r["alias"] in aliases])


if __name__ == "__main__":
    main()
