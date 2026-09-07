# Validate a completed benchmark/smoke bundle: Rscript tools/test-performance.R OUTPUT
local({
  output <- commandArgs(TRUE)
  stopifnot(length(output) == 1L)
  read <- function(name) read.csv(file.path(output, name))
  plan <- read("plan.csv")
  runs <- read("runs.csv")
  medians <- read("medians.csv")
  comparison <- read("comparison.csv")
  stopifnot(nrow(plan) == 12L, !anyDuplicated(plan$case),
            sum(plan$previous_supported) == 2L,
            nrow(runs) == 56L, nrow(medians) == 14L, nrow(comparison) == 12L,
            all(table(runs$iteration) == 14L),
            all(runs$fit_seconds >= 0), all(runs$predict_seconds >= 0),
            all(runs$rds_bytes > 0), all(runs$process_peak_bytes > 0),
            sum(is.na(comparison$fit_seconds_previous)) == 10L)
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
