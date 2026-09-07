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
  Sys.unsetenv("ACCEPTANCE_OUTPUT_DIR")

  # Each new file must be discovered automatically and fail the whole command.
  for (directory in c("examples", "tests")) {
    sentinel <- file.path(directory, "intentional-failure.R")
    writeLines('stop("intentional acceptance regression failure")', sentinel)
    output_file <- file.path(work, paste0(directory, ".log"))
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
