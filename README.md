# venn-abers

Dependency-free binary Inductive/Cross, multiclass Inductive/Cross OvO/OvR,
and moderated Inductive regression calibration for R 4.5 and later.
The development tree adds Inductive regression toward v0.4; the package version
remains the v0.3.0 source candidate until release work is complete.
Release approval remains pending; see the [acceptance record](tools/acceptance-v03.md).

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

## Inductive regression

`venn_abers_regression(truth, prediction)` fits from finite real-valued vectors
of equal nonzero length. Numeric 0/1 truth remains regression; factors, logical
values, matrices, missing/nonfinite values and unknown options are errors.
Names do not align rows. Inputs are never rounded, clipped or dropped.

```r
regression_fit <- venn_abers_regression(c(-10, 0, 2, 6, 20), rep(0, 5))
predict(regression_fit, c(-1, 0, 1))
# Double columns: prediction, lower, upper, in target units and input order.
regression_fit$m
regression_fit$epsilon
source(system.file("examples", "inductive-regression.R", package = "vennabers"))
```

The installed example fits `lm()` on training data, calibrates on separate
observations and reports Base R RMSE/MAE on an untouched assessment set.
The theoretical setting assumes IID observations and a model fixed
independently of calibration data, including preprocessing and tuning.
The bounds concern regularized conditional expectations, not individual-outcome
coverage. Neither improved scores nor a general selector guarantee for this
point merger is promised.

The default is `m=1`. Explicit `m` must be a finite numeric whole number between
1 and `floor((k-1)/2)`; at least three calibration rows are needed. Alternatively,
`epsilon` must be a finite numeric scalar strictly between zero and one:
`m=floor(epsilon*(k+1)/2)` must still satisfy the same domain. Invalid values
are not capped, and both parameters cannot be supplied explicitly. The fit
records `requested`, effective `m`, effective `epsilon=2*m/(k+1)`, and outer
bounds `a`, `b`. Asymmetric moderation replaces extreme truths without deleting
observations; see `?venn_abers_regression` for the exact order statistics.

For bounds `L,U`, the point uses weights `L-a` and `b-U`. Only two exactly zero
weights trigger the midpoint. Constant truths and coincident bounds return
their common finite value. Empty and singleton prediction inputs preserve the
three-column data frame; saved fits work in fresh R processes without training.

This manual entry point is an R extension. The
[reference record](inst/extdata/regression-reference.md) distinguishes valid
Python 1.5.4 regression components from lower-bound and zero-weight defects.
Training, automatic splits, regression score/plot helpers, exact minimax,
observation weights and rounding options remain outside this implementation.

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
See the executable [binary options example](inst/examples/binary-options.R) and
[reference record](inst/extdata/binary-options-reference.md).

## Cross Venn-Abers

Follow the canonical [three-fold GLM example](inst/examples/cross-venn-abers.R).
It generates seeded binary data, sets aside untouched test observations,
fits three binomial GLMs on the other two development folds, restores each
held-out probability to its original row, and retains the models to predict
the same test rows. It then calibrates, predicts, scores, and plots with no
downloads or additional dependencies. From an installed checkout, run:

```sh
Rscript inst/examples/cross-venn-abers.R
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

## Multiclass Inductive OvO and OvR

Supply factor truth and a numeric matrix with one named column per factor
level. Every level must occur in the calibration set. Columns are matched
by name and returned in level order, including names containing spaces or
punctuation. Rows align by position; row names are not matching keys. Entries
must be finite and in `[0, 1]`. Row sums within `1e-8` of one are normalized;
other sums, missing/extra/duplicate/empty column names and invalid values fail.

```r
classes <- c("cat", "dog", "bird")
truth <- factor(rep(classes, 2), levels = classes)
# Illustrative fixed-model probabilities on a separate calibration set.
p <- rbind(c(.7, .2, .1), c(.2, .6, .2), c(.1, .2, .7),
           c(.5, .3, .2), c(.3, .5, .2), c(.2, .3, .5))
colnames(p) <- classes
multiclass <- venn_abers(truth, p, method = "ovo", precision = 2)
new_p <- rbind(c(.6, .3, .1), c(.1, .4, .5))
colnames(new_p) <- classes
details <- predict(multiclass, new_p, loss = "brier", type = "details")
details$prediction
details$pairs
predict(multiclass, new_p, loss = "brier", type = "class")
assessment <- factor(c("cat", "bird"), levels = classes)
brier_score(assessment, details$prediction)
log_loss(assessment, details$prediction)
calibration_plot(assessment, details$prediction)
```

OvO (`method = "ovo"`, the default) uses only each class pair's calibration observations. Pair probabilities
are normalized before optional native R rounding; the later factor level is
the event. An exactly zero pair sum uses event probability `0.5`. That fit
replacement is also rounded (`precision = 0` makes it zero); new pair
probabilities always remain unrounded. No pair models are trained.

For OvO, the selected binary Log/Brier regularization precedes reciprocal coupling:
for class `j`, `w[j] = 1 / (sum(1 / q[j,i]) - (K - 2))`, where `q[j,i]`
is its probability against each other class. Normalize `w` to sum to one.
OvR (`method = "ovr"`) instead fits each class against all remaining classes
using every calibration observation. The class being considered is the event;
its probability is optionally rounded only during fit. Apply the selected
binary Log/Brier regularization, then divide those class points by their row
sum. New class probabilities remain unrounded. To run the same workflow with OvR:

```r
ovr <- venn_abers(truth, p, method = "ovr", precision = 2)
predict(ovr, new_p)
ovr_details <- predict(ovr, new_p, loss = "brier", type = "details")
ovr_details$classes
predict(ovr, new_p, loss = "brier", type = "class")
brier_score(assessment, ovr_details$prediction)
log_loss(assessment, ovr_details$prediction)
calibration_plot(assessment, ovr_details$prediction)
```

For either method, the default result is a class matrix. Classes use its maximum, choosing the
first stored level on ties, including with exactly two factor levels.
Binary vector ties continue to choose the event. Existing positional
`precision` calls remain valid; supply `method` by name.

OvO details contain `prediction` and `pairs`. Each pair-table record has the
integer new-row position `row`, literal character `non_event`/`event` names,
and double `lower`, `upper`, `probability`. Records follow factor-level pair
order and then new-row order. The endpoints stay the same under a loss switch;
the event point and its complement reconstruct the coupling. These are binary
diagnostics, not multiclass confidence intervals.
OvR details contain `prediction` and `classes`, with integer `row`, character
`event`, and double `lower`, `upper`, `probability` columns. Each event is the
literal class name against every other class, in stored class order then new-row
order; no synthetic rest label can collide with a real class name. Normalize
the diagnostic point probabilities across classes per row to reconstruct the
final matrix. Class predictions always use the chosen method's final matrix.
Empty new matrices retain
their class columns; empty classes retain levels; empty details retain schemas.

Assessment may omit observed classes while retaining their factor levels and
probability columns. Multiclass Brier sums all squared class errors per row
before averaging, so the two-column score is twice the binary vector score.
Log loss uses the observed class probability without clipping; zero gives
`Inf`. Calibration plots show final class probabilities against the rest in
one panel per class and invisibly return `class`, `mean_probability`,
`event_rate`, and `count` for occupied bins. Neither loss choice guarantees
an improvement in assessment scores or optimal final multiclass Brier loss.

The complete [OvO](inst/examples/inductive-ovo.R) and [OvR](inst/examples/inductive-ovr.R)
examples verify reconstruction and run against the installed package. `example(venn_abers)` also includes a
complete multiclass scoring/plotting workflow in the installed help.
Stored fixtures cover 33 fixed/seeded cases, two to four classes, both losses,
and rounding at `NULL`, zero, two, and minus one digits, with tolerance `1e-10`.
Log OvO/OvR uses the pinned Python 1.5.4 manual reference; two-class OvR uses
its multiclass component because the Python facade selects a single binary
calibrator for two classes. Brier uses binary reference components followed by
independent coupling or normalization. **Manual Brier for both methods is a
deliberate R extension**: the examined Python manual path does not forward a
Brier selection. Zero-pair replacement, validation and native R rounding are
explicit R rules. Regeneration is in `tools/generate-multiclass-fixtures.py`;
`inst/extdata/ovo-environment.json` and `inst/extdata/ovr-environment.json` record
provenance and hashes. Both methods share the `ovo-calibration.csv` and
`ovo-input.csv` inputs. Ordinary tests need no Python.

## Multiclass Cross OvO and OvR

`cross_venn_abers()` accepts factor truth, a named out-of-fold class matrix,
and one common fold vector. Each class must occur globally. Folds may omit
classes, but every OvO pair must remain nonempty in every fold; otherwise
fit reports both the pair and fold. Singleton and single-class subcalibrations
are supported. OvR uses all observations in each fold.

Predict with a **list named by fold ID**, each element a complete class matrix
for the same new observations in the same row order. The corresponding model
must have excluded that calibration fold throughout fitting, preprocessing,
and tuning. Retain these models yourself. List names and class names align
inputs; row names cannot establish semantic alignment. Missing, additional,
or duplicate names and unequal row counts fail. Class matrices follow the
Inductive value and row-sum rules, including columns for absent fold classes.

```r
# Illustrative OOF values: A's retained model excluded rows 1:3;
# B's retained model excluded rows 4:6. They supplied the matching new matrices.
classes <- c("cat", "dog", "bird")
truth <- factor(rep(classes, 2), levels = classes)
p <- rbind(c(.7, .2, .1), c(.2, .6, .2), c(.1, .2, .7),
           c(.5, .3, .2), c(.3, .5, .2), c(.2, .3, .5))
colnames(p) <- classes
new_by_fold <- list(B = p[4:5, , drop = FALSE], A = p[1:2, , drop = FALSE])
assessment <- factor(c("cat", "dog"), levels = classes)
for (method in c("ovo", "ovr")) {
  fit <- cross_venn_abers(truth, p, rep(c("A", "B"), each = 3),
                          method = method, precision = 2)
  for (loss in c("log", "brier")) {
    details <- predict(fit, new_by_fold, loss = loss, type = "details")
    print(details)
    print(predict(fit, new_by_fold, loss = loss, type = "class"))
    print(brier_score(assessment, details$prediction))
    print(log_loss(assessment, details$prediction))
    calibration_plot(assessment, details$prediction)
  }
}
```

For each subproblem, merge binary folds first: stable equal-weight endpoint
aggregation for Log, equal-weight fold Brier points for Brier. Only then apply
OvO reciprocal coupling or OvR normalization. No pooling, size weighting, or
averaging of finished multiclass fold outputs occurs. Fit rounding follows
pair/class preparation, while new values remain unrounded.

Response is the final class matrix; class predictions use its maximum and
first-level tie rule. Details contain `prediction` and `pairs` (OvO) or
`classes` (OvR), with `row`, `non_event` (OvO only), `event`, `fold`, `lower`,
`upper`, and loss-dependent `probability`. Events are the later pair class
or the selected class against the rest. Integer row positions and literal
fold/class identities permit reconstruction, even with punctuation in names.
Zero/one new row retains the output types and global class mapping. Output
row names come from the first stored fold's matrix. There is no additional
multiclass or Cross confidence interval.

The [complete Cross multiclass example](inst/examples/cross-multiclass.R) checks
reconstruction for both methods and losses, unequal folds, and a missing fold
class, then scores and plots the final probabilities. Run it against the
installed package with `Rscript inst/examples/cross-multiclass.R`; it is also included
in `example(cross_venn_abers)`. Numerical tests use hand calculations and the
existing reference-checked binary IVAP API followed by independent merging
and combination, with absolute tolerance `1e-10`. **Python 1.5.4 has no matching
public manual Cross-multiclass API**; this shared-fold interface is an R
extension, distinct from Python's trained pairwise model/fold plans.

## Current scope

The package does not support package-managed predictive-model fitting, fold
creation, learned preprocessing, tuning or resampling; repeated or overlapping
partitions; one-fold public cross calibration; regression
calibration; separate pairwise model training or pair-specific fold plans; observation weights; alternate event selection; automatic
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
snippets and every R script under `inst/examples/` against that installation.
Errors, warnings and NOTEs fail the gate. Online CRAN incoming checks and
clock probes are disabled so the prepared R environment can run offline.

The active [workflow](.github/workflows/acceptance.yaml) requires R 4.6.1 and
4.5.3 on Linux x86_64, Windows x86_64, macOS Intel and macOS ARM. Linux R-devel
is an additional visible, non-blocking early warning. New releases require
at least the previous R minor series; recheck the matrix and `DESCRIPTION`
floor at final v0.3 acceptance. Older releases retain their original floor.

Set `ACCEPTANCE_OUTPUT_DIR` to an empty directory to retain the source artifact,
logs and environment/package versions. Set `ACCEPTANCE_ARTIFACT` to an existing
source tarball to check that exact candidate instead of rebuilding. CI builds
once, verifies SHA-256, and checks the same archive on every platform. The five
standalone examples ship in the package; find them after installation with
`system.file("examples", package = "vennabers")`.

See the [v0.3 acceptance record](tools/acceptance-v03.md) for the capability
map, migration notes, commands, results and remaining release blockers. The
[earlier CI record](tools/acceptance-v03-ci.md) describes its starting point.

Benchmarks run separately on the documented Linux x86_64 reference machine:

```sh
Rscript tools/performance.R vennabers_0.3.0.tar.gz vennabers_0.2.0.tar.gz benchmark-output
Rscript tools/test-performance.R benchmark-output
```

The runner prepares fixed inputs outside measurement, installs both artifacts,
and runs cases serially in fresh R processes with one warmup and three measured
runs. It records separate fit/predict times, process peak memory, RDS sizes,
individual results, medians and predecessor comparisons. Only shared v0.2
capabilities receive comparisons; new capabilities receive baselines. Increased
costs require investigation before approval. `--smoke` permits another platform
for runner validation and explicitly does not produce release evidence.

The unchanged 100,000-calibration / 100,000-prediction IVAP case is retained.
The comparative protocol replaces the historical 10-second ceiling. Historical
measurements remain in the [v0.2 record](tools/acceptance-v02.md); they cannot
substitute for remeasuring v0.2 on the same reference machine.
