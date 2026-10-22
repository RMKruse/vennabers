# Run from the repository root with R_LIBS pointing at one installed artifact:
# Rscript tools/benchmark-v08.R binary fixed /tmp/binary-fixed.rds
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L, args[[1L]] %in% c("binary", "pairwise", "regression"),
          args[[2L]] %in% c("fixed", "grid", "bayes"))
family <- args[[1L]]
search <- args[[2L]]
library(vennabers)

set.seed(804L)
n <- as.integer(Sys.getenv("BENCH_ROWS", "2500"))
reps <- as.integer(Sys.getenv("BENCH_REPS", "3"))
stopifnot(n >= 600L, reps >= 1L)
x <- matrix(stats::rnorm(n * 10L), ncol = 10L)
colnames(x) <- paste0("x", seq_len(ncol(x)))
data <- as.data.frame(x)
signal <- x[, 1L] + 0.5 * x[, 2L] - 0.3 * x[, 3L]
if (family == "regression") {
  data$truth <- signal + stats::rnorm(n, sd = 0.5)
} else if (family == "binary") {
  data$truth <- factor(ifelse(stats::runif(n) < stats::plogis(signal), "yes", "no"),
                       levels = c("yes", "no"))
} else {
  noisy <- signal + stats::rnorm(n, sd = 1.2)
  data$truth <- factor(c("a", "b", "c")[1L + (noisy > -0.4) + (noisy > 0.7)])
}
development <- data[seq_len(n - 500L), , drop = FALSE]
assessment <- data[(n - 499L):n, , drop = FALSE]
regression <- family == "regression"
if (search == "fixed") {
  model <- if (regression) parsnip::linear_reg(engine = "lm") else
    parsnip::logistic_reg(engine = "glm")
} else {
  model <- parsnip::decision_tree(tree_depth = tune::tune("depth")) |>
    parsnip::set_mode(if (regression) "regression" else "classification") |>
    parsnip::set_engine("rpart")
}
workflow <- workflows::workflow() |>
  workflows::add_formula(truth ~ .) |>
  workflows::add_model(model)
folds <- function(d) {
  if (regression) rsample::vfold_cv(d, v = 2L) else
    rsample::vfold_cv(d, v = 2L, strata = truth, pool = 0)
}
if (search != "fixed") {
  depth <- dials::parameters(dials::new_quant_param(type = "integer",
    range = c(1L, 4L), inclusive = c(TRUE, TRUE), label = c(depth = "Depth")))
  if (regression) {
    cal_grid <- data.frame(moderation = c(0.2, 0.3, 0.4, 0.5))
    cal_params <- dials::parameters(dials::new_quant_param(type = "double",
      range = c(0.2, 0.5), inclusive = c(TRUE, TRUE),
      label = c(moderation = "Moderation")))
  } else {
    cal_grid <- expand.grid(va_loss = c("log", "brier"),
                            rounding = c("none", "-2"))
    cal_params <- dials::parameters(
      dials::new_qual_param(type = "character", values = c("log", "brier"),
                            label = c(va_loss = "Loss")),
      dials::new_qual_param(type = "character", values = c("none", "-2"),
                            label = c(rounding = "Rounding")))
  }
  if (search == "grid") {
    model_search <- list(method = "grid", grid = data.frame(depth = 1:4),
                         resamples = folds)
    cal_search <- list(method = "grid", grid = cal_grid, resamples = folds)
  } else {
    model_search <- list(method = "bayes", initial = 4L, iter = 4L,
      param_info = depth, resamples = folds,
      control = tune::control_bayes(seed = 804L, save_pred = TRUE, no_improve = 4L))
    cal_search <- list(method = "bayes", initial = 4L, iter = 4L,
      param_info = cal_params, resamples = folds,
      control = tune::control_bayes(seed = 805L, save_pred = TRUE, no_improve = 4L))
  }
  tuning <- list(strategy = "two_stage", selection_prop = 0.2,
                 model = model_search, calibration = cal_search)
}
settings <- list(workflow = workflow, outcome = "truth", method = "cross",
                 v = 5L, prediction_model = if (family == "binary") "matched" else "full",
                 seed = 806L)
if (family == "pairwise") {
  settings$classification <- "ovo"
  settings$model_training <- "pairwise"
}
if (regression) {
  settings$m <- 1L
  if (search != "fixed") {
    settings$m <- NULL
    settings$epsilon <- tune::tune("moderation")
  }
} else if (search != "fixed") {
  settings$loss <- tune::tune("va_loss")
  settings$precision <- tune::tune("rounding")
}
if (search != "fixed") settings$tuning <- tuning
calibrated <- do.call(calibrated_workflow, settings, quote = TRUE)
measure <- function() {
  fit_time <- system.time(fitted <- generics::fit(calibrated, development))["elapsed"]
  prediction_time <- system.time(prediction <- predict(fitted, assessment,
    type = if (regression) "numeric" else "prob"))["elapsed"]
  stopifnot(nrow(prediction) == nrow(assessment))
  outer <- rsample::vfold_cv(development, v = 3L)
  metrics <- if (regression) yardstick::metric_set(yardstick::rmse) else
    yardstick::metric_set(yardstick::mn_log_loss)
  outer_time <- system.time(result <- tune::fit_resamples(calibrated, outer,
    metrics = metrics))["elapsed"]
  stopifnot(nrow(tune::collect_metrics(result)) > 0L)
  path <- tempfile(fileext = ".rds")
  saveRDS(fitted, path, version = 3L)
  bytes <- file.info(path)$size
  unlink(path)
  list(fit = unname(fit_time), predict = unname(prediction_time),
       outer = unname(outer_time), bytes = unname(bytes))
}
invisible(measure()) # warm-up
results <- replicate(reps, measure(), simplify = FALSE)
saveRDS(list(family = family, search = search, rows = n, repetitions = results,
             R = R.version.string, package = as.character(utils::packageVersion("vennabers"))),
        args[[3L]], version = 3L)
