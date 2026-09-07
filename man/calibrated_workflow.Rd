\name{calibrated_workflow}
\alias{calibrated_workflow}
\alias{venn_abers_details}
\alias{predict._vennabers_fit}
\title{Train a Binary Inductive Calibrated Workflow}
\description{Wrap an unfitted, fully configured classification workflow in a normal
outer workflow. The outer XY blueprint transports selected raw columns. A single
complete base workflow learns on a local training split; its held-out probabilities
fit the existing binary Inductive Venn-Abers core.}
\usage{
calibrated_workflow(workflow, outcome, ..., predictors = NULL,
  method = "inductive", classification = "binary", event_level = "first",
  calibration_prop = 0.2, strata = NULL, seed = NULL, precision = NULL,
  loss = "log")
venn_abers_details(object, new_data, ..., loss = NULL)
\method{predict}{_vennabers_fit}(object, new_data, type = NULL,
  opts = list(), ..., loss = NULL)
}
\arguments{
\item{workflow}{An unfitted workflows object with a classification model and
recipe, formula, or variable selection. Prepped or partly trained recipes,
unresolved tune placeholders, and additional postprocessors are rejected.}
\item{outcome}{One original outcome column name. Fit requires a nonmissing factor
with exactly two levels, both represented in the development data.}
\item{...}{Must be empty. Unknown, irrelevant and partially matched names are errors.}
\item{predictors}{Optional character vector of raw predictor names, excluding
outcome. NULL selects all other supplied columns. Their stored order is canonical;
unused selected columns still have to be supplied for prediction.}
\item{method, classification}{Only exact values \code{"inductive"} and
\code{"binary"} are currently supported. Cross, multiclass, explicit split plans,
regression and tuning are not enabled by this constructor.}
\item{event_level}{Exactly \code{"first"} or \code{"second"}, identifying the
original factor level whose probability is calibrated.}
\item{calibration_prop}{A number strictly between zero and one.
\code{rsample::initial_split()} uses training proportion \code{1-calibration_prop}.}
\item{strata}{NULL stratifies by outcome with \code{pool=0}; FALSE disables
stratification. Other values are rejected. No retry or automatic split adjustment.}
\item{seed}{NULL uses the caller's RNG stream. A finite whole number in R's integer
seed range sets a local seed for splitting and base fitting, restoring the caller's
state afterwards. Reproducibility also depends on engine and package versions.}
\item{precision}{NULL or a finite numeric whole number, including negative numbers.
Only calibration probabilities are rounded, following \code{venn_abers()}.}
\item{loss}{Constructor: stored prediction default, exactly \code{"log"} or
\code{"brier"}. Prediction/details: omit to use that default; an explicit choice
overrides it without refitting or changing stored state. Explicit NULL is invalid.}
\item{object}{For details, a fitted calibrated workflow. The predict method is
normally dispatched by \code{predict()} on that workflow.}
\item{new_data}{A data frame with required raw predictors. Normal workflow blueprint
and \code{hardhat::forge()} checks apply equally to prediction and details. Novel
factor levels reach the inner workflow, whose recipe/engine handles them or errors.}
\item{type}{Exactly \code{"prob"} or \code{"class"}; NULL defaults to class.}
\item{opts}{The standard parsnip prediction options list; normally empty.}
}
\value{The constructor returns an unfitted ordinary workflow. After
\code{generics::fit()}, native probability predictions are tibbles of double
\code{.pred_<original class>} columns in original level order. Class predictions
contain \code{.pred_class}, a factor retaining both levels; the event class wins
at exactly 0.5. Empty predictions keep the schema without calling the inner engine.

\code{venn_abers_details()} returns a list with \code{prediction} (the same native
probability table) and \code{details}: integer \code{row}, character \code{fold}
(always \code{"Inductive1"}), character \code{event_class}, and double
\code{lower}, \code{upper}, \code{probability}.}
\details{
All learned preprocessing belongs in the base workflow; the outer Variables
preprocessor only carries raw data. Training and calibration positions must form a
complete nonempty disjoint partition. Singleton and one-class calibration sets are
allowed. Trainability of the base engine is a separate requirement, and engine
errors identify the training or probability-prediction stage.

Input and class names must be unique, nonmissing and nonempty. Class \code{class}
and names starting with \code{.pred_} are reserved. Outcome names \code{.pred},
\code{.pred_*}, \code{.row}, \code{.config}, and \code{id} or \code{id} followed
by a positive integer are reserved. Names are never repaired; distinct names such
as \code{a b} and \code{a.b} require a compatible base engine. Raw predictor
\code{id} remains valid. Details do not join raw observations to predictions.

\code{workflows::extract_fit_engine()} returns a \code{vennabers_fit} with:
\code{parameters} (\code{requested}, logical \code{explicit} flags and
\code{effective}), \code{outcome}, \code{predictors}, \code{columns} (predictors
then outcome), \code{class_levels}, \code{event_class}, \code{loss},
\code{folds$Inductive1} (integer \code{analysis}/\code{assessment} positions and
\code{training_size}/\code{calibration_size}), \code{models$Inductive1} (the full
fitted base workflow), \code{calibrator}, \code{versions}, and \code{rng_kind}.
Inspect learned recipes with the public workflow extractors; predict with full
workflows. RDS restoration for pure R engines works in a fresh process after
loading vennabers, workflows, and required engine packages. External-pointer engines
may require their own serialization support.

Integration packages are optional Suggests and version-checked on use. Neither
core loading nor manual calibration requires or loads parsnip. Registration uses
public parsnip APIs, is idempotent in either load order, and rejects foreign model
registrations under the name \code{vennabers}. Packages are never auto-installed.
}
\section{Data roles and limitations}{The split isolates new base learning from
calibration observations. An unfitted workflow does not prove that earlier tuning,
feature choices, or external transformations excluded these observations. Keep
assessment observations separate from all training, selection and calibration.
The statistical setting assumes IID observations and a predictive procedure fixed
independently of its calibration data. The bounds are Venn-Abers probability
intervals, not confidence intervals; improved scores on every data set are not
promised. Outer evaluation and explicit local plans are separate work.}
\examples{
source(system.file("examples", "calibrated-workflow.R", package = "vennabers"))
}
\seealso{\code{\link{venn_abers}}}
