# venn-abers

Dependency-free binary Inductive and Cross Venn-Abers calibration for R 4.5
and later. This is the v0.3 development branch; version 0.2 added matched-fold
cross calibration.

## Quick start

From a local checkout, install the package:

```sh
R CMD INSTALL .
```

Then fit a calibrator, predict regularized probabilities, score them, and draw
a calibration plot:

```r
library(vennabers)

truth <- c(FALSE, TRUE, FALSE, TRUE)
uncalibrated_probability <- c(0.1, 0.4, 0.35, 0.8)
calibrator <- venn_abers(truth, uncalibrated_probability)
prediction <- predict(calibrator, c(0.2, 0.5, 0.9))

brier_score(c(FALSE, TRUE, TRUE), prediction$probability)
log_loss(c(FALSE, TRUE, TRUE), prediction$probability)
calibration_plot(c(FALSE, TRUE, TRUE), prediction$probability)
```

IVAP prediction still returns three double columns: `lower` and `upper` are
the Venn-Abers interval endpoints; `probability` is the regularized event
probability, using log loss by default. These endpoints are not confidence intervals.

## Binary options

Fit on a separate calibration set after the underlying model and its learned
preprocessing are fixed. `precision = NULL` preserves calibration probabilities;
one finite numeric whole number enables native R `round()`, including zero
or negative digits. Original probabilities must be valid before rounding.
Only calibration probabilities are rounded, creating new ties if applicable;
new prediction values stay exact. Changing precision requires refitting.

Choose `loss = "log"` (default) or `loss = "brier"` at prediction time.
Log loss gives `upper / (1 - lower + upper)`; Brier gives
`upper + (lower^2 - upper^2) / 2`. Loss changes neither interval endpoints nor
stored learning state. Request `type = "class"` for an unnamed logical vector:
`TRUE` when the final event probability is at least `0.5`, including ties.
The default `type = "response"` preserves the existing data-frame outputs.

```r
rounded <- venn_abers(truth, uncalibrated_probability, precision = 2)
predict(rounded, c(.2, .501, .9), loss = "brier")
predict(rounded, c(.2, .501, .9), loss = "brier", type = "class")
```

Both fits accept `precision`; both predict methods accept fully named `loss`
and `type`. Unsupported arguments and unknown option values are errors.
Logical, missing, nonfinite, fractional, and multiple precision values are
rejected. R and NumPy can round differently at floating-point boundaries;
native R behavior is intentional, with separate tests from Python parity.
See the executable [binary options example](examples/binary-options.R) and
[reference record](inst/extdata/binary-options-reference.md).

## Cross Venn-Abers

Follow the canonical [three-fold GLM example](examples/cross-venn-abers.R).
It generates seeded binary data, sets aside untouched test observations,
fits three binomial GLMs on the other two development folds, restores each
held-out probability to its original row, and retains the models to predict
the same test rows. It then calibrates, predicts, scores, and plots with no
downloads or additional dependencies. From an installed checkout, run:

```sh
Rscript examples/cross-venn-abers.R
```

The script checks its results and closes and removes a temporary PDF, so it
also runs without an interactive display. Call `calibration_plot()` directly
to view a plot interactively. The script lives in the checkout, outside the
source package; the acceptance gate explicitly runs it against the installed
artifact.

For already computed, correctly aligned probabilities, the interface is:

```r
library(vennabers)

cross_calibrator <- cross_venn_abers(
  truth = c(FALSE, TRUE, FALSE, TRUE, FALSE, TRUE),
  probability = c(.1, .8, .2, .9, .3, .7),
  fold = c("A", "A", "B", "B", "C", "C")
)
# Each column comes from the retained model that excluded its named fold.
# Each row refers to the same new observation across all three columns.
test_probability <- cbind(A = c(.2, .8), B = c(.3, .7), C = c(.1, .9))
cross_prediction <- predict(cross_calibrator, test_probability)
print(cross_calibrator)
cross_prediction
```

The package fits one IVAP per calibration fold and performs equal-weight
log-loss aggregation internally. It returns a data frame with exactly one
double column, `probability`, one finite value in `[0, 1]` per input row, in
input row order. Pass that column to the existing scores and calibration plot.
Request `type = "details"` for a list containing `prediction` (the standard
data frame) and `folds`, with `row`, `fold`, `lower`, `upper`, and `probability`.
The integer `row` is the new row's one-based position in the current call;
`fold` is the stored character fold ID. Results are grouped by stored fold
order, then new-row order. Fold probabilities use the chosen loss. These are
predictions for new observations, not out-of-fold calibration probabilities.

Cross Brier takes the arithmetic mean of the Brier fold probabilities.
Cross log loss keeps its stable aggregation of endpoints in log space; it
does not average log-loss fold probabilities. Both use equal fold weights,
even for unequal fold sizes. Cross classes use the combined probability.
Both aggregates can be reconstructed from the public details:

```r
for (loss in c("log", "brier")) {
  details <- predict(cross_calibrator, test_probability, loss = loss, type = "details")
  reconstructed <- vapply(seq_len(nrow(test_probability)), function(i) {
    f <- details$folds[details$folds$row == i, ]
    if (loss == "log") plogis(mean(log(f$upper)) - mean(log1p(-f$lower))) else mean(f$probability)
  }, 0)
  stopifnot(max(abs(reconstructed - details$prediction$probability)) < 1e-10)
}
```

There is no public aggregate interval. Geometric
aggregate endpoints can cross; neither they nor the combined probability
inherit the IVAP perfect-calibration guarantee. No confidence-interval
coverage or improvement in either score is promised.

Fitting requires three nonempty vectors of equal length, aligned by position:

- `truth`: logical or numeric/integer binary values, with event `TRUE`/`1`.
- `probability`: numeric/integer event probabilities, finite and in `[0, 1]`.
- `fold`: nonempty character labels or finite positive whole-number
  numeric/integer IDs. Matching character labels is literal, without trimming
  or case folding; numeric IDs match their Base R `as.character()` names.
  Factors and logical IDs are rejected. Repeated IDs identify fold membership.

Supply one non-overlapping partition with at least two represented, nonempty
folds. Unequal, singleton and single-class folds are valid and have equal
weight. There is no empty-fold declaration or fold-count cap. Use
`venn_abers()` for a single calibration set.

Prediction requires a numeric/integer matrix with complete, unique, nonempty,
non-missing column names matching the fitted fold IDs. Named columns may be
reordered. Missing, extra, duplicate or unnamed columns and invalid values
fail the entire call. A correctly named zero-row matrix returns the same
one-column empty schema. Vectors, lists, data frames, logical matrices and
character matrices are rejected. A zero-row class output is `logical(0)`;
zero-row details preserve the empty fold-table schema, and one input row
produces one detail record per fold. Additional prediction arguments in
`...` are rejected. Inputs with missing values, nonbinary truth,
nonfinite values or probabilities outside `[0, 1]` fail without dropping rows,
coercing representations or clipping probabilities.

Keep every calibration fold out of its model's complete learned training
pipeline, including learned preprocessing and tuning. Keep test truth outside
model fitting and calibration. Retain the fold models yourself: the calibrator
stores calibration state, and a single all-data refit cannot replace the
models that produced the held-out probabilities. Each underlying calibration
observation must occur once; each test row must identify the same observation
across all model columns. Matching names cannot prove model provenance,
training exclusion, unique observations or semantic row alignment. Vector
element names and matrix row names are not alignment keys.

The five public functions are `venn_abers()`, `cross_venn_abers()`,
`brier_score()`, `log_loss()`, and `calibration_plot()`. Both calibrators use
registered `predict()` and `print()` methods. See `?cross_venn_abers` and
`?predict.cross_venn_abers` for executable help and the complete contract.

## Current scope

The package does not support package-managed predictive-model fitting, fold
creation, learned preprocessing, tuning or resampling; repeated or overlapping
partitions; one-fold public cross calibration; multiclass or regression
calibration; observation weights; alternate event selection; automatic
coercion or missing-value handling; fold-size weighting, pooling or averaging
log-loss fold point predictions; public aggregate cross bounds; formula/data-frame
cross interfaces; tidymodels/yardstick integrations; or new metrics, smoothing,
plotting features or `ggplot2` output.

There is no vignette. PDF-manual checks, CRAN submission guarantees and release
publishing are outside this package gate. Only Base R and standard R
distribution packages are needed. Installation and acceptance require neither Python nor networking;
regenerating the stored Python reference fixtures is optional and separate.

## Acceptance

Run the package gate from the package root:

```sh
Rscript tools/acceptance.R
```

It builds and installs the source artifact into an isolated library, runs
`R CMD check --as-cran --no-manual` (all package tests and help examples),
verifies the loaded package path and version, and executes the README R
snippets and every R script under `examples/` against that installation.
Errors, warnings and NOTEs fail the gate. Online CRAN incoming checks and
clock probes are disabled so the prepared R environment can run offline.

The active [workflow](.github/workflows/acceptance.yaml) requires R 4.6.1 and
4.5.3 on Linux x86_64, Windows x86_64, macOS Intel and macOS ARM. Linux R-devel
is an additional visible, non-blocking early warning. New releases require
at least the previous R minor series; recheck the matrix and `DESCRIPTION`
floor at final v0.3 acceptance. Older releases retain their original floor.

Set `ACCEPTANCE_OUTPUT_DIR` to an empty directory to retain the source artifact,
logs and environment/package versions; CI uploads this evidence even on failure.
See the [v0.3 CI record](tools/acceptance-v03-ci.md) for configuration, evidence
and the distinction between local checks and hosted matrix results.

Benchmarks run separately after installing the built artifact:

```sh
Rscript tools/performance.R
```

The 100,000-calibration / 100,000-prediction IVAP case is preserved, without
the historical 10-second ceiling. The full comparative benchmark protocol in
[the release roadmap](RELEASE-ROADMAP.md#35-performance) belongs to overall
release acceptance. Historical results remain in the [v0.2 record](tools/acceptance-v02.md).
