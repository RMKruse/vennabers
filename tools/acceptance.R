# Run from the package root with `Rscript tools/acceptance.R`.
if (!file.exists("DESCRIPTION")) {
  stop("Run this gate from the package root.", call. = FALSE)
}

local({
  root <- normalizePath(".")
  description <- read.dcf("DESCRIPTION", fields = c("Package", "Version"))[1L, ]
  work_dir <- tempfile("vennabers-acceptance-")
  dir.create(work_dir)
  on.exit({
    setwd(root)
    unlink(work_dir, recursive = TRUE)
  }, add = TRUE)

  run <- function(command, arguments) {
    output_file <- tempfile(tmpdir = work_dir)
    on.exit(unlink(output_file), add = TRUE)
    status <- system2(command, arguments, stdout = output_file, stderr = output_file)
    output <- readLines(output_file, warn = FALSE)
    cat(output, sep = "\n")
    if (!identical(status, 0L)) {
      stop(command, " failed with status ", status, ".", call. = FALSE)
    }
    if (any(grepl("\\b(ERROR|WARNING|NOTE)\\b", output))) {
      stop("Build/check/install reported an error, warning, or note.", call. = FALSE)
    }
  }

  cat("Acceptance environment:", R.version.string, "on", R.version$platform, "\n")
  print(Sys.info()[c("sysname", "release", "machine")])
  print(sessionInfo())
  setwd(work_dir)
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
  # Load only the package just installed from the source artifact. Refuse a
  # previously loaded namespace rather than accidentally testing another build.
  stopifnot(!"vennabers" %in% loadedNamespaces())
  original_libraries <- .libPaths()
  on.exit(.libPaths(original_libraries), add = TRUE)
  .libPaths(c(library_dir, .Library))
  library(vennabers, lib.loc = library_dir)
  installed_path <- normalizePath(file.path(library_dir, description[["Package"]]))
  stopifnot(
    identical(normalizePath(find.package("vennabers")), installed_path),
    identical(normalizePath(getNamespaceInfo("vennabers", "path")), installed_path),
    identical(as.character(packageVersion("vennabers")), description[["Version"]])
  )
  cat("Verified installed artifact:", installed_path, "version",
      as.character(packageVersion("vennabers")), "\n")

  # R 4.1 does not install README.md; read it from the checked source artifact.
  readme_path <- file.path(description[["Package"]], "README.md")
  utils::untar(artifact, files = readme_path, exdir = work_dir)
  # Execute its R fences in order, sharing their environment.
  # Shell fences describe installation and gate commands; those run above.
  local({
    plot_file <- tempfile(fileext = ".pdf")
    on.exit(unlink(plot_file), add = TRUE)
    grDevices::pdf(plot_file)
    on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)
    readme <- readLines(file.path(work_dir, readme_path))
    starts <- grep("^```r[[:space:]]*$", readme)
    ends <- grep("^```[[:space:]]*$", readme)
    stopifnot(length(starts) > 0L)
    example_environment <- new.env()
    for (start in starts) {
      end <- ends[ends > start][1L]
      stopifnot(!is.na(end), end > start + 1L)
      eval(parse(text = readme[seq.int(start + 1L, end - 1L)]), example_environment)
    }
    cat("README R snippets passed:", length(starts), "\n")
  })

  # This checkout script is not run by R CMD check. Its assertions exercise the
  # installed API; its temporary graphics device is closed and removed on exit.
  cat("Running canonical three-fold GLM example.\n")
  sys.source(file.path(root, "examples", "cross-venn-abers.R"), envir = new.env())
  cat("Canonical example passed.\n")

  # Preserve the separate IVAP performance step and its existing threshold.
  cat("Running separate IVAP performance gate.\n")
  sys.source(file.path(root, "tools", "performance.R"), envir = new.env())
  cat("Acceptance gate passed.\n")
})
