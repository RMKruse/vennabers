# Small runnable check: Rscript --vanilla tools/test-ci-environment.R
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
source(file.path(dirname(normalizePath(script)), "ci-environment.R"))
output <- tempfile("ci-environment-")
record_environment(output)
packages <- read.csv(file.path(output, "packages.csv"))
stopifnot(identical(names(packages), c("Package", "Version", "LibPath", "Priority", "Built")))
stopifnot("stats" %in% packages$Package, !anyNA(packages$Version))
stopifnot(identical(packages$Version[packages$Package == "stats"],
  as.character(utils::packageVersion("stats"))))
session <- readLines(file.path(output, "session-info.txt"))
stopifnot(any(grepl(R.version.string, session, fixed = TRUE)), any(grepl("^Platform:", session)))
# Runner host names are not evidence; keep them out of the uploaded record.
stopifnot(!any(grepl(Sys.info()[["nodename"]], session, fixed = TRUE)))
unlink(output, recursive = TRUE)
cat("CI environment record checks passed.\n")
