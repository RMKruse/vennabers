\name{cross_venn_abers}
\alias{cross_venn_abers}
\title{Fit a Binary Cross Venn-Abers Calibrator}
\usage{
cross_venn_abers(truth, probability, fold, precision = NULL)
}
\arguments{
  \item{truth}{A non-empty logical or numeric/integer vector containing only
  \code{FALSE}/\code{0} and \code{TRUE}/\code{1}. The event class is always
  \code{TRUE}/\code{1}.}
  \item{probability}{A numeric/integer vector of out-of-fold event
  probabilities, finite and in \code{[0, 1]}, aligned with \code{truth}.}
  \item{fold}{An aligned vector of non-empty, non-missing character labels
  or finite positive whole-number numeric/integer IDs. Character matching is
  literal, without trimming or case folding. Numeric IDs match their Base R
  \code{as.character} representations. Repeated IDs indicate membership in
  the same fold. Factors and logical IDs are not supported.}
  \item{precision}{\code{NULL} (default) disables rounding. Otherwise, one
  finite numeric whole number, including zero or negative values, used for
  native R rounding of calibration probabilities in every fold. See
  \code{\link{venn_abers}} for validation and rounding semantics.}
}
\value{
An opaque S3 object of class \code{"cross_venn_abers"}, retaining fold
identities and calibration state for repeated predictions. Internal fields
are not public API. Predictive models are retained separately by the caller.
}
\description{
Fits one Inductive Venn-Abers calibrator per calibration fold. Prediction
combines its results with equal-weight log-loss (default) or Brier aggregation
to produce a regularized event probability.
}
\details{
All three inputs must be vectors of equal, nonzero length with no missing
values. Names attached to vector elements are not alignment keys: positions
must refer to the same observation. Invalid types, shapes, nonbinary truth,
nonfinite values, or out-of-range probabilities cause an error for the entire
call. No rows are dropped and probabilities are not clamped or coerced from
other representations. Original probabilities are checked before optional
rounding; exact ties after rounding are combined. New prediction values are
never rounded. Changing precision requires refitting, while loss is chosen
at prediction time. R and NumPy rounding can differ at floating-point boundaries.

Supply one non-overlapping partition with at least two represented non-empty
folds. Unequal sizes, singleton folds, and single-class folds are supported;
each fold receives equal aggregation weight regardless of its size. There is
no separate empty-fold declaration. Use \code{venn_abers()} for one calibration
set.

Each fold model must exclude its calibration fold from the entire learned
training pipeline, including preprocessing and tuning. That same model must
produce both its fold's out-of-fold probabilities and its corresponding named
column of new-observation probabilities. Retain those models for subsequent
prediction: a single model refitted on all data is not a replacement. Keep
evaluation truth outside model fitting and calibration.

Callers ensure each underlying calibration observation appears once and that
new-observation rows align across model columns. The supplied arrays cannot
prove model provenance, training exclusion, absence of leakage, unique
underlying observations, or semantic row alignment.

Cross output defaults to a regularized probability. Classes and individual
fold results are available via \code{\link{predict.cross_venn_abers}}. There is
no aggregate interval. Geometric aggregate endpoints can cross.
Neither those endpoints nor the combined point inherit the IVAP
perfect-calibration guarantee. They are not confidence intervals, and score
improvement is not guaranteed on every data set.
}
\section{Unsupported inputs and features}{
Package-managed predictive-model fitting, fold generation, preprocessing,
tuning or resampling; repeated or overlapping partitions; multiclass or
regression calibration; observation weights; alternate event-class selection;
automatic coercion or missing-value handling; fold-size weighting or pooling;
public aggregate endpoints; formula or data-frame cross
interfaces; tidymodels/yardstick integrations; and new metrics, smoothing or
plotting features are not supported. Only Base R and standard R distribution
packages are needed. Installation and acceptance require neither Python nor
networking; Python reference-fixture regeneration is optional and separate.
}
\seealso{\code{\link{predict.cross_venn_abers}},
\code{\link{print.cross_venn_abers}}, \code{\link{brier_score}},
\code{\link{log_loss}}, \code{\link{calibration_plot}}}
\examples{
# Precomputed probabilities from three retained fold models. Each model
# excluded its corresponding calibration fold from its learned pipeline.
calibrator <- cross_venn_abers(
  truth = c(FALSE, TRUE, FALSE, TRUE, FALSE, TRUE),
  probability = c(.1, .8, .2, .9, .3, .7),
  fold = c("A", "A", "B", "B", "C", "C")
)
print(calibrator)

# Each row is the same new observation across all corresponding fold models.
newdata <- cbind(A = c(.2, .8), B = c(.3, .7), C = c(.1, .9))
result <- predict(calibrator, newdata)
result
test_truth <- c(FALSE, TRUE)  # Untouched by fitting and calibration.
brier_score(test_truth, result$probability)
log_loss(test_truth, result$probability)
calibration_plot(test_truth, result$probability)
}
