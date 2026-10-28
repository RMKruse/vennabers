# Part new of the performance comparison: the nine performance cases of 1.1
# (RELEASE-ROADMAP-1.x.md §4). Normally started by performance-comparison.R;
# a direct run, for example of single cases, takes the same libraries:
#   Rscript --vanilla tools/benchmark-v11.R [--quick] [--cases ivap-1e6,...] \
#     <previous-lib> <candidate-lib> <deps-lib> <dir>
# This parent process writes one input RDS per case with fixed seeds and
# plan.csv (rows, knots, SHA-256), outside every measured window. It then
# measures each case in a fresh process per library, previous before
# candidate, under /usr/bin/time. A process makes a warm-up and three
# measured runs (one under --quick); only the fit, or only predict(), is
# inside the measured window. Results go to measurements.csv in the long form
# of the comparison, failed cases to failed-cases.txt.
#
# Generators and seeds come from research/kernleistung/bench/kernels.R (fit
# cases, seed 1001) and research/cvar-mittelung/bench/predict.R (CVAR
# prediction, seed 1801); fold assignments follow the scores in the same
# random stream.

v11_calibration_rows <- 1e4

# Case sizes: --quick divides the rows by 100; the CVAR prediction keeps its
# model with 1e4 calibration rows.
v11_sizes <- function(cases, quick) {
  cases$rows <- if (quick) cases$rows / 100 else cases$rows
  cases$calibration_rows <- ifelse(cases$method == "cvar_predict", v11_calibration_rows, cases$rows)
  cases
}

v11_input <- function(method, rows, calibration_rows) {
  n <- calibration_rows
  if (method == "cvar_predict") {
    set.seed(1801L)
    truth <- stats::rnorm(n)
    score <- truth + stats::rnorm(n)
    fold <- sample(rep_len(1:5, n))
    new <- matrix(stats::rnorm(rows * 5, sd = sqrt(2)), ncol = 5L, dimnames = list(NULL, as.character(1:5)))
    return(list(truth = truth, score = score, fold = fold, new = new))
  }
  set.seed(1001L)
  if (method %in% c("ivap", "ivap_ties", "cvap")) {
    truth <- stats::runif(n) < 0.5
    score <- stats::plogis(ifelse(truth, 1, -1) + stats::rnorm(n))
    if (method == "ivap_ties") score <- round(score, 3)
  } else {
    truth <- stats::rnorm(n)
    score <- truth + stats::rnorm(n)
  }
  input <- list(truth = truth, score = score)
  if (method %in% c("cvap", "cvar")) input$fold <- sample(rep_len(1:5, n))
  input
}

# Knots of the input; a continuous case must have one distinct score per row.
v11_knots <- function(case, method, score) {
  knots <- length(unique(score))
  if (method != "ivap_ties" && knots != length(score)) {
    stop("Case ", case, ": ", knots, " distinct scores, expected ", length(score), ".", call. = FALSE)
  }
  knots
}

# Writes inputs/<case>.rds and plan.csv; returns the plan.
v11_write_plan <- function(cases, dir) {
  inputs <- file.path(dir, "inputs")
  dir.create(inputs, showWarnings = FALSE)
  plan <- lapply(seq_len(nrow(cases)), function(i) {
    case <- cases[i, ]
    input <- v11_input(case$method, case$rows, case$calibration_rows)
    knots <- v11_knots(case$case, case$method, input$score)
    path <- file.path(inputs, paste0(case$case, ".rds"))
    saveRDS(input, path, version = 3L, compress = FALSE)
    rm(input)
    invisible(gc())
    data.frame(case = case$case, rows = as.integer(case$rows), knots = knots, sha256 = unname(tools::sha256sum(path)))
  })
  plan <- do.call(rbind, plan)
  utils::write.csv(plan, file.path(dir, "plan.csv"), row.names = FALSE)
  plan
}

# One measuring process: warm-up plus `reps` runs, in long form without case
# and library. Heap is the gc() "max used" peak since the reset, in bytes.
v11_measure <- function(method, input, reps) {
  heap <- function() {
    g <- gc()
    round(sum(g[, ncol(g)]) * 1048576)
  }
  if (method == "cvar_predict") {
    model <- vennabers::cross_venn_abers_regression(input$truth, input$score, input$fold, m = 1)
    once <- function() {
      invisible(gc(reset = TRUE))
      seconds <- system.time(prediction <- stats::predict(model, input$new))[["elapsed"]]
      heap_bytes <- heap()
      stopifnot(nrow(prediction) == nrow(input$new))
      rm(prediction)
      invisible(gc())
      c(predict_seconds = seconds, predict_heap_bytes = heap_bytes)
    }
  } else {
    fit <- switch(method,
      ivap = , ivap_ties = function() vennabers::venn_abers(input$truth, input$score),
      cvap = function() vennabers::cross_venn_abers(input$truth, input$score, input$fold),
      ivar = function() vennabers::venn_abers_regression(input$truth, input$score),
      cvar = function() vennabers::cross_venn_abers_regression(input$truth, input$score, input$fold))
    once <- function() {
      invisible(gc(reset = TRUE))
      seconds <- system.time(fitted <- fit())[["elapsed"]]
      heap_bytes <- heap()
      path <- tempfile(fileext = ".rds")
      saveRDS(fitted, path, version = 3L)
      bytes <- file.size(path)
      unlink(path)
      rm(fitted)
      invisible(gc())
      c(fit_seconds = seconds, fit_heap_bytes = heap_bytes, rds_bytes = bytes)
    }
  }
  invisible(once())
  runs <- lapply(seq_len(reps), function(i) once())
  data.frame(run = rep(seq_len(reps), each = length(runs[[1L]])), metric = unlist(lapply(runs, names)),
             value = unlist(runs, use.names = FALSE),
             unit = ifelse(grepl("_seconds$", unlist(lapply(runs, names))), "seconds", "bytes"))
}

v11_usage <- paste("Usage: Rscript --vanilla tools/benchmark-v11.R [--quick] [--cases a,b]",
                   "<previous-lib> <candidate-lib> <deps-lib> <dir>")

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
  if (length(args) == 7L && args[[1L]] == "measure") {
    # Measuring process: <method> <input.rds> <sha256> <lib> <reps> <rows.csv>
    method <- args[[2L]]
    lib <- normalizePath(args[[5L]])
    loaded <- normalizePath(dirname(find.package("vennabers")))
    if (!identical(loaded, lib)) stop("vennabers loaded from ", loaded, ", not ", lib, call. = FALSE)
    if (!identical(unname(tools::sha256sum(args[[3L]])), args[[4L]])) stop("Input ", args[[3L]], " changed.", call. = FALSE)
    input <- readRDS(args[[3L]])
    suppressPackageStartupMessages(loadNamespace("vennabers"))
    rows <- v11_measure(method, input, as.integer(args[[6L]]))
    utils::write.csv(rows, args[[7L]], row.names = FALSE)
  } else {
    source(file.path(dirname(script), "performance-comparison.R"))
    quick <- "--quick" %in% args
    args <- args[args != "--quick"]
    cases <- pc_new_cases
    at <- which(args == "--cases")
    if (length(at)) {
      if (at == length(args)) stop(v11_usage, call. = FALSE)
      chosen <- strsplit(args[[at + 1L]], ",", fixed = TRUE)[[1L]]
      unknown <- setdiff(chosen, cases$case)
      if (length(unknown)) stop("Unknown case(s): ", paste(unknown, collapse = ", "), call. = FALSE)
      cases <- cases[cases$case %in% chosen, ]
      args <- args[-c(at, at + 1L)]
    }
    if (length(args) != 4L || any(startsWith(args, "--"))) stop(v11_usage, call. = FALSE)
    libs <- c(previous = normalizePath(args[[1L]]), candidate = normalizePath(args[[2L]]))
    deps <- normalizePath(args[[3L]])
    dir <- args[[4L]]
    if (dir.exists(dir) && length(list.files(dir, all.files = TRUE, no.. = TRUE, pattern = "^(inputs|runs|plan.csv|measurements.csv)$"))) {
      stop(dir, " already holds a part new run; use an empty directory.", call. = FALSE)
    }
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    dir <- normalizePath(dir)
    cases <- v11_sizes(cases, quick)
    plan <- v11_write_plan(cases, dir)
    reps <- if (quick) 1L else 3L
    runs <- file.path(dir, "runs")
    dir.create(runs)
    rscript <- file.path(R.home("bin"), "Rscript")
    long <- data.frame(case = character(), library = character(), run = integer(), metric = character(),
                       value = numeric(), unit = character())
    failed <- character()
    for (i in seq_len(nrow(cases))) {
      case <- cases[i, ]
      planned <- plan[plan$case == case$case, ]
      for (library in names(libs)) {
        label <- file.path(runs, paste0(case$case, "-", library))
        rows_file <- paste0(label, ".csv")
        env <- c(paste0("R_LIBS=", shQuote(paste(libs[[library]], deps, sep = .Platform$path.sep))),
                 paste0(names(pc_thread_env), "=", pc_thread_env))
        message(format(Sys.time(), "%H:%M:%S"), " ", case$case, " ", library)
        status <- pc_timed(rscript, c("--vanilla", shQuote(script), "measure", case$method,
                                      shQuote(file.path(dir, "inputs", paste0(case$case, ".rds"))), planned$sha256,
                                      shQuote(libs[[library]]), reps, shQuote(rows_file)),
                           paste0(label, ".time"), paste0(label, ".log"), env = env)
        peak <- if (file.exists(paste0(label, ".time"))) pc_parse_time(readLines(paste0(label, ".time"))) else NA_real_
        if (status != 0L || is.na(peak) || !file.exists(rows_file)) {
          message("FAILED ", case$case, " ", library, " (exit ", status, "); see ", label, ".log")
          failed <- union(failed, case$case)
          next
        }
        rows <- utils::read.csv(rows_file)
        long <- rbind(long, data.frame(case = case$case, library = library, rows),
                      data.frame(case = case$case, library = library, run = NA_integer_, metric = "process_peak_bytes",
                                 value = peak, unit = "bytes"))
        utils::write.csv(long, file.path(dir, "measurements.csv"), row.names = FALSE, na = "")
      }
    }
    utils::write.csv(long, file.path(dir, "measurements.csv"), row.names = FALSE, na = "")
    writeLines(failed, file.path(dir, "failed-cases.txt"))
    if (length(failed)) quit(status = 1L)
  }
}
