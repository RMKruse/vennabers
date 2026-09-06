\name{brier_score}
\alias{brier_score}
\alias{log_loss}
\title{Score Binary Event Probabilities}
\usage{
brier_score(truth, probability)

log_loss(truth, probability)
}
\arguments{
  \item{truth}{A non-empty logical or numeric vector containing only
  \code{FALSE}/\code{0} and \code{TRUE}/\code{1}. \code{TRUE}/\code{1}
  is the event class.}
  \item{probability}{A numeric vector of regularized event probabilities,
  the same length as \code{truth}, with finite values in \code{[0, 1]}.}
}
\value{
One unnamed double. \code{brier_score()} returns the binary mean squared
error. \code{log_loss()} returns the mean negative natural log-likelihood;
an incorrect probability of zero or one produces \code{Inf}.
}
\description{
Computes the Brier Score or Log Loss for binary event probabilities.
}
\examples{
truth <- c(FALSE, TRUE, FALSE, TRUE)
uncalibrated_probability <- c(0.1, 0.4, 0.35, 0.8)
calibrator <- venn_abers(truth, uncalibrated_probability)
prediction <- predict(calibrator, uncalibrated_probability)

brier_score(truth, prediction$probability)
log_loss(truth, prediction$probability)
}
