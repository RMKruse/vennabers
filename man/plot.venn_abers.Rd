\name{plot.venn_abers}
\alias{plot.venn_abers}
\alias{plot.cross_venn_abers}
\title{Plot the Calibration Map of a Fitted Venn-Abers Calibrator}
\usage{
\method{plot}{venn_abers}(x, which = "map", loss = "log", ...)

\method{plot}{cross_venn_abers}(x, which = "map", loss = "log", ...)
}
\arguments{
  \item{x}{A fitted binary \code{venn_abers} or \code{cross_venn_abers} object.}
  \item{which}{A character vector of distinct diagrams from \code{"map"}
  (default), the calibration map, and \code{"width"}, the Venn-Abers width
  \code{upper - lower}. Both draw the map before the width, whatever their
  order.}
  \item{loss}{Exactly \code{"log"} (default) or \code{"brier"}: the
  regularization of the drawn and returned probability, as in
  \code{\link{predict.venn_abers}}.}
  \item{...}{Base R graphical options passed to \code{plot()}, taking
  precedence over the defaults in every panel.}
}
\value{
Invisibly, a data frame with the same columns whatever \code{which} holds:
\code{score}, \code{lower}, \code{upper}, \code{probability}, and
\code{width}. Rows hold each stored probability knot plus the range ends 0
and 1 in increasing order. Values are those of \code{predict()} at
\code{score} with the chosen \code{loss}, and \code{width} is
\code{upper - lower}.

For \code{cross_venn_abers}, a leading character column \code{fold} holds the
stored fold IDs. Rows group by fold in stored order, each with its own knots
and the values of its own fold calibrator, not the aggregated Cross
probability.

Between neighbouring rows, the map holds the \code{lower} value of the left
row and the \code{upper} value of the right row, so the width between knots
exceeds the width at them. The drawn curves follow these values exactly.
}
\description{
Draws a fit diagnosis from the stored state of a fitted calibrator, without
new truth values. The calibration map shows the lower and upper Venn-Abers
values as steps and the regularized probability as a dashed line over the
uncalibrated probability on \code{[0, 1]}. The width diagram shows
\code{upper - lower} over the same scores; it is neither a confidence level
nor a nominal coverage.

Cross fits overlay the map of every fold calibrator in one panel,
distinguished by color and legend. Comparing fold maps at common scores does
not describe the spread of an individual Cross prediction.

Choosing both diagrams draws them in their own grid of panels and restores
the previous graphical parameters on exit, also after errors. A single
diagram uses the current layout. Fits without a stored calibration map
(\code{knots}, \code{lower}, \code{upper}) are errors; refit them with
vennabers 1.0.0. Multiclass fits are not supported yet.
}
\seealso{
\code{\link{calibration_plot}} assesses calibration on held-out truth values.
}
\examples{
truth <- c(FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE)
uncalibrated_probability <- c(0.1, 0.2, 0.3, 0.4, 0.4, 0.6, 0.7, 0.9)
calibrator <- venn_abers(truth, uncalibrated_probability)

map <- plot(calibrator, which = c("map", "width"))
head(map)

cross <- cross_venn_abers(truth, uncalibrated_probability, fold = rep(1:2, 4))
plot(cross, loss = "brier")
}
