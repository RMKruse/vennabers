# Rscript --vanilla tools/ci-environment.R OUTPUT_DIR
# Records the R session and every installed package version of one CI run.
record_environment <- function(output) {
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  packages <- utils::installed.packages(fields = "Built")
  packages <- packages[, c("Package", "Version", "LibPath", "Priority", "Built"), drop = FALSE]
  packages <- packages[order(packages[, "Package"], packages[, "LibPath"]), , drop = FALSE]
  utils::write.csv(packages, file.path(output, "packages.csv"), row.names = FALSE)
  system <- Sys.info()[c("sysname", "release", "version", "machine")]
  pandoc <- Sys.which("pandoc")
  pandoc <- if (nzchar(pandoc)) system2(pandoc, "--version", stdout = TRUE)[1] else "pandoc: not found"
  session <- c(capture.output(print(utils::sessionInfo())), "",
    paste(names(system), system, sep = ": "), "",
    capture.output(print(extSoftVersion())), "", pandoc)
  writeLines(session, file.path(output, "session-info.txt"))
  invisible(output)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript --vanilla tools/ci-environment.R OUTPUT_DIR")
  record_environment(args[1])
}
