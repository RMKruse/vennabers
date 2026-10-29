# vennabers parity and capability index

This index lists every capability vennabers supports, what kind of statement
it makes about the Python reference, and the executable evidence behind it.
README, DESCRIPTION, help pages and NEWS refer to this file for parity claims.
"Complete" refers only to the examined and agreed capability scope below. It
does not cover arbitrary sklearn estimators, Tailor step sequences or other
engines' raw interfaces. A newly found reference capability or gap is added
here and re-evaluated visibly.

## Reference and tolerances

The main reference is Python `venn-abers` 1.5.4, commit
`0e7b4bc575ce230134576ba1c76688d46bf99ac7`; numerical module SHA-256
`ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5`, release
sdist SHA-256 `a6bf5383e618ce42d0ecb2335bba0d6b104ecbe979041f10019b57572364bc69`.
Stored fixtures (identical inputs, not matching seeds) define parity. The
reference notes (`cross-reference.md`, which also covers the randomized
fixtures, `binary-options-reference.md`, `multiclass-reference.md` for OvO and
OvR, `regression-reference.md`, `cross-regression-reference.md`), the
`*-environment.json` records and the Sigmoid generator
`generate-sigmoid-reference.py` in `tests/testthat/extdata` describe generators,
Python environments and hashes. Tests and examples need neither Python nor a
network connection.

Every procedure has exactly one binding reference: the main reference for each
procedure it offers, otherwise a pinned procedure reference. A pin never moves
within 1.x; values that a newer release of a reference changes become a D entry
instead. Other software is a counter-comparison (see below), never a reference.

| Procedure | Binding reference | Pin and records |
| --- | --- | --- |
| Binary Inductive and Cross VA, Brier, precision and class decisions | Main reference | `venn-abers` 1.5.4 at the commit above; `binary-options-environment.json`, `cross-environment.json` |
| Manual multiclass one-vs-one and one-vs-rest | Main reference | `venn-abers` 1.5.4; `ovo-environment.json`, `ovr-environment.json` |
| IVAR and CVAR components | Main reference, model-backed regression path | `venn-abers` 1.5.4; `regression-environment.json`, `cross-regression-environment.json` |
| Inductive and Cross full-model transfer | Main reference | `venn-abers` 1.5.4; `full-model-environment.json` |
| Sigmoid direct outputs | Procedure reference scikit-learn `_SigmoidCalibration` | scikit-learn 1.7.2 (tag `1.7.2`); `sigmoid-environment.json`, `generate-sigmoid-reference.py` |
| Isotonic regression postprocessing, CORP graphics and the other R extensions | None | Contract and hand-worked tests only; no numerical parity statement |

- Classification cores: maximum absolute difference `1e-10`, no relative part.
  The `1e-8` input row-sum check is a separate validation rule.
- Regression cores: `abs(actual - expected) <= 1e-10 * s + 1e-10 * abs(expected)`,
  with the positive unit scale `s` fixed before comparison.
- Direct Sigmoid outputs: `1e-7` absolute. Direct isotonic values: `1e-10`
  absolute plus `1e-10` relative.
- Shape, types, finiteness, names and class, fold and row identities are
  checked separately from every numerical tolerance.

## Kinds of statement

- **N numerical parity**: the same valid inputs, calibration/test predictions,
  options and fold assignments give the reference results within the
  tolerances above.
- **T training and data parity**: source models, pair/fold splits,
  preprocessing and calibration roles follow the reference procedure. Equal
  arrays alone do not establish this.
- **R native use**: R functions, workflows, tables and outputs meet the R
  contract. Python class names, tuple shapes and wrapper inheritance are not
  part of the R API.
- **E R extension**: a deliberate capability without a Python counterpart. Its
  evidence is the R contract, not the reference.
- **D reference deviation**: a documented reference defect or defined
  difference, replaced by its own contract tests. Tolerances are never widened
  for it.
- **L accepted limit**: a documented limit of the 1.x contract. The composition
  fails completely with context instead of approximating.

## Capability index

Tests are in `tests/testthat` of the source package (installed with
`R CMD INSTALL --install-tests`); examples are installed under
`system.file("examples", package = "vennabers")`.

| Capability | Statement | Evidence |
| --- | --- | --- |
| Binary Inductive VA endpoints and Log points | N, D | `test-venn-abers.R`, `test-binary-options-parity.R`, `test-randomized-parity.R`; `extdata/binary-options-*`, `extdata/randomized-*`; `examples/binary-options.R`. Native R `round()` controls ties at decimal boundaries, where NumPy can differ (D). |
| Binary Cross VA aggregation | N, D | `test-cross-parity.R`, `test-cross-venn-abers.R`; `extdata/cross-*`; `examples/cross-venn-abers.R`. Stable log-space aggregation replaces the reference product merger, which can underflow; checked against exact reductions (D). |
| Brier regularization, precision, class predictions and fold details | N, E, D | `test-binary-options.R`, `test-binary-options-parity.R`, `test-cross-venn-abers.R`; `extdata/binary-options-*`. Manual Brier selection is an R extension; its reference comes from the model-backed Python merger (E). |
| Manual multiclass one-vs-one | N, D | `test-inductive-multiclass.R`; `extdata/ovo-*`; `examples/inductive-ovo.R`. A zero pair mass uses event probability 0.5 instead of dividing by zero (D). |
| Manual multiclass one-vs-rest | N, D | `test-inductive-ovr.R`, `test-inductive-multiclass.R`; `extdata/ovr-*`; `examples/inductive-ovr.R`. Classes come from the selected method's final matrix; the reference manual OvR predict can return OvO classes (D). |
| Manual Brier multiclass and Cross multiclass with shared folds | E | `test-inductive-multiclass.R`, `test-cross-multiclass.R`; `examples/cross-multiclass.R`. Binary components are compared numerically; the whole procedure has no public Python counterpart. |
| Two-class factor truth with the multiclass contract | D | `test-inductive-multiclass.R`. The reference facade dispatches two classes to its binary path; R keeps multiclass normalization, tie rule and Brier scale. |
| One-hot class decisions | R, D | `test-one-hot.R`; `examples/one-hot-classes.R`. `venn_abers_one_hot()` represents the existing R class decision as a double 0/1 matrix with every class as a column (R). A binary 0.5 tie sets the event column, as in Python `VennAbers.predict` (`>= 0.5`); the Python facade's `argmax` over sorted classes puts it in the first class instead (D). Columns and multiclass ties follow the stored level order, which matches the facade's sorted labels for default `factor()` levels. |
| Brier score, log loss and calibration plots | R, D | `test-venn-abers.R`, `test-inductive-multiclass.R`, `test-cross-multiclass.R`; `examples/inductive-ovo.R`. Unhalved multiclass Brier, unclipped log loss and literal plot groups are hand-checked; no Python scoring export is assumed. |
| Fit diagnoses of fitted calibrators | E | `test-fit-plots.R`; `examples/calibration-graphics.R`. `plot()` draws the stored calibration map and the Venn-Abers width `upper - lower` of binary, multiclass and regression Inductive/Cross calibrators and of workflow fits, without new truth values; the invisible table equals `predict()` at the stored knots. Python venn-abers has no plotting interface. |
| CORP reliability, Brier decomposition and regression assessment graphics | E | `test-corp.R`, `test-regression-plot.R`; `examples/calibration-graphics.R`. `corp_plot()`, `corp_decomposition_plot()` and `regression_plot()` assess held-out pairs; CORP follows Dimitriadis, Gneiting and Jordan (2021); the estimate and both resampling bands are cross-checked against the R package reliabilitydiag under "Counter-comparisons" below, which is no parity statement. Band limits are not Venn-Abers bounds. |
| Moderated Inductive regression (IVAR) with m/epsilon | N, E, D | `test-inductive-regression.R`, `test-regression-parity.R`; `extdata/regression-*`; `examples/inductive-regression.R`. Components come from the model-backed Python path; the manual regression interface itself is an R extension without a public Python wrapper (E). 1,099 valid reference rows compare directly; the defective reference lower scan is replaced by the reflected valid upper component, and vanishing merger weights use the stable midpoint (D). |
| Cross regression (CVAR) with fold results | E, N | `test-cross-regression.R`, `test-cross-regression-parity.R`; `extdata/cross-regression-*`; `examples/cross-regression.R`. No public Python manual CVAR exists; fold components are pinned IVAR components followed by an equal-weight mean. Bounds are descriptive, not intervals. |
| Shared trained workflows: binary, OvO, OvR and regression, Inductive or Cross | T, R, E | `test-calibrated-workflow.R`, `test-cross-workflow.R`, `test-multiclass-workflow.R`, `test-cross-multiclass-workflow.R`, `test-regression-workflow.R`, `test-local-plans.R`, `test-integration-processes.R`; `examples/calibrated-workflow.R`. One shared multiclass model and trained OvR are R extensions, not Python training parity (E). |
| Own models through `model_adapter()` callbacks | R, L | `test-model-adapter.R`, `test-model-adapter-compositions.R`, `test-model-adapter-processes.R`; `examples/model-adapter.R`. R-native counterpart to passing an arbitrary Python estimator: user `fit(x, y)` and `predict(object, new_data)` functions form an unfitted parsnip specification inside the existing workflow lifecycle (Inductive/Cross, matched/full, outer resampling, frozen adoption, saved fits and workers), with probability columns aligned by original class name (R). The same callbacks carry pairwise OvO on each pair's rows and two original levels, Sigmoid probability, Tailor logistic/multinomial/linear and numeric isotonic postprocessing on B with holdout or inner ensembles, and Grid/Bayes searches over calibration and recipe parameters, each matching the native engine; a tuned adapter fit replays on workers and in a fresh process (R). No T: learning only from the local `x`/`y` is a user contract the package cannot check. `sigmoid_input = "glm_link"` requires the native GLM engine, callback state with its own save/restore procedure (external handles) is not covered, and callbacks expose no tunable or replaceable parameters: grid columns or `update()` arguments for the adapter are rejected (L). |
| Fixed engine options and model-internal validation | R, L | `test-engine-options.R`; `examples/engine-options.R`. R-native counterpart to Python fit kwargs that configure the estimator: fixed options in the model specification and `parsnip::set_engine()` reach every local fit (Inductive/Cross sources, class pairs, Full1 and postprocessing B, also in inner ensembles), each on its own rows; native XGBoost early stopping (`stop_iter` with `validation`) translates to a validation share split from each local fit's prepared rows (R). xgboost is not a dependency; `tools/xgboost-early-stopping.R` in the source repository runs the real fits and checks local rows, early stopping and the fold, pair or B/P context of an invalid setting. No T: internal validation follows the local data roles, not a reference procedure. Extra fit arguments to `calibrated_workflow()` or `fit()` are rejected; general Python fit kwargs, per-row fit data (weights, offsets) and an external `eval_set` are not supported (L). |
| Complete outer resampling, last_fit and native scoring | R | `test-outer-resampling.R`, `test-outer-identities.R`, `test-matched-last-fit.R`; `examples/calibrated-resampling.R`, `examples/check-encoded-evaluation.R`. Exact `(id, id2, .row, .config)` coverage is checked, not only a metric table. |
| Automatic, explicit and ordered reference splits | T | `test-reference-splits.R`, `test-local-plans.R`; `examples/reference-splits.R`. Paper-style ordered holdouts illustrate data roles; they do not reproduce paper benchmarks. |
| Independent Inductive training and calibration sizes | T, R, D, L | `test-inductive-sizes.R`; `test-inductive-sizes-processes.R`; `examples/inductive-sizes.R`. `training_size`/`calibration_size` follow sklearn's `train_size`/`test_size` rounding on the local rows (training floor, calibration ceiling, whole numbers exact, missing size as complement). Unassigned rows stay out of source training, B/P and calibration and join the F of Full1, as in the reference; pairwise multiclass resolves the sizes on each class pair, as the reference does per pair (T). R-native arguments of `calibrated_workflow()`, stored `unassigned` positions (per pair) and resolved counts; calibration selection resolves on the final-fit F (R). Stratified draws allocate exact totals per class by largest remainders, rows are not drawn identically to sklearn, and Full1 exists only with `prediction_model = "full"` (D). Absolute row counts are rejected in searches with Venn-Abers candidates (calibration and joint model searches), whose candidates resolve the sizes on resample rows; proportions are accepted there and two-stage model searches accept both (L). |
| Reversible schema encoding of special names | R | `test-schema.R`, `test-schema-workflow.R`, `test-schema-resampling.R`, `test-schema-multiclass-regression.R`, `test-schema-processes.R`; `examples/encoded-binary.R`, `examples/encoded-multiclass-regression.R`. |
| Calibration of existing predictions and frozen workflows | N, E | Manual cores above (N); `test-frozen-workflow.R`, `test-frozen-evaluation.R`, `test-frozen-schema.R`, `test-frozen-multiclass-regression.R`, `test-frozen-processes.R`; `examples/frozen-binary.R`, `examples/frozen-multiclass-regression.R`, `examples/frozen-schema.R`. Direct adoption of a fitted workflow is an R extension (E). |
| Python-style pairwise OvO training | T | `test-pairwise-workflow.R`, `test-pairwise-cross-workflow.R`, `test-pairwise-processes.R`; `examples/pairwise-inductive.R`, `examples/pairwise-cross.R`. Each class pair has its own models and local plans. |
| Inductive and Cross full-model transfer | T, N | `test-full-model-workflow.R`, `test-full-pairwise-workflow.R`, `test-full-multiclass-workflow.R`, `test-full-regression-workflow.R`, `test-full-multiclass-processes.R`, `test-full-regression-processes.R`; `extdata/full-model-reference.csv`; `examples/full-model-workflow.R`, `examples/full-multiclass-workflow.R`, `examples/full-regression-workflow.R`. Full models do not inherit split-calibration guarantees. |
| Joint and two-stage Grid selection without postprocessing | E | `test-binary-grid.R`, `test-multiclass-grid.R`, `test-pairwise-grid.R`, `test-pairwise-grid-cache.R`, `test-pairwise-grid-outer.R`, `test-regression-grid.R`, `test-tuning-plan.R`, `test-tuning-score.R`, `test-tuning-replay-grid-binary.R`; `examples/binary-grid.R`, `examples/shared-multiclass-grid.R`, `examples/pairwise-grid.R`, `examples/regression-grid.R`. All 40 cells of the training matrix. |
| Joint and two-stage Bayes selection without postprocessing | E | `test-binary-bayes.R`, `test-multiclass-bayes.R`, `test-pairwise-bayes.R`, `test-regression-bayes.R`, `test-tuning-replay-bayes-binary.R`; `examples/shared-multiclass-bayes.R`, `examples/pairwise-bayes.R`, `examples/regression-bayes.R`. All 40 cells of the training matrix. |
| Sigmoid holdouts and inner ensembles | N, E, D | `test-sigmoid-holdout.R`, `test-sigmoid-processes.R`, `test-binary-ensemble.R`; `extdata/sigmoid-reference.csv`, `extdata/sigmoid-line-search.csv`; `examples/sigmoid-holdout.R`, `examples/binary-ensemble.R`. Direct outputs match sklearn's smoothed-target fit within `1e-7` on identical inputs; constant P keeps the exact zero-slope solution (D). The composition itself is an R extension (E). |
| Tailor logistic holdouts and ensembles | E | `test-tailor-holdout.R`, `test-tailor-logistic-contract.R`, `test-tailor-processes.R`, `test-tailor-boundary.R`, `test-multiclass-ensemble.R`; `examples/tailor-holdout.R`, `examples/multiclass-ensemble.R`. Python has no tidymodels postprocessing. |
| Tailor multinomial holdouts and ensembles | E, L | `test-tailor-multiclass.R`, `test-tailor-multinomial-compositions.R`, `test-tailor-multiclass-processes.R`; `examples/tailor-multiclass-holdout.R`, `examples/multiclass-ensemble.R`. The P fit uses probably's fixed 100 `nnet::multinom()` iterations; weakly informative inputs can fail to converge, and the composition then fails completely with context (L, maintainer decision of 2026-10-04). |
| Pairwise OvO postprocessing | E | `test-pairwise-postprocessing.R`, `test-pairwise-postprocessing-contract.R`, `test-pairwise-postprocessing-processes.R`; `examples/pairwise-postprocessing.R`. |
| Regression Tailor linear and reference isotonic postprocessing | E, N | `test-tailor-regression.R`, `test-tailor-regression-processes.R`, `test-isotonic-regression.R`, `test-isotonic-regression-processes.R`, `test-regression-ensemble.R`, `test-regression-postprocessing-compositions.R`; `examples/tailor-regression-holdout.R`, `examples/isotonic-regression-holdout.R`, `examples/regression-ensemble.R`. Isotonic values follow the semantics of sklearn's `IsotonicRegression(out_of_bounds = "clip")` and are checked against hand-worked values; there is no stored Python fixture. |
| The 80 fixed postprocessing compositions | E | `test-full-postprocessing.R`, `test-full-postprocessing-processes.R`; `examples/full-postprocessing.R`. Method x holdout/ensemble x Inductive/Cross x matched/full, each with native outer evaluation, last_fit and fresh RDS prediction. |
| Grid and Bayes selection inside postprocessed B | E | `test-postprocessing-grid.R`, `test-postprocessing-grid-processes.R`, `test-postprocessing-bayes.R`, `test-postprocessing-bayes-processes.R`; `examples/postprocessing-grid.R`, `examples/postprocessing-bayes.R`. A targeted 20 + 20 case matrix (five methods x joint/two-stage), not every Cartesian combination of further options. |
| Saved fits, fresh processes and workers | R | `test-integration-processes.R`, `test-schema-processes.R`, `test-binary-ensemble-processes.R`, `test-regression-ensemble-processes.R`, `test-multiclass-ensemble-processes.R`, `test-frozen-multiclass-processes.R`, `test-tuning-replay-grid-ovo.R`, `test-tuning-replay-bayes-ovr.R`; `examples/full-postprocessing.R`. Predict never refits; complete pre- and postprocessing state travels with the fit. |

## Counter-comparisons

A counter-comparison checks other software that offers a vennabers procedure
on identical arrays. It is not binding and makes no parity statement:
differences are explained, never fixed, and no tolerance is widened for them.
Where such software disagrees with the binding reference, the reference
applies; a proven reference defect becomes a D entry. Counter-comparisons are
re-run against current releases at each minor release; each entry names the
versions it was last checked with. The scripts live in `tools/` of the source
repository, outside the package build and tests, and Python runs only in a
temporary virtual environment (`tools/counter-comparison.sh`, instructions in
`tools/RELEASE.md`).

MAPIE and calibrated-explanations are compared by
`tools/counter-comparison-mapie-ce.py` on the stored classification fixtures:
707 binary calibration sets (the 607 folds of the 105 Cross cases and 100
randomized sets) with 17,444 new rows, the 105 Cross cases with their folds
(2,520 rows), and 33 one-vs-one/one-vs-rest cases with two to four classes
(372 rows), for Cross with a shared two-fold plan. Precision is `NULL`, 0, 2,
-1 and 4, tolerance `1e-10` absolute. As a control, the main reference matches
vennabers everywhere (at most `1.22e-15`) when multiclass rows are normalized as
vennabers normalizes them; MAPIE and the main reference do not normalize rows
themselves. Last checked on 2026-10-29 at the 1.1 minor checkpoint with the
vennabers 1.1 development sources, R 4.6.1 and Python 3.12 (NumPy 2.5.4) on
macOS arm64; the earlier runs on 2026-10-25 with vennabers 1.0.0 and on
2026-10-28 gave identical results.

### MAPIE

- **Version:** MAPIE 1.6.0, tag `v1.6.0`, commit
  `f1cc3d07460b2d7198f557d40d60cd563c51822b`; module SHA-256
  `ce6872a6d6cf5e830c4ae7a68db0c9d92d2a259fced8f829f165ab556cd13a78`
  (`mapie/_venn_abers.py`).
- **Compared:** `VennAbersCalibrator(cv = "prefit")`, the private core, the
  Inductive and Cross calibrators over stored per-fold arrays (binary and
  one-vs-one) and the private one-vs-rest function; lower and upper values, Log
  and Brier points, class decisions.
- **Result:** The lower value matches everywhere. The upper value differs
  exactly where a new score lies above the largest (rounded) calibration
  score: MAPIE returns the last slope of the convex minorant there instead
  of 1. Its `calc_p0p1` lacks the line `p1[-1, 1] = 1.0` that the main
  reference added in 1.5.4; MAPIE builds on the code before that fix. Without
  rounding this affects 1,686 of 17,444 binary rows (up to 0.98 in the upper
  value, 0.48 in the Log point), with `precision = -1` 14,450 rows; Cross,
  Brier, one-vs-one and one-vs-rest inherit it. With that line added, MAPIE
  matches vennabers within `1e-10` in every compared path, except one Cross
  one-vs-one row at the R/NumPy rounding boundary 0.575 with `precision = 2`
  (see "Binary Inductive VA endpoints"). All other class differences are
  ties: at a Log point of exactly 0.5, MAPIE's formula (like the main
  reference's) gives `0x1.fffffffffffffp-2` and class 0, while vennabers gives
  0.5 and the event.
- **Not comparable:** MAPIE's own training paths (its own splits, `shuffle`
  on by default where the main reference has it off, per-pair folds in Cross
  multiclass), its public one-vs-rest, Brier on the prefit path, and
  regression, which MAPIE does not offer.
- **Switching:** `cv = "prefit"` corresponds to `venn_abers()` on existing
  predictions. MAPIE's prefit path silently ignores `loss` and returns Log
  even for `"brier"`; vennabers applies `loss`. Above the largest calibration
  score, vennabers returns the upper value 1, as the main reference does. Two
  classes take MAPIE's binary path; see "Two-class factor truth".

### calibrated-explanations

- **Version:** calibrated-explanations 1.0.2, tag `v1.0.2`, commit
  `609d7b728b76b7bfc1e831a9ca7986689c1b43d1`; module SHA-256
  `830ee7f559567cb6ff59cca7bb2befaa39967594289641db283a9611e30c9e5d`
  (`calibrated_explanations/calibration/venn_abers.py`).
- **Compared:** `calibration.VennAbers` with stored calibration probabilities
  and a table prediction function, binary and multiclass, Log; against
  vennabers with `precision = 4` only.
- **Result:** It calls the main reference's kernels but always rounds the
  calibration scores to four decimals; its public interface offers no
  unrounded calibration. Against `precision = 4` it matches exactly, with two
  explained differences. A calibration set holding only label 1 is recoded to
  label 0 and calibrated as all negative (a defect; 98 of 707 sets, 2,387 rows,
  up to 0.99). Classes come from `np.round()`, so a point of 0.5 gives class 0
  (a rule difference; 647 rows). Multiclass is one-vs-rest with Log:
  `normalization = "simplex"` matches `method = "ovr"` exactly in points,
  bounds and classes. The default `"scale"` also divides the bounds by the row
  sum of the points, so its bounds are not Venn-Abers values.
- **Not comparable:** Brier, Cross, one-vs-one and unrounded calibration;
  Mondrian categories, difficulty scaling and probabilistic regression
  `P(y <= t)`, which vennabers does not offer.
- **Switching:** the binary default corresponds to
  `venn_abers(truth, probability, precision = 4)`, multiclass to
  `method = "ovr"` with `normalization = "simplex"`. At a point of exactly 0.5
  vennabers chooses the event.

### fast-ivap (ptocca/VennABERS)

- **Version:** fast-ivap 1.1.0, tag `v1.1.0` of the repository
  `ptocca/VennABERS`, commit `d3d19a647f39f3556fcb11bdd01ff428b8a6287c`, wheel
  from PyPI; module SHA-256
  `3d1fb85989ddc4523709e6292ae5bf568a6c1c3868d51df3ba99580fad57c703`
  (`fast_ivap/_api.py`),
  `6172a4dedf429862893484f0e179736adaa9e8d9900c721b3b40c32047eabdba`
  (`fast_ivap/_reference.py`) and
  `9075dda6e9bf36ed3506e82620316ffceb9c245d357a601dbff95b9ac8da444a`
  (`fast_ivap/sklearn.py`), identical to the files of that commit; the
  compiled core comes from the wheel. MIT licence (Paolo Toccaceli, Royal
  Holloway, University of London); installed only in the temporary
  environment, no code is taken over. Last checked on 2026-10-29 at the 1.1
  minor checkpoint with the vennabers 1.1 development sources, R 4.6.1 and
  Python 3.12 (NumPy 2.5.4) on macOS arm64, by
  `tools/counter-comparison-fast-ivap.py`; the first run on 2026-10-28 gave
  identical results.
- **Why:** the only Venn-Abers implementation that does not derive from the
  main reference. It follows Vovk, Petej and Fedorova (2015), Algorithms 1 and
  2, and obtains the lower value by symmetry; until 0.2 it was the original
  `VennABERS.py`, rewritten as the package fast-ivap in 1.0.0.
- **Compared:** `IVAP` with the compiled and the pure-Python backend,
  `sklearn.VennAbersCalibrator`, and Cross as one `IVAP` per fold merged
  along the folds by `merge_log_minimax()` or `merge_brier()`; lower and upper
  values, Log and Brier points, class decisions; against vennabers with
  `precision = NULL`. Inputs are the 707 binary calibration sets of the
  fixtures above with 17,444 new rows (821 new scores equal to a calibration
  score, 2,129 below and 2,312 above all of them; 100 sets with label 0 only,
  98 with label 1 only; 8,637 rows of sets with tied scores), the 105 Cross
  cases (2,520 rows), and 13 constructed sets with 2,732 calibration and 1,316
  new rows: ties at one, two and three decimals, label 0 only, label 1 only,
  a single calibration point of either label, one and two distinct scores,
  scores at 0 and 1, labels falling with the score and a narrow score range,
  each with every calibration score, the midpoints between them and points
  outside their range as new scores.
- **Result:** Inductive matches bitwise in all 18,760 rows with both backends,
  and so does the calibrator in its 13,828 rows with both labels, including
  class decisions: it chooses the event at a Log point of at least 0.5, as
  vennabers does. This holds for new scores equal to, below and above the
  calibration scores, for one label only and for ties. Cross Brier matches
  bitwise. Cross Log differs in 1,044 of 2,520 rows by at most `1.67e-16`:
  fast-ivap computes `GM(p1) / (GM(1 - p0) + GM(p1))` with geometric means,
  vennabers the algebraically equal
  `plogis(mean(log(upper)) - mean(log1p(-lower)))`; the values per fold are
  bitwise equal. Maximum absolute difference `1.67e-16` at tolerance `1e-10`.
  As a control, the main reference matches vennabers on the same arrays,
  including the constructed sets, within `2.22e-16`.
- **Not comparable:** `precision`, since fast-ivap does not round; the
  calibrator on sets with one label only, which it rejects (`IVAP` accepts
  them); Brier class decisions, for which fast-ivap has no rule; Venn
  categories (`predict_blocks()`, `block_sums()`) and the multiclass Venn
  predictors built on them, which vennabers does not offer.
- **Switching:** `IVAP().fit(scores, labels).predict_p0_p1(new)` corresponds
  to the lower and upper values of `predict(venn_abers(truth, probability),
  new)`, `predict_proba()` to the Log point and `merge_brier()` to
  `loss = "brier"`; Cross is `cross_venn_abers()` with the same folds.
  fast-ivap takes any finite scores, vennabers probabilities in `[0, 1]`.
  By fast-ivap's changelog, versions up to 0.2 were wrong for a new score
  equal to a calibration score and for the upper value above all calibration
  scores; vennabers agrees with 1.0.0 and later.

### reliabilitydiag

- **Version:** reliabilitydiag 0.2.1 from CRAN, with dplyr 1.2.1 and tibble
  3.3.1 and without monotone. Last checked on 2026-10-29 at the 1.1 minor
  checkpoint with the vennabers 1.1 development sources, R 4.6.1 on macOS
  arm64, by `tools/corp-parity-reliabilitydiag.R`; the first run on 2026-10-21
  with vennabers 1.0.0 gave identical results.
- **Compared:** the CORP estimate and both resampling bands of `corp_plot()`
  against `reliabilitydiag(region.method = "resampling")` with the same data
  and seed; consistency band as `region.position = "diagonal"`, confidence
  band as `"estimate"`. Eight cases (continuous, small, discrete with 0 and 1,
  ties, inner estimates 0 and 1, one outcome only, three classes) with both
  bands and three seeds, 1,000 replicates, level 0.9: 48 runs.
- **Result:** maximum absolute difference 0 at tolerance `1e-10`. Two
  differences are by design. A replicate that draws one unique probability
  makes the reference recycle a scalar through its replicate matrix; the
  cases are sized so that this has a chance below `1e-9`. With one outcome
  only, vennabers omits the confidence band with a warning, which the
  reference still computes.
- **Switching:** `corp_plot(seed = s)` corresponds to `set.seed(s)` followed
  by `reliabilitydiag()` as above. With monotone installed, the reference fits
  PAV through it instead of `stats::isoreg()`.

## Outside the agreed scope

- Out-of-fold postprocessing followed by a complete engine refit, further
  postprocessing methods, foreign engines beyond `model_adapter()` callbacks,
  Tailor step sequences, and other new public constructors.
- General group or time-series procedures (group IDs, rolling windows,
  horizons, embargoes, online updates) beyond the reference splits; the
  manual cores remain available for external splits.
- Standalone multicalibration, quantile or conformal extensions.
- Reproducing every paper dataset or benchmark table, and any blanket promise
  of better accuracy, log loss, Brier score or RMSE, or of interval coverage.

## Open gaps

No known gap remains inside the agreed scope. Platform checks and benchmark
runs are release evidence, not capabilities; this index makes no claim for
any platform.
