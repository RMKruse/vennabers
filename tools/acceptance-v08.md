# v0.8 local acceptance record — 2026-09-23

**Decision: open.** This is a reproducible local check of the current v0.8
implementation, not a release approval. The v0.7 aggregate gate has no
`tools/acceptance-v07.md` in this checkout; ticket 06 is still marked open;
the complete local matrix and final controlled cost acceptance are missing. The maintainer
confirmed on 2026-09-24 that development checks run on macOS only and the
cross-OS matrix waits until v1.0. No GitHub or other remote write was made.

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
- Local host: Apple M5 Pro, 24 GiB RAM, macOS Tahoe 26.6.2 ARM64, R 4.6.1. This is one current-R
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

| # | Model family | VA | Prediction source | Related Grid suite | Related Bayes suite |
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
These fields need an explicit final audit for every matrix cell. A suite name
in the table does **not** mean both strategies were tested for that row; for
example, `test-binary-bayes.R` exercises two-stage Inductive matched only.

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

Static inspection of package R code and checked test/example sources found no
Python or network call needed after package setup. Python appears only in
stored reference fixture provenance. The separate missing/old dependency
profile has not been accepted.

## Development support and deferred runners

| Platform | R 4.6 current | R 4.5 previous |
| --- | --- | --- |
| Linux x86_64 | Deferred to v1.0 | Deferred to v1.0 |
| Windows x86_64 | Deferred to v1.0 | Deferred to v1.0 |
| macOS Intel | Deferred to v1.0 | Deferred to v1.0 |
| macOS ARM | Local R 4.6.1 source check: 0 ERROR, 0 WARNING, 2 justified NOTEs | R 4.5 not installed locally; deferred |

The earlier roadmap requires eight OS/R combinations, Linux core-only,
minimum-dependency and R-devel runs. The maintainer moved that broader support
exercise to v1.0; none is claimed here. Record actual R patch, OS image,
architecture, dependency versions, built-artifact SHA-256, test, example and
`R CMD check --as-cran` results when those runs occur. No GitHub Actions run or
remote artifact is part of this record. The historical workflow was renamed
to `.github/workflows/acceptance.yaml.disabled`, so this checkout has no active
Actions workflow.

## Local development cost measurements

The local script [`tools/benchmark-v08.R`](benchmark-v08.R) (SHA-256
`cf6801929f56b460083702d4c9794d86c7deae0aca2270e88812c6a95bd3c64a`)
generated 2,000 development rows, 500 prediction rows and ten numeric
predictors with seed 804. Three-class labels include independent noise so
logistic fits are not perfectly separated. Each case uses five Cross VA folds;
the tuned cases use two local selection resamples, S=20%, four Grid candidates
or four Bayes initial candidates and at most four further proposals. The model
parameter is bounded `rpart` tree depth. The fixed paths use logistic or
linear models. A separate three-fold outer evaluation uses the same configured
workflow. Each artifact ran in a fresh serial R process with one warm-up and
three measured repetitions. Times below exclude data generation and
installation. RDS uses `saveRDS(..., version=3)`; peak RSS comes from macOS
`/usr/bin/time -l` and covers the whole process, not an isolated fit.

The historical local `vennabers_0.7.0.tar.gz` has SHA-256
`f9c0dd191670c0e8c19331f6d75dfb015be29bcc7305cec202aae590e065a16a`;
the current candidate artifact hash is above. Both were installed into
separate local libraries. They share the package version string `0.7.0` but
contain different code. Fixed paths use identical generated data and options.
Tuned paths are new in the candidate and have no v0.7 counterpart. Times are
seconds, shown as median [minimum, maximum] across three measured runs;
sizes are MiB.

| Artifact and case | Fit s | Predict s | Three-fold outer s | RDS MiB | Peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| v0.7 binary fixed | 0.048 [0.046, 0.049] | 0.007 [0.006, 0.008] | 0.214 [0.182, 0.217] | 4.17 | 384.8 |
| Candidate binary fixed | 0.044 [0.044, 0.058] | 0.006 [0.006, 0.010] | 0.179 [0.178, 0.196] | 4.17 | 386.6 |
| Candidate binary Grid | 10.337 [10.309, 10.481] | 0.006 [0.005, 0.006] | 31.021 [30.146, 31.925] | 4.28 | 377.0 |
| Candidate binary Bayes | 12.828 [12.712, 13.233] | 0.006 [0.006, 0.006] | 38.131 [37.944, 38.191] | 4.29 | 567.1 |
| v0.7 pairwise OvO fixed | 0.123 [0.115, 0.129] | 0.007 [0.006, 0.009] | 0.392 [0.382, 0.469] | 2.24 | 426.3 |
| Candidate pairwise OvO fixed | 0.113 [0.108, 0.121] | 0.006 [0.006, 0.007] | 0.363 [0.362, 0.425] | 2.24 | 425.7 |
| Candidate pairwise OvO Bayes | 45.814 [43.097, 45.892] | 0.006 [0.005, 0.007] | 129.521 [128.678, 133.227] | 10.57 | 573.5 |
| v0.7 regression fixed | 0.041 [0.041, 0.041] | 0.024 [0.024, 0.024] | 0.258 [0.257, 0.261] | 1.07 | 360.7 |
| Candidate regression fixed | 0.042 [0.041, 0.049] | 0.024 [0.024, 0.026] | 0.295 [0.289, 0.336] | 1.07 | 363.7 |
| Candidate regression Grid | 11.593 [11.338, 11.919] | 0.024 [0.023, 0.025] | 34.489 [34.222, 35.170] | 3.94 | 381.9 |
| Candidate regression Bayes | 27.157 [27.089, 27.645] | 0.023 [0.023, 0.024] | 81.321 [80.496, 82.279] | 6.00 | 858.7 |

The original candidate pairwise Grid full-size run failed during nested outer
evaluation (`.scratch/acceptance-v08/v08-pairwise-grid.time`): all outer
models reported no eligible calibration candidate because a three-class
selection metric received one probability column. Its standalone warm-up fit
had completed. On a smaller reproduction, manual fits of all three outer
analysis splits passed and the inner Grid result saved all three probability
columns; the mismatch arose during nested native metric evaluation. A local
metric-selection experiment did not repair the outer metric. This was an
acceptance failure, not a measured cost. Pairwise Bayes passed both a smaller
pilot and the full-size measured run.
The original RDS result files and `/usr/bin/time` logs are in the ignored
local `.scratch/acceptance-v08/` directory.

### Pairwise Grid fix — 2026-09-25

The failure above came from yardstick's column-selection cache in tune's
shared progress environment: nested binary model searches cached one
probability column and the three-class calibration metric reused it. Both
Grid and Bayes search now scope that cache locally and restore the enclosing
search's selections on return, including errors.

`tests/testthat/test-pairwise-grid-outer.R` reproduces the nested two-stage
Cross/full path on three-class iris data. It sets `TESTTHAT=false` locally
because tune otherwise disables the cache during tests. Before the fix, both
outer folds rejected every calibration candidate with the recorded column
mismatch. After the fix, the test checks candidate eligibility, complete
outer predictions, native inner scores and outer log loss.
The full source suite (`devtools::test(stop_on_failure=TRUE)`) passed 838
assertions, including all 16 new regression assertions, with zero failures,
warnings or skips; log: `.scratch/pairwise-grid-fix/test-suite.log`.

The fixed working tree was installed into a separate local library and the
original full-size script passed its warm-up and one repeat: 2,000 development
rows, 500 prediction rows, five Cross folds and three outer folds, with no
logged errors or warnings. Reproduction:

```sh
mkdir -p .scratch/pairwise-grid-fix/library
R CMD INSTALL -l .scratch/pairwise-grid-fix/library .
R_LIBS="$PWD/.scratch/pairwise-grid-fix/library" BENCH_REPS=1 /usr/bin/time -l \
  Rscript tools/benchmark-v08.R pairwise grid .scratch/pairwise-grid-fix/full-size.rds
Rscript -e 'devtools::test(filter="^pairwise-grid-outer$", stop_on_failure=TRUE)'
```

Local evidence is `.scratch/pairwise-grid-fix/full-size.rds` and
`.scratch/pairwise-grid-fix/full-size.log`. This verifies the acceptance bug
fix; it is not a replacement timing benchmark (one repeat, concurrent test
suite, no explicit thread limits).

These are development measurements: BLAS/engine thread limits were not set
explicitly, fit counters and retained model counts have not been audited, and
the original pairwise Grid cost run did not complete. The controlled single-thread local
benchmark remains open. Linux x86_64 reference comparison is deferred to
v1.0 by the maintainer's 2026-09-24 decision; Mac and Linux times will not be
treated as directly comparable.

## Reproduction and open gates

```sh
mkdir -p .scratch/acceptance-v08
cd .scratch/acceptance-v08
# Setup only: install the DESCRIPTION Suggests into a compatible local library.
# This host already had all but probably; its checked version was 1.2.0.
Rscript -e 'dir.create("lib", showWarnings = FALSE); install.packages("probably", lib = "lib", repos = "https://cloud.r-project.org")'
cd ../..
Rscript -e 'devtools::test(stop_on_failure=TRUE)'
cd .scratch/acceptance-v08
R CMD build ../..
shasum -a 256 vennabers_0.7.0.tar.gz
R_LIBS="$PWD/lib" R CMD check --as-cran vennabers_0.7.0.tar.gz
```

For the Mac cost run, install the historical and candidate tarballs into
separate libraries, then run the tracked script in a fresh process per case:

```sh
mkdir -p .scratch/acceptance-v08/core-lib .scratch/acceptance-v08/bench-current-lib
R CMD INSTALL -l .scratch/acceptance-v08/core-lib vennabers_0.7.0.tar.gz
R CMD INSTALL -l .scratch/acceptance-v08/bench-current-lib .scratch/acceptance-v08/vennabers_0.7.0.tar.gz
R_LIBS="$PWD/.scratch/acceptance-v08/bench-current-lib" /usr/bin/time -l \
  Rscript tools/benchmark-v08.R pairwise grid .scratch/acceptance-v08/v08-pairwise-grid.rds
```

`tools/benchmark-v08.R` accepts `binary`, `pairwise` or `regression` as its
first argument and `fixed`, `grid` or `bayes` as its second. The same `fixed`
command with `R_LIBS` pointing to `core-lib` measures the historical artifact.
The source artifact named in the first install command is the historical
root tarball, not the candidate under `.scratch/acceptance-v08/`.

The local `lib` used above contains the optional packages installed during
setup. Use a fresh, documented library per support runner.

The source artifact has been checked as an installed package on this Mac.
The absent v0.7 gate, open ticket 06, 80-cell audit and controlled local cost acceptance
remain open for v0.8 development. The broader OS/R and Linux comparison gates
are deferred to v1.0 by the maintainer's decision; they are not claimed here.
