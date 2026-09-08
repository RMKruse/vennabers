\name{vennabers-engine}
\alias{fit_vennabers}
\alias{predict_vennabers_prob}
\alias{predict_vennabers_class}
\alias{predict_vennabers_numeric}
\title{Parsnip Engine Entry Points}
\description{Exported entry points for the optional parsnip registration. Users
should construct and predict with \code{\link{calibrated_workflow}} instead.}
\usage{
fit_vennabers(x, y, base_workflow, outcome, parameters)
predict_vennabers_prob(object, new_data)
predict_vennabers_class(object, new_data)
predict_vennabers_numeric(object, new_data)
}
\arguments{
\item{x, y}{Raw predictor data frame and factor classification or finite numeric regression truth from parsnip.}
\item{base_workflow}{An unfitted configured base workflow.}
\item{outcome}{Original outcome name.}
\item{parameters}{Constructor-validated requested options and explicit flags.}
\item{object}{The fitted \code{vennabers_fit} engine state.}
\item{new_data}{Forged raw predictors.}
}
\value{The fit entry point returns a \code{vennabers_fit}. Prediction entry points
return a named probability tibble, factor of original classes, or double regression points.}
\keyword{internal}
