# Validate a completed benchmark/smoke bundle: Rscript tools/test-performance.R OUTPUT
local({
  output <- commandArgs(TRUE)
  stopifnot(length(output) == 1L)
  read <- function(name) read.csv(file.path(output, name))
  plan <- read("plan.csv")
  runs <- read("runs.csv")
  medians <- read("medians.csv")
  comparison <- read("comparison.csv")
  stopifnot(nrow(plan) > 0L, !anyNA(plan$case), all(nzchar(plan$case)),
            !anyDuplicated(plan$case), is.logical(plan$previous_supported),
            !anyNA(plan$previous_supported))
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
      stop(label, ": differs from measured runs")
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
  other <- plan[plan$case != "binary_inductive", ]
  stopifnot(large$calibration == 100000L, large$prediction == 100000L,
            all(other$calibration == 10000L), all(other$prediction == 1000L),
            all(plan$folds[grepl("cross", plan$case)] == 5L),
            sum(plan$loss == "brier" & plan$precision == 2L, na.rm = TRUE) == 2L)
  for (id in plan$case) {
    path <- file.path(output, paste0(id, "-input.rds"))
    stopifnot(unname(tools::md5sum(path)) == plan$input_md5[plan$case == id])
    input <- readRDS(path)
    if (input$cross && is.factor(input$truth)) stopifnot(all(table(input$truth, input$fold) > 0L))
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
