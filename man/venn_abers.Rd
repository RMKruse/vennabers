\name{venn_abers}
\alias{venn_abers}
\title{Fit a Binary Inductive Venn-Abers Calibrator}
\usage{
venn_abers(truth, probability, precision = NULL)
}
\arguments{
  \item{truth}{A non-empty logical or numeric vector containing only
  \code{FALSE}/\code{0} and \code{TRUE}/\code{1}. \code{TRUE}/\code{1}
  is the event class.}
  \item{probability}{A numeric vector of uncalibrated event probabilities,
  the same length as \code{truth}, with finite values in \code{[0, 1]}.}
  \item{precision}{\code{NULL} (default) disables rounding. Otherwise, one
  finite numeric whole number, including zero or negative values, passed to
  native R \code{round()} for calibration probabilities only. Logical,
  missing, nonfinite, fractional, and multiple values are errors.}
}
\value{
An opaque object of class \code{"venn_abers"}.
}
\description{
Fits an Inductive Venn-Abers calibrator for a binary truth and uncalibrated
event probabilities.
}
\details{
The calibration set must be separate from the fixed predictive model's
training, including learned preprocessing and tuning. Single-class and
singleton calibration sets are valid. Inputs align by position, not names.

Original probabilities are validated before rounding; an out-of-range input
cannot become valid through rounding. Exact ties after rounding are combined.
New probabilities supplied to \code{predict()} remain unrounded, and changing
precision requires a new fit. Native R rounding can differ from NumPy at
floating-point boundaries; NumPy rounding is not emulated.

Choose log-loss (default) or Brier regularization at prediction time without
refitting. See \code{\link{predict.venn_abers}} for probabilities and classes.
}
\examples{
calibrator <- venn_abers(
  truth = c(FALSE, TRUE, FALSE, TRUE),
  probability = c(0.1, 0.4, 0.35, 0.8)
)
calibrator

predict(calibrator, c(0.2, 0.5, 0.9))
rounded <- venn_abers(c(0, 1, 0, 1), c(.501, .502, .509, .510), precision = 2)
predict(rounded, c(.501, .505, .51), loss = "brier")
}
