# Run from any directory: Rscript --vanilla tools/coverage.R [processes=4] [output]
# Measures line coverage of the complete test suite (NOT_CRAN=true) with covr.
# The test files run in parallel like tools/verify.R; covr merges the traces
# of every process that loads the instrumented package, including the future
# workers of the process tests. Writes cobertura.xml (for Codecov) and
# coverage.csv (one row per R file) to the output directory.
coverage_table <- function(coverage) {
  summary <- covr::coverage_to_list(coverage)
  files <- data.frame(file = names(summary$filecoverage),
    percent = round(unname(summary$filecoverage), 2))
  files[order(files$percent, files$file), ]
}

# Runs inside the covr subprocess, where the instrumented package comes first
# on the library path.
coverage_tests <- function(root, processes, output) {
  source(file.path(root, "tools", "verify.R"))
  Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
    MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1",
    NOT_CRAN = "true",
    R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  test_dir <- file.path(find.package("vennabers"), "tests", "testthat")
  files <- order_tests(list.files(test_dir, "^test-.*[.]R$"),
    read.csv(file.path(root, "tools", "test-durations.csv")))
  if (!length(files)) stop("No installed tests found.")
  cluster <- parallel::makePSOCKcluster(processes, outfile = "")
  parallel::clusterCall(cluster, function(paths) .libPaths(paths), .libPaths())
  results <- parallel::parLapplyLB(cluster, files, run_test,
    test_dir = test_dir, output = output, chunk.size = 1L)
  # Workers write their traces when they exit.
  parallel::stopCluster(cluster)
  results <- do.call(rbind, results)
  write.csv(results, file.path(output, "results.csv"), row.names = FALSE)
  print(colSums(results[c("passed", "failed", "errors", "warnings", "skipped", "blocks")]))
  bad <- with(results, failed > 0 | errors > 0 | blocks == 0)
  if (any(bad)) {
    print(results[bad, ], row.names = FALSE)
    stop("Tests failed under coverage; see logs in ", output)
  }
}

coverage <- function(root, processes = 4L, output = tempfile("vennabers-coverage-")) {
  if (length(processes) != 1L || is.na(processes) || processes < 1L) {
    stop("Processes must be a positive integer.")
  }
  dir.create(output, showWarnings = FALSE, recursive = TRUE)
  output <- normalizePath(output)
  cat("Coverage evidence:", output, "\n")
  code <- sprintf("source(%s); coverage_tests(%s, %dL, %s)",
    deparse(file.path(root, "tools", "coverage.R")), deparse(root), processes, deparse(output))
  started <- proc.time()[["elapsed"]]
  # clean = FALSE keeps the command log under package/ for the CI artifact.
  result <- covr::package_coverage(root, type = "none", code = code, quiet = FALSE,
    clean = FALSE, install_path = file.path(output, "package"))
  elapsed <- proc.time()[["elapsed"]] - started
  cat(sprintf("Coverage wall time: %.1fs (%.2f minutes)\n", elapsed, elapsed / 60))
  covr::to_cobertura(result, file.path(output, "cobertura.xml"))
  files <- coverage_table(result)
  write.csv(files, file.path(output, "coverage.csv"), row.names = FALSE)
  cat(sprintf("Total coverage: %.2f%%\n", covr::percent_coverage(result)))
  low <- files[files$percent < 80, ]
  if (nrow(low)) {
    cat("Files below 80%:\n")
    print(low, row.names = FALSE)
  }
  invisible(result)
}

if (sys.nframe() == 0L) {
  script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
  root <- dirname(dirname(normalizePath(script)))
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 2L || (length(args) && !grepl("^[1-9][0-9]*$", args[1]))) {
    stop("Usage: Rscript --vanilla tools/coverage.R [processes=4] [output]")
  }
  coverage(root, if (length(args)) as.integer(args[1]) else 4L,
    if (length(args) == 2L) args[2] else tempfile("vennabers-coverage-"))
}
