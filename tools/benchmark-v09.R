# v0.9 postprocessing benchmark. Run from the repository root in a fresh process
# per case, with R_LIBS pointing at one installed artifact and one BLAS/OpenMP
# thread, for example:
#   OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
#   R_LIBS=<lib> /usr/bin/time -l Rscript tools/benchmark-v09.R binary holdout matched out.rds
# Families: binary (Sigmoid on probabilities), pairwise (three-class pair OvO,
# Sigmoid), ovo (shared three-class OvO, Tailor multinomial), regression
# (reference isotonic). Strategy: holdout (P = 20%) or ensemble (J = 3).
# Model: matched or full. "tuned ensemble full" runs the binary two-stage Grid
# case with four candidates per local search.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4L,
          args[[1L]] %in% c("binary", "pairwise", "ovo", "regression", "tuned"),
          args[[2L]] %in% c("holdout", "ensemble"), args[[3L]] %in% c("matched", "full"))
family <- args[[1L]]; strategy <- args[[2L]]; model_mode <- args[[3L]]
tuned <- family == "tuned"
if (tuned) stopifnot(strategy == "ensemble", model_mode == "full")
library(vennabers)

# Data preparation (outside every measurement): same generator as benchmark-v08.R.
set.seed(804L)
n <- 2500L
reps <- as.integer(Sys.getenv("BENCH_REPS", "3"))
stopifnot(reps >= 1L)
x <- matrix(stats::rnorm(n * 10L), ncol = 10L)
colnames(x) <- paste0("x", seq_len(ncol(x)))
data <- as.data.frame(x)
signal <- x[, 1L] + 0.5 * x[, 2L] - 0.3 * x[, 3L]
regression <- family == "regression"
if (regression) {
  data$truth <- signal + stats::rnorm(n, sd = 0.5)
} else if (family %in% c("binary", "tuned")) {
  data$truth <- factor(ifelse(stats::runif(n) < stats::plogis(signal), "yes", "no"),
                       levels = c("yes", "no"))
} else {
  noisy <- signal + stats::rnorm(n, sd = 1.2)
  data$truth <- factor(c("a", "b", "c")[1L + (noisy > -0.4) + (noisy > 0.7)])
}
development <- data[seq_len(n - 500L), , drop = FALSE]
assessment <- data[(n - 499L):n, , drop = FALSE]
new_data <- assessment[setdiff(names(assessment), "truth")]
outer <- withr::with_seed(807L, rsample::vfold_cv(development, v = 3L))

engine <- if (regression) parsnip::linear_reg(engine = "lm") else if (family == "ovo")
  parsnip::multinom_reg(penalty = 0.1) |> parsnip::set_engine("nnet", trace = FALSE, maxit = 1000) else
  if (tuned) parsnip::decision_tree(tree_depth = tune::tune("depth")) |>
    parsnip::set_mode("classification") |> parsnip::set_engine("rpart") else
  parsnip::logistic_reg(engine = "glm")
# Learned preprocessing: locally fitted normalization (roadmap reference models).
workflow <- workflows::workflow() |> workflows::add_recipe(recipes::recipe(truth ~ ., development) |>
  recipes::step_normalize(recipes::all_numeric_predictors())) |> workflows::add_model(engine)
method <- c(binary = "sigmoid", tuned = "sigmoid", pairwise = "sigmoid",
            ovo = "tailor_multinomial", regression = "isotonic_numeric")[[family]]
post <- list(method = method, strategy = strategy)
if (method == "sigmoid") post$sigmoid_input <- "probability"
if (strategy == "holdout") post$prop <- 0.2 else post$v <- 3L
settings <- list(workflow = workflow, outcome = "truth", method = "cross", v = 5L,
                 prediction_model = model_mode, seed = 806L, postprocessing = post)
if (regression) settings$m <- 1L
if (family %in% c("pairwise", "ovo")) settings$classification <- "ovo"
if (family == "pairwise") settings$model_training <- "pairwise"
if (tuned) settings$tuning <- list(strategy = "two_stage", model = list(method = "grid",
  grid = data.frame(depth = 1:4),
  resamples = function(d) rsample::vfold_cv(d, v = 2L, strata = truth, pool = 0)))
calibrated <- do.call(calibrated_workflow, settings, quote = TRUE)

# Contract costs without tuning: Cross K=5 matched KJ pairs (all retained), full
# (K+1)J trained and J retained, summed over class pairs.
J <- if (strategy == "holdout") 1L else 3L
domains <- if (family == "pairwise") 3L else 1L
expected <- list(base = domains * J * (5L + (model_mode == "full")),
                 retained = domains * J * (if (model_mode == "full") 1L else 5L))
counters <- function(fitted) {
  state <- workflows::extract_fit_engine(fitted)
  parts <- if (is.null(state$pair_models)) list(state) else state$pair_models
  records <- unlist(lapply(parts, `[[`, "postprocessing"), recursive = FALSE)
  retained <- sum(vapply(parts, function(part) sum(vapply(part$models, function(model)
    if (inherits(model, "vennabers_ensemble")) length(model$models) else 1L, 1L)), 1L))
  tuning <- if (tuned) venn_abers_tuning(fitted)$cost$observed_base_fits
  list(composition_base_fits = sum(vapply(records, `[[`, 1L, "observed_base_fits")),
       postprocessor_fits = sum(vapply(records, `[[`, 1L, "observed_postprocessor_fits")),
       retained_pairs = retained, tuning_observed_base_fits = tuning)
}
peak <- function(expr) {
  invisible(gc(reset = TRUE))
  seconds <- system.time(value <- force(expr))[["elapsed"]]
  memory <- gc()
  list(value = value, seconds = seconds, heap_mib = sum(memory[, which(colnames(memory) == "max used") + 1L]))
}
metrics <- if (regression) yardstick::metric_set(yardstick::rmse) else yardstick::metric_set(yardstick::mn_log_loss)
measure <- function() {
  fit <- peak(generics::fit(calibrated, development))
  prediction <- peak(predict(fit$value, new_data, type = if (regression) "numeric" else "prob"))
  stopifnot(nrow(prediction$value) == nrow(new_data), all(is.finite(as.matrix(prediction$value))))
  evaluation <- peak(tune::fit_resamples(calibrated, outer, metrics = metrics,
    control = tune::control_resamples(save_pred = TRUE, allow_par = FALSE)))
  stopifnot(nrow(tune::collect_notes(evaluation$value)) == 0L,
            identical(sort(tune::collect_predictions(evaluation$value)$.row), seq_len(nrow(development))))
  count <- counters(fit$value)
  if (!tuned) stopifnot(count$composition_base_fits == expected$base, count$postprocessor_fits == expected$base,
                        count$retained_pairs == expected$retained)
  path <- tempfile(fileext = ".rds")
  saveRDS(fit$value, path, version = 3L)
  bytes <- file.info(path)$size
  unlink(path)
  # heap_mib is the R heap maximum per phase; the process peak comes from /usr/bin/time.
  list(fit = fit$seconds, predict = prediction$seconds, outer = evaluation$seconds, rds_bytes = bytes,
       fit_heap_mib = fit$heap_mib, predict_heap_mib = prediction$heap_mib, outer_heap_mib = evaluation$heap_mib,
       counters = count)
}
invisible(measure()) # warm-up
results <- replicate(reps, measure(), simplify = FALSE)
saveRDS(list(family = family, strategy = strategy, prediction_model = model_mode, rows = n,
             development = nrow(development), new = nrow(new_data), outer_folds = nrow(outer),
             expected = if (!tuned) expected, repetitions = results, R = R.version.string,
             blas = extSoftVersion()[["BLAS"]], la_library = La_library(),
             threads = Sys.getenv(c("OMP_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "OPENBLAS_NUM_THREADS")),
             session = utils::sessionInfo(), package = as.character(utils::packageVersion("vennabers")),
             library = find.package("vennabers")), args[[4L]], version = 3L)
