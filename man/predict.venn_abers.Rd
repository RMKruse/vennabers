\name{predict.venn_abers}
\alias{predict.venn_abers}
\title{Predict with a Venn-Abers Calibrator}
\usage{
\method{predict}{venn_abers}(object, newdata, ..., loss = "log", type = "response")
}
\arguments{
  \item{object}{A fitted \code{venn_abers} object.}
  \item{newdata}{A numeric vector of uncalibrated event probabilities with
  finite values in \code{[0, 1]}. \code{numeric(0)} is accepted.}
  \item{...}{Must be empty; unsupported arguments are errors.}
  \item{loss}{Exactly \code{"log"} (default) or \code{"brier"}.}
  \item{type}{Exactly \code{"response"} (default) or \code{"class"}.
  Supply both options by their full argument names.}
}
\value{
For \code{type = "response"}, a data frame with one row per value in \code{newdata} and three double
columns: \code{lower} and \code{upper} are the Venn-Abers interval bounds,
and \code{probability} is the regularized event probability
using the chosen loss. For \code{type = "class"}, an unnamed logical vector,
\code{TRUE} when the final event probability is at least 0.5 and \code{FALSE}
otherwise. Zero observations return the same empty data-frame schema or
\code{logical(0)}; one observation retains its data-frame/vector shape.
}
\description{
Predicts a Venn-Abers interval and regularized event probability while
preserving the order of \code{newdata}.
}
\details{
Log-loss regularization is \code{upper / (1 - lower + upper)}. Brier
regularization is \code{upper + (lower^2 - upper^2) / 2}. Changing loss does
not change the interval endpoints or mutate the fitted calibrator. New
probabilities are never rounded, even if calibration used \code{precision}.
Input names are not alignment keys. The endpoints are Venn-Abers bounds,
not confidence intervals. The probability column can be passed to the
existing scores and calibration plot with either loss choice.
}
\examples{
calibrator <- venn_abers(c(0, 1, 0), c(0.1, 0.2, 0.3))
predict(calibrator, c(0.05, 0.2, 0.4))
predict(calibrator, c(0.05, 0.2, 0.4), loss = "brier")
predict(calibrator, c(0.05, 0.2, 0.4), loss = "brier", type = "class")
}
