\name{venn_abers_tuning}
\alias{venn_abers_tuning}
\title{Inspect Binary Grid Selection}
\usage{
venn_abers_tuning(object)
}
\arguments{
\item{object}{A fitted binary \code{calibrated_workflow()} with grid tuning.}
}
\description{
Returns the stored configuration and selection diagnostics without refitting.
}
\value{
A list with \code{config}, \code{calibration}, \code{models}, and \code{seed}.
Each search records candidate IDs, eligibility and exclusion reasons, per-resample
main and report scores, native \code{tune_grid()} results (including prediction
rows and notes), the stable winner, selected values, local plan positions,
gross base-fit budget estimate, attempted evaluation count and observed base-fit
attempts, including failures. The estimate is unavailable when a provider
function determines a nested plan size at fit time; its count factors remain
visible. Calibration selection also records the
disjoint selection (S) and final fit (F) row positions. In full-model mode,
\code{models$Full1} is its separate local search.
}
\seealso{\code{\link{calibrated_workflow}}}
