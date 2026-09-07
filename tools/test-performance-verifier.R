# Exercise the verifier against a completed bundle without changing its evidence:
# Rscript tools/test-performance-verifier.R OUTPUT
local({
  args <- commandArgs(TRUE)
  stopifnot(length(args) == 1L)
  work <- tempfile("benchmark-verifier-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  files <- list.files(args, pattern = "(\\.csv|-input\\.rds)$", full.names = TRUE)
  stopifnot(all(file.copy(files, work)))
  names <- c("plan", "runs", "medians", "comparison")
  original <- setNames(lapply(names, function(name) {
    read.csv(file.path(work, paste0(name, ".csv")))
  }), names)
  check <- function(bundle, valid, label, flags = character()) {
    for (name in names) write.csv(bundle[[name]], file.path(work, paste0(name, ".csv")), row.names = FALSE)
    log <- file.path(work, "verifier.log")
    status <- system2(file.path(R.home("bin"), "Rscript"),
      c("--vanilla", "tools/test-performance.R", shQuote(work), flags), stdout = log, stderr = log)
    passed <- any(readLines(log) == "Benchmark bundle checks passed.")
    if ((status == 0L) != valid || passed != valid) {
      cat(readLines(log), sep = "\n")
      stop("Unexpected verifier result: ", label)
    }
  }
  check(original, TRUE, "original bundle")
  # Plan configuration must describe the saved input, including unused options.
  metadata <- list(calibration = 1L, prediction = 1L, classes = 999L, folds = 999L,
                   method = "ovo", loss = "wrong-loss", precision = 999, m = 999, epsilon = 0.9)
  for (id in original$plan$case) {
    row <- match(id, original$plan$case)
    for (column in intersect(names(metadata), names(original$plan))) {
      bad <- original
      value <- metadata[[column]]
      if (column == "method" && original$plan$method[row] == value) value <- "ovr"
      bad$plan[[column]][row] <- value
      check(bad, FALSE, paste("plan/input mismatch", id, column))
      if (column %in% c("method", "m", "epsilon") && !is.na(original$plan[[column]][row])) {
        bad$plan[[column]][row] <- NA
        check(bad, FALSE, paste("missing plan metadata", id, column))
      }
    }
  }
  bad <- original
  bad$medians$case <- "wrong-case"
  check(bad, FALSE, "wrong summary case")

  # Check every reported metric, including plausible but incorrect positive values.
  for (table in c("medians", "comparison")) {
    for (column in names(original[[table]])) {
      if (!is.numeric(original[[table]][[column]])) next
      for (value in c(-999, NA_real_, Inf, 123456789)) {
        bad <- original
        row <- which(!is.na(bad[[table]][[column]]))[1L]
        bad[[table]][[column]][row] <- value
        check(bad, FALSE, paste(table, column, value))
      }
    }
  }
  for (table in c("runs", "medians", "comparison")) {
    for (column in intersect(c("case", "release", "iteration", "status"), names(original[[table]]))) {
      bad <- original
      bad[[table]][[column]][1L] <- if (column == "iteration") 99L else "wrong-identity"
      check(bad, FALSE, paste(table, column))
    }
    bad <- original
    bad[[table]][1L, ] <- bad[[table]][2L, ]
    check(bad, FALSE, paste(table, "duplicate replacing a missing identity"))
    bad <- original
    bad[[table]] <- bad[[table]][-1L, ]
    check(bad, FALSE, paste(table, "missing row"))
  }
  # A duplicate case/release must fail even when every iteration count is intact.
  bad <- original
  current <- which(bad$runs$release == "current")
  bad$runs$case[current[1:4]] <- bad$runs$case[current[5L]]
  check(bad, FALSE, "balanced duplicate runs")
  bad <- original
  bad$plan$previous_supported <- rev(bad$plan$previous_supported)
  check(bad, FALSE, "predecessor support differs from plan")
  for (metric in c("fit_seconds", "predict_seconds", "rds_bytes", "process_peak_bytes")) {
    bad <- original
    bad$runs[[metric]][bad$runs$iteration > 0L] <- bad$runs[[metric]][bad$runs$iteration > 0L] + 1
    check(bad, FALSE, paste("stale summary", metric))
    bad <- original
    bad$runs[[metric]][1L] <- Inf
    check(bad, FALSE, paste("nonfinite run", metric))
  }
  # Warmup values and CSV row order must not affect the result.
  good <- original
  good$runs$fit_seconds[good$runs$iteration == 0L] <- 999
  for (table in names) good[[table]] <- good[[table]][rev(seq_len(nrow(good[[table]]))), ]
  check(good, TRUE, "warmups excluded and rows reordered")

  # Known timings distinguish a median from a mean or a warmup-inclusive median.
  good <- original
  id <- good$plan$case[good$plan$previous_supported][1L]
  selected <- good$runs$case == id
  good$runs$fit_seconds[selected] <- c(999, 2, 9, 4)[good$runs$iteration[selected] + 1L]
  good$medians$fit_seconds[good$medians$case == id] <- 4
  selected <- good$comparison$case == id
  good$comparison$fit_seconds_current[selected] <- 4
  good$comparison$fit_seconds_previous[selected] <- 4
  good$comparison$fit_seconds_ratio[selected] <- 1
  check(good, TRUE, "known median")
  good$runs$fit_seconds[good$runs$case == id & good$runs$release == "previous"] <- 0
  good$medians$fit_seconds[good$medians$case == id & good$medians$release == "previous"] <- 0
  good$comparison$fit_seconds_previous[selected] <- 0
  good$comparison$fit_seconds_ratio[selected] <- NA_real_
  check(good, TRUE, "zero predecessor timing has no ratio")
  good$comparison$fit_seconds_ratio[selected] <- Inf
  check(good, FALSE, "zero denominator must not yield infinity")

  # Expected coverage follows the plan, including a bundle with no predecessor cases.
  good <- original
  id <- good$plan$case[!good$plan$previous_supported][1L]
  for (table in names) good[[table]] <- good[[table]][good[[table]]$case != id, ]
  good$plan$previous_supported <- FALSE
  for (table in c("runs", "medians")) good[[table]] <- good[[table]][good[[table]]$release == "current", ]
  for (column in grep("_(previous|ratio)$", names(good$comparison), value = TRUE)) good$comparison[[column]] <- NA_real_
  good$comparison$status <- "new capability baseline"
  check(good, TRUE, "plan-derived coverage without predecessors")
  for (column in grep("_(previous|ratio)$", names(good$comparison), value = TRUE)) {
    bad <- good
    bad$comparison[[column]][1L] <- 1
    check(bad, FALSE, paste("unsupported comparison", column))
  }
  if (any(original$plan$method == "regression")) {
    check(original, TRUE, "complete v0.4 coverage", "--v04")
    for (column in c("method", "m", "epsilon")) {
      bad <- original
      bad$plan[[column]][bad$plan$case == "regression_cross_epsilon01"] <- metadata[[column]]
      check(bad, FALSE, paste("v0.4 plan/input mismatch", column), "--v04")
    }
    bad <- original
    id <- "regression_cross_epsilon01"
    for (table in names) bad[[table]] <- bad[[table]][bad[[table]]$case != id, ]
    check(bad, FALSE, "coherently missing regression case", "--v04")
    path <- file.path(work, paste0(id, "-input.rds"))
    input <- readRDS(path)
    for (fault in c("moderation", "fold", "new_row", "newdata")) {
      broken <- input
      if (fault == "moderation") broken$moderation <- list(epsilon = 0.0001)
      if (fault == "fold") broken$fold[1L] <- "extra-fold"
      if (fault == "new_row") broken$new_row <- rev(broken$new_row)
      if (fault == "newdata") colnames(broken$newdata) <- NULL
      saveRDS(broken, path, version = 3)
      bad <- original
      bad$plan$input_md5[bad$plan$case == id] <- unname(tools::md5sum(path))
      check(bad, FALSE, paste("invalid regression", fault), "--v04")
    }
  }
  cat("Benchmark verifier regression checks passed.\n")
})
