"""Counter-comparison of MAPIE and calibrated-explanations with vennabers.

Runs MAPIE, calibrated-explanations and, as a control, the main reference
venn-abers 1.5.4 on the inputs written by counter-comparison-inputs.R and
compares every result with the vennabers result at absolute tolerance 1e-10
(inst/PARITY.md, "Counter-comparisons"). Not binding: differences are
explained, never fixed. Normally started by counter-comparison.sh:

    python -I tools/counter-comparison-mapie-ce.py <data> <out> [--mapie-patched]

Writes to <out>:
- summary.csv: one row per package, path, procedure, precision, loss and
  quantity with the number of compared values, the largest absolute
  difference and the count over the tolerance; class rows split mismatches
  into consequences of a numerical difference, ties and the rest;
- examples.json: up to five differing rows per comparison;
- causes.csv: the checks that tie each known difference to its cause;
- python-environment.json: versions and module SHA-256 hashes.
With --mapie-patched, MAPIE's core gets the main reference's upper tail value
p1[-1, 1] = 1 (venn-abers 1.5.4) and the files carry a -mapie-patched suffix.
This is a diagnosis of the cause, not a comparison of MAPIE as released.
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

import mapie
import calibrated_explanations
from mapie import _venn_abers as mva
from mapie.calibration import VennAbersCalibrator
from venn_abers import venn_abers as rva
from calibrated_explanations.calibration import venn_abers as ce_module
from calibrated_explanations.calibration.venn_abers import VennAbers as CEVennAbers
from calibrated_explanations.calibration.normalization_strategy import NormalizationStrategy

# Module hash of the main reference as pinned in inst/PARITY.md; the control
# only proves the setup if it runs exactly that code.
REFERENCE_MODULE_SHA256 = "ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5"

parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument("data", type=Path, help="directory written by counter-comparison-inputs.R")
parser.add_argument("out", type=Path, help="directory for the summaries")
parser.add_argument("--mapie-patched", action="store_true", help="add the reference's upper tail value to MAPIE")
options = parser.parse_args()
DATA = options.data
OUT = options.out
OUT.mkdir(parents=True, exist_ok=True)
SUFFIX = "-mapie-patched" if options.mapie_patched else ""
warnings.filterwarnings("ignore")


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


MODULES = {
    "venn_abers/venn_abers.py": rva.__file__,
    "mapie/_venn_abers.py": mva.__file__,
    "mapie/calibration.py": sys.modules[VennAbersCalibrator.__module__].__file__,
    "calibrated_explanations/calibration/venn_abers.py": ce_module.__file__,
}
HASHES = {name: sha256(path) for name, path in MODULES.items()}
if HASHES["venn_abers/venn_abers.py"] != REFERENCE_MODULE_SHA256:
    sys.exit("venn_abers/venn_abers.py is not the pinned main reference module; install venn-abers==1.5.4.")
REF = f"venn-abers {version('venn-abers')}"
MAPIE = f"MAPIE {mapie.__version__}"
CE = f"calibrated-explanations {calibrated_explanations.__version__}"

if options.mapie_patched:
    _calc = mva.calc_p0p1

    def _patched(p_cal, y_cal, precision=None):
        p0, p1, c = _calc(p_cal, y_cal, precision)
        p1[-1, 1] = 1.0
        return p0, p1, c

    mva.calc_p0p1 = _patched
TOL = 1e-10
PRECISIONS = ["none", "0", "2", "-1", "4"]


def prec(setting):
    return None if setting == "none" else int(setting)


def num(value):
    return float("nan") if value == "" else float.fromhex(value) if value.startswith(("0x", "-0x")) else float(value)


def read(name):
    with open(DATA / name) as handle:
        return list(csv.DictReader(handle))


def two(p):
    p = np.asarray(p, dtype=float)
    return np.column_stack((1 - p, p))


class Table:
    """Fitted table predictor: X holds row indices into a stored matrix."""

    def __init__(self, matrix, classes=None):
        self.matrix = np.asarray(matrix, dtype=float)
        self.classes_ = np.arange(self.matrix.shape[1]) if classes is None else classes

    def fit(self, *args, **kwargs):
        return self

    def predict_proba(self, X):
        return self.matrix[np.asarray(X, dtype=int).ravel()]


def off(a, b):
    return np.abs(np.asarray(a, dtype=float) - np.asarray(b, dtype=float)) > TOL


def binary_tie(p):
    return np.abs(np.asarray(p, dtype=float) - 0.5) <= TOL


def normalize(m):
    """Row normalization as vennabers does it: binary64 additions from left to right."""
    total = m[:, 0].copy()
    for j in range(1, m.shape[1]):
        total = total + m[:, j]
    return m / total.reshape(-1, 1)


results = []  # rows of the summary
examples = defaultdict(list)
causes = []  # rows of causes.csv


def record(package, path, task, procedure, method, precision, loss, quantity, actual, expected, keys=None):
    actual = np.asarray(actual, dtype=float).ravel()
    expected = np.asarray(expected, dtype=float).ravel()
    assert actual.shape == expected.shape, (package, path, quantity, actual.shape, expected.shape)
    both_nan = np.isnan(actual) & np.isnan(expected)
    diff = np.where(both_nan, 0.0, np.abs(actual - expected))
    diff = np.where(np.isnan(diff), np.inf, diff)
    bad = diff > TOL
    tag = (package, path, task, procedure, method, precision, loss, quantity)
    results.append(dict(package=package, path=path, task=task, procedure=procedure, method=method,
                        precision=precision, loss=loss, quantity=quantity, n=int(actual.size),
                        max_abs=float(diff.max()) if diff.size else 0.0, n_over_tol=int(bad.sum()),
                        class_numeric="", class_tie="", class_other=""))
    if keys is not None and bad.any():
        for i in np.flatnonzero(bad)[:5]:
            examples[tag].append((keys[i], float(actual[i]), float(expected[i])))


def record_class(package, path, task, procedure, method, precision, loss, actual, expected, keys=None,
                 numeric=None, tie=None):
    """Class decisions; mismatches are split into numeric consequences, ties and the rest."""
    actual = np.asarray(actual).ravel().astype(int)
    expected = np.asarray(expected).ravel().astype(int)
    bad = actual != expected
    numeric = np.zeros_like(bad) if numeric is None else np.asarray(numeric, dtype=bool)
    tie = np.zeros_like(bad) if tie is None else np.asarray(tie, dtype=bool)
    tag = (package, path, task, procedure, method, precision, loss, "class")
    results.append(dict(package=package, path=path, task=task, procedure=procedure, method=method,
                        precision=precision, loss=loss, quantity="class", n=int(actual.size),
                        max_abs=float(bad.any()), n_over_tol=int(bad.sum()),
                        class_numeric=int((bad & numeric).sum()), class_tie=int((bad & ~numeric & tie).sum()),
                        class_other=int((bad & ~numeric & ~tie).sum())))
    if keys is not None and bad.any():
        for i in np.flatnonzero(bad)[:5]:
            examples[tag].append((keys[i], int(actual[i]), int(expected[i])))


def record_cause(package, check, precision, differing, explained):
    """A known cause explains a difference only if it holds for every differing row."""
    differing = np.asarray(differing, dtype=bool)
    explained = np.asarray(explained, dtype=bool)
    causes.append(dict(package=package, check=check, precision=precision, n=int(differing.size),
                       differing=int(differing.sum()), explained=int((differing & explained).sum()),
                       unexplained=int((differing & ~explained).sum())))


# ---------------------------------------------------------------- binary data
cal_rows = defaultdict(list)
for r in read("binary-input-calibration.csv"):
    cal_rows[r["key"]].append((int(r["row"]), num(r["truth"]), num(r["score"])))
new_rows = defaultdict(list)
for r in read("binary-input-new.csv"):
    new_rows[r["key"]].append((int(r["row"]), num(r["score"])))
sets = {}
for key in cal_rows:
    c = sorted(cal_rows[key])
    n = sorted(new_rows[key])
    sets[key] = (np.array([t for _, t, _ in c]), np.array([s for _, _, s in c]), np.array([s for _, s in n]))

vb_bin = defaultdict(dict)
for r in read("vb-binary-inductive.csv"):
    vb_bin[(r["precision"], r["key"])][int(r["row"])] = r
keys_all = sorted(sets)


def vb_binary(setting, key, field):
    rows = vb_bin[(setting, key)]
    return np.array([num(rows[i][field]) for i in sorted(rows)])


def inject_cv(cal_list, new_list, precision):
    """MAPIE/reference VennAbersCV with stored per-fold arrays (as the reference generators do)."""
    folds = len(cal_list)
    x_index = np.arange(len(new_list[0]))
    out = []
    for module in (mva, rva):
        cv = module.VennAbersCV(estimator=None, inductive=folds == 1, n_splits=folds, precision=precision,
                                cv_ensemble=True)
        cv.clf_p_cal = [two(s) for _, s in cal_list]
        cv.clf_y_cal = [t for t, _ in cal_list]
        cv.estimators = [Table(two(new_list[0]))] + [Table(two(p)) for p in new_list]
        if module is rva:
            cv.estimators_ = cv.estimators
        out.append(cv)
    return out, x_index


# Binary Inductive
for setting in PRECISIONS:
    precision = prec(setting)
    acc = defaultdict(list)
    for key in keys_all:
        truth, score, new = sets[key]
        n_cal = len(score)
        # reference core
        ref = rva.VennAbers()
        ref.fit(two(score), truth, precision=precision)
        ref_p, ref_b = ref.predict_proba(two(new))
        # MAPIE private core
        mv = mva.VennAbers()
        mv.fit(two(score), truth, precision=precision)
        m_p, m_b = mv.predict_proba(two(new))
        # MAPIE public prefit path
        table = Table(np.vstack((two(score), two(new))))
        cal = VennAbersCalibrator(estimator=table, cv="prefit", precision=precision)
        cal.fit(np.arange(n_cal).reshape(-1, 1), truth.astype(int))
        x_new = (n_cal + np.arange(len(new))).reshape(-1, 1)
        pub_p, pub_b = cal.predict_proba(x_new, p0_p1_output=True)
        pub_class = cal.predict(x_new)
        # MAPIE Brier through a one-fold VennAbersCV (internal harness)
        (mcv, rcv), xi = inject_cv([(truth, score)], [new], precision)
        m_brier = mcv.predict_proba(xi, loss="brier")[:, 1]
        m_log1 = mcv.predict_proba(xi, loss="log")[:, 1]
        # MAPIE public Inductive path: VennAbersCalibrator around a one-pair VennAbersMultiClass
        public = VennAbersCalibrator(estimator=table, inductive=True)
        mc = mva.VennAbersMultiClass(estimator=None, inductive=True, precision=precision)
        mc.classes = np.array([0, 1])
        mc.n_classes = 2
        mc.pairwise_id = [[0, 1]]
        mc.multiclass_va_estimators = [mcv]
        public.va_calibrator_ = mc
        public.classes_ = np.array([0, 1])
        public.n_classes_ = 2
        public._is_fitted = True
        public.cv = None
        pi_log = public.predict_proba(xi, loss="log")[:, 1]
        pi_brier = public.predict_proba(xi, loss="brier")[:, 1]
        pi_class_log = public.predict(xi, loss="log")
        pi_class_brier = public.predict(xi, loss="brier")
        lo, up = vb_binary(setting, key, "lower"), vb_binary(setting, key, "upper")
        lg, br = vb_binary(setting, key, "log"), vb_binary(setting, key, "brier")
        cl_log, cl_brier = vb_binary(setting, key, "class_log"), vb_binary(setting, key, "class_brier")
        rk = [f"{key}|row{i + 1}" for i in range(len(new))]
        # Cause check MAPIE: a new score strictly above the largest (rounded) calibration score.
        rounded = score if precision is None else np.round(score, precision)
        above = new > rounded.max()
        for name, val in [("ref_lower", ref_b[:, 0]), ("ref_upper", ref_b[:, 1]), ("ref_log", ref_p[:, 1]),
                          ("m_lower", m_b[:, 0]), ("m_upper", m_b[:, 1]), ("m_log", m_p[:, 1]),
                          ("pub_lower", pub_b[:, 0]), ("pub_upper", pub_b[:, 1]), ("pub_log", pub_p[:, 1]),
                          ("pub_class", pub_class), ("m_brier", m_brier), ("m_log1", m_log1),
                          ("pi_log", pi_log), ("pi_brier", pi_brier), ("pi_class_log", pi_class_log),
                          ("pi_class_brier", pi_class_brier),
                          ("vb_lower", lo), ("vb_upper", up), ("vb_log", lg), ("vb_brier", br),
                          ("vb_class_log", cl_log), ("vb_class_brier", cl_brier), ("above_max", above),
                          ("keys", rk)]:
            acc[name].append(np.asarray(val) if name != "keys" else val)
        # calibrated-explanations (default: fit precision 4, regularized summary)
        if setting == "4":
            ce = CEVennAbers(np.arange(n_cal), truth.astype(int), learner=None, cprobs=two(score),
                             predict_function=lambda idx, s=new: two(s)[np.asarray(idx, dtype=int)])
            ce_p, ce_lo, ce_hi = ce.predict_proba(np.arange(len(new)), output_interval=True)
            ce_class = ce.predict(np.arange(len(new)))
            acc["ce_log"].append(ce_p[:, 1])
            acc["ce_lower"].append(ce_lo)
            acc["ce_upper"].append(ce_hi)
            acc["ce_class"].append(ce_class)
            # Cause check CE: calibration sets holding label 1 only.
            acc["ce_label1_only"].append(np.full(len(new), set(np.unique(truth)) == {1.0}))
    cat = {k: (np.concatenate(v) if k != "keys" else sum(v, [])) for k, v in acc.items()}
    keys = cat["keys"]
    for q in ["lower", "upper", "log"]:
        record(REF, "VennAbers (core)", "binary", "Inductive", "-", setting, "log", q,
               cat["ref_" + q], cat["vb_" + q], keys)
        record(MAPIE, "_venn_abers.VennAbers (private)", "binary", "Inductive", "-", setting, "log", q,
               cat["m_" + q], cat["vb_" + q], keys)
        record(MAPIE, "VennAbersCalibrator(cv='prefit')", "binary", "Inductive", "-", setting, "log", q,
               cat["pub_" + q], cat["vb_" + q], keys)
        record(f"{MAPIE} vs {REF}", "VennAbers (core)", "binary", "Inductive", "-", setting, "log", q,
               cat["m_" + q], cat["ref_" + q], keys)
    record_class(MAPIE, "VennAbersCalibrator(cv='prefit')", "binary", "Inductive", "-", setting, "log",
                 cat["pub_class"], cat["vb_class_log"], keys, off(cat["pub_log"], cat["vb_log"]),
                 binary_tie(cat["vb_log"]))
    record(MAPIE, "VennAbersCV (n_splits=1, internal)", "binary", "Inductive", "-", setting, "brier", "point",
           cat["m_brier"], cat["vb_brier"], keys)
    record(MAPIE, "VennAbersCV (n_splits=1, internal)", "binary", "Inductive", "-", setting, "log", "point",
           cat["m_log1"], cat["vb_log"], keys)
    for loss in ["log", "brier"]:
        record(MAPIE, "VennAbersCalibrator(inductive=True), injected", "binary", "Inductive", "-", setting,
               loss, "point", cat["pi_" + loss], cat["vb_" + loss], keys)
        record_class(MAPIE, "VennAbersCalibrator(inductive=True), injected", "binary", "Inductive", "-",
                     setting, loss, cat["pi_class_" + loss], cat["vb_class_" + loss], keys,
                     off(cat["pi_" + loss], cat["vb_" + loss]), binary_tie(cat["vb_" + loss]))
    # The lower value never differs; every upper difference lies above the largest calibration score.
    record_cause(MAPIE, "lower value differs nowhere", setting, off(cat["m_lower"], cat["vb_lower"]), False)
    record_cause(MAPIE, "upper value differs only above the largest calibration score", setting,
                 off(cat["m_upper"], cat["vb_upper"]), cat["above_max"])
    if setting == "4":
        for q in ["lower", "upper", "log"]:
            record(CE, "calibration.VennAbers (default, precision 4)", "binary",
                   "Inductive", "-", "4", "log", q, cat["ce_" + q], cat["vb_" + q], keys)
        ce_numeric = off(cat["ce_log"], cat["vb_log"]) | off(cat["ce_lower"], cat["vb_lower"])
        record_class(CE, "calibration.VennAbers (default, precision 4)", "binary",
                     "Inductive", "-", "4", "log", cat["ce_class"], cat["vb_class_log"], keys,
                     ce_numeric, binary_tie(cat["vb_log"]))
        ce_values = ce_numeric | off(cat["ce_upper"], cat["vb_upper"])
        record_cause(CE, "values differ only in calibration sets with label 1 only", "4", ce_values,
                     cat["ce_label1_only"])
        record_cause(CE, "classes differ only after a value difference or at a 0.5 tie", "4",
                     cat["ce_class"].astype(int) != cat["vb_class_log"].astype(int),
                     ce_values | binary_tie(cat["vb_log"]))

# Binary Cross
vb_cross = defaultdict(dict)
for r in read("vb-binary-cross.csv"):
    vb_cross[(r["precision"], r["case_id"])][int(r["row"])] = r
case_folds = defaultdict(list)
for key in keys_all:
    case, fold = key.split("|")
    if fold != "single":
        case_folds[case].append(fold)
for setting in ["none", "0", "2", "-1"]:
    precision = prec(setting)
    acc = defaultdict(list)
    for case in sorted(case_folds):
        folds = sorted(case_folds[case], key=lambda f: int(f.split("_")[1]))
        cal_list = [(sets[f"{case}|{f}"][0], sets[f"{case}|{f}"][1]) for f in folds]
        new_list = [sets[f"{case}|{f}"][2] for f in folds]
        (mcv, rcv), xi = inject_cv(cal_list, new_list, precision)
        rows = vb_cross[(setting, case)]
        public = VennAbersCalibrator(estimator=None, inductive=False, n_splits=len(folds))
        mc = mva.VennAbersMultiClass(estimator=None, inductive=False, n_splits=len(folds), precision=precision)
        mc.classes, mc.n_classes, mc.pairwise_id, mc.multiclass_va_estimators = np.array([0, 1]), 2, [[0, 1]], [mcv]
        public.va_calibrator_, public.classes_, public.n_classes_, public._is_fitted = mc, np.array([0, 1]), 2, True
        for loss in ["log", "brier"]:
            acc["m_" + loss].append(mcv.predict_proba(xi, loss=loss)[:, 1])
            acc["r_" + loss].append(rcv.predict_proba(xi, loss=loss)[:, 1])
            acc["pc_" + loss].append(public.predict(xi, loss=loss))
            acc["vb_" + loss].append(np.array([num(rows[i][loss]) for i in sorted(rows)]))
            acc["vbc_" + loss].append(np.array([int(rows[i]["class_" + loss]) for i in sorted(rows)]))
        acc["keys"].append([f"{case}|row{i}" for i in sorted(rows)])
    cat = {k: (np.concatenate(v) if k != "keys" else sum(v, [])) for k, v in acc.items()}
    for loss in ["log", "brier"]:
        record(REF, "VennAbersCV.predict_proba (internal)", "binary", "Cross", "-", setting, loss,
               "point", cat["r_" + loss], cat["vb_" + loss], cat["keys"])
        record(MAPIE, "VennAbersCV.predict_proba (internal)", "binary", "Cross", "-", setting, loss, "point",
               cat["m_" + loss], cat["vb_" + loss], cat["keys"])
        record(f"{MAPIE} vs {REF}", "VennAbersCV.predict_proba (internal)", "binary", "Cross", "-",
               setting, loss, "point", cat["m_" + loss], cat["r_" + loss], cat["keys"])
        record_class(MAPIE, "VennAbersCalibrator(inductive=False), injected", "binary", "Cross", "-",
                     setting, loss, cat["pc_" + loss], cat["vbc_" + loss], cat["keys"],
                     off(cat["m_" + loss], cat["vb_" + loss]), binary_tie(cat["vb_" + loss]))

# ---------------------------------------------------------------- multiclass
mc_cal = defaultdict(list)
for r in read("multiclass-input-calibration.csv"):
    mc_cal[r["case_id"]].append(r)
mc_new = defaultdict(list)
for r in read("multiclass-input-new.csv"):
    mc_new[(r["case_id"], r["fold"])].append(r)
vb_mc = defaultdict(list)
for r in read("vb-multiclass.csv"):
    vb_mc[(r["case_id"], r["method"], r["precision"], r["procedure"], r["loss"])].append(r)
vb_parts = defaultdict(list)
for r in read("vb-multiclass-parts.csv"):
    vb_parts[(r["case_id"], r["method"], r["precision"], r["procedure"], r["loss"])].append(r)


def matrix(rows, k):
    rows = sorted(rows, key=lambda r: int(r["row"]))
    return np.array([[num(r[f"p{j + 1}"]) for j in range(k)] for r in rows])


def pair_cv(p_cal_list, y_list, new_list, i, j, precision):
    """One OvO pair as MAPIE's VennAbersCV over the given folds (pair-normalized scores)."""
    cv = mva.VennAbersCV(estimator=None, inductive=len(p_cal_list) == 1, n_splits=len(p_cal_list),
                         precision=precision, cv_ensemble=True)
    cv.clf_p_cal, cv.clf_y_cal = [], []
    for p, y in zip(p_cal_list, y_list):
        rows = (y == i) | (y == j)
        pair = p[rows][:, [i, j]]
        cv.clf_p_cal.append(pair / pair.sum(axis=1).reshape(-1, 1))
        cv.clf_y_cal.append((y[rows] == j).astype(float))
    tables = []
    for x in new_list:
        pair = x[:, [i, j]]
        tables.append(Table(pair / pair.sum(axis=1).reshape(-1, 1)))
    cv.estimators = [tables[0]] + tables
    return cv


for setting in PRECISIONS:
    precision = prec(setting)
    acc = defaultdict(list)
    for case in sorted(mc_cal):
        rows = sorted(mc_cal[case], key=lambda r: int(r["row"]))
        k = int(rows[0]["classes"])
        # MAPIE and the main reference do not normalize rows; vennabers does.
        p = normalize(matrix(rows, k))
        y = np.array([int(r["truth"]) - 1 for r in rows])
        fold = np.array([r["fold"] for r in rows])
        xa = normalize(matrix(mc_new[(case, "A")], k))
        xb = normalize(matrix(mc_new[(case, "B")], k))
        m = len(xa)
        keys = [f"{case}|row{i + 1}" for i in range(m)]
        vb = {(meth, proc, loss): matrix(vb_mc[(case, meth, setting, proc, loss)], k)
              for meth in ["ovo", "ovr"] for proc in ["inductive", "cross"] for loss in ["log", "brier"]}
        vbc = {(meth, proc, loss): np.array([int(r["class"]) - 1 for r in sorted(
            vb_mc[(case, meth, setting, proc, loss)], key=lambda r: int(r["row"]))])
            for meth in ["ovo", "ovr"] for proc in ["inductive", "cross"] for loss in ["log", "brier"]}
        # MAPIE public prefit (OvO, Log only); two classes dispatch to the binary path
        table = Table(np.vstack((p, xa)))
        cal = VennAbersCalibrator(estimator=table, cv="prefit", precision=precision)
        cal.fit(np.arange(len(p)).reshape(-1, 1), y)
        x_new = (len(p) + np.arange(m)).reshape(-1, 1)
        pre_p = cal.predict_proba(x_new)
        pre_c = cal.predict(x_new)
        # MAPIE private OvR and reference prefitted functions
        ovr_p, _ = mva.predict_proba_prefitted_va(p, y, xa, precision=precision, va_tpe="one_vs_all")
        ref_ovo, _ = rva.predict_proba_prefitted_va(p, y, xa, precision=precision, va_tpe="one_vs_one")
        ref_ovr, _ = rva.predict_proba_prefitted_va(p, y, xa, precision=precision, va_tpe="one_vs_rest")
        m_ovo, _ = mva.predict_proba_prefitted_va(p, y, xa, precision=precision, va_tpe="one_vs_one")
        acc["pre"].append(pre_p.ravel()); acc["pre_c"].append(pre_c)
        acc["m_ovo"].append(m_ovo.ravel()); acc["m_ovr"].append(ovr_p.ravel())
        acc["ref_ovo"].append(ref_ovo.ravel()); acc["ref_ovr"].append(ref_ovr.ravel())
        for meth in ["ovo", "ovr"]:
            for proc in ["inductive", "cross"]:
                for loss in ["log", "brier"]:
                    acc[f"vb_{meth}_{proc}_{loss}"].append(vb[(meth, proc, loss)].ravel())
                    acc[f"vbc_{meth}_{proc}_{loss}"].append(vbc[(meth, proc, loss)])
        acc["keys"].append([f"{kk}|col{j + 1}" for kk in keys for j in range(k)])
        acc["keys_row"].append(keys)
        acc["k_row"].append(np.full(m, k))
        # MAPIE Inductive / Cross OvO through the public calibrator with injected pairwise VennAbersCV
        for proc, p_list, y_list, n_list in [
            ("inductive", [p], [y], [xa]),
            ("cross", [p[fold == "A"], p[fold == "B"]], [y[fold == "A"], y[fold == "B"]], [xa, xb]),
        ]:
            mc = mva.VennAbersMultiClass(estimator=None, inductive=proc == "inductive", n_splits=len(p_list),
                                         precision=precision)
            mc.classes, mc.n_classes = np.arange(k), k
            mc.pairwise_id = [[i, j] for i in range(k) for j in range(i + 1, k)]
            mc.multiclass_va_estimators = [pair_cv(p_list, y_list, n_list, i, j, precision)
                                           for i, j in mc.pairwise_id]
            public = VennAbersCalibrator(estimator=None, inductive=proc == "inductive", n_splits=len(p_list))
            public.va_calibrator_, public.classes_, public.n_classes_, public._is_fitted = mc, np.arange(k), k, True
            xi = np.arange(m)
            for loss in ["log", "brier"]:
                acc[f"pub_{proc}_{loss}"].append(public.predict_proba(xi, loss=loss).ravel())
                acc[f"pubc_{proc}_{loss}"].append(public.predict(xi, loss=loss))
        # calibrated-explanations multiclass (per-class against the rest), precision 4 only
        if setting == "4" and k > 2:
            for norm in [NormalizationStrategy.SCALE, NormalizationStrategy.SIMPLEX]:
                ce = CEVennAbers(np.arange(len(p)), y, learner=None, cprobs=p,
                                 predict_function=lambda idx, s=xa: s[np.asarray(idx, dtype=int)])
                ce_p, lo, hi, cls = ce.predict_proba(np.arange(m), output_interval=True, normalization=norm)
                acc[f"ce_{norm.name}"].append(ce_p.ravel())
                acc[f"ce_{norm.name}_lo"].append(lo.ravel())
                acc[f"ce_{norm.name}_hi"].append(hi.ravel())
                acc[f"ce_{norm.name}_c"].append(cls)
            parts = vb_parts[(case, "ovr", "4", "inductive", "log")]
            lo_vb = np.zeros((m, k)); hi_vb = np.zeros((m, k))
            for r in parts:
                lo_vb[int(r["row"]) - 1, int(r["event"]) - 1] = num(r["lower"])
                hi_vb[int(r["row"]) - 1, int(r["event"]) - 1] = num(r["upper"])
            acc["ce_vb_lo"].append(lo_vb.ravel()); acc["ce_vb_hi"].append(hi_vb.ravel())
            acc["ce_vb"].append(vb[("ovr", "inductive", "log")].ravel())
            acc["ce_vb_c"].append(vbc[("ovr", "inductive", "log")])
            acc["ce_keys"].append([f"{kk}|col{j + 1}" for kk in keys for j in range(k)])
            acc["ce_keys_row"].append(keys)
            acc["ce_k_row"].append(np.full(m, k))
    cat = {kk: (np.concatenate(v) if not kk.startswith(("keys", "ce_keys")) else sum(v, [])) for kk, v in acc.items()}
    keys, keys_row = cat["keys"], cat["keys_row"]
    k_row = cat["k_row"]
    starts = np.concatenate(([0], np.cumsum(k_row)[:-1]))

    def mrow_off(a, b):
        d = off(a, b)
        return np.array([d[s0:s0 + kk].any() for s0, kk in zip(starts, k_row)])

    def mrow_tie(mat):
        mat = np.asarray(mat, dtype=float)
        out = []
        for s0, kk in zip(starts, k_row):
            r = np.sort(mat[s0:s0 + kk])
            out.append(r[-1] - r[-2] <= TOL)
        return np.array(out)
    record(REF, "predict_proba_prefitted_va", "multiclass", "Inductive", "OvO", setting, "log",
           "matrix", cat["ref_ovo"], cat["vb_ovo_inductive_log"], keys)
    record(REF, "predict_proba_prefitted_va", "multiclass", "Inductive", "OvR", setting, "log",
           "matrix", cat["ref_ovr"], cat["vb_ovr_inductive_log"], keys)
    record(MAPIE, "VennAbersCalibrator(cv='prefit')", "multiclass", "Inductive", "OvO", setting, "log",
           "matrix", cat["pre"], cat["vb_ovo_inductive_log"], keys)
    record_class(MAPIE, "VennAbersCalibrator(cv='prefit')", "multiclass", "Inductive", "OvO", setting, "log",
                 cat["pre_c"], cat["vbc_ovo_inductive_log"], keys_row, mrow_off(cat["pre"], cat["vb_ovo_inductive_log"]),
                 mrow_tie(cat["vb_ovo_inductive_log"]))
    record(MAPIE, "predict_proba_prefitted_va('one_vs_all', private)", "multiclass", "Inductive", "OvR",
           setting, "log", "matrix", cat["m_ovr"], cat["vb_ovr_inductive_log"], keys)
    record(f"{MAPIE} vs {REF}", "predict_proba_prefitted_va", "multiclass", "Inductive", "OvO",
           setting, "log", "matrix", cat["m_ovo"], cat["ref_ovo"], keys)
    record(f"{MAPIE} vs {REF}", "predict_proba_prefitted_va", "multiclass", "Inductive", "OvR",
           setting, "log", "matrix", cat["m_ovr"], cat["ref_ovr"], keys)
    for proc in ["inductive", "cross"]:
        for loss in ["log", "brier"]:
            record(MAPIE, f"VennAbersCalibrator(inductive={proc == 'inductive'}), injected", "multiclass",
                   proc.capitalize(), "OvO", setting, loss, "matrix", cat[f"pub_{proc}_{loss}"],
                   cat[f"vb_ovo_{proc}_{loss}"], keys)
            record_class(MAPIE, f"VennAbersCalibrator(inductive={proc == 'inductive'}), injected",
                         "multiclass", proc.capitalize(), "OvO", setting, loss, cat[f"pubc_{proc}_{loss}"],
                         cat[f"vbc_ovo_{proc}_{loss}"], keys_row,
                         mrow_off(cat[f"pub_{proc}_{loss}"], cat[f"vb_ovo_{proc}_{loss}"]),
                         mrow_tie(cat[f"vb_ovo_{proc}_{loss}"]))
    if setting == "4":
        for norm in ["SCALE", "SIMPLEX"]:
            path = f"calibration.VennAbers (normalization={norm})"
            record(CE, path, "multiclass", "Inductive", "OvR", "4", "log", "matrix",
                   cat[f"ce_{norm}"], cat["ce_vb"], cat["ce_keys"])
            record(CE, path, "multiclass", "Inductive", "OvR", "4", "log", "lower",
                   cat[f"ce_{norm}_lo"], cat["ce_vb_lo"], cat["ce_keys"])
            record(CE, path, "multiclass", "Inductive", "OvR", "4", "log", "upper",
                   cat[f"ce_{norm}_hi"], cat["ce_vb_hi"], cat["ce_keys"])
            record_class(CE, path, "multiclass", "Inductive", "OvR", "4", "log",
                         cat[f"ce_{norm}_c"], cat["ce_vb_c"], cat["ce_keys_row"])


def write_csv(name, rows):
    with open(OUT / name, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


write_csv(f"summary{SUFFIX}.csv", results)
write_csv(f"causes{SUFFIX}.csv", causes)
with open(OUT / f"examples{SUFFIX}.json", "w") as handle:
    json.dump({" / ".join(k): v for k, v in examples.items()}, handle, indent=1)
with open(OUT / "python-environment.json", "w") as handle:
    json.dump({"python": sys.version, "platform": platform.platform(),
               "versions": {name: version(name) for name in
                            ["mapie", "calibrated-explanations", "venn-abers", "numpy", "scikit-learn"]},
               "module_sha256": HASHES}, handle, indent=1)

control = [r for r in results if r["package"] == REF]
print(f"{len(results)} comparisons; {sum(r['n_over_tol'] > 0 for r in results)} with differences over {TOL:g}")
print(f"Control {REF}: largest difference {max(r['max_abs'] for r in control):.3g} over {len(control)} comparisons")
for row in causes:
    print(f"{row['package']}, precision {row['precision']}: {row['check']}: "
          f"{row['differing']} differing, {row['unexplained']} unexplained")
