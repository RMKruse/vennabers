# Standalone environment checks; never part of timed benchmarks or CRAN tests.
local({
  args <- commandArgs(TRUE)
  stopifnot(length(args) == 1L)
  artifact <- normalizePath(args, mustWork = TRUE)
  work <- tempfile("optional-dependencies-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  lib <- file.path(work, "library")
  dir.create(lib)
  run <- function(command, arguments, label) {
    log <- file.path(work, paste0(label, ".log"))
    status <- system2(command, arguments, stdout = log, stderr = log)
    if (status != 0L) stop(paste(readLines(log), collapse = "\n"))
  }
  r <- file.path(R.home("bin"), "R")
  run(r, c("CMD", "INSTALL", paste0("--library=", shQuote(lib)), shQuote(artifact)), "install-core")
  # Hide site/user libraries from these fresh processes and their children.
  old <- Sys.getenv(c("R_LIBS", "R_LIBS_USER", "R_LIBS_SITE"), unset = NA_character_)
  on.exit(for (key in names(old)) {
    if (is.na(old[[key]])) Sys.unsetenv(key) else do.call(Sys.setenv, setNames(list(old[[key]]), key))
  }, add = TRUE)
  Sys.setenv(R_LIBS = lib, R_LIBS_USER = lib, R_LIBS_SITE = lib)
  script <- file.path(work, "probe.R")
  for (state in c("missing", "old")) {
    if (state == "old") {
      package <- file.path(work, "parsnip")
      dir.create(package)
      writeLines(c("Package: parsnip", "Version: 0.0.1", "Title: Dependency Error Probe",
        "Description: An intentionally old namespace for dependency error checks.",
        "Author: Test", "Maintainer: Test <test@example.org>", "License: MIT"), file.path(package, "DESCRIPTION"))
      writeLines(character(), file.path(package, "NAMESPACE"))
      run(r, c("CMD", "INSTALL", paste0("--library=", shQuote(lib)), shQuote(package)), "install-old")
    }
    writeLines(c(
      'stopifnot(!"parsnip" %in% loadedNamespaces())',
      'loadNamespace("vennabers")',
      'stopifnot(!"parsnip" %in% loadedNamespaces())',
      'stopifnot(nrow(predict(vennabers::venn_abers(c(FALSE, TRUE), c(.1, .9)), .5)) == 1L)',
      'error <- tryCatch(vennabers::calibrated_workflow(NULL, "truth"), error = identity)',
      'stopifnot(inherits(error, "error"), grepl("parsnip", conditionMessage(error)), grepl("1.6.0", conditionMessage(error)), grepl("install or update it explicitly", conditionMessage(error)))',
      'error <- tryCatch(vennabers::calibrate_workflow(NULL, data.frame(), "truth"), error = identity)',
      'stopifnot(inherits(error, "error"), grepl("parsnip", conditionMessage(error)), grepl("1.6.0", conditionMessage(error)))'
    ), script)
    run(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)), state)
    cat(state, "optional dependency: clear error; manual core works.\n")
  }
})
