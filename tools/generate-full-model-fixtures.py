"""Pinned Python full-transfer component fixtures; ordinary R tests are offline.

The deterministic table engine matches tests/full-model-workflow.R: its first
class probability is sigmoid(x + training_size / 10 - 3). These are identical
data domains and fixed model outputs, not seed-based training parity.
"""
import csv
import hashlib
import inspect
import json
import platform
from pathlib import Path
from types import SimpleNamespace
import warnings

import numpy as np
from venn_abers import VennAbersCV

output = Path(__file__).resolve().parents[1] / "inst" / "extdata"
pin = json.loads((output / "cross-environment.json").read_text())
module_hash = hashlib.sha256(Path(inspect.getfile(VennAbersCV)).read_bytes()).hexdigest()
assert module_hash == pin["module_sha256"]
x = np.linspace(-3, 3, 40)
y = np.tile([1, 0, 0, 1], 10)
new = np.array([-4, -2.75, -1.5, -.25, 1, 2.25, 3.5])


def probability(x, n):
    p = 1 / (1 + np.exp(-(x + n / 10 - 3)))
    return np.column_stack([1 - p, p])


rows = []
with warnings.catch_warnings():
    # Upstream's known unused gradient warnings do not alter these finite outputs.
    warnings.filterwarnings("ignore", message="All-NaN slice encountered", category=RuntimeWarning)
    for method, folds in [("inductive", [np.arange(32, 40)]),
                          ("cross", [np.arange(8), np.arange(8, 20), np.arange(20, 40)])]:
        for precision in [None, 0, 2, -1]:
            cv = VennAbersCV(None, method == "inductive", n_splits=len(folds),
                            cv_ensemble=False, precision=precision)
            cv.clf_p_cal = [probability(x[f], 40 - len(f)) for f in folds]
            cv.clf_y_cal = [y[f] for f in folds]
            cv.estimators = [SimpleNamespace(predict_proba=lambda X: probability(new, 40))]
            for loss in ["log", "brier"]:
                result, bounds = cv.predict_proba(new[:, None], loss=loss, p0_p1_output=True)
                assert np.isfinite(result).all() and np.isfinite(bounds).all()
                for k in range(len(folds)):
                    for i, value in enumerate(new):
                        lower, upper = bounds[i, k], bounds[i, k + len(folds)]
                        point = upper / (1 - lower + upper) if loss == "log" else upper + .5 * (lower**2 - upper**2)
                        rows.append([method, "none" if precision is None else precision, loss,
                                     k + 1, i + 1, value, lower, upper, point, result[i, 1]])

path = output / "full-model-reference.csv"
with path.open("w", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow(["method", "precision", "loss", "fold", "row", "x", "lower", "upper", "probability", "combined"])
    writer.writerows(rows)
(output / "full-model-environment.json").write_text(json.dumps({
    "commit": pin["commit"], "module_sha256": module_hash,
    "python": platform.python_version(), "numpy": np.__version__,
    "reference": "VennAbersCV.predict_proba(cv_ensemble=False), fixed table model",
    "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    "fixture_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "rows": len(rows),
}, indent=2) + "\n")
print(f"Generated {len(rows)} full-transfer component rows.")
