# Development

- Add Inductive `classification = "ovo"` and `"ovr"` to `calibrated_workflow()`.
  One shared multiclass model feeds the existing factor/matrix cores, including
  for two classes. Preserve original class order, enforce complete named
  probabilities and calibration classes, and expose reconstructible binary
  subproblem details. Native Log/Brier predictions, local plans, repeated outer
  evaluation and fresh-process restoration have installed-package checks.
  `event_level` is binary-only; multiclass ties favor the first stored level.
  Installed examples use the optional recommended `nnet` package.

- Add binary `method = "cross"` to `calibrated_workflow()`: default five-fold
  local training, validated explicit/prepared partitions, matching retained
  workflows/calibrators, and native Cross predictions and fold diagnostics.
  Complete outer resampling uses one base fit per inner fold without a full model.
  Log/Brier loss, calibration rounding, names and local RNG contracts are preserved.

# vennabers 0.4.0

- Identify one regression source candidate for the eight-platform acceptance
  matrix and Linux R-devel. Extend the separate benchmark protocol with IVAR
  and CVAR at `m = 1` and `epsilon = 0.1`, retaining all twelve classification
  cases for remeasurement against v0.3. The maintainer approved v0.4 under the
  updated criterion of passing local tests. The approved candidate and unexecuted
  platform and Linux benchmark checks are documented in `tools/acceptance-v04.md`;
  those checks are no longer approval prerequisites. Publication remains separate.
- Migration from v0.3: regression uses separate real-valued entry points; existing
  classification calls, defaults and tolerances are unchanged. R >= 4.5.0 remains
  the previous-minor support floor for September 2026. No tidymodels, Python or
  network dependency is introduced for normal package use, tests or examples.

- Add `venn_abers_regression()` and its `predict()` method: asymmetric
  moderation, explicit `m` or `epsilon`, weighted point merging, and finite
  constant/zero-weight cases. Outputs are `prediction`, `lower`, `upper` in
  target units. Requested and effective moderation remain visible on the fit.
- Add offline Python 1.5.4 component fixtures, independent isotonic and merger
  checks, strict input contracts, saved-fit restoration, and an installed
  regression example with separate training/calibration/assessment data.
  Known reference lower-bound and zero-weight defects are documented in
  `inst/extdata/regression-reference.md`. Existing classification defaults stay
  unchanged.
- Add `cross_venn_abers_regression()` with complete IVAR fits per named fold,
  fold-local moderation diagnostics, stable equal-weight means of points and
  bounds, and reconstructible fold details. Include offline component/aggregate
  fixtures and an installed matching-fold `lm()` example with RMSE/MAE.

# vennabers 0.3.0

- Package standalone examples under `inst/examples`, available after installation
  through `system.file("examples", package = "vennabers")`. Checkout commands
  formerly using `examples/` now use `inst/examples/`.
- Prepare one source artifact for all platform checks and a separate comparative
  benchmark runner. The maintainer confirmed v0.3 approval and runs on Linux
  and Windows; `tools/acceptance-v03.md` retains the historical evidence and
  records that confirmation.

- Add manual Cross multiclass OvO/OvR with one shared calibration fold plan
  and a fold-named list of new class matrices. Merge binary folds with
  Log/Brier before coupling or normalization; expose reconstructible fold
  diagnostics, preserve global classes, and identify empty OvO pair/folds.
  Reuse the Inductive multiclass paths and binary Cross merger. No model
  training or dependencies added; no public manual Python Cross API claimed.
- Add explicit `method = "ovr"` to manual Inductive multiclass calibration;
  OvO remains the default. Calibrate each class against all remaining classes,
  apply binary Log/Brier regularization, then normalize the class points.
  Reconstructible class diagnostics, classes, scores and plots use the same
  stored class order and final probabilities. Manual Brier is an R extension
  over the pinned Python manual path. Stored fixtures cover both methods.
- Add manual Inductive one-vs-one multiclass calibration using factor truth
  and named probability matrices. Reuse binary rounding and Log/Brier
  regularization, with factor classes and reconstructible pair diagnostics.
  Extend scores and calibration plots to the same class schema; two-column
  Brier scores sum both class errors and ties select the first factor level.
  Existing binary vector calls retain their behavior and positional precision.
- Add optional native R rounding of calibration probabilities, prediction-time
  log-loss/Brier selection, logical binary classes, and public Cross fold
  details. Defaults, scores, plots, and stable Cross log aggregation remain
  unchanged. New installed-package tests cover Python 1.5.4 parity and R
  rounding boundaries without a Python runtime dependency.
- Raise the minimum R version to 4.5.0, the previous R minor series as of
  September 2026. New releases follow this rolling support window; there is
  no continuing R 4.1 promise. Recheck the floor for each release.
- Activate installed-package CRAN-mode checks on R 4.6.1 and 4.5.3 across
  Linux x86_64, Windows x86_64, macOS Intel and macOS ARM, with Linux R-devel
  as a non-blocking early warning.
- Separate package acceptance from the large IVAP benchmark; remove the
  historical fixed 10-second performance threshold.

# vennabers 0.2.0

- Add binary Cross Venn-Abers calibration for matched fold-model probabilities,
  with stable equal-weight log-loss aggregation and named fold matching.
- Add a runnable three-fold GLM example and extend the installed-package
  acceptance gate to cover it and the README examples.
- Preserve the v0.1 IVAP intervals, regularized probabilities, scores, plot,
  and printing behavior. R 4.1.0 remains the minimum; no dependencies added.
# Development

- Add optional `calibrated_workflow()` for automatic binary Inductive calibration
  with raw-variable transport, local recipe learning, native probability/class
  prediction, loss overrides, and `venn_abers_details()` diagnostics.
- Preserve class names, split positions, complete base workflows and calibration
  state; validate unsupported options and naming collisions before inner learning.
- Add data-bound explicit IID holdouts and serializable local prepared-plan
  resolution, rejecting conflicting assignments before model training.
- Validate complete binary outer resampling with public collectors, local data-role
  checks, stored loss defaults, failure cases and fresh parallel worker repeats.
