\name{venn_abers}
\alias{venn_abers}
\title{Fit a Binary Inductive Venn-Abers Calibrator}
\usage{
venn_abers(truth, probability)
}
\arguments{
  \item{truth}{A non-empty logical or numeric vector containing only
  \code{FALSE}/\code{0} and \code{TRUE}/\code{1}. \code{TRUE}/\code{1}
  is the event class.}
  \item{probability}{A numeric vector of uncalibrated event probabilities,
  the same length as \code{truth}, with finite values in \code{[0, 1]}.}
}
\value{
An opaque object of class \code{"venn_abers"}.
}
\description{
Fits an Inductive Venn-Abers calibrator for a binary truth and uncalibrated
event probabilities.
}
\section{Version 0.1 scope}{
Version 0.1 does not support Cross Venn-Abers, multiclass calibration,
regression, predictive-model fitting or resampling, observation weights,
custom event-class selection, coercion or missing-value handling, precision or
rounding controls, formula or data-frame interfaces, tidymodels or yardstick
integration, smoothing or \code{ggplot2} output, or CRAN submission guarantees.
}
\examples{
calibrator <- venn_abers(
  truth = c(FALSE, TRUE, FALSE, TRUE),
  probability = c(0.1, 0.4, 0.35, 0.8)
)
calibrator

predict(calibrator, c(0.2, 0.5, 0.9))
}
