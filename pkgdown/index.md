# vennabers

Calibrate model predictions in R with Inductive or Cross Venn-Abers methods.
`vennabers` supports binary and multiclass classification (one-vs-one or
one-vs-rest), regression, and optional tidymodels workflows.

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

## Choose a guide

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
details and [release notes](news/index.html) for changes and release status.

## Installation

The package requires R 4.5 or later. From a local checkout of the
[source repository](https://github.com/RMKruse/vennabers):

```sh
R CMD build .
R CMD INSTALL vennabers_1.0.0.tar.gz
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
the installed scripts and vignette commands. The
[parity guide](https://github.com/RMKruse/vennabers/blob/HEAD/inst/PARITY.md)
that separates numerical agreement with the Python reference from R extensions
and limitations. Report problems in the
[issue tracker](https://github.com/RMKruse/vennabers/issues).
