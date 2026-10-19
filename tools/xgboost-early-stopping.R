# Executable check of native XGBoost early stopping inside calibrated
# workflows. xgboost is deliberately not in Suggests, so this runs outside the
# package tests. Run from the repository root:
#   Rscript --vanilla tools/xgboost-early-stopping.R [<candidate-lib>] [<xgboost-lib>]
# Both libraries are optional and are put before the site library; the
# remaining integration packages and testthat come from there.
#
# Fixed options stay in parsnip::set_engine(). Every local fit receives
# nrounds = 100, early_stop = 10 and validation = 0.2 and splits its internal
# validation rows only from its own prepared B: source folds, class pairs,
# Full1 and postprocessing B. Stored boosters stopped early on that internal
# validation. An invalid setting fails with the fold, pair or B/P context.

libraries <- commandArgs(trailingOnly = TRUE)
if (length(libraries)) .libPaths(c(normalizePath(libraries, mustWork = TRUE), .libPaths()))
suppressPackageStartupMessages(library(vennabers))
for (package in c("xgboost", "parsnip", "workflows", "testthat", "withr")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Missing package: ", package)
}
versions <- vapply(c("vennabers", "xgboost", "parsnip", "workflows", "hardhat", "rsample", "testthat"),
                   function(p) as.character(utils::packageVersion(p)), "")
cat(R.version.string, "|", R.version$platform, "\n")
cat(paste(names(versions), versions, collapse = ", "), "\n")
cat("vennabers from", find.package("vennabers"), "\n\n")

binary <- withr::with_seed(5, {
  x <- stats::rnorm(400)
  data.frame(x = x, z = stats::rnorm(400), truth = factor(ifelse(stats::runif(400) < stats::plogis(2 * x), "yes", "no")))
})
multi <- withr::with_seed(6, {
  truth <- factor(rep(c("a", "b", "c"), 160))
  data.frame(x = stats::rnorm(480, sd = 1.5) + c(-1, 1, -1)[truth],
             z = stats::rnorm(480, sd = 1.5) + c(-1, -1, 1)[truth], truth = truth)
})
stopifnot(!anyDuplicated(binary$x), !anyDuplicated(multi$x))

early_stopping <- function(validation = 0.2) {
  spec <- parsnip::boost_tree(mode = "classification", trees = 100L, stop_iter = 10L) |>
    parsnip::set_engine("xgboost", validation = validation)
  workflows::workflow() |>
    workflows::add_formula(truth ~ .) |>
    workflows::add_model(spec)
}

# Fits with parsnip::xgb_train() recorded as original rows and fixed options.
recorded_fit <- function(d, ..., validation = 0.2) {
  fits <- list()
  original <- parsnip::xgb_train
  testthat::with_mocked_bindings({
    fit <- generics::fit(calibrated_workflow(early_stopping(validation), "truth", seed = 42, ...), d)
  }, xgb_train = function(x, y, ...) {
    fits[[length(fits) + 1L]] <<- list(rows = sort(match(x[, "x"], d$x)), options = list(...))
    original(x, y, ...)
  }, .package = "parsnip")
  list(state = workflows::extract_fit_engine(fit), fits = fits)
}

# Stored workflows, postprocessed holdouts and inner ensemble members.
boosters <- function(models) lapply(models, function(model) {
  if (inherits(model, "workflow")) return(list(workflows::extract_fit_engine(model)))
  members <- if (inherits(model, "vennabers_ensemble")) model$models else list(model)
  lapply(members, function(m) workflows::extract_fit_engine(m$workflow))
})

check <- function(case, recorded, rows, models) {
  rows <- unname(lapply(rows, sort))
  stopifnot(length(rows) > 0L, identical(lapply(recorded$fits, `[[`, "rows"), rows))
  for (f in recorded$fits) {
    stopifnot(identical(f$options[c("nrounds", "early_stop", "validation")],
                        list(nrounds = 100L, early_stop = 10L, validation = 0.2)))
  }
  rounds <- vapply(unlist(boosters(models), recursive = FALSE), function(b) {
    log <- attributes(b)$evaluation_log
    stopifnot("validation_logloss" %in% names(log), !is.null(attributes(b)$early_stop))
    nrow(log)
  }, 1L)
  stopifnot(length(rounds) > 0L, all(rounds < 100L))
  cat(sprintf("%-34s %2d local fits on %s rows; stored boosters stopped after %s rounds\n", case,
              length(rows), paste(range(lengths(rows)), collapse = "-"), paste(range(rounds), collapse = "-")))
}

# The documented call: Inductive matched with the defaults.
recorded <- recorded_fit(binary)
check("binary inductive matched", recorded, lapply(recorded$state$folds, `[[`, "analysis"), recorded$state$models)

recorded <- recorded_fit(binary, method = "cross", v = 3L, prediction_model = "full")
check("binary cross full", recorded,
      c(lapply(recorded$state$folds, `[[`, "analysis"), list(seq_len(nrow(binary)))), recorded$state$models)

recorded <- recorded_fit(multi, classification = "ovo", model_training = "pairwise",
                         method = "cross", v = 2L, prediction_model = "full")
pairs <- unname(recorded$state$pair_models)
check("pairwise OvO cross full", recorded,
      c(unlist(lapply(pairs, function(pair) lapply(pair$folds, function(f) pair$rows[f$analysis])), recursive = FALSE),
        lapply(pairs, `[[`, "rows")),
      unlist(lapply(pairs, `[[`, "models"), recursive = FALSE))

for (strategy in c("holdout", "ensemble")) {
  post <- c(list(method = "sigmoid", sigmoid_input = "probability", strategy = strategy),
            if (strategy == "holdout") list(prop = .3) else list(v = 2L))
  recorded <- recorded_fit(binary, method = "inductive", prediction_model = "full", postprocessing = post)
  plans <- unlist(lapply(recorded$state$postprocessing, function(p) if (is.null(p$inner_folds)) list(p) else p$inner_folds),
                  recursive = FALSE)
  check(paste("sigmoid", strategy, "inductive full"), recorded, lapply(plans, `[[`, "B"), recorded$state$models)
}

# An invalid validation share fails the whole fit with its local context.
failures <- list(
  shared = list(binary, method = "cross", v = 2L),
  pairwise = list(multi, classification = "ovo", model_training = "pairwise"),
  sigmoid = list(binary, postprocessing = list(method = "sigmoid", sigmoid_input = "probability",
                                               strategy = "ensemble", v = 2L)))
contexts <- c(shared = "^Fold1 base workflow training: ",
              pairwise = "^pair_1 Inductive1 base workflow training: ",
              sigmoid = "^Inductive1 / Fold1 sigmoid \\(B=[0-9]+, P=[0-9]+\\): ")
for (case in names(failures)) {
  message <- tryCatch({
    do.call(recorded_fit, c(failures[[case]], list(validation = 1.5)))
    stop("Invalid validation share was accepted: ", case)
  }, error = function(e) conditionMessage(e))
  stopifnot(grepl(contexts[[case]], message), grepl("`validation` should be on [0, 1)", message, fixed = TRUE))
  cat(sprintf("%-34s %s\n", paste("invalid validation,", case), message))
}
cat("\nAll XGBoost early-stopping checks passed.\n")
