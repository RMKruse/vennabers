"""Optional Python 1.5.4 fixture regeneration; package tests read stored CSVs.

Log OvO/OvR is checked against the manual implementation. Brier uses the
upstream binary model-backed merger with supplied probability tables, followed
by independent reciprocal coupling or class normalization (R API extensions).
OvR reuses the same stored calibration/input tables as OvO.
"""
import csv
import hashlib
import importlib.metadata as metadata
import inspect
import itertools
import json
from pathlib import Path
import platform
from types import SimpleNamespace
import warnings

import numpy as np
from venn_abers import VennAbersCV, VennAbersCalibrator
from venn_abers.venn_abers import predict_proba_prefitted_va


OUTPUT = Path(__file__).resolve().parents[1] / "inst" / "extdata"
PIN = json.loads((OUTPUT / "cross-environment.json").read_text())
assert metadata.version("venn-abers") == "1.5.4"
assert hashlib.sha256(Path(inspect.getfile(VennAbersCV)).read_bytes()).hexdigest() == PIN["module_sha256"]
rng = np.random.default_rng(20260907)
calibration, inputs, pairs_output, output = [], [], [], []
classes_output, ovr_output = [], []


def binary_reference(p, y, new, precision, loss):
    # A one-fold table harness reaches the upstream Inductive merger; this is
    # not a claim that the public R Cross API accepts one fold.
    model = VennAbersCV(None, False, n_splits=1, cv_ensemble=True, precision=precision)
    model.clf_p_cal = [p]
    model.clf_y_cal = [y]
    model.estimators = [None, SimpleNamespace(predict_proba=lambda X: new)]
    result, bounds = model.predict_proba(np.zeros((len(new), 1)), loss=loss, p0_p1_output=True)
    assert np.isfinite(result).all() and np.isfinite(bounds).all()
    return result, bounds


with warnings.catch_warnings():
    warnings.filterwarnings("ignore", message="All-NaN slice encountered", category=RuntimeWarning)
    for k in (2, 3, 4):
        for iteration in range(11):
            name = f"{'fixed' if iteration == 0 else 'random'}_{k}_{iteration:02}"
            if iteration == 0:
                y = np.tile(np.arange(k), 2)
                p = np.tile(np.eye(k) * 0.5 + np.ones((k, k)) * (0.5 / k), (2, 1))
                new = np.vstack((np.ones((1, k)) / k, p[:k]))
            else:
                y = np.concatenate((np.arange(k), rng.integers(k, size=30)))
                p = (rng.multinomial(128 - k, np.ones(k) / k, size=len(y)) + 1) / 128
                new = (rng.multinomial(128 - k, np.ones(k) / k, size=12) + 1) / 128
            # Save exact hexadecimal doubles, including recurring fixed values.
            for row, (truth, values) in enumerate(zip(y, p), 1):
                calibration.append((name, k, row, truth + 1, *(float(v).hex() for v in values), *([""] * (4 - k))))
            for row, values in enumerate(new, 1):
                inputs.append((name, k, row, *(float(v).hex() for v in values), *([""] * (4 - k))))
            # Match the R input contract before pair normalization.
            p = p / p.sum(axis=1, keepdims=True)
            new = new / new.sum(axis=1, keepdims=True)
            for precision in (None, 0, 2, -1):
                setting = "none" if precision is None else str(precision)
                manual = VennAbersCalibrator(precision=precision).predict_proba(p_cal=p, y_cal=y, p_test=new)
                # The facade routes two classes straight to the binary path;
                # use its multiclass component to preserve OvR with rounding.
                manual_ovr, _ = predict_proba_prefitted_va(p, y, new, precision, "one_vs_rest")
                if k > 2:
                    facade = VennAbersCalibrator(precision=precision).predict_proba(
                        p_cal=p, y_cal=y, p_test=new, va_type="one_vs_rest")
                    assert np.max(np.abs(manual_ovr - facade)) <= 1e-10
                for loss in ("log", "brier"):
                    results = {}
                    for a, b in itertools.combinations(range(k), 2):
                        rows = (y == a) | (y == b)
                        cal_pair = p[rows][:, [a, b]]
                        new_pair = new[:, [a, b]]
                        cal_pair = cal_pair / cal_pair.sum(axis=1, keepdims=True)
                        new_pair = new_pair / new_pair.sum(axis=1, keepdims=True)
                        point, bounds = binary_reference(cal_pair, y[rows] == b, new_pair, precision, loss)
                        results[a, b] = point
                        for row in range(len(new)):
                            pairs_output.append((name, setting, loss, a + 1, b + 1, row + 1,
                                                 *bounds[row], point[row, 1]))
                    coupled = np.column_stack([
                        1 / (np.sum([1 / values[:, 0 if c == a else 1]
                                     for (a, b), values in results.items() if c in (a, b)], axis=0) - (k - 2))
                        for c in range(k)])
                    coupled /= coupled.sum(axis=1, keepdims=True)
                    assert np.isfinite(coupled).all()
                    if loss == "log":
                        assert np.max(np.abs(coupled - manual)) <= 1e-10
                    for row, values in enumerate(coupled, 1):
                        output.append((name, setting, loss, row, *values, *([""] * (4 - k))))
                    points = []
                    for c in range(k):
                        point, bounds = binary_reference(
                            np.column_stack((1 - p[:, c], p[:, c])), y == c,
                            np.column_stack((1 - new[:, c], new[:, c])), precision, loss)
                        points.append(point[:, 1])
                        for row in range(len(new)):
                            classes_output.append((name, setting, loss, c + 1, row + 1,
                                                   *bounds[row], point[row, 1]))
                    normalized = np.column_stack(points)
                    normalized /= normalized.sum(axis=1, keepdims=True)
                    assert np.isfinite(normalized).all()
                    if loss == "log":
                        assert np.max(np.abs(normalized - manual_ovr)) <= 1e-10
                    for row, values in enumerate(normalized, 1):
                        ovr_output.append((name, setting, loss, row, *values, *([""] * (4 - k))))

for filename, header, rows in [
    ("ovo-calibration.csv", ["case_id", "classes", "row", "truth", "p1", "p2", "p3", "p4"], calibration),
    ("ovo-input.csv", ["case_id", "classes", "row", "p1", "p2", "p3", "p4"], inputs),
    ("ovo-pairs.csv", ["case_id", "precision", "loss", "non_event", "event", "row", "lower", "upper", "probability"], pairs_output),
    ("ovo-output.csv", ["case_id", "precision", "loss", "row", "p1", "p2", "p3", "p4"], output),
    ("ovr-classes.csv", ["case_id", "precision", "loss", "event", "row", "lower", "upper", "probability"], classes_output),
    ("ovr-output.csv", ["case_id", "precision", "loss", "row", "p1", "p2", "p3", "p4"], ovr_output),
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
    "seed": 20260907, "cases": 33, "classes": [2, 3, 4],
    "precision": [None, 0, 2, -1], "loss": ["log", "brier"],
    "scope": "Manual log OvO; binary reference components plus independent Brier coupling. R zero-pair and rounding differences tested separately.",
    "fixture_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in sorted(OUTPUT.glob("ovo-*.csv"))},
}
(OUTPUT / "ovo-environment.json").write_text(json.dumps(report, indent=2) + "\n")
report["scope"] = ("Manual log OvR (two classes via its multiclass component, three/four also via facade); "
                   "binary reference components plus independent Brier normalization. "
                   "Shared ovo-calibration/input tables; R rounding differences tested separately.")
report["fixture_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in [OUTPUT / "ovo-calibration.csv", OUTPUT / "ovo-input.csv",
                                      OUTPUT / "ovr-classes.csv", OUTPUT / "ovr-output.csv"]}
(OUTPUT / "ovr-environment.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"Generated 33 cases, {len(pairs_output)} pair rows, {len(classes_output)} class rows "
      f"and {len(output) + len(ovr_output)} output rows.")
