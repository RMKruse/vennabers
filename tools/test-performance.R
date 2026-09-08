# Validate a completed benchmark/smoke bundle: Rscript tools/test-performance.R OUTPUT
local({
  output <- commandArgs(TRUE)
  v05 <- "--v05" %in% output
  v04 <- "--v04" %in% output || v05
  output <- output[!output %in% c("--v04", "--v05")]
  stopifnot(length(output) == 1L)
  read <- function(name) read.csv(file.path(output, name))
  plan <- read("plan.csv")
  runs <- read("runs.csv")
  medians <- read("medians.csv")
  comparison <- read("comparison.csv")
  stopifnot(nrow(plan) > 0L, !anyNA(plan$case), all(nzchar(plan$case)),
            !anyDuplicated(plan$case), is.logical(plan$previous_supported),
            !anyNA(plan$previous_supported))
  if (v04) {
    classification <- c("binary_inductive", "binary_cross", "binary_cross_brier_p2",
      "3_cross_ovo_brier_p2", as.vector(outer(c("3", "10"),
        c("inductive_ovo", "inductive_ovr", "cross_ovo", "cross_ovr"), paste, sep = "_")))
    regression <- c("regression_inductive_m1", "regression_inductive_epsilon01",
                    "regression_cross_m1", "regression_cross_epsilon01")
    integration <- as.vector(outer(c("binary", "ovo", "ovr", "regression"),
                                  c("inductive", "cross"), function(x, y) paste("workflow", x, y, sep = "_")))
    stopifnot(setequal(plan$case, c(classification, regression, if (v05) integration)),
              identical(plan$previous_supported, plan$case %in% c(classification, if (v05) regression)))
  }
  pairs <- rbind(data.frame(case = plan$case, release = "current"),
                 data.frame(case = plan$case[plan$previous_supported],
                            release = rep("previous", sum(plan$previous_supported))))
  pairs <- pairs[order(pairs$case, pairs$release), ]
  # Require each identity exactly once, independently of CSV row order.
  align <- function(actual, expected, keys, label) {
    if (!all(keys %in% names(actual)) || nrow(actual) != nrow(expected) ||
        anyNA(actual[keys]) || anyDuplicated(actual[keys])) stop(label, ": invalid identities")
    actual <- actual[do.call(order, actual[keys]), , drop = FALSE]
    expected <- expected[do.call(order, expected[keys]), , drop = FALSE]
    for (key in keys) if (!all(actual[[key]] == expected[[key]])) stop(label, ": unexpected ", key)
    actual
  }
  # The protocol specifies one warmup (0) and three measurements (1–3).
  align(runs, merge(pairs, data.frame(iteration = 0:3), by = NULL),
        c("case", "release", "iteration"), "runs")
  medians <- align(medians, pairs, c("case", "release"), "medians")
  comparison <- align(comparison, plan, "case", "comparison")
  metrics <- c("fit_seconds", "predict_seconds", "rds_bytes", "process_peak_bytes")
  if (v05 || "outer_seconds" %in% names(runs)) metrics <- c(metrics, "outer_seconds")
  stopifnot(all(vapply(runs[metrics], function(x) is.numeric(x) && all(is.finite(x)), FALSE)),
            all(runs$fit_seconds >= 0), all(runs$predict_seconds >= 0),
            all(runs$rds_bytes > 0), all(runs$process_peak_bytes > 0))
  equal_values <- function(actual, expected, label) {
    # read.csv infers a logical column when every entry is NA.
    numeric_column <- is.numeric(actual) || (is.logical(actual) && all(is.na(actual)))
    if (!numeric_column || length(actual) != length(expected) || any(is.nan(actual)) ||
        !identical(is.na(actual), is.na(expected))) stop(label, ": invalid values or missingness")
    present <- !is.na(expected)
    # Allow CSV floating-point round trips, comparing each value separately.
    if (any(!is.finite(actual[present])) ||
        any(abs(actual[present] - expected[present]) > 1e-12 * pmax(1, abs(expected[present])))) {
      stop(label, ": differs from expected values")
    }
  }
  for (metric in metrics) {
    # Recompute directly from each planned group, without the runner's aggregate/merge path.
    expected <- vapply(seq_len(nrow(pairs)), function(i) {
      measured <- runs$case == pairs$case[i] & runs$release == pairs$release[i] & runs$iteration > 0L
      median(runs[[metric]][measured])
    }, 0.0)
    equal_values(medians[[metric]], expected, paste("medians", metric))
    current <- expected[pairs$release == "current"][match(comparison$case, pairs$case[pairs$release == "current"])]
    previous <- expected[pairs$release == "previous"][match(comparison$case, pairs$case[pairs$release == "previous"])]
    ratio <- rep(NA_real_, nrow(comparison))
    positive <- !is.na(previous) & previous > 0
    ratio[positive] <- current[positive] / previous[positive]
    values <- list(current = current, previous = previous, ratio = ratio)
    for (suffix in names(values)) {
      equal_values(comparison[[paste0(metric, "_", suffix)]], values[[suffix]], paste("comparison", metric, suffix))
    }
  }
  supported <- plan$previous_supported[match(comparison$case, plan$case)]
  stopifnot(identical(comparison$status, ifelse(supported, "requires regression review", "new capability baseline")))
  large <- plan[plan$case == "binary_inductive", ]
  other <- plan[plan$case != "binary_inductive" & !grepl("^workflow_", plan$case), ]
  stopifnot(large$calibration == 100000L, large$prediction == 100000L,
            all(other$calibration == 10000L), all(other$prediction == 1000L),
            all(plan$folds[grepl("cross", plan$case)] == 5L),
            sum(plan$loss == "brier" & plan$precision == 2L, na.rm = TRUE) == 2L)
  for (id in plan$case) {
    path <- file.path(output, paste0(id, "-input.rds"))
    stopifnot(unname(tools::md5sum(path)) == plan$input_md5[plan$case == id])
    input <- readRDS(path)
    # Saved inputs are canonical; reconcile every configuration field by case.
    descriptor <- list(calibration = length(input$truth), prediction = input$n_new,
      classes = if (input$method == "regression") NA_integer_ else if (is.factor(input$truth)) nlevels(input$truth) else 2L,
      folds = if (input$cross) length(unique(input$fold)) else 1L,
      method = input$method, loss = input$loss,
      precision = if (is.null(input$precision)) NA_real_ else input$precision)
    # Older classification-only plans predate moderation columns.
    if (v04 || !is.null(input$moderation) || any(c("m", "epsilon") %in% names(plan))) {
      descriptor$m <- if (is.null(input$moderation$m)) NA_real_ else input$moderation$m
      descriptor$epsilon <- if (is.null(input$moderation$epsilon)) NA_real_ else input$moderation$epsilon
    }
    row <- plan[plan$case == id, ]
    for (field in names(descriptor)) {
      label <- paste("plan/input", id, field)
      if (field %in% c("method", "loss")) {
        if (!identical(as.character(row[[field]]), descriptor[[field]])) stop(label, ": differs from saved input")
      } else equal_values(row[[field]], descriptor[[field]], label)
    }
    if (isTRUE(input$integration)) {
      loadNamespace("rsample") # Register rsplit's as.integer() method before inspecting plans.
      stopifnot(v05 || grepl("^workflow_", id), nrow(input$data) == 2000L,
        nrow(input$newdata) == 500L, ncol(input$newdata) == 10L,
        identical(names(input$data), c(paste0("x", 1:10), "truth")),
        identical(names(input$newdata), paste0("x", 1:10)),
        identical(input$data$truth, input$truth), input$seed == 3504L,
        identical(id, paste("workflow", input$method, if (input$cross) "cross" else "inductive", sep = "_")),
        all(vapply(input$data[1:10], function(x) is.double(x) && all(is.finite(x)), FALSE)),
        all(vapply(input$newdata, function(x) is.double(x) && all(is.finite(x)), FALSE)),
        nrow(input$outer) == 3L, length(input$inner) == 3L,
        !row$previous_supported, all(runs$outer_seconds[runs$case == id] > 0))
      spec <- workflows::extract_spec_parsnip(input$base)
      recipe <- workflows::extract_recipe(input$base, estimated = FALSE)
      stopifnot(length(recipe$steps) == 1L, inherits(recipe$steps[[1L]], "step_normalize"),
        !recipe$steps[[1L]]$trained,
        identical(rlang::quo_get_env(recipe$steps[[1L]]$terms[[1L]]), baseenv()),
        spec$engine == if (input$method == "regression") "lm" else if (input$method == "binary") "glm" else "nnet")
      if (input$method == "regression") stopifnot(identical(input$moderation, list(m = 1)),
        is.double(input$truth), all(is.finite(input$truth)))
      else stopifnot(is.factor(input$truth), nlevels(input$truth) == if (input$method == "binary") 2L else 3L,
                    input$loss == "log", is.null(input$precision))
      check_partition <- function(splits, data, folds) {
        stopifnot(length(splits) == folds)
        held <- integer()
        for (split in splits) {
          a <- as.integer(split, data = "analysis")
          b <- as.integer(split, data = "assessment")
          stopifnot(identical(split$data, data), length(a) > 0L, length(b) > 0L,
            !anyNA(c(a, b)), !anyDuplicated(c(a, b)),
            identical(sort(c(a, b)), seq_len(nrow(data))))
          if (folds == 1L) stopifnot(length(a) == floor(.8 * nrow(data)))
          held <- c(held, b)
        }
        if (folds > 1L) stopifnot(identical(sort(held), seq_len(nrow(data))))
      }
      check_local <- function(plan, data) check_partition(if (input$cross) plan$splits else list(plan), data,
                                                          if (input$cross) 5L else 1L)
      check_local(input$split, input$data)
      check_partition(input$outer$splits, input$data, 3L)
      for (i in 1:3) check_local(input$inner[[i]], rsample::analysis(input$outer$splits[[i]]))
      if (input$cross) for (i in 1:5) stopifnot(all(input$fold[as.integer(input$split$splits[[i]], data = "assessment")] == input$split$id[i]))
    }
    if (input$cross && is.factor(input$truth)) stopifnot(all(table(input$truth, input$fold) > 0L))
    if (v04 && id %in% regression) {
      cross <- grepl("_cross_", id)
      epsilon <- grepl("_epsilon01$", id)
      stopifnot(identical(input$cross, cross), input$method == "regression",
                length(input$truth) == 10000L, length(input$prediction) == 10000L,
                identical(input$calibration_row, seq_len(10000L)),
                identical(input$new_row, seq_len(1000L)),
                all(is.finite(c(input$truth, input$prediction, input$newdata))),
                identical(input$moderation, if (epsilon) list(epsilon = 0.1) else list(m = 1)))
      if (cross) stopifnot(identical(dim(input$newdata), c(1000L, 5L)),
                          length(input$fold) == 10000L,
                          identical(colnames(input$newdata), unique(input$fold)))
      else stopifnot(is.null(dim(input$newdata)), length(input$newdata) == 1000L)
      k <- if (cross) as.numeric(table(input$fold)) else 10000
      m <- if (epsilon) floor(0.1 * (k + 1) / 2) else rep(1, length(k))
      stopifnot(length(k) == if (cross) 5L else 1L, all(k == if (cross) 2000L else 10000L),
                all(m >= 1 & m <= floor((k - 1) / 2)))
    }
  }
  if (v05) {
    for (method in c("inductive", "cross")) {
      ovo <- readRDS(file.path(output, paste0("workflow_ovo_", method, "-input.rds")))
      ovr <- readRDS(file.path(output, paste0("workflow_ovr_", method, "-input.rds")))
      for (field in c("data", "newdata", "split", "outer", "inner")) stopifnot(identical(ovo[[field]], ovr[[field]]))
    }
    stopifnot(all(runs$outer_seconds[!grepl("^workflow_", runs$case)] == 0))
  }
  # Independently protect the original IVAP case, including RNG draw order.
  set.seed(20260906)
  truth <- sample(c(FALSE, TRUE), 100000L, replace = TRUE)
  probability <- runif(100000L)
  newdata <- runif(100000L)
  input <- readRDS(file.path(output, "binary_inductive-input.rds"))
  stopifnot(identical(input$truth, truth), identical(input$probability, probability),
            identical(input$newdata, newdata))
  cat("Benchmark bundle checks passed.\n")
})
