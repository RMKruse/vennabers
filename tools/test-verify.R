# Small runnable check: Rscript --vanilla tools/test-verify.R
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
source(file.path(dirname(normalizePath(script)), "verify.R"))
timings <- data.frame(file = c("short", "long", "medium"), seconds = c(1, 3, 2))
stopifnot(identical(order_tests(c("short", "medium", "long"), timings), c("long", "medium", "short")))
stopifnot(identical(order_tests(c("short", "new"), timings), c("new", "short")))
output <- tempfile("verify-check-")
dir.create(output)
cases <- c(pass = "testthat::expect_true(TRUE)", fail = "testthat::expect_true(FALSE)",
  warning = "warning('check'); testthat::expect_true(TRUE)",
  skip = "testthat::skip('check')", error = "stop('check')")
for (case in names(cases)) {
  file <- paste0("test-", case, ".R")
  writeLines(sprintf("testthat::test_that('runner check', { %s })", cases[[case]]), file.path(output, file))
  result <- run_test(file, output, output)
  field <- c(pass = "passed", fail = "failed", warning = "warnings", skip = "skipped", error = "errors")[[case]]
  stopifnot(result[[field]] == 1L)
}
result <- run_test("test-missing.R", output, output)
stopifnot(result$errors == 1L, result$blocks == 0L)
unlink(output, recursive = TRUE)
cat("Verification runner checks passed.\n")
