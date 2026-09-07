# vennabers 0.3.0 (release candidate)

- Package standalone examples under `inst/examples`, available after installation
  through `system.file("examples", package = "vennabers")`. Checkout commands
  formerly using `examples/` now use `inst/examples/`.
- Prepare one source artifact for all platform checks and a separate comparative
  benchmark runner. Release approval is pending the evidence in
  `tools/acceptance-v03.md`; the version number does not assert approval.

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
  no continuing R 4.1 promise. Recheck the floor at final v0.3 acceptance.
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
