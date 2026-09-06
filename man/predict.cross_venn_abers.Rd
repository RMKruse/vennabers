\name{predict.cross_venn_abers}
\alias{predict.cross_venn_abers}
\title{Predict with Matched Fold-Model Probabilities}
\usage{
\method{predict}{cross_venn_abers}(object, newdata, ...)
}
\arguments{
  \item{object}{A fitted \code{\link{cross_venn_abers}} object.}
  \item{newdata}{A numeric/integer matrix of finite event probabilities in
  \code{[0, 1]}, one row per new observation and one column per corresponding
  fold model. Column names must be complete, non-empty, non-missing, unique,
  and match the fitted fold identities exactly. Any column order is accepted.
  A correctly named zero-row matrix is accepted.}
  \item{...}{Must be empty; any supplied prediction options cause an error.}
}
\value{
A data frame with exactly one double column, \code{probability}, containing
one finite regularized event probability in \code{[0, 1]} per input row,
in input row order. A zero-row input returns the same empty schema.
}
\description{
Matches new-observation columns to their fold calibrators by identity and
combines the resulting IVAP endpoints using equal-weight log-loss aggregation.
}
\details{
Character fold identities match literally. Numeric fitting IDs match their
Base R character representations. Missing, extra, duplicate, empty, or absent
column names fail the entire call, as do invalid probability values and
unsupported types or shapes (including vectors, lists, data frames, logical
matrices and character matrices). A column for an unobserved fold is an error.
Values are never dropped, clamped or rounded.

Use each retained fold model that supplied that fold's calibration
probabilities; predictions from one all-data refit cannot substitute for the
matched columns. The caller ensures the same observation occupies a given
row in every column. Row names do not establish that alignment, and valid
column names do not prove model provenance or exclusion of calibration folds
from training. See \code{\link{cross_venn_abers}} for pipeline responsibilities.

For each observation let \eqn{p_0^k, p_1^k} be the IVAP endpoints from fold
\eqn{k}. If \eqn{A} is the geometric mean of \eqn{1-p_0^k} and \eqn{B} is the
geometric mean of \eqn{p_1^k}, the result is \eqn{B/(A+B)}. Evaluation uses
\code{plogis(mean(log(upper)) - mean(log1p(-lower)))} in log space, with equal
fold weight and no endpoint clipping. It does not pool calibration rows,
weight folds by size, or average fold point probabilities.

Only the combined regularized probability is returned. The geometric pair
\eqn{(1-A, B)} can cross; it is not an ordered interval or confidence interval.
Neither that pair nor the combined point inherits the IVAP perfect-calibration
guarantee. There is no universal score-improvement guarantee. The output
feeds the existing scores and Base R calibration plot directly.
}
\examples{
calibrator <- cross_venn_abers(c(0, 1, 0, 1), c(.1, .8, .2, .9), c(1, 1, 2, 2))
newdata <- cbind("1" = c(.2, .8), "2" = c(.3, .7))
predict(calibrator, newdata)
stopifnot(identical(predict(calibrator, newdata), predict(calibrator, newdata[, 2:1])))
predict(calibrator, newdata[FALSE, ])
}
