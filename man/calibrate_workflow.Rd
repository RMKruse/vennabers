\name{calibrate_workflow}
\alias{calibrate_workflow}
\alias{predict.vennabers_frozen}
\title{Calibrate a Frozen Binary Workflow}
\description{Fit only an Inductive Venn-Abers calibrator on new, separate
calibration data using the final probabilities of an already fitted workflow.
The complete workflow, including learned preprocessing and any learned
postprocessor, is retained unchanged.}
\usage{
calibrate_workflow(fitted_workflow, data_calibration, outcome, ...,
  classification = "binary", event_level = "first", precision = NULL,
  loss = "log")
\method{predict}{vennabers_frozen}(object, new_data, type = "prob", ...,
  loss = NULL)
}
\arguments{
\item{fitted_workflow}{A fully fitted binary classification workflow. Single
parsnip fits, extracted engines, unfitted workflows and other modes are rejected.}
\item{data_calibration}{A nonempty data frame in the original learned input
format, including the outcome. Do not pre-bake the data. Missing predictor
values are allowed only if the stored prediction path handles them.}
\item{outcome}{One column name matching the trained outcome. Calibration truth
must be a nonmissing factor with exactly the trained class universe. Factor
levels may be reordered; the stored workflow fixes the output class order.
A nonempty calibration set observing only one of those classes is allowed.}
\item{classification}{Currently exactly \code{"binary"}.}
\item{event_level}{Exactly \code{"first"} or \code{"second"}, selecting the
event by the trained class order.}
\item{precision}{NULL or a finite numeric whole number. Only calibration
probabilities are rounded, following \code{\link{venn_abers}}. New probabilities
are never rounded. Changing this option or the event requires a new calibrator,
but no new base workflow fit.}
\item{loss}{Constructor: exactly \code{"log"} or \code{"brier"}, saved as the
prediction default. Predict and \code{venn_abers_details()}: omit to retain that
default, or override without refitting or changing stored state. Explicit NULL
is invalid at prediction.}
\item{object}{A fitted predictor returned by \code{calibrate_workflow()}.}
\item{new_data}{A data frame in the learned input format. The outcome is not
needed and, if present, is removed before the original workflow predicts.}
\item{type}{Exactly \code{"prob"} (default) or \code{"class"}.}
\item{...}{Must be empty. Constructor argument names must be exact. Unknown,
training, split, Cross, full-model and regression options are rejected.}
}
\value{An already fitted \code{vennabers_frozen} predictor, also inheriting
\code{vennabers_fit}. It is not a trainable workflow or a specification for
\code{fit_resamples()}. The object retains complete workflows in \code{models},
the \code{calibrator}, \code{class_levels}, \code{event_class}, input column
metadata, calibration size, requested/effective \code{parameters}, and relevant
R, package and engine \code{versions}. No additional complete copy of new raw
calibration data is stored; data already retained by the original workflow remain.
Prediction returns a tibble with named \code{.pred_<class>} probabilities in
trained class order, or a factor \code{.pred_class}. The event wins at probability
0.5. \code{venn_abers_details()} returns the same probability table and binary
lower/upper bounds and points with row, Inductive fold and event identity.
Zero and one row preserve types and columns; zero rows do not call the base engine.}
\details{
Calibration uses the complete public workflow \code{predict(type = "prob")}
path, including its existing postprocessor exactly once. Missing, extra,
duplicate or unknown class columns, nonfinite/out-of-range probabilities,
invalid row sums and changed row counts cause errors. Failures retain original
class/input names and prediction-stage context. No learned state is renamed,
refitted or bypassed through an extracted engine or a raw fallback.

The user is responsible for keeping the new calibration data outside all earlier
model, preprocessing, postprocessing and parameter-selection data. Assessment
data must also be separate from calibration and selection. This history is not
automatically verified. Frozen adoption is an R extension, neither Cross
calibration nor full-model transfer.

\code{saveRDS()} and \code{readRDS()} preserve prediction and diagnostics without
learning for the tested GLM workflows, including recipes and Tailor. Required
packages must be available in the new R process. Engines with external resources
retain their own storage contracts; no universal portability is promised.
The integration dependencies are optional; manual cores work without them.
The installed \code{examples/frozen-binary.R} demonstrates earlier model/recipe
and postprocessor learning, separate calibration and independent assessment.
Explicit frozen-schema binding is reserved for the separate schema integration.
}
\seealso{\code{\link{calibrated_workflow}}, \code{\link{venn_abers_details}},
\code{\link{venn_abers}}}
\examples{
if (all(vapply(c("parsnip", "workflows", "hardhat", "rsample", "recipes",
                "rlang", "tibble", "withr", "generics", "tidyselect"),
               requireNamespace, logical(1), quietly = TRUE))) {
  d <- data.frame(x = sin(1:80), truth = factor(rep(c("yes", "no", "no", "yes"), 20)))
  base <- workflows::workflow() |>
    workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  earlier <- generics::fit(base, d[1:40, ])
  calibrated <- calibrate_workflow(earlier, d[41:60, ], "truth")
  predict(calibrated, d[61:80, "x", drop = FALSE])
}
}
