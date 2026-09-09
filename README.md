# venn-abers

Dependency-free binary Inductive/Cross, multiclass Inductive/Cross OvO/OvR,
and moderated Inductive/Cross regression calibration for R 4.5 and later.
The v0.5.0 candidate adds optional native workflows for all eight combinations
of binary/OvO/OvR/regression and Inductive/Cross calibration. The
[v0.5 acceptance record](tools/acceptance-v05.md) identifies the candidate,
support/dependency matrix and missing release evidence. The maintainer's
[v0.4 approval](tools/acceptance-v04.md) remains a completed predecessor decision;
its local-only rule does not approve v0.5. Publication is separate.

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

## Calibrating an already fitted workflow

`calibrate_workflow(fitted_base, calibration, "truth")` returns an already fitted
predictor. It learns only the VA calibrator from the original workflow's final
named probabilities, preserving its learned recipe and any learned postprocessor.
Supply raw inputs in the learned format; no `bake()` or subsequent `fit()` is needed.
Use `predict(..., type = "prob")`, `type = "class"`, and `venn_abers_details()`.
Both event levels, Log/Brier overrides, calibration-only rounding and empty
predictions are supported. The outcome is removed before the frozen path predicts.

The user must keep the new calibration data outside all earlier training,
postprocessing and model selection, and keep final assessment separate as well.
That history is not automatically checked. This is an R extension for Inductive
calibration, not a Cross ensemble or full-model transfer. `saveRDS()` retains the
complete predictor; fresh processes need its packages, and external resources
retain their engine-specific storage requirements.

For a workflow trained on encoded names, retain its original schema. Encode new
calibration and prediction data with `venn_abers_encode(data, schema)` and pass
`outcome = schema$encoded_outcome, schema = schema` to `calibrate_workflow()`.
Omitted classification/event options inherit that schema; contradictory options
fail. Native predictions remain encoded; `venn_abers_decode()` restores original
identities and existing diagnostics in separate roles. Matching codes alone
cannot prove a detached workflow's training provenance.

Workflows trained on original names keep original inputs with `schema = NULL`.
Creating a schema afterward cannot rewrite a learned recipe or repair an old
workflow's failed prediction path. Errors retain stage, names and cause; there
is no automatic raw or extracted-engine fallback.

The installed example includes earlier recipe and Tailor learning, separate new
calibration and independent assessment (requires Tailor and probably):

```r
source(system.file("examples", "frozen-binary.R", package = "vennabers"))
```

For a shared multiclass workflow, explicitly choose `classification = "ovo"`
or `"ovr"`, also for a two-class matrix problem. Every stored class must occur
in calibration; predictions retain the original factor order, and ties select
its first level. `venn_abers_details()` includes binary pair/OvR results.

A regression workflow selects IVAR automatically. Call
`calibrate_workflow(fitted_regressor, calibration, "truth", epsilon = .1)`;
`predict(..., type = "numeric")` returns `.pred`, and `venn_abers_details()`
returns separate IVAR bounds with row IDs.

Omit both `m` and `epsilon` (or set both to NULL) for `m = 1`; otherwise supply
exactly one valid moderation parameter. Requested and effective values are saved.
Regression rejects explicit classification, event, loss and precision options.
IVAR bounds are not confidence or prediction intervals.

The installed example demonstrates all three paths with learned postprocessing:

```r
source(system.file("examples", "frozen-multiclass-regression.R", package = "vennabers"))
source(system.file("examples", "frozen-schema.R", package = "vennabers"))
```

The original workflow must predict successfully at the requested batch size.
The example uses smooth multinomial Tailor calibration: the tested probably
1.2.0 `smooth = FALSE` path fails on a single row, and that error is propagated.

## Automatic classification workflow calibration

`calibrated_workflow(base, outcome = "truth", seed = 42)` wraps a configured,
unfitted tidymodels workflow. Use `generics::fit()` on development data, then
ordinary `predict(..., type = "prob")` or `type = "class"`. The outer Variables
preprocessor carries raw columns; put recipes in `base`. One complete base workflow
learns on 80% of the data by default, and its held-out probabilities calibrate the
binary Inductive core. Both factor levels must exist in the development data.

Use `method = "cross"` to retain five complete base workflows by default (`v`
sets the count, at least two). Each workflow learns its recipe/model on one fold's
complement and calibrates on that held-out fold. New data follow all matching
paths; the existing Cross core combines them with stable log aggregation or the
equal-weight mean of Brier fold points. There is no full-data model, size weighting
or pooled calibration. Invalid partitions fail before training, and any failed
fold fails the whole fit. `strata = FALSE` disables default outcome stratification;
otherwise splitting uses `pool = 0`, without retries or fold-count reduction.

`venn_abers_details(fitted, new_data)` returns native probabilities plus row/fold
bounds. `workflows::extract_fit_engine(fitted)` exposes the model, calibrator,
original class names, split positions, options and versions. Set `event_level`
to `"first"` (default) or `"second"`; the event class wins ties. Set `loss` at
construction or override it in predict/details without refitting. Calibration-only
`precision` accepts NULL and whole numbers, including negatives.

The integration packages listed in DESCRIPTION are optional and must be installed
explicitly; manual calibration still loads without parsnip. The installed example
runs fit, prediction, diagnostics and a comparison to its stored default:

```r
source(system.file("examples", "calibrated-workflow.R", package = "vennabers"))
```

Keep final assessment data separate. This local split cannot undo prior tuning or
external transformations using calibration/assessment observations. The statistical
setting assumes IID data and a model fixed independently of calibration data;
improved scores on every test set are not guaranteed. This first automatic path
supports binary and multiclass Inductive/Cross calibration, direct explicit splits, and complete outer
IID evaluation. See `?calibrated_workflow` for exact input and naming boundaries.


Pass `splits = rsample::initial_split(development)` for a direct explicit fit,
or `splits = function(data) ...` to construct a split from each local outer analysis
set. Cross accepts a simple `vfold_cv()` or `manual_rset()` partition. Omit automatic
`calibration_prop`, `v` and `strata` when supplying a plan.
`local_calibration_splits(prepared, columns = c("x", "truth"))` builds a serializable
resolver from a list of prepared local splits. It checks every entry and rejects
conflicting ordered assignments for identical data. Matching uses selected raw
columns, types, values, factor levels and row order, ignoring container class and
row names. Duplicate observations remain distinct positions. Arbitrary callbacks
must obey this contract themselves; hidden closure state cannot be audited
automatically. Never use call counters or outer assessment data in a resolver.

Ordered Inductive holdouts use the same explicit-plan API. For example, with
`n` local rows and calibration fraction `q`, reserve `ceiling(n * q)` trailing
rows and train on the preceding `n - ceiling(n * q)` rows. Both parts must be
nonempty. At `n = 11, q = .25`, training is positions 1–8 and calibration is
9–11. Use `rsample::make_splits()` to preserve those positions without sorting,
mixing or stratifying. A callback applies this rule separately in the row order
of each outer analysis set. The installed
[`examples/reference-splits.R`](inst/examples/reference-splits.R) implements this
rule and demonstrates all eight training paths, complete non-shuffled folds,
and a small stratified reference assignment. No new splitter is required.

Cross supports ordinary or classification-stratified partitions, mixed or
non-shuffled. Every local row must be held once, and each model trains on the
exact complement of its fold. Non-shuffled folds can train on later rows; they
are not forward validation. Noncomplementary forward plans, repeated/overlapping
inner folds and incomplete assignments fail. Specialized group/time split classes
remain unsupported. Ordered plans do not relax class, base-model trainability or
regression moderation requirements, and invalid plans are never repaired.

For mixed automatic plans, use `seed` and record RNG kind, R/package versions
and engine settings; classification stratifies unless `strata = FALSE` and
regression does not stratify. Explicit plans retain their actual positions and
fold IDs in `workflows::extract_fit_engine(fit)$folds`; requested settings and
effective automatic settings are separate in `$parameters`. Identical R/Python
seeds do not establish equal splits or training. Numerical core comparisons
require the same model outputs, options and assignments.

The installed examples use small synthetic binary, multiclass and regression
tasks inspired by the [documented paper applications](tools/paper-group-time-scenarios.md),
with separate model-training, calibration and final-assessment roles.
Machine-failure detection is classification. Temperature forecast correction is
regression, and its subject alone does not establish time-series validation.
These examples promise neither universally better scores nor individual-interval
coverage, including for dependent data or Cross aggregates.

Use `classification = "ovo"` or `"ovr"` with a multiclass base workflow for
Inductive or Cross calibration. Both use shared multiclass models and the existing
factor/matrix core, including for two classes. Inductive's holdout must contain
every stored class. Cross uses one shared model per fold complement and requires
every class globally in out-of-fold calibration. A fold may omit classes;
nonempty single-class or singleton subcalibrations are valid. Empty OvO pairs
fail before model training with pair and fold context. Probability columns must exactly match `.pred_` plus the original
class names; values must be finite in [0,1] and sum to one within 1e-8. The core
normalizes within that tolerance. Distinct names such as `a b` and `a.b` remain
distinct with a compatible engine; reserved `class` and `.pred_*` levels fail
before learning. Class predictions favor the first maximal stored level.

OvO normalizes each pair, uses 0.5 for zero-sum pairs, then optionally rounds
calibration scores (including 0.5 to 0 at `precision = 0`). OvR calibrates every
class against all remaining observations. New scores remain unrounded. Details
add `method`, `event_class`, and `class_1`/`class_2` or `class`; their binary points
reconstruct final probabilities through OvO coupling or OvR normalization. For
Cross, first merge each binary subproblem across folds using Log/Brier, then
couple or normalize. Never average completed multiclass fold matrices.
`event_level` is binary-only. This shared R plan does not establish parity with
Python's separate pair-model training. `model_training = "shared"` is the
multiclass default. For separate binary models, use `model_training = "pairwise"`
with `classification = "ovo"`, either calibration method, and matching models:

```r
pair_data <- data.frame(x = sin(1:120),
  truth = factor(rep(c("a", "b", "c"), 40)))
pair_base <- workflows::workflow() |>
  workflows::add_formula(truth ~ x) |>
  workflows::add_model(parsnip::logistic_reg(engine = "glm"))
pair_model <- calibrated_workflow(pair_base, "truth", classification = "ovo",
  model_training = "pairwise", seed = 42)
pair_fit <- generics::fit(pair_model, pair_data)
```

Each pair gets its own local holdout or Cross partition after filtering to its two classes; the later
global level is the event. A split callback receives that pair's data, or a direct
fit can supply a list named `pair_1`, `pair_2`, etc. All plans are validated before
learning. Inductive requires both classes in training and calibration. Cross allows
nonempty one-sided calibration folds when their complements produce trainable
binary models and valid probabilities. Recipes learn only
on pair training rows; binary calibrators use matching held-out predictions.
The global schema and class order remain unchanged. Details retain pair/fold IDs,
class identities, model sources and endpoints that reconstruct global probabilities.
Cross aggregates binary folds within each pair before global reciprocal coupling.
Explicit pair partitions may have different fold counts; equal fold IDs across
pairs are unrelated. Every local row is assessed once, with complementary training.
Automatic partitions use `v` without reduction. For K classes, Inductive costs
K*(K-1)/2 base fits; Cross costs the sum of pair fold counts (15 for three classes
with five folds). Each nonempty prediction calls every retained model once.
Full pair training and tuning are not enabled by this option.
Explicit training options remain invalid for binary and regression workflows.
See [the installed pairwise example](inst/examples/pairwise-inductive.R) for
binary reference workflows, local plans, coupling, decoding and outer evaluation.
The [Cross pair example](inst/examples/pairwise-cross.R) shows explicit unequal
partitions, binary reconstruction, native/decoded details and outer fit costs.

The installed evaluation example uses ordinary repeated `fit_resamples()` and a
prepared resolver, aligns constructor/control event levels, and retains every
fitted engine via `extract`. It audits all unsummarized predictions and metrics
against expected resample/repeat/configuration/row identities and checks notes,
missing truths, finite probabilities and hand-computed scores:

```r
source(system.file("examples", "calibrated-resampling.R", package = "vennabers"))
```

It also runs Inductive/Cross OvO and OvR with an `nnet` multinomial model and locally learned
normalization: automatic/explicit fit, probability/class prediction, details,
and repeated outer evaluation. Yardstick's multiclass Brier is half the manual
matrix score, including the two-class matrix path; Log/Brier prediction defaults
and overrides retain the manual core's behavior.

The same example shows Cross fit, predict and fold diagnostics, then five outer
by five inner folds: 25 base fits, with no automatic final fit. Extracting all
states retains all 25 workflows plus recipes/calibrators. Calibration is not an
independent evaluation; keep outer assessment and final test data separate from
training, calibration and parameter selection. Cross requires independently fixed
parameters or suitable nested selection, which this constructor does not perform.

The constructor's stored `loss` controls native outer predictions. Yardstick's
binary Brier matches the binary vector score; log-loss clips only for scoring.
An inner fit failure, metric error, NA removal, or missing row makes the evaluation
incomplete, even if collectors or averages succeed. `save_workflow` alone does not
retain every fitted predictor: use `extract = workflows::extract_fit_engine`,
`extract = identity` for entire workflows, or select compact diagnostics.

`seed = NULL` uses the caller/tune stream; an explicit seed locally covers both
plan resolution and training and restores the caller RNG state. Seed outer plans
separately and retain RNG kind, actual splits and engine configuration. Inner fits
are serial. Outer parallelism uses `parallel_over = "resamples"`; load `vennabers`
and base-engine namespaces in fresh workers using `pkgs`. Repeatability requires
the same RNG kind, versions, seeds, threads, strategy and reproducible engine.
The engine never sees the outer partition: the example validates each outer
analysis/assessment pair before fitting. Assessments may overlap across resamples.

## Classification full-model transfer

Set `prediction_model = "full"` when constructing a binary, shared OvO/OvR or regression Inductive or Cross
`calibrated_workflow()`. The default `"matched"` retains the matching source
models. Both modes use identical held-out calibration sources on the same plan.
Full transfer additionally fits a fresh complete recipe/model on all local fit
rows, including calibration rows, and discards the temporary source models.
New observations use that model once per batch through all retained calibrators.

```r
source(system.file("examples", "full-model-workflow.R", package = "vennabers"))
source(system.file("examples", "full-multiclass-workflow.R", package = "vennabers"))
source(system.file("examples", "full-regression-workflow.R", package = "vennabers"))
```

Inductive costs two base fits, Cross K+1. `fit_resamples()` and `last_fit()` keep
all learning inside their analysis data; no final fit includes test data.
`full` is a fixed fit option, with no prediction-time mode switch or automatic
selection. The installed `examples/full-model-workflow.R` compares both modes
on identical plans. Details retain fold identity separately from model source;
RDS retains the full recipe/model, calibration values and calibrators.
Matching-model calibration/coverage guarantees do not automatically transfer,
and full transfer need not improve quality. Frozen `calibrate_workflow()` still
preserves the already trained procedure without fitting a new model.

Shared multiclass full-model transfer is an R extension. One complete class
matrix supplies every pair/class calibrator and every Cross fold; binary fold
aggregation precedes OvO coupling or OvR normalization. Native and decoded
details identify `model_training`, `prediction_model`, `model_source` and the
original classes and calibration folds. Stored calibration provenance includes
complete held-out class matrices, factor truths and local row identities.
The multiclass example checks repeated outer assessments and `last_fit()`;
yardstick Brier remains half the manual matrix score, also for two classes.

Regression transfer uses the existing weighted IVAR points, including the exact
zero-weight midpoint rule. CVAR averages complete fold points and each bound
separately with equal weights. Details carry `prediction_model` and `model_source`;
Cross descriptive aggregates also identify the mode and list contributing model
IDs in `model_source`. Decoding preserves numeric values and the original outcome
name. State retains held-out numeric predictions/truths and fold moderation.
The installed regression example compares matched/full RMSE and MAE, reconstructs
bounds and checks outer assessment and `last_fit()`. Python 1.5.4 offers regression
full-model transfer through the exported lower `VennAbersCV` class; its regression
facade does not expose that option. Transfer gives no new coverage or quality guarantee.

## Automatic regression workflow calibration

The base model's `regression` mode selects IVAR/CVAR, including for numeric 0/1
truth. Both methods reuse the same local split plans and complete base workflows:

```r
if (all(vapply(c("workflows", "parsnip", "rsample"), requireNamespace,
               logical(1), quietly = TRUE))) {
  development <- data.frame(x = sin(1:100), truth = 10 + 3*sin(1:100) + cos(1:100))
  base <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::linear_reg(engine = "lm"))
  for (method in c("inductive", "cross")) {
    model <- calibrated_workflow(base, "truth", method = method, epsilon = .3, seed = 42)
    fitted <- generics::fit(model, development)
    predict(fitted, data.frame(x = c(-.8, .7)), type = "numeric")
    venn_abers_details(fitted, data.frame(x = c(-.8, .7)))
    workflows::extract_fit_engine(fitted)$parameters$effective
  }
}
```

Omit both `m` and `epsilon` for effective `m=1`, or set one moderation option.
Every calibration fold must satisfy the core's domain before any training begins.
Explicit classification, event, precision and loss options are errors for regression.
Preprocessing learns only within each corresponding model's training portion.
`.pred` contains weighted IVAR points or equal-weight CVAR points in outcome units.
The separate bounds concern regularized conditional expectations; Cross aggregate
bounds are descriptive. Neither confidence/prediction intervals nor improved scores
are promised. The installed `examples/calibrated-resampling.R` demonstrates both
methods with imputation/scaling, automatic/prepared local plans, and full outer
RMSE/MAE evaluation, auditing every assessment row and metric with normal yardstick
conventions. Calibration data are not an independent evaluation set.

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
The manual core does not train models or create splits. Regression score/plot
helpers, exact minimax,
observation weights and rounding options remain outside this implementation.

## Cross regression

`cross_venn_abers_regression(truth, prediction, fold)` accepts finite real-valued
truth and out-of-fold model predictions, aligned by position. Supply one fold
ID per observation and at least two represented folds: nonempty character
labels or finite positive whole-number numeric IDs, with no factors or logical
IDs. Every fold must satisfy the IVAR moderation domain. Unequal sizes are valid.

```r
cross_regression <- cross_venn_abers_regression(
  c(-10, 0, 2, 6, 20, 10, 10, 10), rep(0, 8),
  rep(c("A", "B"), c(5, 3))
)
# Each column comes from its retained model, for the same new rows.
regression_details <- predict(cross_regression,
                              cbind(B = c(1, 0), A = c(-1, 0)), type = "details")
regression_details
lapply(cross_regression$calibrators, function(x) x[c("requested", "m", "epsilon")])
source(system.file("examples", "cross-regression.R", package = "vennabers"))
```

Each fold receives a complete IVAR fit. The default `m=1`, explicit `m`, and
alternative `epsilon` follow the Inductive contract above. With epsilon,
`m_f=floor(epsilon*(k_f+1)/2)` and effective `epsilon_f=2*m_f/(k_f+1)` may
differ across folds. The named `calibrators` list retains each fold's requested
and effective parameters and size. Invalid moderation in any fold fails the
entire fit with fold context, without capping or omission.

Predict requires a finite numeric matrix with exactly one uniquely named column
per fold. Column order may change; missing, additional, duplicate, empty or
absent names are errors. Rows align by position, regardless of row names.
Inputs are never rounded or clipped, including tied and exterior scores.
Unsupported options are errors. Predict trains nothing.

First compute complete IVAR points and bounds per fold. Then take separate
equal-weight arithmetic means of points, lower bounds and upper bounds, even
for unequal fold sizes. No pooling, size weighting or new point merger on
averaged bounds occurs. Default output has double columns `prediction`, `lower`,
`upper`; details add the named list `folds` with the same complete schema.
Zero and one row retain their schema, and empty details retain every fold ID.
All three aggregates can be reconstructed from these fold results. Fits survive
`saveRDS()`/`readRDS()` in a fresh R process with the package loaded.

The installed example retains three `lm()` models, excluding each held-out
fold from the entire learned procedure, then uses those same models for the
new matrix columns. Separate assessment outcomes enter only the RMSE/MAE
evaluation. The caller is responsible for model provenance, including learned
preprocessing and tuning, and semantic row identity across columns; matching
names cannot verify these. A model retrained on all development data cannot
replace the fold models. The theoretical setting assumes IID observations
and a model fixed independently of its calibration observations.

Aggregated bounds are descriptive fold summaries without an additional
coverage or selector guarantee. They are not confidence or prediction intervals
for individual outcomes, and no score improvement is promised. The
[Cross reference record](inst/extdata/cross-regression-reference.md) documents
offline Python 1.5.4 IVAR component evidence and independent aggregation;
there is no corresponding public manual Python CVAR wrapper.

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

The seven public functions are `venn_abers()`, `cross_venn_abers()`,
`venn_abers_regression()`, `cross_venn_abers_regression()`, `brier_score()`,
`log_loss()`, and `calibration_plot()`. All four calibrators use registered
`predict()` methods; the classification calibrators also have registered
`print()` methods. See `?cross_venn_abers` and
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
partitions; one-fold public cross calibration;
full pairwise model training; observation weights; alternate event selection; automatic
coercion or missing-value handling; fold-size weighting, pooling or averaging
log-loss fold point predictions; public aggregate classification cross bounds; formula/data-frame
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
floor for each release. Older releases retain their original floor.

Set `ACCEPTANCE_OUTPUT_DIR` to an empty directory to retain the source artifact,
logs and environment/package versions. Set `ACCEPTANCE_ARTIFACT` to an existing
source tarball to check that exact candidate instead of rebuilding. CI builds
once, verifies SHA-256, and checks the same archive on every platform. The
standalone examples ship in the package; find them after installation with
`system.file("examples", package = "vennabers")`.

See the [v0.4 acceptance record](tools/acceptance-v04.md) for the capability
map, migration notes, commands, results and the updated approval criterion.
The [v0.3 record](tools/acceptance-v03.md) records maintainer approval and retains
the historical evidence. Unexecuted platform and Linux benchmark checks are
not blockers under the updated v0.4 criterion and are not claimed as passes.

Benchmarks run separately on the documented Linux x86_64 reference machine:

```sh
Rscript tools/performance.R vennabers_0.4.0.tar.gz vennabers_0.3.0.tar.gz benchmark-output
Rscript tools/test-performance.R benchmark-output --v04
```

The runner prepares fixed inputs outside measurement, installs both artifacts,
and runs cases serially in fresh R processes with one warmup and three measured
runs. It records separate fit/predict times, process peak memory, RDS sizes,
individual results, medians and predecessor comparisons. All twelve classification
cases are compared with v0.3. IVAR and CVAR each add baselines for `m = 1` and
`epsilon = 0.1`, with 10,000 calibration rows, 1,000 new rows and five CVAR folds.
The runner checks moderation per fold and saves exact inputs and row assignments. Increased
costs require investigation before approval. `--smoke` permits another platform
for runner validation and explicitly does not produce release evidence.

The unchanged 100,000-calibration / 100,000-prediction IVAP case is retained.
The comparative protocol replaces the historical 10-second ceiling. Historical
measurements remain in the [v0.2 record](tools/acceptance-v02.md); they cannot
substitute for remeasuring v0.3 on the same reference machine.

### Reversible names for calibrated workflows

Create one schema from the selected development columns, encode the data, and
build the base formula/recipe and outer resamples on those encoded names. Pass
`schema$encoded_outcome` and `schema = schema` to `calibrated_workflow()`.
`venn_abers_decode()` keeps probability matrices, class factors, truth, the
numeric regression predictions, original outcome name, and resample identities
in separate roles, so names such
as `class`, `.pred_class`, and `id` cannot overwrite each other. Native results
remain encoded. Detached collector tables require their actually associated
schema; matching codes alone cannot establish provenance.

Factor outcomes use `classification = "binary"`, `"ovo"`, or `"ovr"`; only binary
accepts `event_level`. Numeric outcomes remain regression, including 0/1, and
require both options to be omitted. Multiclass preserves the complete factor
level order, including the first-maximum tie rule with two classes. Regression
keeps numeric points, details and available Cross aggregate bounds.

The installed examples cover all eight trainable methods, with preparation,
prediction and repeated outer evaluation with exact identity and decoded-metric
checks:

```r
source(system.file("examples", "encoded-binary.R", package = "vennabers"))
source(system.file("examples", "encoded-multiclass-regression.R", package = "vennabers"))
```
