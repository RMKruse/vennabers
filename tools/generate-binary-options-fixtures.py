"""Regenerate option fixtures using the pinned Python 1.5.4 model-backed merger.

Reuses five fixed and the first twenty seeded cross cases, with their exact
stored inputs. Normal R tests only read CSVs; Python is optional tooling.
"""
import csv
import hashlib
import importlib.metadata as metadata
import inspect
import json
from pathlib import Path
import platform
from types import SimpleNamespace
import warnings

import numpy as np
from venn_abers import VennAbersCV


OUTPUT = Path(__file__).resolve().parents[1] / "inst" / "extdata"
PIN = json.loads((OUTPUT / "cross-environment.json").read_text())
assert metadata.version("venn-abers") == "1.5.4"
assert hashlib.sha256(Path(inspect.getfile(VennAbersCV)).read_bytes()).hexdigest() == PIN["module_sha256"]


def two_columns(probability):
    p = np.asarray(probability, dtype=float)
    return np.column_stack((1 - p, p))


def reference(folds, precision, loss):
    # Same pinned-state table-predictor harness as generate-cross-fixtures.py.
    # A one-fold reduction exercises the actual upstream Brier merger for IVAP;
    # it does not assert a public manual Python Brier or one-fold R cross API.
    cv = VennAbersCV(None, False, n_splits=len(folds), cv_ensemble=True,
                     precision=precision)
    cv.clf_p_cal = [two_columns(p) for p, y, s in folds]
    cv.clf_y_cal = [np.asarray(y) for p, y, s in folds]
    cv.estimators = [None] + [SimpleNamespace(
        predict_proba=lambda X, s=s: two_columns(s)) for p, y, s in folds]
    result, endpoints = cv.predict_proba(np.zeros((len(folds[0][2]), 1)),
                                         loss=loss, p0_p1_output=True)
    assert np.isfinite(result).all() and np.isfinite(endpoints).all()
    assert ((result >= 0) & (result <= 1)).all()
    assert ((endpoints >= 0) & (endpoints <= 1)).all()
    return result[:, 1], endpoints


def number(value):
    return float.fromhex(value) if value.startswith("0x") else float(value)


cases = {}
for row in csv.DictReader((OUTPUT / "cross-calibration.csv").open()):
    name = row["case_id"]
    if name.startswith("random_") and int(name.removeprefix("random_")) > 20:
        continue
    p, y, s = cases.setdefault(name, {}).setdefault(row["fold"], ([], [], []))
    p.append(number(row["probability"]))
    y.append(int(row["truth"]))
for row in csv.DictReader((OUTPUT / "cross-predictions.csv").open()):
    if row["case_id"] in cases:
        cases[row["case_id"]][row["fold"]][2].append(number(row["probability"]))

fold_rows, combined_rows = [], []
with warnings.catch_warnings():
    warnings.filterwarnings("ignore", message="All-NaN slice encountered", category=RuntimeWarning)
    for precision in (None, 0, 2, -1):
        for name, by_fold in cases.items():
            folds = list(by_fold.values())
            log, endpoints = reference(folds, precision, "log")
            brier, brier_endpoints = reference(folds, precision, "brier")
            assert np.array_equal(endpoints, brier_endpoints)
            setting = "none" if precision is None else str(precision)
            combined_rows.extend((setting, name, row, a, b)
                                 for row, (a, b) in enumerate(zip(log, brier), 1))
            for k, (identity, fold) in enumerate(by_fold.items()):
                fold_log, fold_endpoints = reference([fold], precision, "log")
                fold_brier, _ = reference([fold], precision, "brier")
                assert np.array_equal(fold_endpoints[:, 0], endpoints[:, k])
                assert np.array_equal(fold_endpoints[:, 1], endpoints[:, k + len(folds)])
                fold_rows.extend((setting, name, identity, row + 1,
                                  bounds[0], bounds[1], fold_log[row], fold_brier[row])
                                 for row, bounds in enumerate(fold_endpoints))

for filename, header, rows in [
    ("binary-options-folds.csv", ["precision", "case_id", "fold", "row", "lower", "upper", "log", "brier"], fold_rows),
    ("binary-options-combined.csv", ["precision", "case_id", "row", "log", "brier"], combined_rows),
]:
    with (OUTPUT / filename).open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)

report = {
    "commit": PIN["commit"], "module_sha256": PIN["module_sha256"],
    "release_sdist_sha256": PIN["release_sdist_sha256"],
    "python": platform.python_version(), "platform": platform.platform(),
    "versions": {p: metadata.version(p) for p in PIN["versions"]},
    "cases": list(cases), "precision": [None, 0, 2, -1], "loss": ["log", "brier"],
    "rounding_boundaries": {str(p): float(np.round(p, 2)) for p in [.545, .575]},
    "input_sha256": {name: hashlib.sha256((OUTPUT / name).read_bytes()).hexdigest()
                     for name in ["cross-calibration.csv", "cross-predictions.csv"]},
    "fixture_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in sorted(OUTPUT.glob("binary-options-*.csv"))},
}
(OUTPUT / "binary-options-environment.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"Generated {len(cases)} cases, {len(fold_rows)} fold rows, {len(combined_rows)} combined rows.")
