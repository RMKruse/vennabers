"""Regenerate stored CVAP fixtures with Python venn-abers==1.5.4.

Run from any directory in an environment containing the pinned reference and
its dependencies. No predictive models are fitted or random splits generated.
Ordinary R tests do not run this script. See inst/extdata/cross-reference.md.
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
from venn_abers import VennAbers, VennAbersCV

SEED = 20260906
COMMIT = "0e7b4bc575ce230134576ba1c76688d46bf99ac7"
MODULE_SHA256 = "ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5"
SDIST_SHA256 = "a6bf5383e618ce42d0ecb2335bba0d6b104ecbe979041f10019b57572364bc69"
assert metadata.version("venn-abers") == "1.5.4"
assert hashlib.sha256(Path(inspect.getfile(VennAbersCV)).read_bytes()).hexdigest() == MODULE_SHA256


def two_columns(probability):
    p = np.asarray(probability, dtype=float)
    return np.column_stack((1 - p, p))


def reference(folds):
    # Pinned research harness: table predictors drive the actual matched-model
    # classification/log-loss ensemble path. This is not a user-facing API.
    cv = VennAbersCV(None, False, n_splits=len(folds), cv_ensemble=True,
                     precision=None)
    cv.clf_p_cal = [two_columns(p) for p, y, s in folds]
    cv.clf_y_cal = [np.asarray(y) for p, y, s in folds]
    cv.estimators = [None] + [SimpleNamespace(
        predict_proba=lambda X, s=s: two_columns(s)) for p, y, s in folds]
    return cv.predict_proba(np.zeros((len(folds[0][2]), 1)), loss="log",
                            p0_p1_output=True)


# Reused from .scratch/venn-abers-r-v02/research/check-reference.py, except
# the one-fold identity: public cross fitting requires at least two folds.
# A fold contains (calibration probabilities, binary truth, test probabilities).
cases = {
    "unequal": [([.1, .2, .3], [0, 1, 0], [0, .2, .25, 1]),
                ([.2, .2, .4, .4, .8], [0, 1, 0, 1, 1], [1, .4, .2, 0])],
    "crossing_pair": [([.5] * 9, [0] * 9, [.5] * 4),
                      ([.5] * 9, [1] * 9, [.5] * 4)],
    "singletons": [([0], [0], [0, .25, .5, 1]),
                   ([1], [1], [0, .25, .5, 1])],
    "boundaries": [([0, .5, 1], [0, 1, 0], [0, .5, .75, 1]),
                   ([0, .5, 1], [1, 0, 1], [1, .75, .5, 0]),
                   ([.2, .5, .8], [0, 0, 0], [0, .5, .8, 1])],
    "near_knots": [([.5, np.nextafter(.5, 1), .8], [0, 1, 0],
                    [np.nextafter(.5, 0), .5, np.nextafter(.5, 1), 1]),
                   ([.2, .5, .8], [1, 1, 1], [0, .5, .8, 1])],
}

rng = np.random.default_rng(SEED)
fold_index = 0
for case in range(100):
    folds = []
    k = 2 + case % 9
    for model in range(k):
        # Cycle all sizes, guaranteeing every size 1..200 occurs in the suite.
        n = 1 + fold_index % 200
        p = rng.uniform(.05, .95, n)
        if fold_index % 2:
            p = rng.choice([.1, .3, .5, .7, .9], n)
        y = rng.integers(0, 2, n)
        if fold_index % 7 in (0, 1):
            y[:] = fold_index % 7
        elif n > 1:
            y[:2] = [0, 1]
        s = (model + rng.random(25)) / k
        s[:3] = [0, 1, p[0]]
        folds.append((p, y, s))
        fold_index += 1
    cases[f"random_{case + 1:03d}"] = folds

random_cases = [f for name, f in cases.items() if name.startswith("random_")]
random_folds = [f for folds in random_cases for f in folds]
coverage = {
    "random_cases": len(random_cases),
    "fold_counts": sorted({len(f) for f in random_cases}),
    "fold_sizes": sorted({len(p) for p, y, s in random_folds}),
    "new_observation_counts": sorted({len(s) for p, y, s in random_folds}),
    "tied_folds": sum(len(set(p)) < len(p) for p, y, s in random_folds),
    "continuous_folds": sum(len(p) > 1 and len(set(p)) == len(p) for p, y, s in random_folds),
    "truth_class_counts": sorted({len(set(y)) for p, y, s in random_folds}),
    "distinct_model_columns": all(
        all(not np.array_equal(folds[0][2], f[2]) for f in folds[1:])
        for folds in random_cases),
}
assert coverage["random_cases"] == 100
assert coverage["fold_counts"] == list(range(2, 11))
assert coverage["fold_sizes"] == list(range(1, 201))
assert coverage["new_observation_counts"] == [25]
assert coverage["tied_folds"] and coverage["continuous_folds"]
assert coverage["truth_class_counts"] == [1, 2]
assert coverage["distinct_model_columns"]

calibration, prediction, combined = [], [], []
results = {}
with warnings.catch_warnings():
    # The pinned IVAP implementation emits this warning on valid inputs;
    # every stored result is independently checked for finite values below.
    warnings.filterwarnings("ignore", message="All-NaN slice encountered", category=RuntimeWarning)
    for name, folds in cases.items():
        q, endpoints = reference(folds)
        assert np.isfinite(q).all() and np.isfinite(endpoints).all()
        assert ((q >= 0) & (q <= 1)).all()
        assert ((endpoints >= 0) & (endpoints <= 1)).all()
        results[name] = (q[:, 1], endpoints)
        k = len(folds)
        for f, (p, y, s) in enumerate(folds):
            identity = f"model_{f + 1}"
            calibration.extend((name, identity, row, a, b)
                               for row, (a, b) in enumerate(zip(p, y), 1))
            prediction.extend((name, identity, row + 1, a,
                               endpoints[row, f], endpoints[row, k + f])
                              for row, a in enumerate(s))
        combined.extend((name, row, value) for row, value in enumerate(q[:, 1], 1))

    # Verify that the deterministic fixture can reject three tempting mergers.
    q, endpoints = results["unequal"]
    lo, hi = endpoints[:, :2], endpoints[:, 2:]
    weighted = 1 / (1 + np.exp(
        np.average(np.log1p(-lo), axis=1, weights=[3, 5]) -
        np.average(np.log(hi), axis=1, weights=[3, 5])))
    va = VennAbers()
    va.fit(two_columns(sum((f[0] for f in cases["unequal"]), [])),
           np.asarray(sum((f[1] for f in cases["unequal"]), [])), precision=None)
    pooled, _ = va.predict_proba(two_columns(cases["unequal"][0][2]))
    alternatives = {"mean_fold_points": np.mean(hi / (1 - lo + hi), axis=1),
                    "size_weighted": weighted, "pooled_first_model": pooled[:, 1]}
    assert all(np.max(abs(q - value)) > 1e-5 for value in alternatives.values())
    _, crossed = results["crossing_pair"]
    assert np.all(1 - np.sqrt(np.prod(1 - crossed[:, :2], axis=1)) >
                  np.sqrt(np.prod(crossed[:, 2:], axis=1)))

output = Path(__file__).resolve().parents[1] / "inst" / "extdata"
for filename, header, rows in [
    ("cross-calibration.csv", ["case_id", "fold", "row", "probability", "truth"], calibration),
    ("cross-predictions.csv", ["case_id", "fold", "row", "probability", "lower", "upper"], prediction),
    ("cross-combined.csv", ["case_id", "row", "probability"], combined),
]:
    with (output / filename).open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(header)
        for row in rows:
            row = list(row)
            if row[0] == "near_knots":
                # R 4.1 on arm64 can round adjacent decimal inputs onto a knot.
                # Hexadecimal floats preserve the exact reference probability.
                i = header.index("probability")
                row[i] = float(row[i]).hex()
            writer.writerow(row)

report = {
    "seed": SEED, "commit": COMMIT, "module_sha256": MODULE_SHA256,
    "release_sdist_sha256": SDIST_SHA256,
    "python": platform.python_version(), "platform": platform.platform(),
    "versions": {p: metadata.version(p) for p in
                 ["venn-abers", "numpy", "scipy", "pandas", "scikit-learn"]},
    "settings": {"classification": True, "precision": None,
                 "loss": "log", "cv_ensemble": True},
    "coverage": coverage,
    "unequal_alternatives": {name: value.tolist() for name, value in alternatives.items()},
    "fixture_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in sorted(output.glob("cross-*.csv"))},
}
(output / "cross-environment.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(coverage, indent=2))
