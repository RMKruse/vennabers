"""Research probe, not production code. Python venn-abers 1.5.4 only.
Run: python integration-boundaries-python.py [path/to/reference/src]
Dependencies: numpy, pandas, scikit-learn; optionally installed venn-abers 1.5.4.
The first X column is a row ID, stripped before numerical model fitting.
"""
import hashlib
import inspect
import io
import json
import pickle
import platform
import sys
import subprocess
import tarfile
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch

if len(sys.argv) > 1:
    sys.path.insert(0, sys.argv[1])
import numpy as np
import pandas as pd
import sklearn
import venn_abers as va
from sklearn.base import BaseEstimator, ClassifierMixin, RegressorMixin
from sklearn.calibration import CalibratedClassifierCV
from sklearn.ensemble import StackingRegressor
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import LogisticRegression, Ridge
from sklearn.model_selection import PredefinedSplit, cross_validate
from sklearn.metrics import log_loss, mean_squared_error


def ids(x):
    return set(np.asarray(x)[:, 0].astype(int))


class LoggedClassifier(ClassifierMixin, BaseEstimator):
    def fit(self, X, y):
        self.fit_ids_ = ids(X)
        self.score_ids_ = []
        self.model_ = LogisticRegression().fit(X[:, 1:], y)
        self.classes_ = self.model_.classes_
        return self

    def decision_function(self, X):
        self.score_ids_.append(ids(X))
        return self.model_.decision_function(X[:, 1:])

    def predict_proba(self, X):
        self.score_ids_.append(ids(X))
        return self.model_.predict_proba(X[:, 1:])

    def predict(self, X):
        return self.classes_[self.predict_proba(X).argmax(1)]


class LoggedCalibration(CalibratedClassifierCV):
    def fit(self, X, y, **kwargs):
        self.fit_ids_ = ids(X)
        self.predict_ids_ = []
        return super().fit(X, y, **kwargs)

    def predict_proba(self, X):
        self.predict_ids_.append(ids(X))
        return super().predict_proba(X)


class NumericPostprocessor(RegressorMixin, BaseEstimator):
    """Explicit numeric composite: Ridge then held-out learned isotonic mapping."""
    def fit(self, X, y):
        self.fit_ids_ = ids(X)
        self.predict_ids_ = []
        # Fixed local split, no occurrence dispatch; nested fit owns this split.
        cut = len(X) * 2 // 3
        self.model_ids_, self.post_ids_ = ids(X[:cut]), ids(X[cut:])
        self.model_ = Ridge().fit(X[:cut, 1:], y[:cut])
        self.post_ = IsotonicRegression(out_of_bounds='clip').fit(
            self.model_.predict(X[cut:, 1:]), y[cut:])
        return self

    def predict(self, X):
        self.predict_ids_.append(ids(X))
        return self.post_.predict(self.model_.predict(X[:, 1:]))


def expect_error(label, operation, kind):
    try:
        operation()
    except kind as err:
        print('NEGATIVE', label, type(err).__name__, str(err).splitlines()[0][:120])
    else:
        raise AssertionError(label + ': expected failure did not occur')


def provenance():
    expected_source = 'ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5'
    expected_sdist = 'a6bf5383e618ce42d0ecb2335bba0d6b104ecbe979041f10019b57572364bc69'
    source = Path(inspect.getfile(va.VennAbers)).read_bytes()
    assert hashlib.sha256(source).hexdigest() == expected_source
    metadata = json.load(urllib.request.urlopen('https://pypi.org/pypi/venn-abers/1.5.4/json'))
    sdist = next(a for a in metadata['urls'] if a['packagetype'] == 'sdist')
    archive = urllib.request.urlopen(sdist['url']).read()
    assert sdist['digests']['sha256'] == hashlib.sha256(archive).hexdigest() == expected_sdist
    with tarfile.open(fileobj=io.BytesIO(archive)) as tf:
        member = next(n for n in tf.getnames() if n.endswith('/src/venn_abers.py'))
        assert tf.extractfile(member).read() == source
    git_source = urllib.request.urlopen('https://raw.githubusercontent.com/ip200/venn-abers/'
        '0e7b4bc575ce230134576ba1c76688d46bf99ac7/src/venn_abers.py').read()
    assert git_source == source
    report = subprocess.check_output(['gh', 'api',
        'repos/RMKruse/venn-abers/contents/tools/python-parity-research.md?ref='
        'd7b87f1b093e6d1cd9b96a0116ced8ee19b973b2',
        '-H', 'Accept: application/vnd.github.raw+json'], text=True)
    assert expected_source in report and expected_sdist in report
    print('PROVENANCE source/sdist/Git/issue-3 hashes match')
    print('VERSIONS Python', platform.python_version(), 'NumPy', np.__version__,
          'pandas', pd.__version__, 'sklearn', sklearn.__version__)


def names(x, xt):
    count = 0
    for labels in [('class', 'other'), ('.pred_class', '.pred_yes'),
                   ('a b', 'a-b'), ('1yes', 'a/b'), ('a b', 'a.b', 'a-b')]:
        classes = np.sort(np.array(labels))
        y = np.array(labels)[np.arange(len(x)) % len(classes)]
        encoded = np.searchsorted(classes, y)
        for inductive in (True, False):
            for ensemble in (True, False):
                options = dict(inductive=inductive, n_splits=3, cal_size=.3,
                               random_state=42, cv_ensemble=ensemble)
                obj = va.VennAbersCalibrator(LogisticRegression(), **options).fit(x[:, 1:], y)
                ref = va.VennAbersCalibrator(LogisticRegression(), **options).fit(x[:, 1:], encoded)
                p = obj.predict_proba(xt[:, 1:])
                np.testing.assert_array_equal(obj.classes_, classes)
                np.testing.assert_allclose(p, ref.predict_proba(xt[:, 1:]))
                np.testing.assert_array_equal(obj.predict(xt[:, 1:], one_hot=False), classes[p.argmax(1)])
                np.testing.assert_array_equal(obj.predict(xt[:, 1:]), np.eye(len(classes))[p.argmax(1)])
                count += 1
        model = LogisticRegression().fit(x[:100, 1:], y[:100])
        pc, pt = model.predict_proba(x[100:, 1:]), model.predict_proba(xt[:, 1:])
        args = dict(p_cal=pc, p_test=pt, y_cal=y[100:])
        for typ in (['one_vs_one'] if len(classes) == 2 else ['one_vs_one', 'one_vs_rest']):
            expect_error('manual raw ' + repr(labels) + ' ' + typ,
                lambda: va.VennAbersCalibrator().predict_proba(**args, va_type=typ),
                (TypeError, ValueError, IndexError, np.exceptions.DTypePromotionError))
            # Caller owns the reversible dictionary and probability column alignment.
            manual = va.VennAbersCalibrator()
            fixed = dict(args, y_cal=encoded[100:])
            probs = manual.predict_proba(**fixed, va_type=typ)
            assert np.isfinite(probs).all()
            decoded = classes[probs.argmax(1)]
            assert set(decoded) <= set(labels)
            # Permute probability columns and label codes consistently; recover same identity.
            perm = np.arange(len(classes))[::-1]
            inverse = np.argsort(perm)
            permuted = manual.predict_proba(p_cal=pc[:, perm], p_test=pt[:, perm],
                y_cal=inverse[encoded[100:]], va_type=typ)
            np.testing.assert_allclose(permuted[:, inverse], probs, atol=1e-12)
    print('NAMES', count, 'trained label/mode cases; raw manual failures and reversible mapping passed')


def audit_nested(model, outer_ids):
    assert model.fit_ids_.isdisjoint(outer_ids)
    if isinstance(model, LoggedCalibration):
        for child in model.calibrated_classifiers_:
            base = child.estimator
            # In CCC ensemble=True, first score is held-out postprocessor training.
            post_ids = base.score_ids_[0]
            assert base.fit_ids_.isdisjoint(post_ids)
            assert base.fit_ids_ | post_ids == model.fit_ids_
            assert base.fit_ids_.isdisjoint(outer_ids) and post_ids.isdisjoint(outer_ids)
            assert all(hasattr(c, 'a_') and hasattr(c, 'b_') for c in child.calibrators)
    else:
        assert model.model_ids_.isdisjoint(model.post_ids_)
        assert model.model_ids_ | model.post_ids_ == model.fit_ids_


def nested(x, xt):
    outer_ids = ids(xt)
    cases, pairs_seen = 0, 0
    for k in (2, 3):
        y = np.arange(len(x)) % k
        for inductive in (True, False):
            for ensemble in (True, False):
                base = LoggedCalibration(LoggedClassifier(), cv=3, ensemble=True, method='sigmoid')
                obj = va.VennAbersCalibrator(base, inductive=inductive, n_splits=3,
                    cal_size=.3, random_state=42, cv_ensemble=ensemble).fit(x, y)
                va_inputs = []
                original_fit = va.VennAbers.fit
                def capture_fit(self, X=None, y=None, **kwargs):
                    va_inputs.append((kwargs.get('p_cal', X), kwargs.get('y_cal', y)))
                    return original_fit(self, X, y, **kwargs)
                with patch.object(va.VennAbers, 'fit', capture_fit):
                    p, bounds = obj.predict_proba(xt, p0_p1_output=True)
                expected_inputs = [(pc, yc) for pair_cv in obj.va_calibrator_.multiclass_va_estimators
                    for pc, yc in zip(pair_cv.clf_p_cal, pair_cv.clf_y_cal)]
                assert len(va_inputs) == len(expected_inputs)
                for actual, expected in zip(va_inputs, expected_inputs):
                    np.testing.assert_array_equal(actual[0], expected[0])
                    np.testing.assert_array_equal(actual[1], expected[1])
                assert np.isfinite(log_loss(np.arange(len(xt)) % k, p))
                assert p.shape == (len(xt), k) and np.isfinite(p).all()
                np.testing.assert_allclose(p.sum(1), 1)
                np.testing.assert_allclose(pickle.loads(pickle.dumps(obj)).predict_proba(xt), p)
                for pair, cv in zip(obj.va_calibrator_.pairwise_id,
                                    obj.va_calibrator_.multiclass_va_estimators):
                    pair_ids = ids(x[np.isin(y, pair)])
                    assert cv.estimators[0].fit_ids_ == pair_ids
                    for model in cv.estimators:
                        audit_nested(model, outer_ids)
                    for j, model in enumerate(cv.estimators[1:]):
                        cal_ids = model.predict_ids_[0]
                        assert cal_ids.isdisjoint(model.fit_ids_)
                        assert cal_ids | model.fit_ids_ == pair_ids
                        assert len(cal_ids) == len(cv.clf_y_cal[j]) == len(cv.clf_p_cal[j])
                        if ensemble:
                            assert outer_ids in model.predict_ids_
                        else:
                            assert outer_ids not in model.predict_ids_
                    assert (outer_ids in cv.estimators[0].predict_ids_) == (not ensemble)
                    # Additional preliminary OvO fits exist, separate from retained VA models.
                    pairs_seen += 1
                for extra in obj.va_calibrator_.clf_ovo.estimators_:
                    audit_nested(extra, outer_ids)
                cases += 1
    # Separate genuine numeric composition: Ridge -> held-out learned isotonic map.
    yr = 2*x[:, 1] - x[:, 2] + .3*np.sin(x[:, 3])
    for inductive in (True, False):
        for ensemble in (True, False):
            cv = va.VennAbersCV(NumericPostprocessor(), inductive=inductive,
                n_splits=3, cal_size=.3, shuffle=True, random_state=42,
                setting='regression', cv_ensemble=ensemble)
            cv.fit(x, yr)
            point, bounds = cv.predict_interval(xt)
            assert np.isfinite(point).all() and np.isfinite(bounds).all()
            outer_y = 2*xt[:, 1] - xt[:, 2] + .3*np.sin(xt[:, 3])
            assert np.isfinite(mean_squared_error(outer_y, np.mean(point, axis=0)))
            np.testing.assert_allclose(pickle.loads(pickle.dumps(cv)).predict_interval(xt)[0], point)
            for model in cv.estimators:
                audit_nested(model, outer_ids)
            for j, model in enumerate(cv.estimators[1:]):
                cal_ids = model.predict_ids_[0]
                assert cal_ids.isdisjoint(model.fit_ids_) and cal_ids | model.fit_ids_ == ids(x)
                assert len(cal_ids) == len(cv.clf_p_cal[j])
                assert (outer_ids in model.predict_ids_) == ensemble
            assert (outer_ids in cv.estimators[0].predict_ids_) == (not ensemble)
            cases += 1
        public = va.VennAbersRegressor(NumericPostprocessor(), inductive=inductive,
            n_splits=3, cal_size=.3, random_state=42).fit(x, yr)
        assert np.isfinite(public.predict(xt)[0]).all()
        # Independent standard sklearn numeric composite call, no row audit for stacking.
        stack = StackingRegressor([('ridge', Ridge())], final_estimator=Ridge(), cv=3)
        reg = va.VennAbersRegressor(stack, inductive=inductive,
            n_splits=3, cal_size=.3, random_state=42).fit(x[:, 1:], yr)
        assert np.isfinite(reg.predict(xt[:, 1:])[0]).all()
    print('NESTED', cases, 'row-audited modes;', pairs_seen,
          'classification pair domains; numeric public facade + stacking IV/CV calls passed')


def run_occurrence(bundle):
    occurrence, x, y, xt, test_fold = pickle.loads(bundle)
    # sklearn controls prescribed model folds. VA low-level is invoked manually.
    result = cross_validate(LoggedClassifier(), x, y, cv=PredefinedSplit(test_fold),
        scoring='neg_log_loss', return_estimator=True, return_indices=True)
    endpoints = []
    realized = []
    for model, train, cal in zip(result['estimator'], result['indices']['train'], result['indices']['test']):
        assert model.fit_ids_ == ids(x[train])
        assert ids(x[cal]).isdisjoint(model.fit_ids_)
        assert model.fit_ids_.isdisjoint(ids(xt))
        calibration = va.VennAbers().fit(model.predict_proba(x[cal]), y[cal])
        endpoints.append(calibration.predict_proba(model.predict_proba(xt))[1])
        realized.append(tuple(sorted(ids(x[cal]))))
    p0, p1 = np.array(endpoints)[:, :, 0], np.array(endpoints)[:, :, 1]
    # External CVAP merger, not a package-controlled explicit-split fit.
    g1, g0 = np.exp(np.log(p1).mean(0)), np.exp(np.log1p(-p0).mean(0))
    return occurrence, tuple(realized), g1/(g0+g1)


def plans(x, xt):
    y = np.arange(len(x)) % 2
    options = dict(inductive=False, n_splits=3, random_state=42)
    # Native positive: limited contiguous plans expressible by public parameters.
    for name, ncal in [('native-A', 36), ('native-B', 54)]:
        native = va.VennAbersCalibrator(LoggedClassifier(), inductive=True,
            cal_size=ncal, shuffle=False).fit(x, y)
        model = native.va_calibrator_.multiclass_va_estimators[0].estimators[1]
        assert model.fit_ids_ == ids(x[:-ncal])
        assert model.score_ids_[0] == ids(x[-ncal:])
    print('PLANS native shuffle=False accepts two prescribed contiguous IVAP plans (36/54 calibration rows)')
    plan_a, plan_b = (np.arange(len(x))//2) % 3, (np.arange(len(x))//4) % 3
    assert not np.array_equal(plan_a, plan_b)
    expect_error('native constructor cv', lambda: va.VennAbersCalibrator(
        LoggedClassifier(), cv=PredefinedSplit(plan_a), **options), TypeError)
    expect_error('native n_splits=PredefinedSplit', lambda: va.VennAbersCalibrator(
        LoggedClassifier(), inductive=False, n_splits=PredefinedSplit(plan_a)).fit(x, y), ValueError)
    expect_error('native fit cv is forwarded, not VA plan', lambda: va.VennAbersCalibrator(
        LoggedClassifier(), **options).fit(x, y, cv=PredefinedSplit(plan_a)), TypeError)
    # Public CCC cv does accept the plan, but controls its postprocessor, not VA.
    for plan in (plan_a, plan_b):
        calibrated = LoggedCalibration(LoggedClassifier(), cv=PredefinedSplit(plan), ensemble=True).fit(x, y)
        for model, (_, post) in zip(calibrated.calibrated_classifiers_, PredefinedSplit(plan).split()):
            assert model.estimator.score_ids_[0] == ids(x[post])
        expect_error('global CCC local-position plan is invalid after VA shrinking',
            lambda: va.VennAbersCalibrator(calibrated, **options).fit(x, y), IndexError)
    bundles = [pickle.dumps((name, x, y, xt, plan)) for name, plan in [('repeat-A', plan_a), ('repeat-B', plan_b)]]
    initial = {name: (folds, p) for name, folds, p in map(run_occurrence, bundles)}
    assert initial['repeat-A'][0] != initial['repeat-B'][0]
    with ThreadPoolExecutor(max_workers=2) as pool:
        repeated = list(pool.map(run_occurrence, bundles[::-1] + bundles))
    for name, folds, p in repeated:
        assert folds == initial[name][0]
        np.testing.assert_allclose(p, initial[name][1])
    print('PLANS explicit occurrence IDs + serialized data/plan bundles; prescribed distinct folds;')
    print('PLANS repeat, reverse invocation order, thread-parallel fits reproduce membership and probabilities')


def main():
    provenance()
    rng = np.random.default_rng(19)
    x = np.column_stack([np.arange(180), rng.normal(size=(180, 4))])
    xt = np.column_stack([np.arange(1000, 1012), rng.normal(size=(12, 4))])
    names(x, xt)
    plans(x, xt)
    nested(x, xt)
    print('ALL integration-boundary assertions passed')


if __name__ == '__main__':
    main()
