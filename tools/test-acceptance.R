# Regression check for the gate's process exit status; run from the repo root.
local({
  root <- normalizePath(".")
  work <- tempfile("acceptance-regression-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  checkout <- file.path(work, "checkout")
  dir.create(checkout)
  files <- list.files(root, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  files <- files[!grepl("^(\\.git|\\.scratch)$|\\.(tar\\.gz|Rcheck)$", basename(files))]
  stopifnot(all(file.copy(files, checkout, recursive = TRUE)))
  setwd(checkout)
  on.exit(setwd(root), add = TRUE, after = FALSE)
  Sys.unsetenv(c("ACCEPTANCE_OUTPUT_DIR", "ACCEPTANCE_ARTIFACT", "ACCEPTANCE_PROFILE"))

  # Fail before any build when integration coverage would silently be skipped.
  description <- readLines("DESCRIPTION")
  for (requirement in c("parsnip (>= 999.0.0)", "vennabersMissingDependencyProbe")) {
    writeLines(sub("parsnip \\(>= 1.6.0\\)", requirement, description), "DESCRIPTION")
    log <- file.path(work, "dependency-gate.log")
    status <- system2(file.path(R.home("bin"), "Rscript"),
      c("--vanilla", "tools/acceptance.R"), stdout = log, stderr = log)
    stopifnot(status != 0L, any(grepl("integration checks must not skip", readLines(log), fixed = TRUE)))
  }
  writeLines(description, "DESCRIPTION")
  cat("Missing/old integration dependency requirements fail the gate.\n")

  # Each new file must be discovered automatically and fail the whole command.
  for (directory in c("inst/examples", "tests")) {
    sentinel <- file.path(directory, "intentional-failure.R")
    writeLines('stop("intentional acceptance regression failure")', sentinel)
    output_file <- file.path(work, paste0(basename(directory), ".log"))
    status <- system2(file.path(R.home("bin"), "Rscript"),
      c("--vanilla", "tools/acceptance.R"), stdout = output_file, stderr = output_file)
    output <- readLines(output_file, warn = FALSE)
    if (status == 0L || !any(grepl("intentional acceptance regression failure", output)) ||
        any(grepl("Acceptance gate passed.", output, fixed = TRUE))) {
      cat(output, sep = "\n")
      stop("The injected ", directory, " failure did not fail the gate correctly.")
    }
    unlink(sentinel)
    cat("Injected", directory, "failure: gate exited", status, "as required.\n")
  }
})
