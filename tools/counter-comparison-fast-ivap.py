"""Counter-comparison of fast-ivap (ptocca/VennABERS) with vennabers.

Runs fast-ivap, the binary IVAP by Paolo Toccaceli and the only Venn-Abers
implementation that does not derive from venn-abers, with both of its backends
and its scikit-learn calibrator, and as a control the main reference
venn-abers 1.5.4, on the inputs written by counter-comparison-inputs.R. Every
result is compared with the vennabers result for precision NULL at absolute
tolerance 1e-10 (inst/PARITY.md, "Counter-comparisons"). Not binding:
differences are explained, never fixed. Normally started by
counter-comparison.sh:

    python -I tools/counter-comparison-fast-ivap.py <data> <out>

The inputs are the 707 binary calibration sets of the stored fixtures with
their 105 Cross cases, and the 13 constructed edge sets. Writes to <out>:
- summary-fast-ivap.csv: one row per package, path, inputs, subset, procedure,
  loss and quantity with the number of compared values, the number not
  bitwise equal, the largest absolute difference and the count over the
  tolerance. Subsets split the new rows by the position of the new score
  (equal to a calibration score, below or above all of them, in between) and
  the calibration sets by their labels and ties;
- examples-fast-ivap.json: up to five differing rows per comparison;
- python-environment-fast-ivap.json: versions, the pinned commit and module
  SHA-256 hashes, including the compiled core from the wheel.
"""
import argparse
import csv
import hashlib
import json
import platform
import sys
import warnings
from collections import defaultdict
from importlib.metadata import version
from pathlib import Path

import numpy as np

import fast_ivap
from fast_ivap import IVAP, merge_brier, merge_log_minimax
from fast_ivap import _api as fast_api
from fast_ivap import _core as fast_core
from fast_ivap import _reference as fast_reference
from fast_ivap import sklearn as fast_sklearn
from venn_abers import venn_abers as rva

# fast-ivap is pinned to the commit of tag v1.1.0, released on PyPI as 1.1.0
# (inst/PARITY.md). The wheel's Python modules must be the files of that
# commit; its compiled core has no source hash and is compared on its own.
FAST_IVAP_COMMIT = "d3d19a647f39f3556fcb11bdd01ff428b8a6287c"
FAST_IVAP_MODULE_SHA256 = {
    "fast_ivap/_api.py": "3d1fb85989ddc4523709e6292ae5bf568a6c1c3868d51df3ba99580fad57c703",
    "fast_ivap/_reference.py": "6172a4dedf429862893484f0e179736adaa9e8d9900c721b3b40c32047eabdba",
    "fast_ivap/sklearn.py": "9075dda6e9bf36ed3506e82620316ffceb9c245d357a601dbff95b9ac8da444a",
}
# Module hash of the main reference, as in counter-comparison-mapie-ce.py.
REFERENCE_MODULE_SHA256 = "ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5"

parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument("data", type=Path, help="directory written by counter-comparison-inputs.R")
parser.add_argument("out", type=Path, help="directory for the summaries")
options = parser.parse_args()
DATA = options.data
OUT = options.out
OUT.mkdir(parents=True, exist_ok=True)
warnings.filterwarnings("ignore")


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


MODULES = {
    "fast_ivap/_api.py": fast_api.__file__,
    "fast_ivap/_reference.py": fast_reference.__file__,
    "fast_ivap/sklearn.py": fast_sklearn.__file__,
    "fast_ivap/" + Path(fast_core.__file__).name: fast_core.__file__,
    "venn_abers/venn_abers.py": rva.__file__,
}
HASHES = {name: sha256(path) for name, path in MODULES.items()}
for name, expected in FAST_IVAP_MODULE_SHA256.items():
    if HASHES[name] != expected:
        sys.exit(f"{name} is not the module of the pinned commit {FAST_IVAP_COMMIT}; install fast-ivap==1.1.0.")
if HASHES["venn_abers/venn_abers.py"] != REFERENCE_MODULE_SHA256:
    sys.exit("venn_abers/venn_abers.py is not the pinned main reference module; install venn-abers==1.5.4.")
REF = f"venn-abers {version('venn-abers')}"
FAST = f"fast-ivap {fast_ivap.__version__}"
TOL = 1e-10


def num(value):
    return float("nan") if value == "" else float.fromhex(value) if value.startswith(("0x", "-0x")) else float(value)


def read(name):
    with open(DATA / name) as handle:
        return list(csv.DictReader(handle))


def two(p):
    p = np.asarray(p, dtype=float)
    return np.column_stack((1 - p, p))


def load_sets(calibration, new):
    cal_rows = defaultdict(list)
    for r in read(calibration):
        cal_rows[r["key"]].append((int(r["row"]), num(r["truth"]), num(r["score"])))
    new_rows = defaultdict(list)
    for r in read(new):
        new_rows[r["key"]].append((int(r["row"]), num(r["score"])))
    sets = {}
    for key in cal_rows:
        c = sorted(cal_rows[key])
        n = sorted(new_rows[key])
        sets[key] = (np.array([t for _, t, _ in c]), np.array([s for _, _, s in c]), np.array([s for _, s in n]))
    return sets


def load_vennabers(name, precision=None):
    rows = defaultdict(dict)
    for r in read(name):
        if precision is None or r["precision"] == precision:
            rows[r.get("key") or r["case_id"]][int(r["row"])] = r
    return rows


def column(rows, field):
    return np.array([num(rows[i][field]) for i in sorted(rows)])


results = []  # rows of the summary
examples = defaultdict(list)


def record(package, path, inputs, procedure, loss, quantity, actual, expected, subsets, keys):
    """One summary row per non-empty subset; examples from all rows."""
    actual = np.asarray(actual, dtype=float).ravel()
    expected = np.asarray(expected, dtype=float).ravel()
    assert actual.shape == expected.shape, (package, path, quantity, actual.shape, expected.shape)
    both_nan = np.isnan(actual) & np.isnan(expected)
    diff = np.where(both_nan, 0.0, np.abs(actual - expected))
    diff = np.where(np.isnan(diff), np.inf, diff)
    unequal = ~both_nan & (actual != expected)
    for subset, mask in subsets.items():
        if not mask.any():
            continue
        results.append(dict(package=package, path=path, inputs=inputs, subset=subset, procedure=procedure, loss=loss,
                            quantity=quantity, n=int(mask.sum()), n_unequal=int(unequal[mask].sum()),
                            max_abs=float(diff[mask].max()), n_over_tol=int((diff[mask] > TOL).sum())))
    tag = (package, path, inputs, procedure, loss, quantity)
    for i in np.flatnonzero(diff > TOL)[:5]:
        examples[tag].append((keys[i], float(actual[i]), float(expected[i])))


def subsets_for(truth, score, new):
    """Masks over the new rows of one calibration set."""
    m = len(new)
    labels = set(np.unique(truth).tolist())
    tied = len(np.unique(score)) < len(score)
    return {
        "all": np.ones(m, bool),
        "new score equals a calibration score": np.isin(new, score),
        "new score below all calibration scores": new < score.min(),
        "new score above all calibration scores": new > score.max(),
        "new score between calibration scores": (new > score.min()) & (new < score.max()) & ~np.isin(new, score),
        "labels 0 and 1": np.full(m, labels == {0.0, 1.0}),
        "label 0 only": np.full(m, labels == {0.0}),
        "label 1 only": np.full(m, labels == {1.0}),
        "tied calibration scores": np.full(m, tied),
        "distinct calibration scores": np.full(m, not tied),
    }


def concat(parts):
    return {name: np.concatenate([p[name] for p in parts]) for name in parts[0]}


# ------------------------------------------------------------ binary Inductive
INPUTS = {
    "fixtures": (load_sets("binary-input-calibration.csv", "binary-input-new.csv"),
                 load_vennabers("vb-binary-inductive.csv", "none")),
    "edge sets": (load_sets("edge-input-calibration.csv", "edge-input-new.csv"),
                  load_vennabers("vb-binary-edge.csv")),
}
not_comparable = {}
for inputs, (sets, vb) in INPUTS.items():
    acc = defaultdict(list)
    masks = []
    two_label = []
    for key in sorted(sets):
        truth, score, new = sets[key]
        for backend in ["cpp", "python"]:
            ivap = IVAP(backend=backend).fit(score, truth)
            p0, p1 = ivap.predict_p0_p1(new)
            acc[f"{backend}_lower"].append(p0)
            acc[f"{backend}_upper"].append(p1)
            acc[f"{backend}_log"].append(ivap.predict_proba(new))
            acc[f"{backend}_brier"].append(merge_brier(p0, p1))
        ref = rva.VennAbers()
        ref.fit(two(score), truth, precision=None)
        ref_p, ref_b = ref.predict_proba(two(new))
        acc["ref_lower"].append(ref_b[:, 0])
        acc["ref_upper"].append(ref_b[:, 1])
        acc["ref_log"].append(ref_p[:, 1])
        rows = vb[key]
        for field in ["lower", "upper", "log", "brier", "class_log"]:
            acc["vb_" + field].append(column(rows, field))
        acc["keys"].append([f"{key}|row{i + 1}" for i in range(len(new))])
        masks.append(subsets_for(truth, score, new))
        # The scikit-learn calibrator needs both labels.
        both = len(np.unique(truth)) == 2
        two_label.append(np.full(len(new), both))
        if both:
            cal = fast_sklearn.VennAbersCalibrator().fit(score, truth.astype(int))
            p0, p1 = cal.predict_p0_p1(new)
            acc["sk_lower"].append(p0)
            acc["sk_upper"].append(p1)
            acc["sk_log"].append(cal.predict_proba(new)[:, 1])
            acc["sk_class"].append(cal.predict(new))
    not_comparable[inputs] = sum(not m.all() for m in two_label)
    cat = {k: (np.concatenate(v) if k != "keys" else sum(v, [])) for k, v in acc.items()}
    keys = cat["keys"]
    subsets = concat(masks)
    both = np.concatenate(two_label)
    sk_subsets = {name: mask[both] for name, mask in subsets.items()}
    sk_keys = [k for k, b in zip(keys, both) if b]
    for backend, path in [("cpp", "IVAP(backend='cpp')"), ("python", "IVAP(backend='python')")]:
        for q, loss in [("lower", "log"), ("upper", "log"), ("log", "log"), ("brier", "brier")]:
            record(FAST, path, inputs, "Inductive", loss, "point" if q in ("log", "brier") else q,
                   cat[f"{backend}_{q}"], cat["vb_" + q], subsets, keys)
    for q in ["lower", "upper", "log"]:
        record(FAST, "sklearn.VennAbersCalibrator", inputs, "Inductive", "log", "point" if q == "log" else q,
               cat["sk_" + q], cat["vb_" + q][both], sk_subsets, sk_keys)
    record(FAST, "sklearn.VennAbersCalibrator", inputs, "Inductive", "log", "class",
           cat["sk_class"], cat["vb_class_log"][both], sk_subsets, sk_keys)
    for q in ["lower", "upper", "log"]:
        record(REF, "VennAbers (core)", inputs, "Inductive", "log", "point" if q == "log" else q,
               cat["ref_" + q], cat["vb_" + q], subsets, keys)

# --------------------------------------------------------------- binary Cross
# Cross Venn-Abers as fast-ivap documents it: one IVAP per fold, merged with
# merge_log_minimax or merge_brier along the folds.
sets, _ = INPUTS["fixtures"]
vb_cross = load_vennabers("vb-binary-cross.csv", "none")
case_folds = defaultdict(list)
for key in sets:
    case, fold = key.split("|")
    if fold != "single":
        case_folds[case].append(fold)
acc = defaultdict(list)
masks = []
for case in sorted(case_folds):
    folds = sorted(case_folds[case], key=lambda f: int(f.split("_")[1]))
    for backend in ["cpp", "python"]:
        pairs = [IVAP(backend=backend).fit(sets[f"{case}|{f}"][1], sets[f"{case}|{f}"][0])
                 .predict_p0_p1(sets[f"{case}|{f}"][2]) for f in folds]
        p0 = np.vstack([p for p, _ in pairs])
        p1 = np.vstack([p for _, p in pairs])
        acc[f"{backend}_log"].append(merge_log_minimax(p0, p1, axis=0))
        acc[f"{backend}_brier"].append(merge_brier(p0, p1, axis=0))
    rows = vb_cross[case]
    acc["vb_log"].append(column(rows, "log"))
    acc["vb_brier"].append(column(rows, "brier"))
    acc["keys"].append([f"{case}|row{i}" for i in sorted(rows)])
    both = all(len(np.unique(sets[f"{case}|{f}"][0])) == 2 for f in folds)
    masks.append({"all": np.ones(len(rows), bool),
                  "labels 0 and 1 in every fold": np.full(len(rows), both),
                  "one label only in some fold": np.full(len(rows), not both)})
cat = {k: (np.concatenate(v) if k != "keys" else sum(v, [])) for k, v in acc.items()}
for backend in ["cpp", "python"]:
    for loss, merge in [("log", "merge_log_minimax"), ("brier", "merge_brier")]:
        record(FAST, f"IVAP(backend='{backend}') per fold, {merge}(axis=0)", "fixtures", "Cross", loss, "point",
               cat[f"{backend}_{loss}"], cat["vb_" + loss], concat(masks), cat["keys"])


def write_csv(name, rows):
    with open(OUT / name, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


write_csv("summary-fast-ivap.csv", results)
with open(OUT / "examples-fast-ivap.json", "w") as handle:
    json.dump({" / ".join(k): v for k, v in examples.items()}, handle, indent=1)
with open(OUT / "python-environment-fast-ivap.json", "w") as handle:
    json.dump({"python": sys.version, "platform": platform.platform(),
               "versions": {name: version(name) for name in ["fast-ivap", "venn-abers", "numpy", "scikit-learn"]},
               "fast_ivap_commit": FAST_IVAP_COMMIT, "module_sha256": HASHES}, handle, indent=1)

totals = [r for r in results if r["subset"] == "all"]
for package in [FAST, REF]:
    rows = [r for r in totals if r["package"] == package]
    print(f"{package}: {len(rows)} comparisons, largest difference {max(r['max_abs'] for r in rows):.3g}, "
          f"{sum(r['n_over_tol'] for r in rows)} values over {TOL:g}, "
          f"{sum(r['n_unequal'] for r in rows)} not bitwise equal")
for inputs, count in not_comparable.items():
    print(f"{inputs}: {count} calibration sets with one label only skipped by sklearn.VennAbersCalibrator")
