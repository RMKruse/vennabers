\name{venn_abers_schema}
\alias{venn_abers_schema}
\alias{venn_abers_encode}
\alias{venn_abers_decode}
\title{Reversible Names for Binary Calibrated Workflows}
\description{Explicitly encode input columns and binary outcome classes before
constructing a base workflow, and decode native results into separate roles.
These helpers learn no preprocessing, statistics, or calibration.}
\usage{
venn_abers_schema(data, outcome, classification = "binary", event_level = "first")
venn_abers_encode(data, schema)
venn_abers_decode(x, schema)
}
\arguments{
\item{data}{A data frame containing exactly the selected input columns. At schema
construction the outcome must be a factor with exactly two declared levels.
Encoding accepts new data without the outcome, but requires every predictor.}
\item{outcome}{One exact original outcome name, including reserved or
nonsyntactic names.}
\item{classification}{Exactly \code{"binary"}. Schema support for multiclass and
regression is outside this binary interface.}
\item{event_level}{Exactly \code{"first"} or \code{"second"}, selecting the event
from the original factor levels in their stored order.}
\item{schema}{The fixed object returned by \code{venn_abers_schema()}. Pass the
same schema to encoding, \code{calibrated_workflow()}, and decoding.}
\item{x}{A native probability or class prediction data frame, an unsummarized
\code{tune::collect_predictions()} table, or a \code{venn_abers_details()} result.}
}
\value{
\code{venn_abers_schema()} returns a \code{vennabers_schema} metadata list.
\code{version} is the format version; \code{outcome} and \code{encoded_outcome}
are the original and technical target names. \code{columns} maps original column
names to codes, in \code{original_columns} order. \code{classes} maps original
class names to codes, in \code{class_levels} order. \code{ordered} records whether
the original target is ordered. \code{mode}, \code{classification},
\code{event_level}, and original \code{event_class} define the task.
No observation values or additional calibration data are retained in the schema.

\code{venn_abers_encode()} returns a data frame in schema column order with
encoded column names and, when present, encoded target levels. Predictor values,
types, attributes, factor levels, row order, and row names are preserved.
The target is aligned to the saved class order even if incoming levels are
reordered or known levels are absent. Missing target values stay missing;
the fitting boundary rejects missing truth.

\code{venn_abers_decode()} returns a list with \code{outcome} (the original
outcome name as metadata), and only the result roles available in \code{x}:
\code{probability} (a numeric matrix with original class columns in schema order),
\code{class} (an original-level factor), \code{truth} (an original-level factor),
\code{identity} (available \code{.row}, \code{id}, \code{id2}, further numbered
\code{id} columns, and \code{.config}), and \code{details} (binary diagnostics
with decoded \code{event_class}). It preserves numbers, dimensions, row order,
and identities, including zero and one row. No class is inferred from probabilities,
and no truth or details are inferred from a prediction table.
}
\details{
Select the intended columns before creating the schema. All selected names and
all declared outcome levels get deterministic, collision-free technical codes.
Mapping uses exact names, never name repair, Unicode normalization, case folding,
or frequency sorting. Even original names that resemble codes remain distinct.
Empty, missing or duplicate names, unknown columns or classes, missing predictors,
and damaged or incomplete schema mappings are errors. The schema is fixed across
folds, prediction batches and processes; do not edit it after construction.

Build formulas, recipes, variable selections, and outer resamples explicitly on
the encoded data. Use \code{schema$encoded_outcome} in the workflow constructor.
Existing recipes are not rewritten. To retain prescribed outer memberships,
rebuild their splits on the encoded data with the same row positions and IDs.
Inner plan functions receive local encoded data; the exact local plan/data
comparison and all training, calibration and assessment separation rules remain.

Native predictions remain encoded. Separate decoded roles avoid collisions
between an original class \code{class}, outcome \code{.pred_class}, and external
\code{id}/\code{id2}. The decoder does not flatten or repair these names.
Probability columns must cover every schema class exactly once; named columns
are reordered to schema order. Unknown encoded output names or class codes fail.

Encoded data, native predictions, and details carry a \code{vennabers_schema}
attribute. Existing foreign bindings are rejected. Ordinary table operations or
collectors may drop attributes: detached tables therefore require the actually
associated schema supplied by the caller. Matching codes alone cannot establish
provenance. Decode unsummarized predictions to preserve repetitions; the decoder
cannot recover rows already summarized or dropped. Collect notes and unsummarized
metrics separately, audit completeness, and explicitly extract fitted states
when inner models or diagnostics are needed. Match \code{control_resamples()}'s
\code{event_level} to the schema; no control is silently changed.

Schema helpers use base R and do not load optional integration packages.
The schema and fitted pure R workflow state survive RDS restoration in a fresh
process with the required engine namespaces loaded. Outer workers require
\code{pkgs = c("vennabers", "stats")} for the installed GLM example,
\code{parallel_over = "resamples"}, and consistent seeds and thread settings.
}
\examples{
source(system.file("examples", "encoded-binary.R", package = "vennabers"))
}
\seealso{\code{\link{calibrated_workflow}}, \code{\link{local_calibration_splits}}}
