# vennabers

`vennabers` calibrates model predictions in R with Inductive or Cross
Venn-Abers methods. It supports binary classification, multiclass
classification (one-vs-one or one-vs-rest) and regression.

You can calibrate predictions from a model you already have, or let optional
tidymodels workflows fit the model, create the calibration splits and tune the
complete procedure.

## Installation

`vennabers` requires R 4.5 or later. Install it from a local checkout of this
repository:

```sh
R CMD build .
R CMD INSTALL vennabers_1.0.0.tar.gz
```

Calibrating supplied predictions needs no additional packages. The tidymodels
workflows and the vignettes use the optional packages listed under `Suggests`
in `DESCRIPTION`.

## Example

Fit a calibrator with probabilities from a model trained on separate data, then
calibrate probabilities for new observations:

```r
library(vennabers)

truth <- c(FALSE, TRUE, FALSE, TRUE)
uncalibrated <- c(0.1, 0.4, 0.35, 0.8)
calibrator <- venn_abers(truth, uncalibrated)

prediction <- predict(calibrator, c(0.2, 0.5, 0.9))
prediction
brier_score(c(FALSE, TRUE, TRUE), prediction$probability)
```

`prediction` holds the `lower` and `upper` Venn-Abers bounds and a regularized
`probability`. The bounds are not confidence intervals.

With tidymodels installed, `calibrated_workflow()` trains a workflow and its
calibrator together:

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

## Overview

| Task | Function |
| --- | --- |
| Calibrate binary or multiclass probabilities | `venn_abers()`, `cross_venn_abers()` |
| Calibrate numeric predictions | `venn_abers_regression()`, `cross_venn_abers_regression()` |
| Fit and calibrate a tidymodels workflow | `calibrated_workflow()` |
| Calibrate an already fitted workflow | `calibrate_workflow()` |
| Use your own fit and predict functions in a workflow | `model_adapter()` |
| Score and plot calibration | `brier_score()`, `log_loss()`, `calibration_plot()` |

## Documentation

Start with `?vennabers` for the package overview, then follow the guides:

- [Calibrating supplied predictions](vignettes/manual-calibration.Rmd):
  `vignette("manual-calibration", package = "vennabers")`
- [Training and freezing calibrated workflows](vignettes/workflows.Rmd):
  `vignette("workflows", package = "vennabers")`
- [Tuning and assessing the complete procedure](vignettes/tuning.Rmd):
  `vignette("tuning", package = "vennabers")`

Runnable example scripts for every interface are collected in
`?vennabers_examples`, and learned postprocessing is covered in
`?workflow_postprocessing`.

## Relationship to Python venn-abers

This is an independent R implementation. Its shared core results are checked
against reference outputs of the Python package
[venn-abers](https://github.com/ip200/venn-abers).
[`PARITY.md`](inst/PARITY.md) separates numerical parity from R extensions,
documented deviations and accepted limits.

## Stability

From 1.0.0 on, the user-facing functions, their arguments and defaults, and
their documented output formats stay compatible throughout 1.x. See
[NEWS](NEWS.md) for the full promise and for migrating from 0.9.0.

## Contributing

Report problems in the [issue tracker](https://github.com/RMKruse/venn-abers/issues).
See [CONTRIBUTING](.github/CONTRIBUTING.md) for running the tests and building
the documentation.

## References

- Vovk and Petej (2014). Venn-Abers predictors. <doi:10.48550/arXiv.1211.0025>
- Vovk, Petej and Fedorova (2015). Large-scale probabilistic predictors with
  and without guarantees of validity. <doi:10.48550/arXiv.1511.00213>
- Manokhin (2017). Multi-class probabilistic classification using inductive
  and cross Venn-Abers predictors.
  <https://proceedings.mlr.press/v60/manokhin17a.html>

## License

MIT
