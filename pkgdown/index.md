# vennabers

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/vennabers)](https://CRAN.R-project.org/package=vennabers)
[![R-CMD-check](https://github.com/RMKruse/vennabers/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/RMKruse/vennabers/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/RMKruse/vennabers/graph/badge.svg)](https://app.codecov.io/gh/RMKruse/vennabers)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
<!-- badges: end -->

Calibrate model predictions in R with Inductive or Cross Venn-Abers methods.
`vennabers` supports binary and multiclass classification (one-vs-one or
one-vs-rest), regression, and optional tidymodels workflows. Start with
[Venn-Abers methods and their guarantees](articles/method.html) for what the
predictors compute and what they guarantee.

## Get started

Fit a calibrator using probabilities from a model trained on separate data:

```r
library(vennabers)

calibrator <- venn_abers(
  truth = c(FALSE, TRUE, FALSE, TRUE),
  probability = c(0.1, 0.4, 0.35, 0.8)
)
predict(calibrator, c(0.2, 0.5, 0.9))
```

The result contains `lower` and `upper` Venn-Abers bounds and a regularized
`probability`. The bounds are not confidence intervals. Keep final assessment
data separate from training, selection and calibration.

A logistic regression that is linear in `x` cannot follow event probabilities
of `plogis(x^3)`. Calibrated on separate data, its probabilities follow the
diagonal of the CORP reliability diagram on independent assessment data; the
[comparison guide](articles/comparison.html) adds Platt scaling and isotonic
calibration.

![CORP reliability diagrams on the assessment data: the logistic model (left) leaves the consistency band, its Venn-Abers calibration (right) follows the diagonal.](reference/figures/README-corp-1.png)

## Choose a guide

- [Venn-Abers methods and their guarantees](articles/method.html): start
  here for what Inductive and Cross Venn-Abers predictors compute, what is
  guaranteed and what is not, for classification and regression.
- [Venn-Abers, Platt and isotonic calibration compared](articles/comparison.html):
  a small illustration on simulated data, with separate training, calibration
  and assessment sets and the limits of what one data set shows.
- [Calibrating supplied predictions](articles/manual-calibration.html):
  binary and multiclass classification, regression, Inductive/Cross methods,
  scoring and plots.
- [Diagnose and assess calibration](articles/diagnostics.html): fit
  diagnoses of the stored calibration map, CORP reliability diagrams with
  uncertainty bands, the Brier decomposition and regression assessment plots.
- [Training and freezing calibrated workflows](articles/workflows.html):
  preprocessing, model training, postprocessing and already fitted workflows.
- [Tuning and assessing the complete procedure](articles/tuning.html):
  Grid/Bayes selection, outer resampling and independent assessment.

The [package overview](reference/vennabers-package.html) connects the main
interfaces. Use the [function reference](reference/index.html) for argument
details and [release notes](news/index.html) for changes.

## Installation

The package requires R 4.5 or later. Install the released version from CRAN:

```r
install.packages("vennabers")
```

Or install the development version from the
[source repository](https://github.com/RMKruse/vennabers):

```r
# install.packages("pak")
pak::pak("RMKruse/vennabers")
```

Manual calibration needs no additional R packages. Workflow integration and
building the guides use the optional packages listed in `DESCRIPTION`; guide
building also requires Pandoc.

## Further examples and support

Browse the annotated example scripts by topic. Each article has a contents list
and commands for running the installed originals:

- [Manual calibration](articles/examples-manual.html): binary options,
  multiclass OvO/OvR, one-hot class decisions and regression, including Cross
  fold matching, fit diagnoses and assessment graphics.
- [Training and frozen workflows](articles/examples-workflows.html): own fit
  and predict functions, fixed engine options, schemas, independent Inductive
  sizes, full-model transfer, pairwise training and adoption of already fitted
  models.
- [Learned postprocessing](articles/examples-postprocessing.html): Sigmoid,
  Tailor and isotonic holdouts, ensembles and full compositions.
- [Grid and Bayes selection](articles/examples-tuning.html): binary, shared
  multiclass, pairwise and regression searches, including postprocessing.

The [example index in the R help](reference/vennabers_examples.html) also lists
the installed scripts and vignette commands. Report problems in the
[issue tracker](https://github.com/RMKruse/vennabers/issues).
