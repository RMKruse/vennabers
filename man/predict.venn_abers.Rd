\name{predict.venn_abers}
\alias{predict.venn_abers}
\title{Predict with a Venn-Abers Calibrator}
\usage{
\method{predict}{venn_abers}(object, newdata, ...)
}
\arguments{
  \item{object}{A fitted \code{venn_abers} object.}
  \item{newdata}{A numeric vector of uncalibrated event probabilities with
  finite values in \code{[0, 1]}. \code{numeric(0)} is accepted.}
  \item{...}{Must be empty; prediction options are not supported.}
}
\value{
A data frame with one row per value in \code{newdata} and three double
columns: \code{lower} and \code{upper} are the Venn-Abers interval bounds,
and \code{probability} is the regularized event probability
\code{upper / (1 - lower + upper)}.
}
\description{
Predicts a Venn-Abers interval and regularized event probability while
preserving the order of \code{newdata}.
}
\examples{
calibrator <- venn_abers(c(0, 1, 0), c(0.1, 0.2, 0.3))
predict(calibrator, c(0.05, 0.2, 0.4))
}
