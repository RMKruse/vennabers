\name{calibrated_workflow}
\alias{calibrated_workflow}
\alias{venn_abers_details}
\alias{predict._vennabers_fit}
\alias{predict.vennabers_workflow}
\title{Train a Calibrated Classification or Regression Workflow}
\description{Wrap an unfitted, fully configured classification or regression workflow in a normal
outer workflow. The outer XY blueprint transports selected raw columns. Complete base workflows learn only on their local training splits; held-out
predictions fit the existing classification or regression Inductive/Cross Venn-Abers core.}
\section{Release scope and dependencies}{
Version 0.5 supports all eight combinations of binary, OvO, OvR and regression
with Inductive or Cross training, including complete outer resampling.
The integration packages in DESCRIPTION are optional Suggests and must be
installed explicitly; manual calibration needs none of them. Use the declared
minimum versions or newer supported versions. Basis engines also need their own
packages: the examples use \code{stats} for GLM/LM and \code{nnet} for a shared
multinomial model. Fresh parallel workers must load \code{vennabers} and those
engine namespaces, for example through \code{control_resamples(pkgs = ...)}.
Reversible name encoding for binary, OvO/OvR and regression is available through \code{venn_abers_schema()}.
Frozen classification/regression workflow adoption is available through \code{\link{calibrate_workflow}}.
Ordered reference holdouts and binary/shared multiclass full-model transfer are supported.
Matched/full Inductive and Cross pair training are also supported in v0.7.
Binary, shared OvO/OvR, pairwise OvO, and regression joint/two-stage grid and Bayes selection is available in v0.8;
learned postprocessing in v0.9. Shared multiclass training does not establish
complete Python training parity.
}
\usage{
calibrated_workflow(workflow, outcome, ..., predictors = NULL,
  method = "inductive", classification = "binary", event_level = "first",
  calibration_prop = 0.2, v = 5L, strata = NULL, splits = NULL, seed = NULL,
  precision = NULL, loss = "log", m = NULL, epsilon = NULL, schema = NULL,
  prediction_model = "matched", model_training = "shared", tuning = NULL,
  postprocessing = NULL)
venn_abers_details(object, new_data, ..., loss = NULL)
\method{predict}{_vennabers_fit}(object, new_data, type = NULL,
  opts = list(), ..., loss = NULL)
}
\arguments{
\item{workflow}{An unfitted workflows object with a classification or regression model and
recipe, formula, or variable selection. Prepped or partly trained recipes,
unresolved tune placeholders without \code{tuning}, and postprocessors without an
explicit matching \code{postprocessing} request are rejected.}
\item{postprocessing}{NULL preserves the existing unprocessed training path and
does not remove a supplied postprocessor. Otherwise a named list with explicit
\code{method = "tailor_logistic"}, \code{"tailor_multinomial"}, \code{"tailor_linear"}, \code{"sigmoid"}, or \code{"isotonic_numeric"},
\code{strategy = "holdout"}, and either
\code{prop} (the P fraction, strictly between zero and one) or \code{splits}
(a local rsplit or serializable function of local Q data). Analysis is B;
assessment is P. A supplied plan cannot be combined with prop or v. Unknown,
duplicate, irrelevant and conflicting fields are errors. Currently binary and shared OvO/OvR
Inductive/Cross VA and regression IVAR/CVAR with matched models and fixed parameters are implemented;
Binary \code{tailor_logistic} and \code{sigmoid} also support
\code{strategy = "ensemble"}, with an explicit integer \code{v >= 2} or
\code{splits} (a local unrepeated rset or serializable function of Q).
Ensembles reject prop; explicit splits reject v. Other ensemble methods,
full models and tuning combinations fail explicitly.}
\item{tuning}{NULL keeps fixed settings. For binary, shared OvO/OvR or pairwise OvO classification and regression, a named list
with \code{strategy = "joint"} or \code{"two_stage"} and \code{model} and/or
\code{calibration} searches matching the present \code{tune()} placeholders.
Each search has \code{method = "grid"} or \code{"bayes"}. Grid uses a concrete grid data frame with columns
named by placeholder IDs or a positive integer grid size with dials
\code{param_info}. Bayes uses positive whole \code{initial} and \code{iter} budgets plus
\code{param_info}; \code{initial} must exceed the number of tuned parameters. Its
\code{control_bayes()} must save predictions, use \code{uncertain = Inf}, and supplies
the seed, \code{no_improve}, and optional time limit. Local model searches and calibration searches require
\code{resamples = function(data) ...} (or a bound rsample rset); pairwise
\code{joint} model grids use the global plan described below. Optional \code{primary_metric} defaults to
\code{yardstick::mn_log_loss} for classification or \code{yardstick::rmse} for regression; \code{report_metrics} are independent yardstick
metrics. Explicit \code{control} must be the matching \code{tune::control_grid()} or \code{tune::control_bayes()}
with \code{save_pred=TRUE}. Bayes calls the public \code{tune::tune_bayes()} one
iteration at a time, filtering incomplete candidates before the next call. Inner parallelism is disabled, and a custom
\code{extract} callback is unavailable because selection uses extraction for
diagnostics.
Model/recipe and calibration IDs must be unique. Calibration search requires
exactly one of \code{selection_prop} (the proportion reserved for selection S)
or \code{selection_split} (rsplit or function, with analysis=final fit F and
assessment=selection S). S is never included in F. Automatic calibration
selection requires \code{splits=NULL} or a local plan provider function.
In pairwise OvO \code{two_stage}, model searches and resamples run on each local class pair. Calibration
selection scores the coupled complete Multiclass output on S; its final fit
uses only F. Pair plans must be local provider functions when calibration is tuned.
For pairwise \code{joint} Grid model tuning, candidate choices form a Cartesian grid
over class pairs (and separate full-model choices when requested). Bayes model
searches instead advance independently on each local pair and source/full domain;
they require local \code{model$resamples}. Global calibration candidates use
complete coupled predictions. Model-only joint Bayes evaluates the complete
locally selected procedure on \code{joint_resamples}; model-only joint Grid
uses that plan to select its Cartesian candidates. Omit \code{model$resamples}
only for the Cartesian Grid route. Global plans are never used as pair plans.
A joint grid above 4096
combinations is rejected before fitting; reduce the grids.
Loss candidates are \code{"log"}/\code{"brier"}; precision candidates are
\code{"none"}, \code{"0"}, \code{"2"}, and \code{"-2"}. Regression searches exactly one of
\code{m = tune::tune("moderation")} or \code{epsilon = tune::tune("moderation")};
classification options are rejected. Every inner calibration fold must satisfy
\code{1 <= m <= floor((k-1)/2)}, with \code{m = floor(epsilon*(k+1)/2)}
when epsilon is supplied. Invalid local candidates are excluded without clipping.
Joint model selection scores complete IVAR/CVAR predictions; two-stage selection
scores the uncalibrated numeric predictions first. Fixed model/recipe or
moderation options stay fixed. Each Cross source and Full1 searches only its
own training domain; Full1 never averages fold choices. See
\code{\link{venn_abers_tuning}} for selections and diagnostics.}
\item{schema}{NULL retains the direct naming contract. A schema from
\code{venn_abers_schema()} fixes the encoded input names, mode, class order and binary event.
Omitted classification/event options inherit the schema; contradictory explicit
options fail before learning. Build the base formula/recipe and resamples on
\code{venn_abers_encode()} data. All schema predictors must be selected.}
\item{outcome}{One original outcome column name, or \code{schema$encoded_outcome}
when a schema is supplied. Fit requires a nonmissing factor
with exactly two levels for binary or at least two for OvO/OvR. All stored levels
must be represented in the development data. Regression requires finite numeric
truth; numeric 0/1 outcomes remain regression.}
\item{...}{Must be empty. Unknown, irrelevant and partially matched names are errors.}
\item{predictors}{Optional character vector of raw predictor names, excluding
outcome. NULL selects all other supplied columns. Their stored order is canonical;
unused selected columns still have to be supplied for prediction.}
\item{method}{Exactly \code{"inductive"} (default) or \code{"cross"}.}
\item{prediction_model}{Exactly \code{"matched"} (default) or \code{"full"}.
Available for binary, shared OvO/OvR, pairwise OvO classification and regression.
This is a fixed fit option; predict cannot change it.
Matched uses each calibration source model for new observations. Full applies
the unchanged held-out calibrators to predictions from one additional workflow
trained on the entire permitted local fit domain, including calibration rows.
For pairwise training there is one such full workflow per local class pair.}
\item{model_training}{Exactly \code{"shared"} (default) or \code{"pairwise"}.
Explicit values are rejected for binary and regression workflows. A shared model
produces one complete class matrix; OvO splits calibration into pairs without
training pair models. Pairwise requires \code{classification="ovo"},
and a workflow
that can train on a two-level factor. Each pair has its own models, recipes and
holdout or Cross partition. The later global level is its event; no extra shared/OvR model is fitted.}
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
\item{splits}{NULL generates a local split. Otherwise a mixed or ordered holdout
\code{rsplit} from \code{rsample::initial_split()} or \code{rsample::make_splits()},
for Inductive; a simple \code{rset} from \code{rsample::vfold_cv()} or
\code{rsample::manual_rset()} for Cross; or a serializable function receiving only
selected local raw predictors followed by outcome and returning such a plan. Explicit plans cannot be combined with
explicit \code{calibration_prop}, \code{v} or \code{strata}, even their defaults.
Use \code{\link{local_calibration_splits}} for prepared assignments.
Pairwise accepts a function of the current local pair data, or for direct fits a
list named by exactly \code{pair_1}, \code{pair_2}, etc. A single global
multiclass plan is not a pair plan. Automatic holdouts/partitions are generated after filtering.
Explicit Cross plans may have different fold counts per pair.}
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
Trainable workflow details also contain character \code{prediction_model} and
\code{model_source}. The source is the fold ID in matched mode, or \code{"Full1"}
for every fold in full mode. These are model metadata, separate from original
class identities and the \code{fold} identifying the held-out calibrator;
\code{venn_abers_decode()} preserves them without decoding them as classes.
Trainable OvO/OvR details include \code{model_training}.
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
separate equal-weight means of fold bounds. Trainable regression aggregates also
contain character \code{prediction_model} and a \code{model_source} list column:
each row lists all contributing source model IDs (only \code{"Full1"} in full mode).
Zero/one rows retain these schemas. Frozen regression outputs retain their existing schema.}
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
by a positive integer are reserved. Without a schema, names are never repaired; distinct names such
as \code{a b} and \code{a.b} require a compatible base engine. Raw predictor
\code{id} remains valid. Details do not join raw observations to predictions.

\code{workflows::extract_fit_engine()} returns a \code{vennabers_fit} with:
\code{schema} (NULL or the explicitly supplied metadata),
\code{parameters} (\code{requested}, logical \code{explicit} flags and
\code{effective}), \code{outcome}, \code{predictors}, \code{columns} (predictors
then outcome), \code{class_levels}, \code{event_class}, \code{loss},
\code{folds} (by fold ID, with integer \code{analysis}/\code{assessment} positions and
\code{training_size}/\code{calibration_size}), \code{models} (full
fitted base workflows named by the same IDs, or only \code{Full1} in full mode),
\code{calibrator}, \code{calibration} (for binary: a list named by fold ID, each
with original local integer \code{row}, logical event \code{truth} and unrounded
double held-out \code{probability}; for multiclass: one list per fold with
integer \code{row}, factor \code{truth} retaining all levels, and the complete
unrounded named class matrix \code{probability}; for regression: a data frame per
fold with integer \code{row}, numeric \code{truth} and held-out double
\code{prediction}), \code{versions}, and \code{rng_kind}.
Full mode fits the source recipes/models only on each analysis portion, then
fits a fresh complete recipe/model on all local fit rows. No source recipe
statistics are reused. Only after success are temporary source workflows
discarded. Held-out values and the separate calibrators never change; there is
no pooled OOF calibration or in-sample replacement. Training failure invalidates
the whole fit; there is no fallback. A one-row full-model prediction validates
its output contract during fit and is discarded without calibration.
Print identifies the mode and fold-to-model
mapping. Saved RDS objects retain the complete prediction procedure.
The cost is one/two base fits for matched/full Inductive and K/K+1 for Cross.
Full prediction calls its one model once per nonempty batch, reusing that output
across calibrators within the call. There is no persistent prediction cache.
The existing Log/Brier mergers and prediction-time loss override are unchanged.
For regression, \code{parameters$requested$mode} is \code{"regression"};
\code{effective$m} and \code{effective$epsilon} are numeric vectors named by
fold ID. Each \code{folds[[id]]$moderation} stores \code{requested}, effective
\code{m} and effective \code{epsilon=2*m/(k+1)}, alongside the fold sizes.
Implicit classification options are absent from effective settings; class levels,
event class and loss are NULL. The calibrator is the unchanged IVAR or CVAR core.
IVAR uses weighted points, including the midpoint when both weights vanish.
CVAR averages complete fold points, lower bounds and upper bounds separately
with equal weights, regardless of fold size; it never merges averaged bounds.
Matched mode retains each source workflow/recipe. Full mode retains one fresh
full workflow and applies its numeric prediction to every held-out calibrator.
No rounding or probability constraint is applied to regression predictions.
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
Ordinary and classification-stratified partitions may be mixed or non-shuffled.
For an ordered Inductive holdout use \code{make_splits()} with the first
\code{n - ceiling(n * q)} local rows for training and the remaining
\code{ceiling(n * q)} for calibration, requiring both parts to be nonempty.
This example convention rounds the calibration size upwards: 11 rows and
\code{q = .25} give training 1--8 and calibration 9--11. Explicit plans are
used as supplied, without sorting, mixing or stratification. Order is local to
each outer analysis set. Non-shuffled Cross folds retain exact training
complements, including later rows, and are not forward validation.
Group, time and other specialized split classes
are outside this partition contract. An unbound global positions plan cannot be reused
on different outer analysis data.
See installed \code{examples/reference-splits.R} for all eight training paths,
known ordinary/stratified memberships, data roles and assessment scores.
Equal R/Python seeds alone do not establish equal splits or training; numerical
comparisons require identical model outputs, assignments and options.

Matched Cross retains exactly one full base workflow per fold and all corresponding
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
fixed using independent data or selected through the configured local
\code{tuning} searches inside the allowed training portions.
The statistical setting assumes IID observations and a predictive procedure fixed
independently of its calibration data. The bounds are Venn-Abers probability
intervals, not confidence intervals. Regression bounds concern regularized
conditional expectations, not individual outcome coverage; Cross aggregate bounds
are descriptive. Improved scores on every data set are not
promised. The engine cannot validate an outer partition it never receives.
Validate outer analysis/assessment disjointness before calling fit_resamples;
assessment sets from different outer resamples may overlap.}
\section{Pairwise model training}{
Global factor levels fix the class order before decomposition. Each stable
\code{pair_id} names its two classes through
\code{pair_models[[pair_id]]$class_levels}; the second is always the event.
Each complete binary workflow
learns exclusively from its pair's training rows, including all recipe estimates.
Only its held-out event probabilities fit the existing binary calibrator.
For Cross, the existing binary core first aggregates within each pair using stable
log-loss aggregation or equal-weight Brier points. Only then are pair points
combined with the same reciprocal OvO merger as shared training; coupled
multiclass fold predictions are never averaged.
The global schema remains unchanged; only the unfitted recipe's outcome type is
adapted to the two-level local domain, retaining steps, roles and blueprint options.

\code{pair_models[[pair_id]]} retains \code{pair_id}, \code{class_levels},
\code{event_class}, \code{rows} (positions in the current global fit domain),
\code{folds} (positions in the local pair, plus sizes), \code{models},
\code{calibrator}, and \code{calibration}. Folds, models and calibration records
are named by local fold ID: \code{Inductive1} or the supplied Cross IDs.
The Cross calibrator retains its ordered, named binary fold calibrators.
Prediction re-derives the pair order from the global class levels and rejects
components whose \code{pair_id}, \code{class_levels} or fold names disagree,
as well as models whose fitted two-class outcome mold is not the pair's.
These replace the shared model/fold/calibrator fields. Calibration records retain
local row positions, binary truths and unrounded probabilities. Details add
\code{pair_id}, \code{model_training="pairwise"},
\code{prediction_model}, and \code{model_source} equal to the pair ID in matched mode.
The pair ID together with \code{fold} identifies the source workflow
and calibrator in matched mode. Full mode instead names each new model source
\code{pair_N/Full1}, separately from the unchanged pair/fold calibrator. Decoding changes class identities while preserving pair/fold/source
IDs. Zero-row outputs retain all columns without calling any base model.

All pair plans and data bindings are validated before the first base fit.
For Inductive, both classes must occur in each pair's training and calibration
portions. Cross permits nonempty one-sided calibration folds when the training
complement supports a trainable engine returning correct two-class probabilities.
Within each pair, assessment folds partition every local row exactly once and
training is the exact complement. Repeated/overlapping or incomplete plans,
foreign data and missing/duplicate IDs fail before training. Automatic Cross uses
the requested \code{v} without reduction; explicit valid partitions may have
different fold counts across pairs. Equal fold IDs in different pairs have no
shared meaning. Ordinary/stratified and non-shuffled reference partitions follow
the same local IID split rules as shared training.
Observations may recur across pairs. Explicit plans retain their local position
order; an ordered pair holdout does not imply a global time cutoff. With a fixed
\code{seed}, each pair resolver/automatic plan starts from that same seed
in a restored local scope, so plans do not depend on preceding fits or call counters.
Base fits then consume the enclosing fit's seeded stream in stable pair order.
With NULL, splitting and fitting consume the caller's stream. Prepared assignments
use \code{local_calibration_splits()} over every local pair, which rejects
conflicting plans for identical data. Resampling callbacks see only the current
outer analysis pair; development-wide plans cannot be replayed on different data.

For K classes, P=K*(K-1)/2 pairs cost P base fits for Inductive and the sum of
local fold counts for Cross (three classes with five folds cost 15 fits).
Each nonempty prediction call uses each retained model exactly once. Recipes, calibrators and models remain stored; prediction never learns.
With \code{prediction_model="full"}, all source workflows and calibrators are
built first, then one extra full workflow learns its recipe/model on each complete
local two-class domain. This order preserves source RNG draws and held-out values.
After every full workflow succeeds, \code{models} retains only \code{Full1} per
pair; all calibrators, held-out records and identities remain. No in-sample
recalibration or OOF pooling occurs. Full Inductive costs 2P fits; full Cross costs
the sum of local fold counts plus P (18 for three classes and five folds).
Each nonempty prediction uses each pair full model once and shares its named event
probability across that pair's calibrators before binary aggregation and global
coupling. Outer assessment/test rows never enter these fits.
Any failed component fails the whole fit. See installed
\code{examples/pairwise-inductive.R} for separate binary references, explicit
pair plans, independent coupling, decoding and complete outer evaluation.
The installed \code{examples/pairwise-cross.R} adds explicit unequal Cross
partitions, reconstruction, native/decoded diagnostics and outer fit costs.
Both examples compare matched/full predictions, costs and held-out scores;
matching-model guarantees do not automatically transfer and better quality is not promised.
}
\section{Tailor holdouts}{
Each VA source training portion Q is partitioned into disjoint B and P. The
recipe and engine learn only on B. The complete public workflow is fitted with
\code{data = B, data_calibration = P}, using
\code{tailor::adjust_probability_calibration(method = "logistic", smooth = FALSE)}
for two classes, or \code{method = "multinomial", smooth = FALSE} for three or
more classes. The requested method must match the class count; no automatic
exchange is performed. Shared two-class OvO/OvR retains multiclass class and
tie rules, not the binary event contract.
One exactly matching untrained Tailor adjustment may already be configured;
it is adopted once. Foreign, trained or multiple adjustments are rejected.
The full stored workflow predicts held-out VA data C and new predictors.
The VA core, event alignment, loss and rounding rules are unchanged.

Both B and P must contain all K model classes. P needs at least K+1 rows and
a full-rank design: the logistic intercept and one probability for two classes,
or the multinomial intercept and K-1 probabilities for K classes. Rank and
convergence are checked on the actual learned model after the necessary B
predictions. Failed fits, absent learned state and method switches to none
are errors. Warnings from successful fits are retained with source/fold context.
The existing VA rules for missing C classes remain unchanged (including valid
one-class Cross subproblems); B/P requirements do not apply to C. Use \code{venn_abers_schema()} for nonsyntactic outcome
or class names that the underlying Tailor/probably formula interface cannot use.

Regression requires \code{method = "tailor_linear"} explicitly and uses
\code{tailor::adjust_numeric_calibration(method = "linear", smooth = FALSE)}
through the public workflow calibration path. Recipe/engine learning uses B;
the intercept and slope are learned only on P. Numeric 0/1 targets remain
regression. Automatic B/P splits are unstratified. P needs at least three rows,
finite predictions and truth, full actual design rank two, finite coefficients
and convergence; constant predictions, absent fits and switches to none fail.
The complete workflow's numeric output enters the unchanged IVAR/CVAR core
with the requested valid \code{m} or \code{epsilon}. CVAR averages fold points
and both bounds separately. No confidence or prediction intervals are added.
See installed \code{examples/tailor-regression-holdout.R} for both paths,
encoded names, complete native evaluation and data-role checks.

\code{method = "isotonic_numeric"} accepts a regression base workflow without
a postprocessor. The recipe and engine learn on B, and unweighted increasing
least-squares isotonic regression learns on finite P predictions and truths.
At least two P rows are needed; tied predictions retain their frequencies.
Fitted support values are linearly interpolated, extended constantly beyond
the support, and are not restricted to [0,1]. A single support predicts the
mean P truth everywhere. No full-rank or Ridge condition applies. The complete
saved B workflow and isotonic fit enter the same IVAR/CVAR cores. See installed
\code{examples/isotonic-regression-holdout.R} for both native evaluation paths.

All B/P plans are validated before any source is trained. Static plans must
match local selected columns in order, values, types, levels and row order.
Automatic classification splits use the local outcome with \code{pool = 0}, without retries
or size adjustments; ordered valid explicit holdouts are allowed. The enclosing
seed scope covers VA splitting, B/P splitting and fitting in stored fold order;
NULL consumes the caller's stream and an explicit seed restores it.

For binary ensembles, P folds partition Q exactly once and each B is its
own P complement. B/P disjointness is local to a pair: a P row can belong to
another pair's B. Gaps, overlap, bootstrap duplicates, repeated folds and
incorrect local data bindings fail before learning. Each pair uses the same
complete holdout fitting rules. Aligned final probability vectors are averaged
with equal pair weights before VA, without inner VA calibrators or size weights.
All plans are resolved first, followed by fits in stored VA/inner-fold order in
one RNG stream; the seed is never restarted for each pair. Local plan functions
must be pure functions of their supplied data, not call counters or global row
positions. Different Q domains may have different inner fold counts.

\code{extract_fit_engine(fitted)$postprocessing} and the \code{postprocessing}
element of \code{venn_abers_details()} store actual Q/B/P/C row memberships,
Q-local analysis/assessment positions, sizes, class/event and schema bindings,
RNG settings, method-specific fit state, warnings and observed fit counts. Prediction
details add the inner fold, method, input and B/P sizes. Package versions are
stored in the fitted engine's \code{versions}. Each nonempty prediction calls
each complete retained workflow once; empty batches call none. Predict needs
no truth or plan resolution and never learns. RDS retains the full trained state.
Ensemble records contain a named \code{inner_folds} list of complete pair
diagnostics and summed observed fit counts. Their prediction details use
list-columns for \code{inner_fold}, \code{B_size} and \code{P_size}, retaining
one VA result row and the ordered identities/sizes of every contributing pair.
An Inductive ensemble fits J engines and J postprocessors; a K-fold Cross
ensemble with J pairs per fold fits K*J of each. Missing or failed pairs abort
the whole composition with fold context. See installed
\code{examples/binary-ensemble.R} for complete native evaluation.
Tailor and probably are optional and required only for this path.
See installed \code{examples/tailor-holdout.R} for native fit, complete repeated
outer resampling, last_fit, diagnostics and checks of held-out data roles.
\code{examples/tailor-multiclass-holdout.R} adds shared two-, three- and four-class
OvO/OvR, encoded names and the yardstick Brier factor of one half. Single-row
multinomial predictions retain matrix dimensions through a stored S3 adapter
for nnet, preserving the full Workflow/Tailor/probably prediction path.
}
\section{Printed costs}{The fitted engine prints source mappings, the number of base
fits (including temporary source fits discarded in full mode), models used per
nonempty prediction, and stored calibration rows containing held-out truth and
model predictions. Pairwise calibration rows count membership in each pair.}
\section{Full-model transfer}{For \code{prediction_model="full"}, the split isolates
calibration observations from source learning only. The extra full model includes
them. Existing matching-model calibration or coverage guarantees do not
automatically transfer to this differently trained model; improved quality is
not guaranteed. Binary, shared multiclass and regression grids give Full1 its own local model/recipe search;
the training method and prediction-model mode remain fixed per run.
\code{fit_resamples()} rebuilds the complete procedure inside each outer analysis
domain. \code{last_fit()} trains solely on its analysis domain, never analysis
plus test. \code{calibrate_workflow()} remains a frozen-model path and does not
accept this training option. Shared multiclass full-model transfer is an R
extension, not Python pair-model training parity. It uses the same full class
matrix for every subproblem and fold, with binary aggregation before multiclass
combination. See the installed examples \code{full-model-workflow.R} and
\code{full-multiclass-workflow.R} under \code{system.file("examples", package="vennabers")};
the latter shows native/decoded diagnostics, repeated outer assessment,
\code{last_fit()} and the unchanged yardstick Brier factor of two.
\code{full-regression-workflow.R} demonstrates IVAR/CVAR transfer, RMSE/MAE,
decoded numeric predictions and reconstruction of descriptive bounds. The Python
1.5.4 full-model regression option belongs to the exported lower
\code{VennAbersCV} class, not its regression facade.}
\examples{
source(system.file("examples", "calibrated-workflow.R", package = "vennabers"))
source(system.file("examples", "full-model-workflow.R", package = "vennabers"))
}
\seealso{\code{\link{venn_abers}}, \code{\link{cross_venn_abers}}, \code{\link{venn_abers_schema}}}

\section{Binary Sigmoid holdouts}{
For binary matched Inductive/Cross workflows with fixed parameters, set
\code{postprocessing = list(method = "sigmoid", strategy = "holdout", prop = .3,
  sigmoid_input = "probability")} or explicitly select \code{sigmoid_input = "glm_link"}.
The base workflow must have no postprocessor. Recipe and engine learn only on B;
Sigmoid learns only on P; the unchanged VA core learns on held-out C. Both B and
P must contain both factor levels, and P needs at least two rows. Constant P
inputs are valid; coefficients are not identifiable in that case.

\code{probability} uses the final named probability of the second stored factor
level from the complete public base workflow. \code{glm_link} requires a
\code{logistic_reg(engine = "glm")} binomial model with logit link and calls
\code{predict(workflow, new_data, type = "raw", opts = list(type = "link"))},
including recipe processing. It never reconstructs links from probabilities.
Both VA event choices are supported by named probability selection after Sigmoid.

The mapping minimizes unregularized logistic loss with targets
\eqn{(N_1+1)/(N_1+2)} for the second class and \eqn{1/(N_0+2)} for the first.
It follows scikit-learn's Platt calibration. Stored \code{coefficients} are
\code{a, b} on the stored input \code{scale}: the second-class output is
\code{plogis(-(a * (x / scale) + b))}. The scale is the maximum absolute P
input when at least 30, otherwise one. Constant inputs use a zero slope.
Nonfinite or incomplete inputs, unsuccessful optimization, and incomplete
probability outputs fail with method, role and local fold context.

The fitted state retains the complete base workflow, mapping and package
versions. Details expose B/P/C memberships, \code{input}, \code{sigmoid_class},
scale, coefficients, convergence, warnings and fit counts. Empty batches retain their schema without engine calls.
No Tailor, probably or Python installation is required for Sigmoid. Python is
used only by the separate checked-in reference generator; regular tests read
its fixed CSV outputs. See \code{system.file("examples", "sigmoid-holdout.R",
package = "vennabers")} for both inputs and native outer evaluation.
}
