# vennabers 0.3.0 (development)

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
