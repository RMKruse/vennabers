# Run from the package root with `Rscript tools/acceptance.R`.
if (!file.exists("DESCRIPTION")) {
  stop("Run this gate from the package root.", call. = FALSE)
}

root <- normalizePath(".")
description <- read.dcf("DESCRIPTION", fields = c("Package", "Version"))[1L, ]
work_dir <- tempfile("vennabers-acceptance-")
dir.create(work_dir)
on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

run <- function(command, arguments) {
  status <- system2(command, arguments)
  if (!identical(status, 0L)) {
    stop(command, " failed with status ", status, ".", call. = FALSE)
  }
}

cat("Acceptance environment:", R.version.string, "on", R.version$platform, "\n")
original_dir <- setwd(work_dir)
on.exit(setwd(original_dir), add = TRUE)
r_executable <- file.path(R.home("bin"), "R")
run(r_executable, c("CMD", "build", shQuote(root)))

artifact <- file.path(work_dir, paste0(description[["Package"]], "_", description[["Version"]], ".tar.gz"))
run(r_executable, c("CMD", "check", "--no-manual", shQuote(artifact)))
check_log <- readLines(file.path(work_dir, paste0(description[["Package"]], ".Rcheck"), "00check.log"))
if (!identical(tail(grep("^Status:", check_log, value = TRUE), 1L), "Status: OK")) {
  stop("R CMD check did not finish with zero errors, warnings, and notes.", call. = FALSE)
}

library_dir <- file.path(work_dir, "library")
dir.create(library_dir)
run(r_executable, c("CMD", "INSTALL", paste0("--library=", shQuote(library_dir)), shQuote(artifact)))
Sys.setenv(R_LIBS_USER = library_dir)
run(file.path(R.home("bin"), "Rscript"), shQuote(file.path(root, "tools", "performance.R")))
cat("Acceptance gate passed.\n")
