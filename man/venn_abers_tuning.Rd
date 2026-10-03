\name{venn_abers_tuning}
\alias{venn_abers_tuning}
\title{Inspect Classification or Regression Grid or Bayes Selection}
\usage{
venn_abers_tuning(object)
}
\arguments{
\item{object}{A fitted binary, shared multiclass, pairwise OvO, or regression \code{calibrated_workflow()} with grid or Bayes tuning.}
}
\description{
Returns the stored configuration and selection diagnostics without refitting.
}
\value{
A list with \code{config}, \code{calibration}, \code{models}, \code{seed},
class/schema and method metadata, final fit roles and model source mappings.
Each search records candidate IDs and grid values, eligibility and exclusion reasons, per-resample
main and report scores, native \code{tune_grid()} or \code{tune_bayes()} results (including prediction
rows and notes), the stable candidate-order tie break, selected values, local plan positions,
gross base-fit budget estimate, attempted evaluation count and observed base-fit
attempts, including failures. Bayes diagnostics additionally retain each public one-step
continuation, its stop reason, elapsed time, and the global no-improvement count. The estimate is unavailable when a provider
function determines a nested plan size at fit time; its count factors remain
visible. In Bayes candidate tables, parameter IDs that collide with
\code{id}, \code{status}, \code{estimate} or \code{reason} receive unique
numeric suffixes separated by an underscore (for example, \code{status_1}).
Selected values and native results keep the original parameter IDs.
Calibration selection also records the
disjoint selection (S) and final fit (F) row positions. In full-model mode,
\code{models$Full1} is its separate local search. With postprocessing, each
\code{models} entry is a list of local B searches named by inner fold, with
\code{fold_id}, \code{inner_fold}, B positions and \code{search_seed} (one draw per B from the fit stream, so each search has its own RNG stream); budgets report \code{inner_pairs}.
For regression calibration searches, saved native predictions also carry the
requested \code{m} or \code{epsilon} value (\code{va_m} or \code{va_epsilon}
when the outcome itself is named \code{m} or \code{epsilon}). Actual candidate
values, including locally generated grids, are stored separately in \code{grid}.
Effective per-fold moderation is
recorded in \code{fit_roles[[fold]]$moderation}; epsilon may imply different
integer m values on different fold sizes. These are moderation parameters,
not confidence or prediction interval levels.
}
\seealso{\code{\link{calibrated_workflow}}}
