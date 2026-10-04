# Run from any directory: Rscript --vanilla tools/verify.R [processes=4] [tarball]
order_tests <- function(files, timings) {
  seconds <- timings$seconds[match(files, timings$file)]
  seconds[is.na(seconds)] <- max(c(0, timings$seconds))
  files[order(-seconds, files)]
}

run_test <- function(file, test_dir, output) {
  cat("START", file, "pid", Sys.getpid(), "\n")
  log <- file.path(output, paste0(file, ".log"))
  connection <- file(log, "wt")
  sink(connection)
  sink(connection, type = "message")
  started <- proc.time()[["elapsed"]]
  result <- tryCatch({
    tests <- as.data.frame(testthat::test_file(
      file.path(test_dir, file), package = "vennabers", load_package = "installed",
      reporter = "summary", stop_on_failure = FALSE, stop_on_warning = FALSE
    ))
    data.frame(file = file, seconds = proc.time()[["elapsed"]] - started,
      passed = sum(tests$passed), failed = sum(tests$failed),
      errors = sum(tests$error), warnings = sum(tests$warning),
      skipped = sum(tests$skipped), blocks = nrow(tests))
  }, error = function(error) {
    cat(conditionMessage(error), "\n")
    data.frame(file = file, seconds = proc.time()[["elapsed"]] - started,
      passed = 0L, failed = 0L, errors = 1L, warnings = 0L,
      skipped = 0L, blocks = 0L)
  }, finally = { sink(type = "message"); sink(); close(connection) })
  write.csv(result, file.path(output, paste0(file, ".csv")), row.names = FALSE)
  cat("DONE", file, sprintf("%.1fs", result$seconds), "\n", file = stdout())
  result
}

verify <- function(root, processes = 4L, tarball = NULL) {
  if (length(processes) != 1L || is.na(processes) || processes < 1L) {
    stop("Processes must be a positive integer.")
  }
  output <- tempfile("vennabers-verify-", tmpdir = Sys.getenv("TMPDIR", "/tmp"))
  dir.create(output)
  cat("Verification evidence:", output, "\n")
  library <- file.path(output, "lib")
  dir.create(library)
  # Subprocess tests and their two future workers inherit these limits and paths.
  Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
    MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1",
    NOT_CRAN = "true",
    R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  description <- read.dcf(file.path(root, "DESCRIPTION"))
  packages <- trimws(sub(" *[(].*", "", strsplit(description[1, "Suggests"], ",")[[1]]))
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing test dependencies: ", paste(missing, collapse = ", "))
  install_log <- file.path(output, "install.log")
  install_source <- if (is.null(tarball)) root else normalizePath(tarball)
  if (!is.null(tarball)) cat("Source archive SHA-256:", tools::sha256sum(install_source), "\n")
  status <- system2(file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--install-tests", paste0("--library=", shQuote(library)), shQuote(install_source)),
    stdout = install_log, stderr = install_log)
  if (status != 0L) stop("Package installation failed; see ", install_log)
  .libPaths(c(library, .libPaths()))
  Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  test_dir <- file.path(library, "vennabers", "tests", "testthat")
  files <- list.files(test_dir, "^test-.*[.]R$")
  if (!length(files)) stop("No installed tests found.")
  timing_file <- file.path(root, "tools", "test-durations.csv")
  timings <- read.csv(timing_file)
  stopifnot(!anyDuplicated(timings$file), all(is.finite(timings$seconds)), all(timings$seconds >= 0))
  files <- order_tests(files, timings)
  cat(length(files), "files;", processes, "processes; longest recorded durations first\n")
  started <- proc.time()[["elapsed"]]
  cluster <- parallel::makePSOCKcluster(processes, outfile = "")
  on.exit(parallel::stopCluster(cluster), add = TRUE)
  parallel::clusterCall(cluster, function(paths) {
    .libPaths(paths)
    stopifnot(normalizePath(find.package("vennabers")) == normalizePath(file.path(paths[1L], "vennabers")))
  }, .libPaths())
  # One file per dispatch lets a free process take the next longest file.
  results <- parallel::parLapplyLB(cluster, files, run_test,
    test_dir = test_dir, output = output, chunk.size = 1L)
  results <- do.call(rbind, results)
  stopifnot(identical(results$file, files), !anyDuplicated(results$file))
  write.csv(results, file.path(output, "results.csv"), row.names = FALSE)
  elapsed <- proc.time()[["elapsed"]] - started
  cat(sprintf("Test wall time: %.1fs (%.2f minutes)\n", elapsed, elapsed / 60))
  print(colSums(results[c("passed", "failed", "errors", "warnings", "skipped", "blocks")]))
  bad <- with(results, failed > 0 | errors > 0 | warnings > 0 | skipped > 0 | blocks == 0)
  if (any(bad)) {
    print(results[bad, ], row.names = FALSE)
    stop("Verification failed; see logs in ", output)
  }
  write.csv(results[c("file", "seconds")], timing_file, row.names = FALSE)
  cat("PASS; refreshed", timing_file, "\n")
  invisible(results)
}

if (sys.nframe() == 0L) {
  script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
  root <- dirname(dirname(normalizePath(script)))
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 2L || (length(args) && !grepl("^[1-9][0-9]*$", args[1]))) {
    stop("Usage: Rscript --vanilla tools/verify.R [processes=4] [tarball]")
  }
  verify(root, if (length(args)) as.integer(args[1]) else 4L,
    if (length(args) == 2L) args[2] else NULL)
}
