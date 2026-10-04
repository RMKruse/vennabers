# Rscript --vanilla tools/build-candidate.R [commit=HEAD] [output=<new temporary directory>]
# Git and a working LaTeX installation are required; no package dependencies.
build_candidate <- function(root, ref = "HEAD",
    output = tempfile("vennabers-candidate-", tmpdir = dirname(tempdir()))) {
  root <- normalizePath(root)
  git <- function(...) {
    result <- system2("git", c("-C", shQuote(root), ...), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(result, "status"))) stop(paste(result, collapse = "\n"))
    result
  }
  commit <- git("rev-parse", "--verify", "--end-of-options", shQuote(paste0(ref, "^{commit}")))
  tree <- git("rev-parse", paste0(commit, "^{tree}"))
  if (!dir.create(output, recursive = TRUE)) stop("Output must be a new directory: ", output)
  output <- normalizePath(output)
  previous <- setwd(output)
  on.exit(setwd(previous), add = TRUE)
  run <- function(command, args, log) {
    status <- system2(command, args, stdout = log, stderr = log)
    if (status != 0L) stop("Command failed; see ", file.path(output, log))
  }
  run("git", c("-C", shQuote(root), "archive", "--format=tar",
    paste0("--output=", shQuote(file.path(output, "checkout.tar"))), commit), "export.log")
  dir.create("checkout")
  utils::untar("checkout.tar", exdir = "checkout")
  unlink("checkout.tar")
  description <- read.dcf("checkout/DESCRIPTION")
  package <- description[1, "Package"]
  version <- description[1, "Version"]
  artifact <- paste0(package, "_", version, ".tar.gz")
  manual <- paste0(package, "-manual.pdf")
  r <- file.path(R.home("bin"), "R")
  run(r, c("CMD", "build", "--no-manual", "checkout"), "build.log")
  run(r, c("CMD", "Rd2pdf", "--no-preview", paste0("--output=", shQuote(manual)), "checkout"), "manual.log")
  stopifnot(file.exists(artifact), file.info(manual)$size > 0)
  dir.create("unpacked")
  utils::untar(artifact, exdir = "unpacked")
  built <- file.path("unpacked", package)
  required <- list.files(file.path("checkout", c("tests", "inst", "vignettes")), recursive = TRUE, full.names = TRUE)
  relative <- substring(required, nchar("checkout/") + 1L)
  present <- file.path(built, relative)
  if (!all(file.exists(present)) ||
      !identical(unname(tools::sha256sum(required)), unname(tools::sha256sum(present))))
    stop("Built package omitted or changed tests, fixtures, installed examples or vignette sources.")
  files <- list.files(built, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  contents <- data.frame(path = substring(files, nchar(paste0(built, "/")) + 1L),
    sha256 = unname(tools::sha256sum(files)))
  utils::write.csv(contents, "contents.csv", row.names = FALSE)
  hashes <- tools::sha256sum(c(artifact, manual))
  identity <- data.frame(Package = package, Version = version, Commit = commit, Tree = tree,
    Source = artifact, `Source-SHA256` = unname(hashes[1]),
    Manual = manual, `Manual-SHA256` = unname(hashes[2]),
    R = R.version.string, Platform = R.version$platform, check.names = FALSE)
  write.dcf(identity, "candidate.dcf")
  writeLines(paste(hashes, names(hashes)), "SHA256SUMS")
  writeLines(utils::capture.output(utils::sessionInfo()), "build-session.txt")
  cat("Candidate:", commit, "version", version, "\nEvidence:", output, "\n")
  invisible(output)
}

if (sys.nframe() == 0L) {
  script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
  root <- dirname(dirname(normalizePath(script)))
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 2L) stop("Usage: Rscript --vanilla tools/build-candidate.R [commit] [new-output-dir]")
  build_candidate(root, if (length(args)) args[1] else "HEAD",
    if (length(args) == 2L) args[2] else tempfile("vennabers-candidate-", tmpdir = dirname(tempdir())))
}
