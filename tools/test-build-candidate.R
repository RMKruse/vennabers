# Public release boundary: a real Git export, source archive, PDF and identity.
# Rscript --vanilla tools/test-build-candidate.R (requires Git, LaTeX, knitr,
# rmarkdown and Pandoc).
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
tools_dir <- dirname(normalizePath(script))
root <- tempfile("candidate-probe-")
dir.create(root)
for (path in c("R", "man", "tests/testthat/extdata", "inst/examples", "vignettes"))
  dir.create(file.path(root, path), recursive = TRUE)
writeLines(c("Package: candidateprobe", "Version: 1.0.0", "Title: Candidate Probe",
  "Description: A small package to check the public release boundary.",
  "Authors@R: person('A', 'Tester', email = 'tester@example.org', role = c('aut', 'cre'))",
  "License: GPL-3", "Encoding: UTF-8", "Suggests: knitr, rmarkdown",
  "VignetteBuilder: knitr"), file.path(root, "DESCRIPTION"))
writeLines("export(hello)", file.path(root, "NAMESPACE"))
writeLines("hello <- function() 'hello'", file.path(root, "R", "hello.R"))
writeLines(c("\\name{hello}", "\\alias{hello}", "\\title{Say hello}",
  "\\description{Returns a greeting.}", "\\usage{hello()}",
  "\\value{A character string.}", "\\examples{hello()}"), file.path(root, "man", "hello.Rd"))
writeLines("hello", file.path(root, "tests/testthat/extdata", "fixture.txt"))
writeLines("stopifnot(candidateprobe::hello() == 'hello')", file.path(root, "tests", "probe.R"))
writeLines("candidateprobe::hello()", file.path(root, "inst/examples", "hello.R"))
writeLines(c("---", "title: 'Greeting'", "output: rmarkdown::html_vignette",
  "vignette: >", "  %\\VignetteIndexEntry{Greeting}",
  "  %\\VignetteEngine{knitr::rmarkdown}", "  %\\VignetteEncoding{UTF-8}",
  "---", "", "```{r}", "stopifnot(candidateprobe::hello() == 'hello')", "```"),
  file.path(root, "vignettes", "greeting.Rmd"))
git <- function(...) {
  result <- system2("git", c("-C", shQuote(root), ...), stdout = TRUE, stderr = TRUE)
  stopifnot(is.null(attr(result, "status")))
  result
}
git("init", "--quiet")
git("add", ".")
git("-c", "user.name=Tester", "-c", "user.email=tester@example.org", "commit", "--quiet", "-m", "probe")
commit <- git("rev-parse", "HEAD")
# These files and edits must never contaminate the candidate for the commit.
writeLines("untracked", file.path(root, "inst/examples", "untracked.R"))
writeLines("hello <- function() 'dirty'", file.path(root, "R", "hello.R"))
source(file.path(tools_dir, "build-candidate.R"))
out <- build_candidate(root, commit)
identity <- read.dcf(file.path(out, "candidate.dcf"))
stopifnot(identity[1, "Package"] == "candidateprobe", identity[1, "Version"] == "1.0.0",
  identity[1, "Commit"] == commit, file.exists(file.path(out, "candidateprobe_1.0.0.tar.gz")),
  file.exists(file.path(out, "candidateprobe-manual.pdf")))
contents <- read.csv(file.path(out, "contents.csv"))
stopifnot(all(c("tests/probe.R", "tests/testthat/extdata/fixture.txt", "inst/examples/hello.R",
  "vignettes/greeting.Rmd", "inst/doc/greeting.html", "inst/doc/greeting.R") %in% contents$path),
  !"inst/examples/untracked.R" %in% contents$path,
  identical(readLines(file.path(out, "checkout/R/hello.R")), "hello <- function() 'hello'"))
hashes <- tools::sha256sum(file.path(out, c("candidateprobe_1.0.0.tar.gz", "candidateprobe-manual.pdf")))
stopifnot(identical(unname(hashes), unname(identity[1, c("Source-SHA256", "Manual-SHA256")])) )
# A CLI run must leave its default output available after Rscript exits.
dir.create(file.path(root, "tools"))
file.copy(file.path(tools_dir, "build-candidate.R"), file.path(root, "tools"))
cli <- system2(file.path(R.home("bin"), "Rscript"),
  c("--vanilla", shQuote(file.path(root, "tools/build-candidate.R")), commit), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(cli, "status")))
cli_out <- trimws(sub("^Evidence:", "", grep("^Evidence:", cli, value = TRUE)))
stopifnot(length(cli_out) == 1L, file.exists(file.path(cli_out, "candidate.dcf")))
unlink(c(root, out, cli_out), recursive = TRUE)
cat("Candidate build checks passed.\n")
