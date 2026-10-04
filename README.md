# venn-abers

`vennabers` calibrates model predictions in R. It supports binary and multiclass
classification (one-vs-one or one-vs-rest) and regression, each with Inductive
or Cross calibration.

You can supply predictions from an existing model or use optional tidymodels
workflows to fit models and create calibration splits. The package requires
R 4.5 or later.

## Installation

From a local checkout (building the source archive also renders the vignettes):

```sh
R CMD build .
R CMD INSTALL vennabers_1.0.0.tar.gz
```

The manual calibration functions need no additional R packages. Workflow
integration uses the optional packages listed in `DESCRIPTION`. Building the
vignettes requires the suggested packages, including `knitr` and `rmarkdown`,
plus Pandoc. `R CMD INSTALL .` installs directly from a checkout without
rendering the vignettes.

## Getting started

Fit a binary calibrator with probabilities from a model trained on separate
data. Then predict calibrated probabilities for new observations:

```r
library(vennabers)

truth <- c(FALSE, TRUE, FALSE, TRUE)
uncalibrated <- c(0.1, 0.4, 0.35, 0.8)
calibrator <- venn_abers(truth, uncalibrated)
prediction <- predict(calibrator, c(0.2, 0.5, 0.9))

prediction
brier_score(c(FALSE, TRUE, TRUE), prediction$probability)
log_loss(c(FALSE, TRUE, TRUE), prediction$probability)
```

`prediction` contains `lower` and `upper` Venn-Abers bounds and a regularized
`probability`. The bounds are not confidence intervals. Keep final assessment
data separate from model training and calibration.

## Other interfaces

| Task | Function |
| --- | --- |
| Calibrate binary or multiclass probabilities | `venn_abers()` |
| Calibrate out-of-fold classification probabilities | `cross_venn_abers()` |
| Calibrate numeric predictions | `venn_abers_regression()` or `cross_venn_abers_regression()` |
| Fit and calibrate a tidymodels workflow | `calibrated_workflow()` |
| Calibrate an already fitted workflow | `calibrate_workflow()` |

For multiclass calibration, pass factor truth and a probability matrix with
columns named after its levels. Choose `method = "ovo"` (default) or `"ovr"`.
When supplying probabilities directly, Cross calibration needs predictions
from the corresponding retained fold models.

Here is a binary workflow that creates its own training and calibration split:

```r
data <- data.frame(
  x = sin(1:80),
  truth = factor(rep(c("yes", "no", "no", "yes"), 20))
)
base <- workflows::workflow() |>
  workflows::add_formula(truth ~ x) |>
  workflows::add_model(parsnip::logistic_reg(engine = "glm"))

fit <- calibrated_workflow(base, outcome = "truth", seed = 42) |>
  generics::fit(data)
predict(fit, data.frame(x = c(-0.5, 0.5)), type = "prob")
```

Use `method = "cross"` for fold-based workflow calibration. Continue with the
[step-by-step workflow guide](vignettes/workflows.Rmd), also available through
`vignette("workflows", package = "vennabers")`. Use `?calibrated_workflow` for
arguments, `?workflow_training` for split and model rules, and
`?venn_abers_details` for prediction diagnostics. For an already fitted model,
see `?calibrate_workflow`.

Binary workflows also support
`postprocessing = list(method = "sigmoid", strategy = "holdout", prop = .3,
sigmoid_input = "probability")`. Select `"glm_link"` explicitly for binomial
GLM logit inputs through the complete workflow and recipe. Sigmoid requires
both classes in B and P, at least two P rows, and no existing postprocessor.
It uses sklearn-compatible smoothed targets without a Python runtime dependency.

Binary and shared OvO/OvR workflows can learn Tailor postprocessing on a separate
holdout before VA calibration. Pass
`postprocessing = list(method = "tailor_logistic", strategy = "holdout", prop = .3)`;
Use `tailor_multinomial` instead for shared models with three or more classes;
two-class OvO/OvR requires `tailor_logistic`. `prop` is the fraction reserved for the postprocessor. Recipe/model training,
postprocessing, and VA calibration use separate B/P/C portions. This path needs
the optional `tailor` and `probably` packages and fixed model parameters.
For binary and shared OvO/OvR classification, choose `strategy = "ensemble", v = 3`
instead of `strategy = "holdout", prop = .3` to retain three complete B/P pairs.
The P folds partition the local Q; finished class vectors are averaged with equal
pair weights before Inductive/Cross VA. Shared two-class models still require
`tailor_logistic`, and three or more classes require `tailor_multinomial`.
Pairwise OvO (`model_training = "pairwise"`) supports both holdout and ensemble
postprocessing with `tailor_logistic` or either Sigmoid input. Each class pair
is selected before its VA and B/P plans are built. Local complete predictions
are averaged before binary VA and global OvO coupling. See the
[installed pairwise example](inst/examples/pairwise-postprocessing.R) for native
resampling, `last_fit`, and the distinction between class pairs and inner B/P pairs.
Regression workflows use `method = "tailor_linear"` with `smooth=FALSE`; P needs
at least three rows and a full-rank intercept/prediction design. Automatic
regression splits are unstratified. The unchanged IVAR/CVAR kernels consume the
complete adjusted workflow predictions, using the requested `m` or `epsilon`.
For numeric reference isotonic calibration, use `method = "isotonic_numeric"`
with a base workflow without a postprocessor. P needs at least two finite rows;
ties retain their frequencies, predictions interpolate between fitted supports,
and extrapolation uses the nearest fitted value. No `tailor` or `probably`
installation is needed for this method.
Both numeric methods also accept `strategy = "ensemble", v = 3`: each pair
keeps its complete B workflow and P postprocessor, and their finished numeric
predictions are averaged equally before IVAR/CVAR. CVAR bounds remain descriptive
VA bounds, not confidence or prediction intervals.

Set `prediction_model = "full"` with any fixed postprocessing method to train
one additional complete holdout or ensemble on the permitted fit data, with its
own B/P splits. Held C predictions and VA calibrators stay unchanged; only the
additional full composition is retained for prediction. Each inner engine still
learns only on B. Full Inductive costs 2J pairs; Cross costs (K+1)J, retaining J
per domain (sum differing local counts). Full-model transfer does not inherit
split-calibration guarantees automatically. The
[installed full-postprocessing example](inst/examples/full-postprocessing.R)
covers all 80 fixed combinations through native evaluation and `last_fit`.

Postprocessing also accepts `tuning` with joint or two-stage Grid selection of
engine/recipe settings. Each B (every VA source, inner ensemble pair and full
composition) runs its own local search; P, C, outer assessment and a reserved
selection share never enter it. Joint scores complete compositions with fixed
candidate settings, and the first two-stage step scores the raw engine without
postprocessor or VA. See the
[installed postprocessing grid example](inst/examples/postprocessing-grid.R).
Stepwise Bayes selection uses the same local searches; only complete valid
candidates feed the next GP, and failed or repeated proposals spend budget.
See the [installed postprocessing Bayes example](inst/examples/postprocessing-bayes.R).

## Supported postprocessing compositions

Each row runs with holdout or inner ensemble, Inductive or Cross VA, and
matched or full prediction models: eight fixed compositions per row, 80 in
total. Every composition also accepts joint or two-stage Grid/Bayes selection
of engine/recipe settings inside each B.

| Path | Methods | Compositions |
| --- | --- | ---: |
| Binary | Sigmoid (probability or GLM-link input), Tailor logistic | 16 |
| Pairwise OvO | Sigmoid (either input), Tailor logistic | 16 |
| Shared OvO, three or more classes | Tailor multinomial | 8 |
| Shared OvR, three or more classes | Tailor multinomial | 8 |
| Shared OvO, two classes | Tailor logistic | 8 |
| Shared OvR, two classes | Tailor logistic | 8 |
| Regression (IVAR/CVAR) | Reference isotonic, Tailor linear | 16 |

B learns recipe and engine, P learns the postprocessor, and held-out C trains
the unchanged VA core. Full compositions train an additional B/P holdout or
ensemble on the permitted final data F. Without tuning, J inner pairs cost J
(Inductive matched), 2J (Inductive full), KJ (Cross matched with K folds) or
(K+1)J (Cross full) engine and postprocessor fits per domain and retain J, J,
KJ or J pairs; class pairs add up. For example, three class pairs, five Cross
folds and a three-pair ensemble in full mode train 54 engines and 54
postprocessors and keep nine pairs.

Sigmoid follows the sklearn target smoothing without a Python runtime. Tailor
methods use the public workflow path with `smooth = FALSE`; reference isotonic
needs neither `tailor` nor `probably`. These are R extensions of the Python
reference, which has no tidymodels postprocessing. Tailor multinomial uses
probably's `nnet::multinom()` defaults (at most 100 iterations); the fixed
postprocessing arguments expose no `maxit` setting. Weakly informative class
probabilities can reach this limit even when the B engine converges. The fit
then fails with fold, inner-pair and B/P context, without retry, method switch
or partial ensemble. Setting `maxit` on the B engine does not change the P
postprocessor's limit. This is an accepted limit of the 1.x contract, not a
pending option. It does not change numerical VA parity on the same valid
inputs. Out of scope: out-of-fold postprocessing followed by a complete engine
refit, arbitrary foreign engines or Tailor step sequences, further methods and
new constructors. Frozen
workflows (`calibrate_workflow()`) keep their existing contract. Full-model
transfer does not inherit split-calibration guarantees.

## Compatibility, parity and migration

From 1.0.0 on, the user-facing functions in `help(package = "vennabers")`, their
arguments and defaults, and the output formats their help pages document stay
compatible throughout 1.x; incompatible changes wait for 2.0.0. Documented bug
fixes may still change numerical results, and NEWS names each one. The parsnip
engine entry points (`?vennabers-engine`) exist only for model registration.
The minimum R version is separate: each release supports at least the previous
R minor series and may raise the minimum with a NEWS entry.

[`PARITY.md`](inst/PARITY.md) (installed as
`system.file("PARITY.md", package = "vennabers")`) indexes the evidence for each
capability. It keeps numerical parity with Python venn-abers 1.5.4,
training/data parity, R extensions, reference deviations and accepted limits
apart. Matching numbers on identical inputs do not imply identical training
procedures.

Code written for 0.9.0 runs unchanged. In the 22 paths checked by
`tools/migration-v09.R`, objects saved with 0.9.0 predict identically and keep
their diagnostics. Refit Sigmoid compositions to pick up the corrected
optimizer; see [NEWS](NEWS.md) for details.

## Learn more

Start with the three executable guides, also available after installing a
built package through `browseVignettes("vennabers")`:

| Guide | Contents | R command |
| --- | --- | --- |
| [Calibrating supplied predictions](vignettes/manual-calibration.Rmd) | Binary and multiclass OvO/OvR, Inductive/Cross, regression, scores and bounds | `vignette("manual-calibration", package = "vennabers")` |
| [Training and freezing calibrated workflows](vignettes/workflows.Rmd) | Recipes, matched/full models, pairwise training, frozen adoption and postprocessing | `vignette("workflows", package = "vennabers")` |
| [Tuning and assessing the complete procedure](vignettes/tuning.Rmd) | Joint/two-stage Grid, Bayes, data roles, outer resampling and final assessment | `vignette("tuning", package = "vennabers")` |

Standalone examples cover additional combinations:

- [Binary options example](inst/examples/binary-options.R) for precision, Log/Brier and event selection
- [Binary Cross example](inst/examples/cross-venn-abers.R)
- [Binary Sigmoid holdout example](inst/examples/sigmoid-holdout.R) with probability and GLM-link inputs
- [Regression Tailor holdout example](inst/examples/tailor-regression-holdout.R) with IVAR/CVAR and native evaluation
- [Regression isotonic holdout example](inst/examples/isotonic-regression-holdout.R) with IVAR/CVAR and native evaluation
- [Regression ensemble example](inst/examples/regression-ensemble.R) with both numeric methods, native evaluation and held-out data checks
- [Shared multiclass ensemble example](inst/examples/multiclass-ensemble.R) with retained pairs, encoded names and native evaluation
- [Shared multiclass Tailor holdout example](inst/examples/tailor-multiclass-holdout.R) with encoded names and native evaluation
- [Binary Tailor holdout example](inst/examples/tailor-holdout.R) with diagnostics, resampling and last_fit
- [Multiclass OvO example](inst/examples/inductive-ovo.R), [OvR example](inst/examples/inductive-ovr.R) and [Cross multiclass example](inst/examples/cross-multiclass.R)
- [Binary grid example](inst/examples/binary-grid.R) for joint/two-stage selection with independent assessment
- [Shared multiclass grid example](inst/examples/shared-multiclass-grid.R) for OvO/OvR and joint/two-stage selection
- [Shared multiclass Bayes example](inst/examples/shared-multiclass-bayes.R) for complete OvO/OvR matrix selection
- [Pairwise OvO grid example](inst/examples/pairwise-grid.R) for local pair grids and coupled selection
- [Pairwise OvO Bayes example](inst/examples/pairwise-bayes.R) for local pair searches and coupled selection
- [Regression grid example](inst/examples/regression-grid.R) for IVAR/CVAR with joint or two-stage selection
- [Postprocessing grid example](inst/examples/postprocessing-grid.R) for local B searches with classification and regression postprocessing
- [Postprocessing Bayes example](inst/examples/postprocessing-bayes.R) for local B Bayes searches with budget and failure records
- [Regression Bayes example](inst/examples/regression-bayes.R) for IVAR/CVAR with joint or two-stage selection
- [Regression example](inst/examples/inductive-regression.R) and [Cross regression example](inst/examples/cross-regression.R)
- [Workflow example](inst/examples/calibrated-workflow.R) and [fitted workflow example](inst/examples/frozen-binary.R)
- [Reference splits example](inst/examples/reference-splits.R) with the paper-style binary, multiclass and regression data roles (not paper benchmark reproductions)
- [Release notes](NEWS.md)

Run `help(package = "vennabers")` for the complete function reference.

## Verification

```sh
Rscript --vanilla tools/verify.R
# Verify a specific built archive, using four local test processes:
Rscript --vanilla tools/verify.R 4 /absolute/path/vennabers_1.0.0.tar.gz
```

This installs the current package and its tests in a temporary library, then
runs every test file once on four processes. Files start in descending order
of recorded duration; each free process takes the next file. Failures, errors,
warnings and skips fail verification. Logs and results stay in the printed
temporary directory. A successful run refreshes `tools/test-durations.csv`.
All suggested dependencies and `rpart` must be installed; use `R_LIBS` for an
additional dependency library. Pass `3` to compare three processes.

CRAN checks use a short profile. `tests/cran-long-tests.txt` explicitly lists
the process, worker and integration matrix files excluded there. They remain
in the source archive; `NOT_CRAN=true` runs the complete check suite, and
`tools/verify.R` always runs every installed test file.

Build an identified release candidate from a committed checkout with
`Rscript --vanilla tools/build-candidate.R HEAD`. This creates the source
archive, PDF manual, packaged-content hashes and `candidate.dcf` in the printed
temporary directory. [Release verification instructions](tools/RELEASE.md)
cover dependency setup, offline product tests, examples and the separate
benchmark tools.

The original timings total about 60 minutes of test work. After splitting the
large replay test, ideal scheduling estimates about 20 minutes with three
processes or 15 with four. These are planning estimates: some tests launch two
workers themselves, so actual gains require measurement. The local macOS / R
4.6.1 run on 2026-10-03 completed all 96 files and 21,219 expectations in
15.90 minutes with four processes, with no failures, errors, warnings or skips.
The timing file now contains measured durations for all ten replay groups.
