# Small runnable check: Rscript --vanilla tools/test-coverage.R
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
source(file.path(dirname(normalizePath(script)), "coverage.R"))
source_code <- "half <- function(x) {\n  if (x > 0) {\n    1\n  } else {\n    2\n  }\n}"
result <- covr::code_coverage(source_code, "half(1)")
files <- coverage_table(result)
stopifnot(nrow(files) == 1L, files$percent > 0, files$percent < 100)
stopifnot(all.equal(files$percent, round(covr::percent_coverage(result), 2)))
failed <- tryCatch({ coverage(tempdir(), 0L); FALSE }, error = function(e) TRUE)
stopifnot(failed)
cat("Coverage helper checks passed.\n")
