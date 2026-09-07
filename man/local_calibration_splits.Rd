\name{local_calibration_splits}
\alias{local_calibration_splits}
\title{Resolve Prepared Local Inductive Calibration Splits}
\description{Validate all prepared assignments and return a serializable function
mapping selected local raw data to one Inductive IID holdout.}
\usage{local_calibration_splits(splits, columns)}
\arguments{
\item{splits}{A nonempty list of data-bound holdouts from
\code{rsample::initial_split()} or \code{rsample::make_splits()}. Each split's
stored data is its local fitting domain, typically one outer analysis set.}
\item{columns}{Unique selected raw predictor names in carrier order followed by
the outcome name. These columns, including outcome, define data identity. They
must exactly match the canonical columns received by the resolver; an omitted
outcome or selected predictor is an error.}
}
\value{A function of local raw \code{data}, suitable for the \code{splits} argument
of \code{calibrated_workflow()}. It returns a data-bound \code{rsplit}.}
\details{Every prepared split is validated before the function is returned.
Identity includes column values, types, factor levels and row order. Container
class and row names are ignored. Extra unselected columns are ignored; duplicate
observations remain distinct positions. All plans use method \code{inductive}
and the fixed single fold ID \code{Inductive1}; rsample creation/outer IDs are
metadata. Identical data require identical ordered analysis/assessment indices.
Duplicate identical plans are allowed; conflicting entries are errors identifying
their positions. A lookup without a matching snapshot is an error. No call counter,
first conflicting match, or outer assessment access is used. Construction compares
pairs of prepared entries; lookup scans the saved snapshots. Large collections may
need a more efficient user resolver.

The resolver supports \code{saveRDS()} and \code{readRDS()} and arbitrary lookup
order. An arbitrary user callback is trusted R code and must obey the same data
and plan contract; this helper does not prove the absence of hidden state in other
callbacks. Keep model selection and all other learning outside assessment data.
See the executable installed \code{examples/calibrated-resampling.R}.}
\examples{
if (all(vapply(c("rsample", "parsnip", "workflows", "withr"),
               requireNamespace, logical(1), quietly = TRUE))) {
  data <- data.frame(x = 1:20, truth = factor(rep(c("yes", "no"), 10)))
  split <- withr::with_seed(42, rsample::initial_split(data))
  resolve <- local_calibration_splits(list(split, split), c("x", "truth"))
  stopifnot(identical(as.integer(resolve(data)), as.integer(split)))
}
}
\seealso{\code{\link{calibrated_workflow}}}
