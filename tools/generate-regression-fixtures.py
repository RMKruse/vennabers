"""Generate IVAR fixtures from the pinned 1.5.4 source (Python only at generation).

PYTHONPATH=/path/to/pinned-checkout/src python tools/generate-regression-fixtures.py
The identity estimator supplies exact arrays; no wrapper/manual API is claimed.
"""
import csv
import hashlib
import importlib.metadata as metadata
import inspect
import json
import math
from pathlib import Path
import platform
import subprocess
import warnings

import numpy as np
from sklearn.base import BaseEstimator, RegressorMixin
from venn_abers import VennAbers, VennAbersCV


OUTPUT = Path(__file__).resolve().parents[1] / "inst" / "extdata"
COMMIT = "0e7b4bc575ce230134576ba1c76688d46bf99ac7"
MODULE_SHA256 = "ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5"
module = Path(inspect.getfile(VennAbersCV)).resolve()
assert hashlib.sha256(module.read_bytes()).hexdigest() == MODULE_SHA256
assert subprocess.check_output(["git", "-C", str(module.parent), "rev-parse", "HEAD"], text=True).strip() == COMMIT
assert "version='1.5.4'" in (module.parent.parent / "setup.py").read_text()


class SuppliedPrediction(RegressorMixin, BaseEstimator):
    def fit(self, X, y):
        return self

    def predict(self, X):
        return X[:, 0]


def reference(y, p, new, m, epsilon):
    cv = VennAbersCV(SuppliedPrediction(), inductive=True, cal_size=len(y),
                     shuffle=False, stratify=None, setting="regression",
                     m_parameter=m, epsilon=epsilon)
    # With shuffle=False, the last k rows are precisely the calibration set.
    cv.fit(np.r_[[-2., -1., 0.], p].reshape(-1, 1), np.r_[[0., 0., 0.], y])
    assert np.array_equal(cv.clf_p_cal[0], p)
    lower_y, upper_y = cv.clf_y_cal_lower[0], cv.clf_y_cal_upper[0]
    a, b = cv.y_stars_lower_[0], cv.y_stars_upper_[0]
    with warnings.catch_warnings():
        # The reference evaluates undefined intermediate slopes and zero-weight
        # point divisions. Preserve final defects below; never use their NaNs.
        warnings.simplefilter("ignore", RuntimeWarning)
        direct_point, direct_bounds = cv.predict_interval(new.reshape(-1, 1))
        reflected = VennAbers(setting="regression")
        reflected.fit(p_cal=-p, y_cal=-lower_y)
        _, reflected_bounds = reflected.predict_proba(p_test=-new)
    lower = -reflected_bounds[:, 1]
    upper = direct_bounds[0][:, 1]
    left, right = lower - a, b - upper
    point = (lower + upper) / 2
    positive = left + right > 0
    point[positive] = (left[positive] * lower[positive] + right[positive] * upper[positive]) / (left[positive] + right[positive])
    return cv, lower_y, upper_y, np.c_[point, lower, upper], np.c_[direct_point[0], direct_bounds[0]]


seed = 20260907
rng = np.random.default_rng(seed)
cases = [
    ("minimum", [0, 1, 2], [-2, 0, 3], [-3, -2, -1, 0, 2, 3, 4], 1, None),
    ("all_tied", [-10, 0, 2, 6, 20], [0] * 5, [-1, 0, 1], 1, None),
    ("maximum_m", [-10, 0, 2, 6, 20], [-2, -2, 0, 1, 1], [-3, -2, -1, 0, 1, 2], 2, None),
    ("zero_weights", [0, 0, 2, 2], [1, 2, 3, 4], [0, 1, 2.5, 4, 5], 1, None),
    ("constant", [7] * 5, [-2, -2, 0, 1, 3], [-3, -2, 0, 2, 4], 1, None),
]
for i in range(24):
    k = int(rng.integers(3, 46))
    y = rng.normal(0, 3, k)
    p = rng.integers(-4, 5, k).astype(float) if i % 2 else rng.normal(0, 2, k)
    new = np.r_[p[:5], rng.normal(0, 3, 7), min(p) - 1, max(p) + 1]
    m = int(rng.integers(1, (k - 1) // 2 + 1))
    epsilon = (2 * m + .25) / (k + 1) if i % 3 == 0 else None
    cases.append((f"random_{i:02d}", y, p, new, m, epsilon))

calibration, predictions, options = [], [], []
for name, y, p, new, m, epsilon in cases:
    for unit, shift, suffix in [(1., 0., "ordinary"), (1e-12, 0., "small"),
                                (1e120, 0., "large"), (1., 1e5, "shifted")]:
        case = f"{name}_{suffix}"
        y, p, new = np.asarray(y), np.asarray(p, dtype=float), np.asarray(new, dtype=float)
        cv, ly, uy, expected, direct = reference(y * unit + shift, p, new, m, epsilon)
        # s is declared by the unit transformation, before any comparison.
        valid = np.all(np.isfinite(direct) & (abs(direct - expected) <= 1e-10 * unit + 1e-10 * abs(expected)), axis=1)
        options.append([case, "epsilon" if epsilon is not None else "m", epsilon if epsilon is not None else m,
                        cv.m_parameter, 2 * cv.m_parameter / (len(y) + 1), unit, shift, cv.y_stars_lower_[0], cv.y_stars_upper_[0]])
        for row, values in enumerate(zip(y * unit + shift, p, ly, uy), 1):
            calibration.append([case, row, *values])
        for row, (value, wanted, raw, ok) in enumerate(zip(new, expected, direct, valid), 1):
            predictions.append([case, row, value, *wanted, *raw, int(ok)])


def write(name, header, rows):
    with (OUTPUT / name).open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(header.split())
        writer.writerows([[float(x).hex() if isinstance(x, (float, np.floating)) and np.isfinite(x) else x for x in row] for row in rows])


write("regression-options.csv", "case_id parameter requested m epsilon scale shift a b", options)
write("regression-calibration.csv", "case_id row truth prediction lower_truth upper_truth", calibration)
write("regression-predictions.csv", "case_id row input prediction lower upper direct_prediction direct_lower direct_upper direct_valid", predictions)
environment = {
    "commit": COMMIT, "source_version": "1.5.4", "module_sha256": MODULE_SHA256,
    "seed": seed, "python": platform.python_version(), "platform": platform.platform(),
    "versions": {p: metadata.version(p) for p in ("numpy", "scipy", "scikit-learn", "pandas")},
    "options": {"setting": "regression", "precision": None, "shuffle": False, "stratify": None},
    "cases": len(options), "rows": len(predictions),
    "direct_valid_rows": sum(row[-1] for row in predictions),
    "direct_defect_rows": sum(not row[-1] for row in predictions),
    "lower_reference": "Negated regression upper endpoint on reflected scores and negated lower-moderated targets",
    "point_reference": "Formula 6 on valid component endpoints; direct VennAbersCV merger also retained wherever valid",
    "fixture_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUTPUT.glob("regression-*.csv"))},
}
(OUTPUT / "regression-environment.json").write_text(json.dumps(environment, indent=2) + "\n")
print(json.dumps({key: environment[key] for key in ("cases", "rows", "direct_valid_rows", "direct_defect_rows")}))

# CVAR is an R extension. Use only the IVAR reference above, followed by
# independent equal-weight arithmetic; do not invent a Python CVAR wrapper.
cross_seed = 20260908
rng = np.random.default_rng(cross_seed)
cross_cases = [
    ("unequal_tied", [([-10, 0, 2, 6, 20], [0] * 5), ([10] * 3, [1, 2, 3])], "default", None),
    ("zero_and_small_weights", [([0, 0, 2, 2], [1, 2, 3, 4]), ([0, 0, 0, 4, 10], [0] * 5)], "m", 1),
    ("epsilon_unequal", [([-10, 0, 2, 6, 20], [-2, -2, 0, 1, 1]),
                         ([-8, -2, 0, 1, 3, 8, 10, 30], [-3, -2, -2, 0, 0, 1, 2, 3])], "epsilon", .5),
    ("explicit_two", [([-10, 0, 2, 6, 20], [0] * 5),
                      ([-4, -2, 0, 1, 3, 8, 10], [-2, -2, 0, 0, 1, 2, 3])], "m", 2),
]
for i in range(16):
    components = []
    for k in rng.integers(5, 26, 2 + i % 3):
        y = rng.normal(0, 3, k)
        p = rng.integers(-4, 5, k).astype(float) if i % 2 else rng.normal(0, 2, k)
        components.append((y, p))
    parameter, requested = [("default", None), ("m", 2), ("epsilon", .5)][i % 3]
    cross_cases.append((f"random_{i:02d}", components, parameter, requested))

cross_calibration, cross_predictions, cross_options, cross_aggregate = [], [], [], []
for name, components, parameter, requested in cross_cases:
    for unit, shift, suffix in [(1., 0., "ordinary"), (1e-12, 0., "small"),
                                (1e120, 0., "large"), (1., 1e5, "shifted")]:
        case = f"{name}_{suffix}"
        cal_rows, outputs = [], []
        for index, (y, p) in enumerate(components):
            fold = ["B / held out", "A:fold", "17", "last"][index]
            y, p = np.asarray(y) * unit + shift, np.asarray(p, dtype=float)
            # Include exact ties, exterior scores, and the zero-weight gap.
            new = np.array([min(p) - 1, p[0], 0, 2.5, p[-1], max(p) + 1, -1])
            epsilon = requested if parameter == "epsilon" else None
            m = math.floor(epsilon * (len(y) + 1) / 2) if epsilon is not None else requested or 1
            cv, ly, uy, expected, direct = reference(y, p, new, m, epsilon)
            assert cv.m_parameter == m
            cross_options.append([case, fold, parameter, requested, len(y), m,
                                  2 * m / (len(y) + 1), unit, shift,
                                  cv.y_stars_lower_[0], cv.y_stars_upper_[0]])
            cal_rows.extend([[case, fold, *values] for values in zip(y, p, ly, uy)])
            valid = np.all(np.isfinite(direct) & (abs(direct - expected) <= 1e-10 * unit + 1e-10 * abs(expected)), axis=1)
            for row, (value, wanted, raw, ok) in enumerate(zip(new, expected, direct, valid), 1):
                cross_predictions.append([case, fold, row, value, *wanted, *raw, int(ok)])
            outputs.append(expected)
        # Store non-contiguous fold membership and explicit positional row IDs.
        for row, index in enumerate(rng.permutation(len(cal_rows)), 1):
            cross_calibration.append([*cal_rows[index][:2], row, *cal_rows[index][2:]])
        for row in range(7):
            cross_aggregate.append([case, row + 1, *[
                math.fsum(output[row, column] for output in outputs) / len(outputs)
                for column in range(3)]])

write("cross-regression-options.csv", "case_id fold parameter requested observations m epsilon scale shift a b", cross_options)
write("cross-regression-calibration.csv", "case_id fold row truth prediction lower_truth upper_truth", cross_calibration)
write("cross-regression-predictions.csv", "case_id fold row input prediction lower upper direct_prediction direct_lower direct_upper direct_valid", cross_predictions)
write("cross-regression-aggregate.csv", "case_id row prediction lower upper", cross_aggregate)
cross_environment = {
    "commit": COMMIT, "source_version": "1.5.4", "module_sha256": MODULE_SHA256,
    "seed": cross_seed, "python": platform.python_version(), "platform": platform.platform(),
    "versions": environment["versions"], "cases": len(cross_cases) * 4,
    "folds": len(cross_options), "aggregate_rows": len(cross_aggregate),
    "component_rows": len(cross_predictions),
    "direct_valid_rows": sum(row[-1] for row in cross_predictions),
    "direct_defect_rows": sum(not row[-1] for row in cross_predictions),
    "component_reference": "Same pinned IVAR components and retained defects as regression-reference.md",
    "aggregate_reference": "Separate math.fsum of IVAR points, lower and upper endpoints divided by fold count",
    "scale": "Predeclared unit: 1, 1e-12, 1e120; shifted cases have unit 1 and shift 1e5",
    "fixture_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUTPUT.glob("cross-regression-*.csv"))},
}
(OUTPUT / "cross-regression-environment.json").write_text(json.dumps(cross_environment, indent=2) + "\n")
print(json.dumps({key: cross_environment[key] for key in ("cases", "folds", "aggregate_rows", "component_rows", "direct_valid_rows", "direct_defect_rows")}))
