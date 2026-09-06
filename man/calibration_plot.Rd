\name{calibration_plot}
\alias{calibration_plot}
\title{Plot Binary Probability Calibration}
\usage{
calibration_plot(truth, probability, bins = 10, ...)
}
\arguments{
  \item{truth}{A non-empty logical or numeric vector containing only
  \code{FALSE}/\code{0} and \code{TRUE}/\code{1}. \code{TRUE}/\code{1}
  is the event class.}
  \item{probability}{A numeric vector of regularized event probabilities,
  the same length as \code{truth}, with finite values in \code{[0, 1]}.}
  \item{bins}{One finite whole number of equal-width bins.}
  \item{...}{Base R graphical options passed to \code{plot()}.}
}
\value{
Invisibly, a data frame with columns \code{mean_probability},
\code{event_rate}, and \code{count} for each non-empty bin.
}
\description{
Draws a dependency-free reliability diagram of mean regularized probability
against observed event rate.
}
\examples{
truth <- c(FALSE, TRUE, FALSE, TRUE)
uncalibrated_probability <- c(0.1, 0.4, 0.35, 0.8)
calibrator <- venn_abers(truth, uncalibrated_probability)
prediction <- predict(calibrator, uncalibrated_probability)

calibration_plot(truth, prediction$probability)
}
