\name{calibrated_workflow}
\alias{calibrated_workflow}
\alias{venn_abers_details}
\alias{predict._vennabers_fit}
\title{Train a Calibrated Classification or Regression Workflow}
\description{Wrap an unfitted, fully configured classification or regression workflow in a normal
outer workflow. The outer XY blueprint transports selected raw columns. Complete base workflows learn only on their local training splits; held-out
predictions fit the existing classification or regression Inductive/Cross Venn-Abers core.}
\usage{
calibrated_workflow(workflow, outcome, ..., predictors = NULL,
  method = "inductive", classification = "binary", event_level = "first",
  calibration_prop = 0.2, v = 5L, strata = NULL, splits = NULL, seed = NULL,
  precision = NULL, loss = "log", m = NULL, epsilon = NULL)
venn_abers_details(object, new_data, ..., loss = NULL)
\method{predict}{_vennabers_fit}(object, new_data, type = NULL,
  opts = list(), ..., loss = NULL)
}
\arguments{
\item{workflow}{An unfitted workflows object with a classification or regression model and
recipe, formula, or variable selection. Prepped or partly trained recipes,
unresolved tune placeholders, and additional postprocessors are rejected.}
\item{outcome}{One original outcome column name. Fit requires a nonmissing factor
with exactly two levels for binary or at least two for OvO/OvR. All stored levels
must be represented in the development data. Regression requires finite numeric
truth; numeric 0/1 outcomes remain regression.}
\item{...}{Must be empty. Unknown, irrelevant and partially matched names are errors.}
\item{predictors}{Optional character vector of raw predictor names, excluding
outcome. NULL selects all other supplied columns. Their stored order is canonical;
unused selected columns still have to be supplied for prediction.}
\item{method}{Exactly \code{"inductive"} (default) or \code{"cross"}.}
\item{classification}{Exactly \code{"binary"} (default), \code{"ovo"}, or
\code{"ovr"}. OvO/OvR explicitly use the
factor/matrix core, including with two classes. Mode comes from the base model.
Regression rejects explicit classification, event_level, precision and loss options,
including their defaults; implicit classification defaults do not apply.}
\item{event_level}{Exactly \code{"first"} or \code{"second"}, identifying the
original factor level whose probability is calibrated. Only for binary;
explicitly supplying this option for OvO/OvR is an error.}
\item{calibration_prop}{A number strictly between zero and one.
\code{rsample::initial_split()} uses training proportion \code{1-calibration_prop}.
Explicitly supplying this option requires Inductive.}
\item{v}{Cross fold count, a whole number of at least two, default five.
Automatic \code{rsample::vfold_cv()} uses one repetition and never reduces this
count; it must not exceed the local row count. Explicitly supplying \code{v}
requires Cross.}
\item{strata}{NULL stratifies classification by outcome with \code{pool=0}; regression
is unstratified. FALSE disables
stratification. Other values are rejected. No retry or automatic split adjustment.}
\item{splits}{NULL generates a local split. Otherwise an IID holdout
\code{rsplit} from \code{rsample::initial_split()} or \code{rsample::make_splits()},
for Inductive; a simple \code{rset} from \code{rsample::vfold_cv()} or
\code{rsample::manual_rset()} for Cross; or a serializable function receiving only
selected local raw predictors followed by outcome and returning such a plan. Explicit plans cannot be combined with
explicit \code{calibration_prop}, \code{v} or \code{strata}, even their defaults.
Use \code{\link{local_calibration_splits}} for prepared assignments.}
\item{seed}{NULL uses the caller's RNG stream. A finite whole number in R's integer
seed range sets a local seed for splitting and base fitting, restoring the caller's
state and RNG kind afterwards, including on error. The scope includes the plan
callback and model learning. Seed the outer plan separately. Reproducibility also
depends on RNG kind, engine, package versions, thread and parallel configuration.}
\item{precision}{NULL or a finite numeric whole number, including negative numbers.
Only calibration probabilities are rounded, following \code{venn_abers()}.}
\item{loss}{Constructor: stored prediction default, exactly \code{"log"} or
\code{"brier"}. Prediction/details: omit to use that default; an explicit choice
overrides it without refitting or changing stored state. Explicit NULL is invalid.
Regression rejects explicit loss at construction and prediction/details.}
\item{m, epsilon}{Regression moderation: both NULL means effective \code{m=1}.
Only one non-NULL option may be supplied and only that option reaches the core.
\code{m} is a positive numeric whole number; \code{epsilon} is strictly between
zero and one. Before any inner training, each fold of calibration size k must
satisfy \code{1 <= m <= floor((k-1)/2)}, with
\code{m = floor(epsilon*(k+1)/2)} for an epsilon request. Invalid folds fail the
entire fit with fold/size context; there is no clipping or fold-count adjustment.
Classification rejects explicit m/epsilon, including NULL.}
\item{object}{For details, a fitted calibrated workflow. The predict method is
normally dispatched by \code{predict()} on that workflow.}
\item{new_data}{A data frame with required raw predictors. Normal workflow blueprint
and \code{hardhat::forge()} checks apply equally to prediction and details. Novel
factor levels reach the inner workflow, whose recipe/engine handles them or errors.}
\item{type}{Classification: \code{"prob"} or \code{"class"}, default class. Regression:
\code{"numeric"}, also the default, returns double \code{.pred} in outcome units.
Neither \code{"conf_int"} nor \code{"pred_int"} is registered.}
\item{opts}{The standard parsnip prediction options list; normally empty.}
}
\value{The constructor returns an unfitted ordinary workflow. After
\code{generics::fit()}, native probability predictions are tibbles of double
\code{.pred_<original class>} columns in original level order. Class predictions
contain \code{.pred_class}, a factor retaining all levels. Binary favors its event
at exactly 0.5; OvO/OvR select the first maximum in stored level order from the
final probabilities, even with two classes. Empty predictions keep the schema without calling the inner engine.

\code{venn_abers_details()} returns a list with \code{prediction} (the same native
probability table) and \code{details}: integer \code{row}, character \code{fold}
(\code{"Inductive1"} for Inductive; the supplied fold IDs for Cross), character \code{event_class}, and double
\code{lower}, \code{upper}, \code{probability}. Cross details contain one row per
new observation and fold; their probability is the fold point, while
\code{prediction} contains the final aggregate.
OvO/OvR details additionally contain character \code{method} and either
\code{class_1}/\code{class_2} (OvO) or \code{class} (OvR). Each row identifies
one new observation, fold and binary subproblem. \code{event_class} is the later class
in an OvO pair or the considered OvR class. These binary point probabilities
must first be merged across folds for Cross (Log/Brier), then coupled (OvO)
or normalized (OvR) to reconstruct \code{prediction}.
Regression returns the native \code{.pred} table as \code{prediction}, and
\code{details} with integer \code{row}, character \code{fold}, and double
\code{prediction}, \code{lower}, \code{upper}. Cross additionally returns
\code{aggregate} with \code{row}, \code{lower}, \code{upper}: descriptive
separate equal-weight means of fold bounds. Zero/one rows retain these schemas.}
\details{
All learned preprocessing belongs in the base workflow; the outer Variables
preprocessor only carries raw data. Training and calibration positions must form a
complete nonempty disjoint partition. Binary allows singleton and one-class calibration sets.
Inductive OvO/OvR require every stored class in the holdout. Cross requires every
class globally in the out-of-fold calibration; individual folds may omit classes.
Nonempty one-class or singleton binary subcalibrations remain valid. An empty
OvO pair in any fold fails before any base training, naming the pair and fold.
Splits are never repaired. Trainability of the base engine is a separate requirement, and engine
errors identify the training or probability-prediction stage.

Multiclass uses one shared trained base workflow per split complement. Its probability columns must
be exactly \code{.pred_} plus each original class name, unique and complete;
column order is matched by name. Values must be finite in [0,1], with row sums
within 1e-8 of one. The existing matrix core normalizes within this tolerance.
OvO normalizes each pair and uses a neutral 0.5 score for zero-sum pairs before
optional native fit rounding (so 0.5 becomes 0 at precision 0). OvR uses all
calibration observations for each class against the rest. New probabilities
remain unrounded. Coupling, normalization and Log/Brier regularization are the
same as in the manual core; no separate pair models are trained.

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
\code{folds} (by fold ID, with integer \code{analysis}/\code{assessment} positions and
\code{training_size}/\code{calibration_size}), \code{models} (full
fitted base workflows named by the same IDs), \code{calibrator}, \code{versions}, and \code{rng_kind}.
For regression, \code{parameters$requested$mode} is \code{"regression"};
\code{effective$m} and \code{effective$epsilon} are numeric vectors named by
fold ID. Each \code{folds[[id]]$moderation} stores \code{requested}, effective
\code{m} and effective \code{epsilon=2*m/(k+1)}, alongside the fold sizes.
Implicit classification options are absent from effective settings; class levels,
event class and loss are NULL. The calibrator is the unchanged IVAR or CVAR core.
IVAR keeps its full analysis-trained workflow and weighted points, including the
midpoint when both weights vanish. CVAR keeps every matching workflow/recipe and
calibrator and averages points, lower bounds and upper bounds separately with
equal weights, regardless of fold size. No full-data transfer, rounding or
probability constraint is applied to regression predictions.
For OvO/OvR, the global \code{event_class} and effective \code{event_level} are
NULL; events belong to subproblems in details. The calibrator stores the original
classes and chosen multiclass method.
For Cross, \code{calibrator} is a \code{cross_venn_abers} core with
\code{folds}. Binary has a correspondingly named \code{calibrators} list;
multiclass has one binary Cross core per stored pair or class, each retaining
its fold IDs and corresponding ordered Inductive calibrators.
Inspect learned recipes with the public workflow extractors; predict with full
workflows. RDS restoration for pure R engines works in a fresh process after
loading vennabers, workflows, and required engine packages. External-pointer engines
may require their own serialization support.

For an explicit plan, selected raw columns (in canonical predictor order, then
outcome), values, column types, factor levels and row order must match local fit
data. Container class and row names are ignored; equal observations still occupy
distinct positions. Training and calibration indices must be finite, whole,
unique, in range, disjoint, nonempty and cover all local rows. The single internal
fold ID is always \code{Inductive1}; rsample's creation/outer IDs are metadata,
not configurable inner fold IDs. Cross requires unique nonempty character IDs,
at least two folds, exactly one assessment assignment for every local row, and
the exact complementary analysis set in each fold. All folds are checked before
any learning starts. Repeated inner folds and bootstrap duplicates are rejected.
Group, time and other specialized split classes
are outside this IID contract. An unbound global positions plan cannot be reused
on different outer analysis data.

Cross retains exactly one full base workflow per fold and all corresponding
binary subproblem calibrators, with no
additional full-data model. New data traverse every matching learned recipe/model
path. A failed fold fails the entire fit. Log loss uses the core's stable logarithmic
aggregation of endpoints; Brier uses the equal-weight mean of fold Brier points.
Neither merger weights by fold size or pools calibration data. Precision rounds
only calibration probabilities, never new model probabilities. Fold details
reconstruct the final probability using these mergers. For multiclass, merge each
binary subproblem across folds first, then couple OvO or normalize OvR. Averaging
already coupled/normalized multiclass fold matrices is a different procedure.
This shared R fold plan does not establish Python pair-model training parity.

Ordinary \code{tune::fit_resamples()} fits the complete predictor independently
on every outer analysis set. The stored loss controls native predictions even
when tune calls parsnip directly; there is no loss argument to fit_resamples and
no implicit control modification. For binary, match \code{event_level} in the constructor and
\code{tune::control_resamples()}. Yardstick's binary Brier is the binary vector
score. For OvO/OvR, yardstick Brier is exactly half the manual matrix score,
including the two-class matrix contract. Its log-loss clipping affects scoring
only, never stored predictions. Regression uses normal yardstick RMSE/MAE
(\code{.estimator = "standard"}) in outcome units, scored on the complete
procedure's held-out predictions.

Use \code{save_pred = TRUE} and all public collectors, including
\code{collect_notes()}, to check complete unsummarized resample, repeat,
configuration and assessment-row identities and finite metrics. Inner failures,
metric errors, NA removal or missing rows mean incomplete evaluation. All fits
failing may make a collector itself error; a mean of surviving fits is insufficient.
The installed \code{examples/calibrated-resampling.R} shows binary Inductive/Cross
and multiclass Inductive/Cross OvO/OvR, plus both regression methods with an
executable completeness check. Five outer by five inner Cross folds require exactly
25 base fits; no final fit runs automatically. Keeping extracted Cross states retains
all 25 workflows and their recipes/calibrators, so memory scales with the number
of retained base fits. A separate final development fit costs another five fits.

Use \code{control_resamples(extract = workflows::extract_fit_engine)} for all
fitted engine states, \code{extract = identity} for full fitted workflows, or a
function selecting compact diagnostics. \code{save_workflow = TRUE} alone does
not preserve each fitted composite. Inner training is serial; use
\code{parallel_over = "resamples"} for outer parallelism. Fresh workers must load
vennabers and required base-engine namespaces through \code{pkgs}. Reproducibility
is checked for the same versions, seeds, threads, strategy and deterministic
engine; changing strategies or external engine RNGs is not covered.

Integration packages are optional Suggests and version-checked on use. Neither
core loading nor manual calibration requires or loads parsnip. Registration uses
public parsnip APIs, is idempotent in either load order, and rejects foreign model
registrations under the name \code{vennabers}. Packages are never auto-installed.
}
\section{Data roles and limitations}{The split isolates new base learning from
calibration observations. An unfitted workflow does not prove that earlier tuning,
feature choices, or external transformations excluded these observations. Keep
assessment observations separate from all training, selection and calibration.
Calibration is not an independent evaluation. Cross model parameters must be
fixed using independent data or suitable selection nested inside the allowed
training portions; this constructor does not perform that selection.
The statistical setting assumes IID observations and a predictive procedure fixed
independently of its calibration data. The bounds are Venn-Abers probability
intervals, not confidence intervals. Regression bounds concern regularized
conditional expectations, not individual outcome coverage; Cross aggregate bounds
are descriptive. Improved scores on every data set are not
promised. The engine cannot validate an outer partition it never receives.
Validate outer analysis/assessment disjointness before calling fit_resamples;
assessment sets from different outer resamples may overlap.}
\examples{
source(system.file("examples", "calibrated-workflow.R", package = "vennabers"))
}
\seealso{\code{\link{venn_abers}}, \code{\link{cross_venn_abers}}}
