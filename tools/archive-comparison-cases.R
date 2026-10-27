# Fixed case catalog of the archive comparison (RELEASE-ROADMAP-1.x.md §3.2),
# sourced by tools/archive-comparison.R in each version's own R process.
#
# A case is archive_case(fit, new, predict = ...): `fit()` builds the object,
# and every `predict` entry names one set of arguments after `new`. Omitted
# options take their default in both versions, so existing cases already cover
# the default of every new option. To also cover an explicitly passed default,
# a later minor adds it under `new_options`: the candidate passes `fit` options
# to `fit()` and `predict` options to every prediction, the predecessor
# (which lacks them) passes nothing. Add a case with a new name; never change
# an existing one except under the defect exception of §3.2.

archive_case <- function(fit, new, predict = list(default = list()), details = FALSE,
                         new_options = list(fit = list(), predict = list())) {
  list(fit = fit, new = new, predict = predict, details = details, new_options = new_options)
}

archive_cases <- function() {
  library(vennabers)
  # Fixed generators with an explicit RNG kind; the scores are rounded so that
  # every kernel meets tied scores.
  set.seed(20261027, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  n <- 120L
  p <- round(stats::runif(n), 2)
  y <- stats::runif(n) < p
  classes <- c("a", "b", "c")
  pm <- matrix(round(stats::runif(3L * n), 2) + .01, n, dimnames = list(NULL, classes))
  pm <- pm / rowSums(pm)
  ym <- factor(classes[apply(pm + matrix(stats::runif(3L * n, 0, .6), n), 1L, which.max)], classes)
  x <- round(stats::rnorm(n), 2)
  truth <- 3 + x + stats::rnorm(n, sd = .5)
  fold <- rep(1:4, length.out = n)
  ids <- as.character(1:4)

  # New scores include both ends, ties with calibration scores and new values.
  new_p <- c(0, .005, p[1:3], .5, .995, 1)
  new_pm <- rbind(pm[1:3, ], c(1, 0, 0), c(1, 1, 1) / 3)
  new_x <- c(min(x) - 1, x[1:3], 0, max(x) + 1)
  per_fold <- function(values) matrix(rep(values, 4L), length(values), dimnames = list(NULL, ids))
  per_fold_matrix <- function(values) stats::setNames(rep(list(values), 4L), ids)

  probability <- list(log = list(), brier = list(loss = "brier"), class = list(type = "class"))
  cross_probability <- c(probability, list(details = list(type = "details")))
  regression <- list(default = list())
  cross_regression <- list(default = list(), details = list(type = "details"))

  list(
    binary_inductive = archive_case(function(...) venn_abers(y, p, ...), new_p, probability),
    binary_inductive_precision = archive_case(function(...) venn_abers(y, p, precision = 1, ...), new_p, probability),
    binary_cross = archive_case(function(...) cross_venn_abers(y, p, fold, ...), per_fold(new_p), cross_probability),
    binary_cross_precision = archive_case(function(...) cross_venn_abers(y, p, fold, precision = 1, ...),
      per_fold(new_p), cross_probability),
    ovo_inductive = archive_case(function(...) venn_abers(ym, pm, ...), new_pm, cross_probability),
    ovr_inductive = archive_case(function(...) venn_abers(ym, pm, method = "ovr", ...), new_pm, cross_probability),
    ovo_inductive_precision = archive_case(function(...) venn_abers(ym, pm, precision = 1, ...),
      new_pm, cross_probability),
    ovo_cross = archive_case(function(...) cross_venn_abers(ym, pm, fold, ...), per_fold_matrix(new_pm),
      cross_probability),
    ovr_cross = archive_case(function(...) cross_venn_abers(ym, pm, fold, method = "ovr", ...),
      per_fold_matrix(new_pm), cross_probability),
    ovr_cross_precision = archive_case(function(...) cross_venn_abers(ym, pm, fold, precision = 1, method = "ovr", ...),
      per_fold_matrix(new_pm), cross_probability),
    ivar = archive_case(function(...) venn_abers_regression(truth, x, ...), new_x, regression),
    ivar_m = archive_case(function(...) venn_abers_regression(truth, x, m = 5, ...), new_x, regression),
    ivar_epsilon = archive_case(function(...) venn_abers_regression(truth, x, epsilon = .1, ...), new_x, regression),
    cvar = archive_case(function(...) cross_venn_abers_regression(truth, x, fold, ...), per_fold(new_x),
      cross_regression),
    cvar_m = archive_case(function(...) cross_venn_abers_regression(truth, x, fold, m = 3, ...), per_fold(new_x),
      cross_regression),
    cvar_epsilon = archive_case(function(...) cross_venn_abers_regression(truth, x, fold, epsilon = .1, ...),
      per_fold(new_x), cross_regression),
    workflow_binary = archive_workflow_case("binary", p, y, x, truth, pm, ym, method = "inductive"),
    workflow_ovo = archive_workflow_case("ovo", p, y, x, truth, pm, ym, method = "cross", precision = 1),
    workflow_ovr = archive_workflow_case("ovr", p, y, x, truth, pm, ym, method = "inductive"),
    workflow_regression = archive_workflow_case("regression", p, y, x, truth, pm, ym, method = "cross", m = 3))
}

# A workflow case starts where the engine hands over its scores: a
# model_adapter() returns the fixed score columns as they are, and explicit
# splits fix the fold assignment. Engine fits and dependencies stay outside
# the comparison (§3.2); everything from the scores on is vennabers.
archive_workflow_case <- function(target, p, y, x, truth, pm, ym, method, ...) {
  rows <- seq_along(p)
  data <- switch(target,
    binary = data.frame(s = p, truth = factor(ifelse(y, "yes", "no"), c("yes", "no"))),
    regression = data.frame(s = x, truth = truth),
    data.frame(sa = pm[, "a"], sb = pm[, "b"], sc = pm[, "c"], truth = ym))
  fit_data <- data[rows <= 100L, ]
  new_data <- data[rows > 100L, setdiff(names(data), "truth"), drop = FALSE]
  adapter <- if (target == "regression") {
    model_adapter("regression", fit = function(x, y) NULL, predict = function(object, new_data) new_data$s)
  } else if (target == "binary") {
    model_adapter("classification", fit = function(x, y) levels(y),
      predict = function(object, new_data) matrix(c(new_data$s, 1 - new_data$s), ncol = 2L,
                                                  dimnames = list(NULL, object)))
  } else {
    model_adapter("classification", fit = function(x, y) levels(y),
      predict = function(object, new_data) matrix(as.matrix(new_data[c("sa", "sb", "sc")]), ncol = 3L,
                                                  dimnames = list(NULL, object)))
  }
  base <- workflows::workflow() |>
    workflows::add_formula(stats::reformulate(setdiff(names(data), "truth"), "truth")) |>
    workflows::add_model(adapter)
  splits <- if (method == "cross") {
    held <- split(seq_len(100L), rep(1:4, length.out = 100L))
    rsample::manual_rset(lapply(held, function(h) {
      rsample::make_splits(list(analysis = setdiff(seq_len(100L), h), assessment = h), fit_data)
    }), paste0("Fold", 1:4))
  } else {
    rsample::make_splits(list(analysis = 1:70, assessment = 71:100), fit_data)
  }
  options <- c(list(method = method, splits = splits), list(...),
               if (target %in% c("ovo", "ovr")) list(classification = target))
  predict <- if (target == "regression") list(numeric = list(type = "numeric")) else
    list(prob = list(type = "prob"), brier = list(type = "prob", loss = "brier"), class = list(type = "class"))
  archive_case(function(...) {
    generics::fit(do.call(calibrated_workflow, c(list(base, "truth"), options, list(...))), fit_data)
  }, new_data, predict, details = TRUE)
}
