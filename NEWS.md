# vennabers 1.0.0

## Additions

- Add `venn_abers_one_hot()`, which represents existing class decisions as a
  double 0/1 matrix with one column per class. It accepts the factor from
  multiclass `predict(type = "class")` or `venn_abers_decode()$class`, the
  logical vector from binary `predict(type = "class")` (columns `FALSE`,
  `TRUE`) and `.pred_class` tables from workflows. It never chooses a class
  from probabilities, so binary ties stay with the event and multiclass ties
  with the first level. All classes keep their columns; missing decisions give
  `NA` rows. Prediction methods and their output formats are unchanged. See
  the installed example `one-hot-classes.R`.
- Add `model_adapter(mode, fit, predict)`, which turns your own
  `fit(x, y)` and `predict(object, new_data)` functions into an unfitted
  parsnip model for workflows and `calibrated_workflow()`, without registering
  an engine. Each local fit trains a fresh model on its prepared rows:
  Inductive or Cross sources, the full-model refit and outer resamples.
  Calibration rows never reach `fit`. Classification returns a matrix with one
  column per original class, also for two classes; columns are matched by
  name. Regression returns one number per row. Malformed output fails with a
  concrete error and the fold or refit context. The local seed applies to
  callbacks that use R's generator. Saved fits keep the functions; bind
  helpers and settings locally so they work in a fresh process. Fitted
  adapter workflows can be adopted frozen with `calibrate_workflow()`.
  Adapters also work in pairwise OvO (a binary callback per class pair), in
  Sigmoid, Tailor and numeric isotonic postprocessing (fitted on B, also in
  inner ensembles) and in Grid or Bayes searches over calibration and recipe
  parameters. Adapters have no tunable parameters of their own. The
  `glm_link` Sigmoid input still requires the native GLM engine. See the
  installed example `model-adapter.R`.
- Add independent Inductive sizes `training_size` and `calibration_size` to
  `calibrated_workflow()`, like sklearn's `train_size`/`test_size`. A value in
  (0, 1) is a proportion of the local rows (training rounds down, calibration
  up), a whole number is a row count, and a missing size is the complement.
  Rows in neither set form the unassigned set: the matched source model, its
  B/P postprocessing and the calibrator never use them, while
  `prediction_model = "full"` learns on all local rows. Classification draws
  are stratified with exact totals unless `strata = FALSE`. Both arguments
  default to `NULL`, which keeps `calibration_prop` and its draw unchanged;
  they cannot be combined with Cross, explicit `calibration_prop`, `splits` or
  `tune()`. Pairwise multiclass resolves the sizes on each class pair, with
  unassigned rows per pair, and calibration selection on the final-fit F.
  Calibration and joint model searches fit Venn-Abers candidates that resolve
  the sizes on their resample rows, so they accept only proportions; two-stage
  model searches also accept row counts. Fits with sizes store `unassigned`
  positions and resolved counts, and `print()` shows them. See the installed
  example `inductive-sizes.R`.

## Guides

- Document fixed engine options and model-internal validation in
  `?workflow_training` and the workflows guide. Options set with
  `parsnip::set_engine()` reach every local fit (sources, class pairs, the
  full-model refit and postprocessing B), each on its own rows; extra fit
  arguments to `calibrated_workflow()` or `fit()` stay rejected. Native
  XGBoost early stopping (`stop_iter` with `validation`) splits its validation
  share from each local fit's prepared rows. A table lists the rows each local
  fit learns from. No new fit-data interface is added, and no support is
  promised for observation weights, offsets or an external `eval_set`. xgboost
  stays outside Suggests; `tools/xgboost-early-stopping.R` runs the real fits.
  See the installed example `engine-options.R`.
- Publish all 42 standalone examples in four annotated articles with contents
  lists for manual calibration, workflows, postprocessing and Grid/Bayes
  selection. The articles include the installed script sources without running
  their fits during documentation builds. `?vennabers_examples`, the package
  overview and related function help link to the collections, also available
  through `vignette()` and `browseVignettes()`.
- Add a package overview at `?vennabers`, project and issue links in package
  metadata, and a pkgdown website configuration with grouped reference topics
  and all three guides. `tools/build-docs.R` builds the site locally from the
  source package, excluding internal project notes.
- Add three executable HTML vignettes covering manual Inductive/Cross binary,
  OvO/OvR and regression calibration; trainable and frozen workflows; and
  Grid/Bayes tuning with independent assessment. Register the knitr builder
  and build the guides into release candidates for access through `vignette()`.

## Release verification

- Version the v0.9 acceptance matrices and benchmark sources. The repository's
  `tools/build-candidate.R` exports a specific commit, builds its source package
  and PDF manual, checks packaged tests/fixtures/examples and records SHA-256
  identities. Platform and benchmark evidence must name that candidate.
- CRAN checks run the short test profile. `tests/cran-long-tests.txt` lists the
  process, worker and integration matrix files excluded there; all remain in
  the source package. `NOT_CRAN=true` enables the complete suite, and
  `tools/verify.R` always runs it locally with bounded parallelism.

## Compatibility promise

- From 1.0.0 on, the user-facing functions listed in
  `help(package = "vennabers")`, their arguments and defaults, and the output
  formats their help pages document stay compatible throughout 1.x.
  Documented formats include prediction columns and types, `type = "details"`
  and `venn_abers_details()` tables, the documented postprocessing records
  and `venn_abers_tuning()` fields. Incompatible changes wait for 2.0.0.
  New options keep the previous behaviour unless they are enabled explicitly.
- Documented bug fixes may still change numerical results; NEWS names each one.
- The parsnip engine entry points `fit_vennabers()`, `fit_vennabers_proxy()`
  and `predict_vennabers_*()` are exported only for model registration
  (`?vennabers-engine`). Use `calibrated_workflow()` instead.
- The minimum R version is separate from this promise. Each release supports
  at least the R minor series before it and may raise the minimum, noted
  here; the minimum of a published release never changes afterwards.
- The installed `PARITY.md` (`system.file("PARITY.md", package = "vennabers")`)
  indexes the evidence for every capability and keeps numerical parity with
  Python venn-abers 1.5.4, training/data parity, R extensions, reference
  deviations and accepted limits apart. Public parity statements refer to it.
- Maintainer decision (2026-10-04): the Tailor multinomial P fit keeps
  probably's fixed limit of 100 `nnet::multinom()` iterations and its complete
  failure with context. This is an accepted limit of the 1.x contract, with no
  `maxit` option. README, `?calibrated_workflow` and the installed examples
  `tailor-multiclass-holdout.R`, `multiclass-ensemble.R` and
  `full-postprocessing.R` describe it: a B engine's `maxit` setting does not
  change the P postprocessor's limit, and numerical VA parity on identical
  valid inputs is unaffected.

## Migration from the previous release

- No code changes are needed. Existing exported functions keep their arguments
  and defaults; new functions and opt-in arguments are listed under Additions.
- `tools/migration-v09.R` in the source repository fits 22 representative
  paths with 0.9.0 in a fresh process: manual cores, shared, pairwise,
  schema-encoded and frozen workflows, Grid- and Bayes-tuned fits and
  postprocessing compositions. In all of them, saved 0.9.0 objects return
  identical predictions, `venn_abers_details()` and `venn_abers_tuning()`
  (apart from run times and native tune objects) in the current version.
- Refit Sigmoid compositions to obtain the corrected optimizer result below;
  saved 0.9.0 fits keep their stored coefficients. In the checked paths all
  other refits reproduce 0.9.0 exactly. For a saved specification `spec` and
  its training data:

  ```r
  refitted <- generics::fit(spec, training)
  venn_abers_details(refitted, new_data)$postprocessing
  ```

## Fixes and changes

- Fix Sigmoid outputs drifting from scikit-learn by up to 1.7e-5: L-BFGS-B now
  keeps SciPy's ten correction pairs (`lmm = 10`) instead of R's five. sklearn's
  tolerances stop short of the exact optimum, so the optimizer path decides the
  result. Across 2,000 random P sets, every nonconstant case now agrees within
  2.1e-8. The sklearn fixture gains a 30-row concentrated case; constant P
  keeps the exact zero-slope solution.
- Fix Bayes selection failing when a tuning parameter ID is `status`,
  `estimate` or `reason`: candidate metadata overwrote the parameter column.
  Bayes candidate tables now suffix such IDs (for example `status_1`); selected
  values and native results keep the original IDs. Grid tables keep parameter
  values separately in `grid` and were not affected. The ID `id` remains
  unsupported because native tune uses it for resample identities.
- Bayes diagnostics also keep tune's messages and warnings as `notes` for
  steps that fail or repeat a candidate.
- Fix `print()` of `calibrate_workflow()` results, which failed since v0.7. It
  now reports the unchanged adopted workflow, zero base fits and the
  calibration rows.
- Frozen class predictions keep an ordered trained outcome ordered, as the
  original workflow does.
- `?calibrate_workflow` and `frozen-binary.R` show the loss-only Log/Brier
  choice on separate validation rows without refitting. The help page also
  covers adopting workflows fitted by native `fit_resamples()`/`last_fit()`.
- The outer evaluation audit rejects missing or empty saved extracts and
  mismatched extract configurations even when predictions and metrics are complete.
- The pairwise OvO examples print the fitted full-transfer state instead of fixed
  cost text and no longer describe automatic local selection as pending.
- `?calibrated_workflow` describes the supported scope without version history,
  and `?venn_abers` and `?venn_abers_tuning` name the installed binary-option,
  OvR and Grid/Bayes examples.

## Package metadata and optional dependencies

- Package metadata: René-M. Kruse is the sole author, maintainer and copyright
  holder (`aut`, `cre`, `cph`); the placeholder author "Venn-Abers Authors" is
  removed from `Authors@R` and `LICENSE`. The Description cites Vovk and Petej
  (2014), Vovk, Petej and Fedorova (2015) and, for the one-vs-one coupling,
  Manokhin (2017), and names the 'Python' package 'venn-abers' as the numerical
  reference.
- `Suggests` now declares `rpart`, which tests and an installed example use,
  and requires `dials (>= 1.4.3)`, the lowest version that `tune (>= 2.1.0)`
  accepts.
- Tuning checks `tune`, `dials` and `yardstick` against their declared minimum
  versions when `calibrated_workflow(tuning = ...)` is called and again when
  the specification is fitted, with an error that names the package and
  version. Tailor postprocessing also repeats its `tailor`/`probably` check at
  fit time. Nothing is installed automatically. All three errors now end with
  "; install or update it explicitly.", and the integration error starts with
  "Workflow integration requires optional package ..." because it comes from
  every workflow entry point, not only `calibrated_workflow()`.
- The `?local_calibration_splits` example and the installed examples that the
  help pages source (`full-model-workflow.R`, `encoded-binary.R`,
  `encoded-multiclass-regression.R`) now run only when every workflow
  integration package is available, instead of failing when only some are.

## Release status

- Not yet released. Still outstanding before 1.0.0: the source package with
  PDF manual as a fixed candidate, `R CMD check --as-cran` on Linux x86_64,
  Windows x86_64, macOS Intel and macOS ARM with the current and previous R
  minor series, the Linux runs without tidymodels, with the declared minimum
  dependencies and on R-devel, and the Linux benchmark series against 0.9.0.
  Local macOS checks are not evidence for these runs.

# vennabers 0.9.0 (local macOS acceptance candidate)

- Scope: 80 fixed postprocessing compositions (method x holdout/inner ensemble
  x Inductive/Cross x matched/full) for binary and pairwise OvO (Sigmoid,
  Tailor logistic), shared OvO/OvR (Tailor multinomial from three classes,
  Tailor logistic for two) and regression (reference isotonic, Tailor linear),
  each with joint or two-stage Grid/Bayes selection inside B. B learns recipe
  and engine, P the postprocessor, C the unchanged VA calibrator, and F is the
  final fit data of a full composition. `?calibrated_workflow` lists costs,
  retained pairs and limits.
- Known limit: Tailor multinomial fits use probably's `nnet::multinom()`
  defaults (at most 100 iterations) and cannot be tuned through the fixed
  Tailor arguments; weakly informative probabilities can stop unconverged,
  which fails the fit.
- Not included: out-of-fold postprocessing with a complete engine refit,
  arbitrary foreign engines or Tailor step sequences, further methods and new
  constructors.
  Frozen workflows keep their contract.
- Fix Sigmoid rejecting converged fits: with sklearn's tolerance, L-BFGS-B can
  end its line search at the optimum (`ABNORMAL_TERMINATION_IN_LNSRCH`). Such a
  fit is now kept when its mean gradient per P row is at most `pgtol`
  (sklearn keeps such a point without any check); other nonconvergence still
  fails without a fallback.
- Two-stage model search strips a Tailor postprocessor once per search instead
  of once per candidate. The per-candidate check made tuned two-stage fits about
  25% slower than in v0.8 even without postprocessing.
- The 80-combination and tuned postprocessing examples now use repeated outer
  folds and check exact `(id, id2, .row, .config)` coverage, notes and saved
  extracts through the installed `check_outer_identities()` helper.
- Older entries name `tools/acceptance-v0*.md` records that are no longer in
  the source checkout. They are historical references, not available evidence.
- Acceptance is local to macOS. GitHub Actions stay disabled; the eight
  R/platform combinations, Linux core-only, minimum-dependency and R-devel runs
  and the Linux reference benchmark are deferred to v1.0 and not claimed here.

- Allow stepwise Bayes selection with every postprocessing composition, using
  the same B-local searches as Grid. Only complete valid candidates feed the
  next GP; a failed inner pair, missing row or invalid main score excludes the
  whole candidate. Proposals that tune drops after failing everywhere are now
  kept as excluded candidates with global IDs and spend budget instead of
  ending the search as repeats; Bayes diagnostics record native notes per step
  and the too-few-initial-points error lists its reasons.
- Allow joint and two-stage Grid selection with every postprocessing method,
  holdout/ensemble, VA, pairwise and full path. Each B searches locally
  (each VA source, inner pair and full composition); P, C, A and S stay out.
  Two-stage scores the raw engine first; pairwise joint Grid then selects per
  local B instead of a Cartesian pair grid. Diagnostics name every inner search.
- Add full-model transfer for every fixed holdout/ensemble postprocessing path.
  Preserve held C values and VA calibrators, fit an additional complete B/P
  composition per allowed domain, and retain only its prediction workflows.
  Diagnostics include the final plans and actual costs; predictions reuse each
  full composition across VA folds. Cover all 80 fixed combinations with native
  outer evaluation, last_fit and fresh RDS prediction.
- Add pairwise OvO holdout and ensemble postprocessing with Tailor logistic
  or either Sigmoid input before matched Inductive/Cross VA. Preserve local
  pair/fold plans, class identities, RNG order and complete prediction paths.
  Include pair diagnostics, decoded names, native evaluation and fresh RDS checks.

- Add matched IVAR/CVAR inner ensembles with Tailor-linear or numeric
  reference isotonic postprocessing. Average complete pair predictions before
  VA, retaining method-specific validation, local diagnostics and all pairs.
  Cover numeric references, data roles, native evaluation and fresh RDS prediction.

- Add shared OvO/OvR inner ensembles for matched Inductive/Cross VA: explicit
  Tailor logistic for two classes and multinomial for three or more. Average
  complete class vectors before VA; retain local pair diagnostics, schema and
  fit counts through native evaluation and fresh RDS prediction.

- Add binary inner ensembles for matched Inductive/Cross VA with Tailor
  logistic or either Sigmoid input. Validate local P partitions, retain all
  complete B/P pairs, and average their aligned probabilities equally before
  VA. Preserve pair diagnostics, fit counts, schema and fresh RDS prediction.

- Add matched IVAR/CVAR numeric isotonic holdouts using unweighted P fits,
  frequency-aware ties, linear interpolation and constant edge extension.
  Save the complete B workflow and isotonic support for prediction; cover
  native evaluation, schema decoding and fresh-process restoration.

- Add binary Sigmoid holdouts with explicit probability or public GLM-logit
  inputs, sklearn-compatible smoothed targets, complete saved prediction
  state, diagnostics and native evaluation. No Python runtime is required.

- Add matched fixed-parameter IVAR/CVAR Tailor-linear holdouts through
  `postprocessing`, with unstratified B/P plans, finite-input, rank and
  convergence checks, numeric diagnostics and unchanged regression cores.
  Include public Tailor parity across scales, data-role checks, native
  evaluation, fresh-process RDS checks and an installed regression example.

- Add shared OvO/OvR Tailor holdouts: explicit logistic for two classes and
  multinomial for three or more, with full-rank and convergence checks. Preserve
  multiclass decoding, single-row predictions and complete native evaluation.
- Add binary Tailor logistic holdouts through `postprocessing` for matched
  Inductive/Cross VA with fixed parameters. Recipes and engines learn on B,
  Tailor learns on disjoint P, and held-out C trains the unchanged VA core.
- Validate all local B/P plans before learning and reject unsupported methods,
  incompatible steps, deficient designs and unsuccessful learned states.
  Preserve complete source workflows, plans and fit diagnostics through RDS.
- Add an installed example covering complete native resampling and last_fit.
  Postprocessing tuning remains unimplemented.

# v0.8 development candidate (acceptance open)

- Add local Grid and Bayes selection with joint and two-stage strategies for
  binary, shared OvO/OvR, pairwise OvO and regression workflows, with matched
  or full prediction models. Model/recipe and calibration options can be
  selected; fixed values remain fixed.
- Keep automatic calibration-option selection on a separate S portion and
  retain candidate eligibility, local plans, budgets, errors and final search
  state through `venn_abers_tuning()` and RDS restoration.
- Reuse pair-specific source/full fits and predictions across joint Grid
  combinations. Pair fits use independent RNG scopes so reuse does not depend
  on candidate order; diagnostics report actual and reused fits.
- No release is approved yet. Local checks, missing support runners, the v0.7
  gate and the benchmark protocol are recorded in `tools/acceptance-v08.md`.

# vennabers 0.7.0

- Add `prediction_model = "full"` (default: `"matched"`) to train one extra
  recipe/model on all local fit rows, including calibration rows, while retaining
  the original held-out calibrators. It is available for binary, shared or
  pairwise OvO/OvR, and regression Inductive and Cross workflows.
- `"full"` costs one extra fit per shared/binary/regression workflow (2 fits for
  Inductive; K+1 for K-fold Cross), or one per OvO pair with
  `model_training = "pairwise"`; source models are discarded after fitting.
- Add `model_training = "pairwise"` for OvO (default: `"shared"`), training a
  separate binary workflow and local calibration plan for each class pair.
- Full-model transfer is fixed at fit time and does not automatically transfer
  matching-model calibration or coverage guarantees, nor promise better quality.

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
