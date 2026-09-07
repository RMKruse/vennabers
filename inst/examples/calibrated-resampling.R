# Run against an installed vennabers package. Helpers here are an executable
# audit of this binary, fixed-configuration example, not an evaluation API.
check_outer_splits <- function(outer) {
  ids <- setdiff(names(outer), "splits")
  stopifnot(!anyDuplicated(outer[ids]))
  for (split in outer$splits) {
    a <- as.integer(split, data = "analysis")
    b <- as.integer(split, data = "assessment")
    stopifnot(length(a) > 0L, length(b) > 0L, !anyDuplicated(a), !anyDuplicated(b),
              !anyNA(c(a, b)), all(c(a, b) == floor(c(a, b))),
              all(c(a, b) >= 1L & c(a, b) <= nrow(split$data)), !length(intersect(a, b)))
  }
  invisible(NULL)
}

check_evaluation <- function(result, outer, event_level = "first") {
  check_outer_splits(outer)
  # A collector can itself fail when all fits fail. That is an incomplete run.
  notes <- tune::collect_notes(result)
  predictions <- tune::collect_predictions(result, summarize = FALSE)
  metrics <- tune::collect_metrics(result, summarize = FALSE)
  stopifnot(nrow(notes) == 0L)
  ids <- setdiff(names(outer), "splits")
  config <- "pre0_mod0_post0" # tune 2.1: the one fixed fit_resamples configuration
  expected <- do.call(rbind, lapply(seq_len(nrow(outer)), function(i) {
    rows <- as.integer(outer$splits[[i]], data = "assessment")
    cbind(as.data.frame(outer[rep(i, length(rows)), ids, drop = FALSE]),
          .row = rows, .config = config)
  }))
  expected_metrics <- do.call(rbind, lapply(seq_len(nrow(outer)), function(i) {
    cbind(as.data.frame(outer[rep(i, 2L), ids, drop = FALSE]),
          .metric = c("brier_class", "mn_log_loss"), .config = config)
  }))
  same_keys <- function(actual, expected) {
    actual <- as.data.frame(actual[names(expected)])
    expected <- as.data.frame(expected)
    stopifnot(!anyNA(actual), !anyDuplicated(actual), nrow(actual) == nrow(expected))
    actual <- actual[do.call(order, actual), , drop = FALSE]
    expected <- expected[do.call(order, expected), , drop = FALSE]
    rownames(actual) <- rownames(expected) <- NULL
    stopifnot(identical(actual, expected))
  }
  same_keys(predictions, expected)
  same_keys(metrics, expected_metrics)
  stopifnot(all(is.finite(metrics$.estimate)), all(metrics$.estimator == "binary"))
  for (i in seq_len(nrow(outer))) {
    matches <- function(table) Reduce(`&`, lapply(ids, function(id) table[[id]] == outer[[id]][i]))
    p <- predictions[matches(predictions), ]
    truth <- outer$splits[[i]]$data$truth[p$.row]
    stopifnot(identical(p$truth, truth), !anyNA(truth))
    event <- levels(truth)[if (event_level == "first") 1L else 2L]
    probability <- p[[paste0(".pred_", event)]]
    all_p <- as.matrix(p[paste0(".pred_", levels(truth))])
    stopifnot(all(is.finite(all_p)), all(all_p >= 0 & all_p <= 1),
              all(abs(rowSums(all_p) - 1) <= 1e-10))
    # yardstick binary vector Brier; only the metric clips for log loss.
    clipped <- pmin(pmax(probability, .Machine$double.eps), 1 - .Machine$double.eps)
    manual <- c(brier_class = mean(((truth == event) - probability)^2),
                mn_log_loss = -mean(ifelse(truth == event, log(clipped), log1p(-clipped))))
    m <- metrics[matches(metrics), ]
    stopifnot(all(abs(m$.estimate - manual[m$.metric]) <= 1e-10))
  }
  invisible(list(predictions = predictions, metrics = metrics, notes = notes))
}

if (all(vapply(c("vennabers", "tune", "yardstick", "rsample", "workflows"),
               requireNamespace, logical(1), quietly = TRUE))) {
  development <- data.frame(x = sin(1:120), truth = factor(rep(c("yes", "no", "no", "yes"), 30)))
  base <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  # Direct explicit calibration uses a bound local rsplit.
  direct_split <- withr::with_seed(101, rsample::initial_split(development, .8))
  direct <- generics::fit(vennabers::calibrated_workflow(base, "truth", splits = direct_split), development)
  stopifnot(nrow(predict(direct, development, type = "prob")) == nrow(development))

  # Seed the outer plan separately. Prepared inner assignments see only analysis.
  outer <- withr::with_seed(102, rsample::vfold_cv(development, v = 3, repeats = 2))
  check_outer_splits(outer)
  prepared <- withr::with_seed(103, lapply(outer$splits, function(split) {
    rsample::initial_split(rsample::analysis(split), .8)
  }))
  resolver <- vennabers::local_calibration_splits(prepared, c("x", "truth"))
  model <- vennabers::calibrated_workflow(base, "truth", splits = resolver,
                                         seed = 104, event_level = "first", loss = "brier")
  # For compact diagnostics use extract = function(w) {
  #   s <- workflows::extract_fit_engine(w)
  #   list(folds = s$folds, parameters = s$parameters, rng_kind = s$rng_kind)
  # }. extract = identity retains every entire fitted outer workflow instead.
  control <- tune::control_resamples(save_pred = TRUE, extract = workflows::extract_fit_engine,
                                     event_level = "first", parallel_over = "resamples",
                                     pkgs = c("vennabers", "stats"))
  result <- withr::with_seed(105, tune::fit_resamples(model, outer,
    metrics = yardstick::metric_set(yardstick::brier_class, yardstick::mn_log_loss), control = control))
  checked <- check_evaluation(result, outer, event_level = "first")
  states <- tune::collect_extracts(result)
  stopifnot(nrow(states) == nrow(outer), all(vapply(states$.extracts, inherits, logical(1), "vennabers_fit")))
}
