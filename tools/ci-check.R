# Rscript --vanilla tools/ci-check.R SOURCE_DIR CHECK_DIR [R CMD check arguments]
# Verifies the one source package in SOURCE_DIR against its SHA256SUMS and
# checks it with R CMD check --as-cran plus the given arguments. Warnings fail.
verified_tarball <- function(source) {
  tarball <- list.files(source, "[.]tar[.]gz$", full.names = TRUE)
  if (length(tarball) != 1L) stop("Expected one source package in ", source)
  expected <- paste0(tools::sha256sum(tarball), "  ", basename(tarball))
  if (!identical(readLines(file.path(source, "SHA256SUMS")), expected)) {
    stop("Source package does not match SHA256SUMS: ", basename(tarball))
  }
  normalizePath(tarball)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2L) {
    stop("Usage: Rscript --vanilla tools/ci-check.R SOURCE_DIR CHECK_DIR [R CMD check arguments]")
  }
  rcmdcheck::rcmdcheck(verified_tarball(args[1]), args = c("--as-cran", args[-(1:2)]),
    error_on = "warning", check_dir = args[2])
}
