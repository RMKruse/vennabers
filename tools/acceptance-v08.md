# v0.8 local acceptance record — 2026-09-23

**Decision: open.** This is a reproducible local check of the current v0.8
implementation, not a release approval. The v0.7 aggregate gate has no
`tools/acceptance-v07.md` in this checkout; ticket 06 is still marked open; and
the required runner and benchmark evidence below has not been produced. No
GitHub or other remote write was made.

## Candidate identity and local environment

- Candidate source commit: `9997bc9d95f9009165572fef154ef4608082696b`;
  comparison baseline: `f5dd6d8fdcd2a7c21453c9dc1a8c57bfe6420250`.
- Built source artifact: `.scratch/acceptance-v08/vennabers_0.7.0.tar.gz`;
  SHA-256 `87cf9818d874ec7ccc5bb9a6646f39beddb349085686b3327860af23454dace4`.
  `R CMD build` completed without an error; the artifact is local and ignored.
- Local check log: `.scratch/acceptance-v08/final-check.log`, SHA-256
  `451a5bc8cf47ae137bf9a3899927309aeb90c376a67d92d0a5e685a48fc81e55`.
  Installed test log: `.scratch/acceptance-v08/vennabers.Rcheck/tests/testthat.Rout`,
  SHA-256 `fba738a263334996f01b793df4ca6afb1a7b4dbc760a495e4955a9a9edcbf6dd`.
- Package metadata still says `0.7.0`; this source tree includes v0.8 tuning
  work but has not been approved or versioned as a v0.8 release.
- Local host: Apple M5 Pro, macOS Tahoe 26.6.2 ARM64, R 4.6.1. This is one current-R
  development environment, not a substitute for a release runner.
- Installed direct integration versions: parsnip 1.6.0, workflows 1.3.0,
  hardhat 1.4.3, rsample 1.3.2, recipes 1.4.0, rlang 1.3.0,
  tibble 3.3.1, withr 3.0.3, generics 0.1.4, tidyselect 1.2.1,
  tailor 0.1.0, tune 2.1.0, dials 1.4.4, yardstick 1.4.0,
  future 1.75.0. `probably` 1.2.0 was installed for source checking in the
  ignored local library `.scratch/acceptance-v08/lib`.

## Support matrix

The 20 rows below are the trainable method paths: five model families ×
Inductive/Cross × matched/full. Each row needs both `joint` and `two_stage`,
each with Grid and Bayes. Family suites below exercise these dimensions, but
no 80-cell run has been recorded; the table maps implementation and existing
test evidence, not an assertion that every cell has passed independently.

| # | Model family | VA | Prediction source | Grid (`joint`/`two_stage`) evidence | Bayes (`joint`/`two_stage`) evidence |
| ---: | --- | --- | --- | --- | --- |
| 1 | binary | Inductive | matched | `test-binary-grid.R` | `test-binary-bayes.R` |
| 2 | binary | Inductive | full | `test-binary-grid.R` | `test-binary-bayes.R` |
| 3 | binary | Cross | matched | `test-binary-grid.R` | `test-binary-bayes.R` |
| 4 | binary | Cross | full | `test-binary-grid.R` | `test-binary-bayes.R` |
| 5 | shared OvO | Inductive | matched | `test-multiclass-grid.R` | `test-multiclass-bayes.R` |
| 6 | shared OvO | Inductive | full | `test-multiclass-grid.R` | `test-multiclass-bayes.R` |
| 7 | shared OvO | Cross | matched | `test-multiclass-grid.R` | `test-multiclass-bayes.R` |
| 8 | shared OvO | Cross | full | `test-multiclass-grid.R` | `test-multiclass-bayes.R` |
| 9 | shared OvR | Inductive | matched | `test-multiclass-grid.R` | `test-multiclass-bayes.R` |
| 10 | shared OvR | Inductive | full | `test-multiclass-grid.R` | `test-multiclass-bayes.R` |
| 11 | shared OvR | Cross | matched | `test-multiclass-grid.R` | `test-multiclass-bayes.R` |
| 12 | shared OvR | Cross | full | `test-multiclass-grid.R` | `test-multiclass-bayes.R` |
| 13 | pairwise OvO | Inductive | matched | `test-pairwise-grid.R` | `test-pairwise-bayes.R` |
| 14 | pairwise OvO | Inductive | full | `test-pairwise-grid.R` | `test-pairwise-bayes.R` |
| 15 | pairwise OvO | Cross | matched | `test-pairwise-grid.R` | `test-pairwise-bayes.R` |
| 16 | pairwise OvO | Cross | full | `test-pairwise-grid.R` | `test-pairwise-bayes.R` |
| 17 | regression | Inductive | matched | `test-regression-grid.R` | `test-regression-bayes.R` |
| 18 | regression | Inductive | full | `test-regression-grid.R` | `test-regression-bayes.R` |
| 19 | regression | Cross | matched | `test-regression-grid.R` | `test-regression-bayes.R` |
| 20 | regression | Cross | full | `test-regression-grid.R` | `test-regression-bayes.R` |

The searched axes are model/recipe parameters and, when selected, Log/Brier
and finite rounding for classification or `m`/`epsilon` for regression. A
fixed option stays fixed. A separate S/F plan is required for automatic
calibration options; explicit local plans, Cross fold plans and outer plans
are tested in the family suites. `venn_abers_tuning()` retains the chosen
candidate, eligible/excluded rows, local plans, scores, native predictions,
fit roles, seeds, budget, attempts, elapsed time, errors and stop reason.
These fields need an explicit final audit for every matrix cell.

## Executed checks and test mapping

| Check | Local result / evidence |
| --- | --- |
| Shared multiclass Bayes focused suite | 42 PASS, 0 FAIL/WARN/SKIP (`devtools::test(filter="multiclass-bayes")`). |
| Full source test suite | 756 PASS, 0 FAIL, 9 WARN, 0 SKIP before the test assertion fix. All nine warnings came from `test-pairwise-cross-workflow.R`; its focused rerun after the fix: 1 PASS, 0 FAIL/WARN/SKIP. |
| Built source and `R CMD check --as-cran` | Final installed artifact: 0 ERROR, 0 WARNING, 2 NOTEs; installed-package tests: 756 PASS, 0 FAIL/WARN/SKIP; examples and PDF manual: OK. The NOTEs are `New submission` (this package is not on CRAN) and skipped HTML validation/math rendering because local HTML Tidy is too old and V8 is absent. |
| Native fit/predict, details/tuning, schemas, RDS and fresh workers | Existing `test-*-grid.R`, `test-*-bayes.R`, `test-outer-resampling.R`, `test-matched-last-fit.R`, `test-schema-processes.R`, `test-full-*-processes.R`, `test-pairwise-processes.R`, `test-integration-processes.R` all executed in the full source suite. |
| Frozen Log/Brier on new validation data | `inst/examples/frozen-binary.R` shows both losses after one frozen fit; `test-frozen-workflow.R` checks both prediction losses without relearning. This is the narrow comparison; no new tuning API is implied. |
| Numerical core parity | Existing tests reconstruct manual binary/multiclass/regression cores with absolute `1e-10` or regression scale-aware `1e-10`; all passed in the full source suite. |

### Instrumented exclusion and failure evidence

| Contract | Existing executable test | Remaining gap |
| --- | --- | --- |
| S excluded from F and outer assessment targets cannot alter fitting | `test-regression-grid.R` checks disjoint S/F rows, changed `last_fit()` assessment targets and a foreign plan rejected at binding; `test-binary-grid.R` checks S/F. | Repeat these probes for every family and Bayes path. |
| Local pair and Full1 model domains | `test-pairwise-grid.R`, `test-pairwise-bayes.R`, `test-multiclass-bayes.R`, `test-regression-grid.R` inspect pair/Fold/Full1 choices and source IDs. | Record a unified 20-row domain audit. |
| Held calibration sources unchanged | `test-full-model-workflow.R`, `test-full-*-processes.R` reconstruct from stored held sources. | Explicit before/after byte comparison for every tuned full path. |
| Failed fold, main fit, final fit | `test-regression-grid.R` injects fold and final fit failures; `test-regression-bayes.R` injects final fit failure; `test-pairwise-bayes.R` rejects missing pairs. | Complete cross-family error matrix. |
| Failed report metric | `test-regression-grid.R` and `test-regression-bayes.R` keep primary eligibility independent of report errors. | Complete cross-family error matrix. |
| Repeated Bayes proposal; no valid initial points | `test-regression-bayes.R` records repeated proposals and invalid initial points; `test-multiclass-bayes.R` rejects missing complete initial matrices. | Complete cross-family error matrix. |
| No silent fallback | `test-binary-grid.R`, `test-regression-grid.R`, `test-regression-bayes.R` require the selected final fit failure to surface. | Verify all families and both search methods. |

Normal package use and the checked R test/example sources require no Python or
network access after package setup. Python appears only in stored reference
fixture provenance. The separate missing/old dependency profile has not been
accepted.

## Required support runners

| Platform | R 4.6 current | R 4.5 previous |
| --- | --- | --- |
| Linux x86_64 | Not run | Not run |
| Windows x86_64 | Not run | Not run |
| macOS Intel | Not run | Not run |
| macOS ARM | Local R 4.6.1 source check: 0 ERROR, 0 WARNING, 2 justified NOTEs; not a CI runner | Not run |

The separate Linux core-only (without tidymodels), previous-minor minimum
dependency, and Linux R-devel runs are also not run. Record actual R patch,
OS image, architecture, dependency versions, built-artifact SHA-256, test,
example, and `R CMD check --as-cran` results for each run. No GitHub Actions
run or remote artifact is part of this record. The historical workflow was
renamed to `.github/workflows/acceptance.yaml.disabled`, so this checkout has
no active Actions workflow.

## Benchmark protocol and status

Use one documented Linux x86_64 machine and serial processes with one
engine/BLAS thread. Fix the random seed, CPU/RAM/OS/R/dependency versions,
datasets, options, expected fit counts and RDS settings before measuring.
Use 2,000 development rows, 500 prediction rows and ten numeric predictors;
compare binary matched, three-class pairwise OvO full, and regression full.
Each uses Cross VA with five folds, two local selection resamples, a separate
20% option-selection S when automatic options are selected, Grid with four
candidates, and Bayes with four valid initial candidates plus at most four
further proposals. Use bounded-depth `rpart` so model parameters actually
change. Run one warm-up and three measured repetitions per case and release.

Measure fit, predict, and complete three-fold outer evaluation separately; report median
and spread, fit count, retained model count, serialized fit bytes and process
peak memory. Exclude data generation and installation; include product input
validation. Remeasure v0.7 on the same Linux machine with the same compatible
inputs in a fresh R process before comparing ratios. Report local exploratory
and external runner results separately. **No v0.8 or same-machine v0.7
benchmark measurement is available yet; no performance ratio is asserted.**

## Reproduction and open gates

```sh
Rscript -e 'devtools::test(stop_on_failure=TRUE)'
mkdir -p .scratch/acceptance-v08
cd .scratch/acceptance-v08
R CMD build ../..
shasum -a 256 vennabers_0.7.0.tar.gz
R_LIBS="$PWD/lib" R CMD check --as-cran vennabers_0.7.0.tar.gz
```

The local `lib` used above contains the optional packages installed during
setup. Use a fresh, documented library per support runner.

The source artifact must be tested as an installed package on the runner
matrix. A test suite on this Mac cannot close the absent v0.7 gate, the open
ticket 06, the 80-cell audit, missing dependency profiles, or Linux benchmark
comparison. Keep the release blocked until those results are attached here.
