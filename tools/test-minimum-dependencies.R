# Small runnable check: Rscript --vanilla tools/test-minimum-dependencies.R
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
source(file.path(dirname(normalizePath(script)), "minimum-dependencies.R"))

description <- tempfile("DESCRIPTION-")
writeLines(c(
  "Package: example",
  "Version: 1.0.0",
  "Suggests:",
  "    knitr,",
  "    parsnip (>= 1.6.0),",
  "    tibble(>=3.3.1),",
  "    testthat (>= 3.0.0)"
), description)
suggests <- suggested_packages(description)
stopifnot(identical(suggests$package, c("knitr", "parsnip", "tibble", "testthat")))
stopifnot(identical(suggests$minimum, c(NA, "1.6.0", "3.3.1", "3.0.0")))

# testthat runs the checks; it is no integration package and stays unpinned.
# Documented transitive pins follow the declared minimums.
transitive <- data.frame(package = "furrr", minimum = "0.3.1")
stopifnot(identical(minimum_refs(suggests, transitive),
  c("knitr", "parsnip@1.6.0", "tibble@3.3.1", "testthat", "furrr@0.3.1")))
pins <- pinned_minimums(suggests)
stopifnot(identical(pins$package, c("parsnip", "tibble")))
stopifnot(identical(pinned_minimums(suggests, transitive)$package, c("parsnip", "tibble", "furrr")))

installed <- c(parsnip = "1.6.0", tibble = "3.3.2")
mismatches <- version_mismatches(pins, installed)
stopifnot(identical(mismatches$package, "tibble"), identical(mismatches$installed, "3.3.2"))
mismatches <- version_mismatches(pins, c(tibble = "3.3.1"))
stopifnot(identical(mismatches$package, "parsnip"), is.na(mismatches$installed))
stopifnot(nrow(version_mismatches(pins, c(parsnip = "1.6.0", tibble = "3.3.1"))) == 0L)
# R normalises "1.0-1" to "1.0.1"; both name the same version.
hyphenated <- data.frame(package = "ipred", minimum = "0.9-12")
stopifnot(nrow(version_mismatches(hyphenated, c(ipred = "0.9.12"))) == 0L)

writeLines(c("Package: example", "Suggests: parsnip (== 1.6.0)"), description)
failed <- tryCatch({ suggested_packages(description); FALSE }, error = function(e) TRUE)
stopifnot(failed)
unlink(description)
cat("Minimum dependency checks passed.\n")
