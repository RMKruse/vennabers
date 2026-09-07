"""Reference check only; run with Python venn-abers 1.5.4 and sklearn installed."""
import hashlib
import inspect
from unittest.mock import patch

import numpy as np
import sklearn
import venn_abers as va
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.model_selection import KFold, StratifiedKFold, train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

assert hashlib.sha256(open(inspect.getfile(va.VennAbers), 'rb').read()).hexdigest() == (
    'ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5')
rng = np.random.default_rng(42)
x = rng.normal(size=(120, 3))
x[:, 0] += np.arange(120) / 20
xt = rng.normal(size=(7, 3))
y = (np.arange(120) % 2).astype(int)
yr = 2 * x[:, 0] - x[:, 1] + rng.normal(size=120)
checks = 0
for setting, truth, base in [
    ('classification', y, LogisticRegression()),
    ('regression', yr, LinearRegression()),
]:
    for inductive in [True, False]:
        obj = va.VennAbersCV(make_pipeline(StandardScaler(), base),
            inductive=inductive, n_splits=3, cal_size=.25,
            shuffle=True, random_state=42, setting=setting, cv_ensemble=False)
        obj.fit(x, truth)
        splits = [train_test_split(np.arange(len(x)), test_size=.25,
                    shuffle=True, random_state=42)] if inductive else list(
            (StratifiedKFold if setting == 'classification' else KFold)(
                n_splits=3, shuffle=True, random_state=42).split(x, truth))
        assert len(obj.estimators) == len(splits) + 1
        np.testing.assert_allclose(obj.estimators[0][0].mean_, x.mean(axis=0))
        for i, (train, cal) in enumerate(splits):
            np.testing.assert_allclose(obj.estimators[i+1][0].mean_, x[train].mean(axis=0))
            predict = obj.estimators[i+1].predict_proba if setting == 'classification' else obj.estimators[i+1].predict
            np.testing.assert_allclose(obj.clf_p_cal[i], predict(x[cal]))
        for ensemble in [False, True]:
            obj.cv_ensemble = ensemble
            if setting == 'classification':
                for loss in ['log', 'brier']:
                    actual, bounds = obj.predict_proba(xt, loss=loss, p0_p1_output=True)
                    endpoints = []
                    for i in range(len(splits)):
                        cal = va.VennAbers().fit(p_cal=obj.clf_p_cal[i], y_cal=obj.clf_y_cal[i])
                        model = obj.estimators[i+1 if ensemble else 0]
                        endpoints.append(cal.predict_proba(p_test=model.predict_proba(xt))[1])
                    p0 = np.column_stack([p[:, 0] for p in endpoints])
                    p1 = np.column_stack([p[:, 1] for p in endpoints])
                    expected = (np.exp(np.log(p1).mean(axis=1)) /
                        (np.exp(np.log(p1).mean(axis=1)) + np.exp(np.log1p(-p0).mean(axis=1)))) if loss == 'log' else (p1 + .5*p0**2 - .5*p1**2).mean(axis=1)
                    np.testing.assert_allclose(actual[:, 1], expected, atol=1e-12, rtol=1e-12)
                    np.testing.assert_allclose(bounds, np.column_stack([p0, p1]))
                    checks += 1
            else:
                models = obj.estimators[1:] if ensemble else [obj.estimators[0]]
                with patch.object(models[0], 'predict', wraps=models[0].predict) as spy:
                    points, bounds = obj.predict_interval(xt)
                assert spy.call_count == (1 if ensemble else len(splits))
                assert len(points) == len(bounds) == len(splits)
                assert np.isfinite(points).all() and np.isfinite(bounds).all()
                # Excluding the unused model proves the chosen prediction route.
                unused = obj.estimators[0] if ensemble else obj.estimators[1]
                with patch.object(unused, 'predict', side_effect=AssertionError('unused model called')):
                    again = obj.predict_interval(xt)
                np.testing.assert_allclose(points, again[0])
                checks += 1

for classes in [2, 3]:
    truth = np.arange(120) % classes
    pairs = [(a, b) for a in range(classes) for b in range(a+1, classes)]
    for inductive in [True, False]:
        obj = va.VennAbersCalibrator(make_pipeline(StandardScaler(), LogisticRegression()),
            inductive=inductive, n_splits=3, cal_size=.25,
            shuffle=True, random_state=42, cv_ensemble=False)
        obj.fit(x, truth)
        pair_models = obj.va_calibrator.multiclass_va_estimators
        assert len(pair_models) == len(pairs)
        for pair, model in zip(pairs, pair_models):
            np.testing.assert_allclose(model.estimators[0][0].mean_, x[np.isin(truth, pair)].mean(axis=0))
        for loss in ['log', 'brier']:
            p = obj.predict_proba(xt, loss=loss)
            assert p.shape == (len(xt), classes) and np.isfinite(p).all()
            np.testing.assert_allclose(p.sum(axis=1), 1)
            checks += 1
assert 'cv_ensemble' not in inspect.signature(va.VennAbersRegressor).parameters
reg = va.VennAbersRegressor(LinearRegression(), inductive=False, n_splits=3, random_state=42)
reg.fit(x, yr)
assert reg.va_calibrator.cv_ensemble is True
print(f'{checks} reference cases passed; numpy {np.__version__}, sklearn {sklearn.__version__}')
print('Verified held-out calibration predictions, full/fold preprocessing, model routing, pair-domain full models, log/Brier formulas and regression facade default.')
