# vennabers (development)

- Extend `prediction_model = "full"` to Inductive and Cross regression workflows.
  Keep held-out numeric predictions/truths and fold moderation; fit a fresh full
  recipe/model and discard temporary source workflows. IVAR's weighted merger
  and CVAR's separate equal-weight points/bounds remain unchanged. Trainable
  regression details and descriptive aggregates identify mode and model sources;
  native `.pred`, decoding and frozen outputs retain their contracts. Add offline
  component/reconstruction, role/count, outer evaluation and fresh RDS checks,
  plus an installed matched/full RMSE/MAE example. No coverage or quality
  guarantee is implied. Python's option belongs to the lower `VennAbersCV` class.

- Extend full-model transfer to shared Inductive/Cross OvO and OvR workflows.
  `model_training = "shared"` is the multiclass default and currently the only
  offered training option; binary/regression reject explicit training options.
  This is an R extension, separate from pairwise model training. Complete
  held-out class matrices/truths remain available after source models are
  discarded. Native/decoded details retain training mode and model source.
  Binary aggregation precedes multiclass combination; class ties, precision
  and yardstick conventions remain unchanged. Add component reconstruction,
  outer evaluation, fresh-process restoration and an installed example.

- Add explicit binary `prediction_model = "full"` for Inductive and Cross
  workflows; `"matched"` remains the default. A fresh full recipe/model uses the
  entire local fit domain while held-out values and calibrators remain unchanged.
  Discard temporary source models after success; retain calibration provenance.
- Full transfer costs 2 or K+1 base fits and one model prediction per nonempty
  batch. Details/print identify mode and model source. Native prediction, loss
  overrides, encoding, outer resampling, last_fit and RDS restoration are covered.
  Frozen calibration has no new training path. No automatic calibration/coverage
  guarantee or quality improvement follows from transfer to a different model.

# vennabers 0.6.0

- Prepare a local v0.6 candidate and cumulative benchmarks, including separate
  schema/encoding/decoding costs and frozen calibration on new data. Actual
  checks and open platform/performance gates are in `tools/acceptance-v06.md`.
  GitHub Actions remains disabled by user decision; no full release is claimed.
- Migration: R >= 4.5.0 and manual APIs remain unchanged. Encode explicitly
  before new training and retain that schema for frozen adoption and decoding.
  Already learned postprocessing is preserved; newly learning postprocessing,
  pair training, full-model transfer and tuning remain later-release work.

- Document and verify ordered Inductive holdouts and mixed/non-shuffled ordinary
  and stratified Cross partitions through existing explicit local plans. Add
  installed paper-oriented examples for all eight training paths, with explicit
  rounding, data roles, exact training complements and statistical limits.

- Preserve the original training schema in `calibrate_workflow()` for binary,
  shared OvO/OvR and IVAR. Check learned names, mode, class order and retained
  bindings; preserve encoded native outputs and decoded identities/diagnostics.
  Add final-postprocessor parity, no-learning and fresh-process RDS checks,
  plus an installed example and explicit legacy-workflow limits.

- Extend `calibrate_workflow()` to shared OvO/OvR (including two classes) and
  moderated IVAR. Reuse final frozen workflow outputs, native predictions and
  method-specific details. Preserve requested/effective moderation and add
  learned-postprocessor, boundary, no-refit and fresh-process persistence checks.

- Add `calibrate_workflow()` for fully fitted binary workflows, retaining learned
  recipes and postprocessors. Predict and shared details reuse the binary core,
  support loss overrides and preserve classes and empty results. Add no-learning
  guards, final-probability parity checks and fresh-process persistence tests.

- Extend reversible schemas to shared OvO/OvR and regression for Inductive and
  Cross workflows. Decode original class/truth identities, regression points,
  all available inner details and Cross regression aggregate bounds. Add installed
  examples, manual-core comparisons, outer evaluation audits and fresh-process
  worker checks for all six additional paths.

- Add explicit binary naming schemas, lossless input encoding, and role-based
  decoding of predictions, truth, identities and details. `calibrated_workflow()`
  now accepts `schema` for Inductive/Cross fitting and ordinary outer resampling.
  Schemas preserve exact original names and class/event order without changing
  the numerical cores or the direct naming contract.

# vennabers 0.5.0

- Normalize class matrices with binary64 column-order additions on every
  platform. Extended-precision row sums on x86 could move a prediction across
  a calibration knot after calibration-only rounding. This fixes the existing
  multiclass reference checks without relaxing their tolerance or changing the
  rounding rule; affected x86 predictions may change.

- Prepare the eight native integration paths for acceptance, with one source
  candidate, mandatory current/minimum dependency checks and a separate manual
  core check without tidymodels. Extend benchmarks with complete Fit/Predict and
  outer evaluation; retain all 16 manual cases for comparison to approved v0.4.
  `tools/acceptance-v05.md` records actual results and missing release evidence.
  The historical local-only v0.4 approval does not approve v0.5.
- Migration: manual APIs, numerical tolerances and R >= 4.5.0 are unchanged.
  Install optional integration packages explicitly; the core does not load them.
  Frozen workflows, name encoding and ordered reference holdouts follow in v0.6;
  pair training/full-model transfer in v0.7, tuning in v0.8 and learned
  postprocessing in v0.9. No complete Python training parity is claimed.

- Add Inductive and Cross regression to `calibrated_workflow()`, using the base
  model's regression mode and existing IVAR/CVAR cores. Validate every fold's
  moderation before training; retain requested/effective moderation and sizes.
  Native double `.pred` outputs, separate fold bounds and descriptive Cross
  aggregates support complete outer RMSE/MAE evaluation with local preprocessing.
  Add scale-aware parity, data-role, fresh-process and worker checks and examples.

- Add Cross `classification = "ovo"` and `"ovr"` workflows with one shared
  multiclass model per fold complement and the existing manual Cross cores.
  Binary fold aggregation precedes OvO coupling/OvR normalization; details retain
  fold, row, event and pair/class identities for reconstruction. Empty OvO pairs
  fail before model learning; incomplete but nonempty subcalibrations stay valid.
  Add manual comparisons, complete outer evaluation, fresh-process restoration,
  reproducible workers and installed examples. This shared-fold procedure does
  not claim Python pair-model training parity.

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

- Add optional `calibrated_workflow()` for automatic binary Inductive calibration
  with raw-variable transport, local recipe learning, native probability/class
  prediction, loss overrides, and `venn_abers_details()` diagnostics.
- Preserve class names, split positions, complete base workflows and calibration
  state; validate unsupported options and naming collisions before inner learning.
- Add data-bound explicit IID holdouts and serializable local prepared-plan
  resolution, rejecting conflicting assignments before model training.
- Validate complete binary outer resampling with public collectors, local data-role
  checks, stored loss defaults, failure cases and fresh parallel worker repeats.

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
