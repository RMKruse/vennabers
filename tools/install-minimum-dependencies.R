# Environment setup only: network is never used by package tests/examples.
# Rscript tools/install-minimum-dependencies.R EMPTY_LIBRARY
local({
  args <- commandArgs(TRUE)
  stopifnot(length(args) == 1L)
  dir.create(args, recursive = TRUE, showWarnings = FALSE)
  lib <- normalizePath(args, mustWork = TRUE)
  .libPaths(c(lib, .libPaths()))
  pins <- read.csv("tools/minimum-dependencies.csv", stringsAsFactors = FALSE)
  remaining <- pins$Package
  work <- tempfile("minimum-sources-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  while (length(remaining)) {
    ready <- remaining[vapply(remaining, function(p) {
      !any(strsplit(pins$Dependencies[pins$Package == p], ";", fixed = TRUE)[[1L]] %in% remaining)
    }, FALSE)]
    if (!length(ready)) stop("Cyclic or incomplete minimum dependency manifest.")
    for (package in ready) {
      version <- pins$Version[pins$Package == package]
      filename <- paste0(package, "_", version, ".tar.gz")
      dest <- file.path(work, filename)
      urls <- paste0("https://cran.r-project.org/src/contrib/",
                     c("", paste0("Archive/", package, "/")), filename)
      downloaded <- FALSE
      for (url in urls) {
        status <- tryCatch(suppressWarnings(utils::download.file(url, dest, mode = "wb")), error = function(e) 1L)
        if (status == 0L) { downloaded <- TRUE; break }
      }
      if (!downloaded) stop("Cannot download pinned source: ", filename)
      cat(filename, unname(tools::md5sum(dest)), "\n")
      utils::install.packages(dest, lib = lib, repos = NULL, type = "source")
      stopifnot(as.character(utils::packageVersion(package, lib.loc = lib)) == version)
    }
    remaining <- setdiff(remaining, ready)
  }
  cat("Pinned dependency installation passed.\n")
})
