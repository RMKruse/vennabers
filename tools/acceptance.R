# Run from the package root with `Rscript tools/acceptance.R`.
if (!file.exists("DESCRIPTION")) {
  stop("Run this gate from the package root.", call. = FALSE)
}

local({
  root <- normalizePath(".")
  supplied_artifact <- Sys.getenv("ACCEPTANCE_ARTIFACT")
  if (nzchar(supplied_artifact)) supplied_artifact <- normalizePath(supplied_artifact, mustWork = TRUE)
  description <- read.dcf("DESCRIPTION", fields = c("Package", "Version"))[1L, ]
  output_dir <- Sys.getenv("ACCEPTANCE_OUTPUT_DIR")
  work_dir <- if (nzchar(output_dir)) output_dir else tempfile("vennabers-acceptance-")
  if (dir.exists(work_dir) && length(list.files(work_dir, all.files = TRUE, no.. = TRUE))) {
    stop("Acceptance output directory must be empty.", call. = FALSE)
  }
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  work_dir <- normalizePath(work_dir, mustWork = TRUE)
  on.exit({
    setwd(root)
    if (!nzchar(output_dir)) unlink(work_dir, recursive = TRUE)
  }, add = TRUE)

  run <- function(command, arguments) {
    # R copies the tree before applying .Rbuildignore. On Windows an open
    # log inside that tree cannot be copied, even when it will be excluded.
    output_file <- tempfile("acceptance-command-", fileext = ".log")
    on.exit(unlink(output_file), add = TRUE)
    status <- system2(command, arguments, stdout = output_file, stderr = output_file)
    stopifnot(file.copy(output_file, file.path(work_dir, paste0(tolower(arguments[2L]), ".log"))))
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
  environment <- capture.output({
    print(Sys.info())
    print(sessionInfo())
    print(Sys.getenv(c("ImageOS", "ImageVersion", "RUNNER_OS", "RUNNER_ARCH",
                       "GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")))
    print(installed.packages()[, c("Package", "Version", "LibPath"), drop = FALSE])
  })
  writeLines(environment, file.path(work_dir, "environment.txt"))
  expected_arch <- Sys.getenv("EXPECTED_R_ARCH")
  if (nzchar(expected_arch) && !identical(R.version$arch, expected_arch)) {
    stop("Expected R architecture ", expected_arch, "; got ", R.version$arch)
  }
  # CRAN mode without online incoming/repository/clock probes. Tests and examples
  # still run, including those guarded by NOT_CRAN. No dependency downloads.
  Sys.setenv(NOT_CRAN = "false", `_R_CHECK_CRAN_INCOMING_` = "false",
             `_R_CHECK_CRAN_INCOMING_REMOTE_` = "false",
             `_R_CHECK_SYSTEM_CLOCK_` = "false")
  capture.output({
    cat("R CMD check --as-cran --no-manual\nPDF manual and online incoming/clock probes are not checked.\n")
    print(Sys.getenv(c("NOT_CRAN", "_R_CHECK_CRAN_INCOMING_",
                       "_R_CHECK_CRAN_INCOMING_REMOTE_", "_R_CHECK_SYSTEM_CLOCK_")))
    print(Sys.getenv()[grepl("^_R_CHECK_", names(Sys.getenv()))])
  }, file = file.path(work_dir, "check-settings.txt"))
  setwd(work_dir)
  r_executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "R.exe" else "R")
  artifact <- file.path(work_dir, paste0(description[["Package"]], "_", description[["Version"]], ".tar.gz"))
  if (nzchar(supplied_artifact)) {
    stopifnot(file.copy(supplied_artifact, artifact))
  } else {
    run(r_executable, c("CMD", "build", shQuote(root)))
  }
  utils::untar(artifact, files = "vennabers/DESCRIPTION", exdir = work_dir)
  stopifnot(identical(description, read.dcf("vennabers/DESCRIPTION",
                                         fields = c("Package", "Version"))[1L, ]))
  writeLines(paste(basename(artifact), unname(tools::md5sum(artifact))),
             file.path(work_dir, "artifact-md5.txt"))
  library_dir <- file.path(work_dir, "library")
  dir.create(library_dir)
  run(r_executable, c("CMD", "INSTALL", paste0("--library=", shQuote(library_dir)), shQuote(artifact)))
  run(r_executable, c("CMD", "check", "--as-cran", "--no-manual",
                     paste0("--library=", shQuote(library_dir)), shQuote(artifact)))
  check_log <- readLines(file.path(work_dir, paste0(description[["Package"]], ".Rcheck"), "00check.log"))
  if (!identical(tail(grep("^Status:", check_log, value = TRUE), 1L), "Status: OK")) {
    stop("R CMD check did not finish with zero errors, warnings, and notes.", call. = FALSE)
  }
  # Load only the package just installed from the source artifact. Refuse a
  # previously loaded namespace rather than accidentally testing another build.
  stopifnot(!"vennabers" %in% loadedNamespaces())
  original_libraries <- .libPaths()
  on.exit(.libPaths(original_libraries), add = TRUE)
  .libPaths(c(library_dir, original_libraries))
  library(vennabers, lib.loc = library_dir)
  installed_path <- normalizePath(file.path(library_dir, description[["Package"]]))
  stopifnot(
    identical(normalizePath(find.package("vennabers")), installed_path),
    identical(normalizePath(getNamespaceInfo("vennabers", "path")), installed_path),
    identical(as.character(packageVersion("vennabers")), description[["Version"]])
  )
  cat("Verified installed artifact:", installed_path, "version",
      as.character(packageVersion("vennabers")), "\n")
  options(warn = 2)

  # Read the README from the checked source artifact, never a stale installation.
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

  # Standalone examples exercise the installed API. Discover new scripts too.
  examples <- list.files(system.file("examples", package = "vennabers"),
                         pattern = "\\.[Rr]$", full.names = TRUE, recursive = TRUE)
  stopifnot(length(examples) > 0L)
  for (example in examples) {
    cat("Running example:", basename(example), "\n")
    sys.source(example, envir = new.env())
  }
  cat("Acceptance gate passed.\n")
})
