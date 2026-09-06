# venn-abers

Dependency-free binary Inductive and Cross Venn-Abers calibration for R 4.1
and later. Version 0.2 adds matched-fold cross calibration.

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
the Venn-Abers interval endpoints; `probability` is the log-loss regularized
event probability. These endpoints are not confidence intervals.

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
There is no public aggregate interval or fold diagnostic output. Geometric
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
character matrices are rejected. Neither fitting options nor prediction
options in `...` are supported. Inputs with missing values, nonbinary truth,
nonfinite values or probabilities outside `[0, 1]` fail without dropping rows,
coercing representations, clipping or rounding probabilities.

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

## v0.2 scope

Version 0.2 does not support package-managed predictive-model fitting, fold
creation, learned preprocessing, tuning or resampling; repeated or overlapping
partitions; one-fold public cross calibration; multiclass or regression
calibration; observation weights; alternate event selection; automatic
coercion or missing-value handling; precision/rounding controls; alternate
aggregation (including Brier-loss, fold-size weighting, pooling or averaging
fold point predictions); public cross bounds/diagnostics; formula/data-frame
cross interfaces; tidymodels/yardstick integrations; or new metrics, smoothing,
plotting features or `ggplot2` output.

There is no vignette. R-devel, R releases older than 4.1, CRAN-mode checks, and
PDF-manual checks are outside acceptance, as are CRAN submission guarantees
and release publishing. Only Base R and standard R distribution packages are
needed. Installation and acceptance require neither Python nor networking;
regenerating the stored Python reference fixtures is optional and separate.

## Acceptance

Run the complete local gate from the package root:

```sh
Rscript tools/acceptance.R
```

It records the R and performance environments, builds the source package,
runs `R CMD check --no-manual` on that artifact with zero errors, warnings and
notes, and executes all IVAP and cross contract/parity tests and help examples.
It installs the artifact into an isolated library, verifies its loaded path
and version, executes the README R snippets and the canonical standalone
script, and separately runs the preserved IVAP performance check: the median
of three runs fitting 100,000 and predicting 100,000 observations must be at
most 10 seconds. No Cross Venn-Abers timing ceiling is imposed.

Run the same complete gate on R 4.1.3 and latest stable R. The preserved CI
matrix specifies `4.1.3` and `release`; its workflow is currently disabled.
Successful local evidence for both versions is recorded in
[the v0.2 acceptance record](tools/acceptance-v02.md).
