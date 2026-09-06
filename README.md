# venn-abers

Dependency-free binary Inductive Venn-Abers calibration for R 4.1 and later.

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

The public functions are `venn_abers()`, `brier_score()`, `log_loss()`, and
`calibration_plot()`. Prediction and printing are available through the
registered `predict()` and `print()` methods.

## v0.1 scope

Version 0.1 does not support Cross Venn-Abers, multiclass calibration,
regression, predictive-model fitting or resampling, observation weights,
custom event-class selection, coercion or missing-value handling, precision or
rounding controls, formula or data-frame interfaces, tidymodels or yardstick
integration, smoothing or `ggplot2` output, or CRAN submission guarantees.

There is no vignette. R-devel, R releases older than 4.1, CRAN-mode checks, and
PDF-manual checks are outside the v0.1 acceptance boundary.

## Acceptance

Run the complete local gate from the package root:

```sh
Rscript tools/acceptance.R
```

It records the R and performance environments, builds the source package,
runs `R CMD check --no-manual` on that artifact, executes all contract and
parity tests and documentation examples, and runs the 100,000-row performance
check. CI runs the same gate under R 4.1 and the latest stable R.
