# venn-abers

`vennabers` calibrates model predictions in R. It supports binary and multiclass
classification (one-vs-one or one-vs-rest) and regression, each with Inductive
or Cross calibration.

You can supply predictions from an existing model or use optional tidymodels
workflows to fit models and create calibration splits. The package requires
R 4.5 or later.

## Installation

From a local checkout:

```sh
R CMD INSTALL .
```

The manual calibration functions need no additional R packages. Workflow
integration uses the optional packages listed in `DESCRIPTION`.

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

Use `method = "cross"` for fold-based workflow calibration. See
`?calibrated_workflow` and `?calibrate_workflow` for split, model and prediction
options.

Binary matched workflows also support
`postprocessing = list(method = "sigmoid", strategy = "holdout", prop = .3,
sigmoid_input = "probability")`. Select `"glm_link"` explicitly for binomial
GLM logit inputs through the complete workflow and recipe. Sigmoid requires
both classes in B and P, at least two P rows, and no existing postprocessor.
It uses sklearn-compatible smoothed targets without a Python runtime dependency.

Binary and shared OvO/OvR matched workflows can learn Tailor postprocessing on a separate
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

## Learn more

- [Binary Cross example](inst/examples/cross-venn-abers.R)
- [Binary Sigmoid holdout example](inst/examples/sigmoid-holdout.R) with probability and GLM-link inputs
- [Regression Tailor holdout example](inst/examples/tailor-regression-holdout.R) with IVAR/CVAR and native evaluation
- [Regression isotonic holdout example](inst/examples/isotonic-regression-holdout.R) with IVAR/CVAR and native evaluation
- [Regression ensemble example](inst/examples/regression-ensemble.R) with both numeric methods, native evaluation and held-out data checks
- [Shared multiclass ensemble example](inst/examples/multiclass-ensemble.R) with retained pairs, encoded names and native evaluation
- [Shared multiclass Tailor holdout example](inst/examples/tailor-multiclass-holdout.R) with encoded names and native evaluation
- [Binary Tailor holdout example](inst/examples/tailor-holdout.R) with diagnostics, resampling and last_fit
- [Multiclass example](inst/examples/inductive-ovo.R) and [Cross multiclass example](inst/examples/cross-multiclass.R)
- [Shared multiclass grid example](inst/examples/shared-multiclass-grid.R) for OvO/OvR and joint/two-stage selection
- [Shared multiclass Bayes example](inst/examples/shared-multiclass-bayes.R) for complete OvO/OvR matrix selection
- [Pairwise OvO grid example](inst/examples/pairwise-grid.R) for local pair grids and coupled selection
- [Pairwise OvO Bayes example](inst/examples/pairwise-bayes.R) for local pair searches and coupled selection
- [Regression grid example](inst/examples/regression-grid.R) for IVAR/CVAR with joint or two-stage selection
- [Regression Bayes example](inst/examples/regression-bayes.R) for IVAR/CVAR with joint or two-stage selection
- [Regression example](inst/examples/inductive-regression.R) and [Cross regression example](inst/examples/cross-regression.R)
- [Workflow example](inst/examples/calibrated-workflow.R) and [fitted workflow example](inst/examples/frozen-binary.R)
- [Release notes](NEWS.md)
- [v0.8 local acceptance record](tools/acceptance-v08.md) for the support matrix and open release gates

Run `help(package = "vennabers")` for the complete function reference.
