\name{corp_plot}
\alias{corp_plot}
\alias{corp_decomposition_plot}
\title{Assess Calibration with CORP Reliability Diagrams}
\usage{
corp_plot(truth, probability, band = "consistency", level = 0.9,
          replicates = 1000, seed = NULL, ...)

corp_decomposition_plot(truth, probability, ...)
}
\arguments{
  \item{truth}{A non-empty logical or numeric vector containing only
  \code{FALSE}/\code{0} and \code{TRUE}/\code{1}. \code{TRUE}/\code{1}
  is the event class. Alternatively factor truth under the scoring contract
  in \code{\link{brier_score}}; assessment may omit observations of some levels.}
  \item{probability}{A numeric vector of regularized event probabilities,
  the same length as \code{truth}, with finite values in \code{[0, 1]}.
  For factor truth, the final class matrix under the input contract of
  \code{\link{venn_abers}}, never the internal pair probabilities.}
  \item{band}{Exactly one of \code{"consistency"} (default),
  \code{"confidence"}, or \code{"none"}: the uncertainty band drawn with the
  CORP estimate. Bands other than \code{"none"} are not yet available and
  stop with an error, so the default does too.}
  \item{level}{One number strictly between 0 and 1: the pointwise level of
  the band.}
  \item{replicates}{One finite whole number of at least 1: the resampling
  replicates of the band. \code{replicates * (1 - level) / 2} must be at
  least 1, so that each band quantile has a replicate beyond it.}
  \item{seed}{\code{NULL} or one integer in R's seed range for the band
  replicates.}
  \item{...}{Base R graphical options passed to \code{plot()} in
  \code{corp_plot()} and to \code{barplot()} in
  \code{corp_decomposition_plot()}, taking precedence over the defaults in
  every panel.}
}
\value{
\code{corp_plot()} returns invisibly a data frame with one row per unique
probability in increasing order and the same columns whatever \code{band}
holds: \code{probability}, \code{estimate} (the CORP estimate of the
conditional event probability), \code{count} (the pairs with this
probability), \code{band_lower} and \code{band_upper} (the band limits),
\code{valid_replicates} (the replicates the limits rest on), and the
controls \code{band}, \code{level}, \code{replicates}, and \code{seed}, the
same in every row. Without a band, \code{band_lower}, \code{band_upper},
and \code{valid_replicates} are \code{NA}; without a seed, \code{seed} is
\code{NA}. The band limits are named apart from the Venn-Abers values
\code{lower} and \code{upper}, which they are not.

\code{corp_decomposition_plot()} returns invisibly a data frame with one row
and the columns \code{brier}, \code{mcb}, \code{dsc}, and \code{unc}.

For factor truth, both add a leading factor column \code{class} with the
truth levels, grouping rows by class order.
}
\description{
Assesses the calibration of probabilities on evaluation pairs of truth and
probability, held out from fitting the calibrator, such as an assessment
set or a test set. Unlike \code{\link{plot.venn_abers}}, which shows the
stored state of a fit, these graphics need new truth values.

\code{corp_plot()} draws the CORP reliability diagram of Dimitriadis,
Gneiting and Jordan (2021): the CORP estimate of the conditional event
probability as a step over the probabilities, from the smallest to the
largest, against the dashed diagonal of perfect calibration on
\code{[0, 1]}. \code{corp_decomposition_plot()} draws the CORP decomposition
of the Brier score as bars of miscalibration (MCB), discrimination (DSC),
and uncertainty (UNC).
}
\details{
The CORP estimate is the isotonic (PAV) regression of the events on the
probabilities, computed with \code{\link[stats]{isoreg}}. Equal
probabilities are valid and pooled, so they share one estimate, and the
estimate never decreases. Unlike the bins of \code{\link{calibration_plot}},
it needs no tuning.

With the PAV estimate \code{q} and the event rate \code{r} on the same pairs,
\code{mcb} is the Brier score of the probabilities minus that of \code{q},
\code{dsc} the Brier score of \code{r} minus that of \code{q}, and
\code{unc} the Brier score of \code{r}, so that
\code{brier = mcb - dsc + unc} up to rounding. Lower \code{mcb} and higher
\code{dsc} are better; \code{unc} depends on the truth only.
The decomposition is deterministic.

Pairs are assumed independent. Both graphics describe the evaluation pairs
given, conditional on the fitted calibrator; they make no statement about
Venn-Abers validity.
}
\section{Multiclass}{
Every factor, even with two levels, is evaluated class by class: each class
against the rest, using its final probability. \code{corp_plot()} draws one
panel per class, titled \code{"CORP: <class>"}, in its own nearly square grid
as in \code{\link{calibration_plot}}, and restores the previous graphical
parameters on exit, also after errors. \code{corp_decomposition_plot()}
draws one panel of the components grouped side by side, one bar and legend
entry per class, without a combined value.

Each \code{brier} is the binary Brier score of its class,
\code{mean((y_k - p_k)^2)}. Their sum over classes is the multiclass value of
\code{\link{brier_score}}, which they do not replace.
}
\references{
Dimitriadis, T., Gneiting, T. and Jordan, A. I. (2021). Stable reliability
diagrams for probabilistic classifiers. \emph{Proceedings of the National
Academy of Sciences}, 118(8), e2016191118.
\doi{10.1073/pnas.2016191118}
}
\seealso{
\code{\link{calibration_plot}} for binned reliability diagrams,
\code{\link{brier_score}} for scores, and \code{\link{plot.venn_abers}} for
fit diagnoses.
}
\examples{
set.seed(1)
score <- runif(400)
truth <- rbinom(400, 1, score^2)
fitting <- 1:200
calibrator <- venn_abers(truth[fitting], score[fitting])
assessment <- predict(calibrator, score[-fitting])$probability

corp_plot(truth[-fitting], assessment, band = "none")
corp_decomposition_plot(truth[-fitting], assessment)
}
