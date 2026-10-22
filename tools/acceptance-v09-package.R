# Local v0.9 package-operation acceptance. Run from the repository root:
#   Rscript tools/acceptance-v09-package.R <candidate-lib> <deps-lib> <tarball> <temporary-out-dir>
# <temporary-out-dir> receives a core library, logs and scripts; keep it
# outside .scratch and remove it after summarizing.
# <candidate-lib> holds the installed candidate, <deps-lib> optional packages
# missing from the site library (probably and its imports).
# Run after the mapped installed suite tests pass without skips on this candidate.
example_coverage <- function(examples, map) {
  coverage <- map[match(basename(examples), map$example), , drop = FALSE]
  coverage$example <- basename(examples)
  added <- is.na(coverage$coverage)
  coverage$coverage[added] <- "standalone"
  coverage$covered_by[added] <- "package standalone example"
  coverage$reason[added] <- "New example; no suite execution mapped."
  rownames(coverage) <- NULL
  coverage
}

if (sys.nframe() == 0L) {
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4L)
candidate <- normalizePath(args[[1L]]); deps <- normalizePath(args[[2L]])
tarball <- normalizePath(args[[3L]]); out <- args[[4L]]
dir.create(out, showWarnings = FALSE, recursive = TRUE); out <- normalizePath(out)
map <- utils::read.csv("tools/acceptance-v09-example-coverage.csv", stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(map$example), all(map$coverage %in% c("suite", "core", "helper", "standalone")))
examples <- list.files(system.file("examples", package = "vennabers", lib.loc = candidate), "[.]R$", full.names = TRUE)
coverage <- example_coverage(examples, map)
utils::write.csv(coverage, file.path(out, "example-coverage.csv"), row.names = FALSE)
rscript <- file.path(R.home("bin"), "Rscript")
run <- function(name, lines, libs = c(candidate, deps)) {
  script <- file.path(out, paste0(name, ".R")); log <- file.path(out, paste0(name, ".log"))
  writeLines(c(if (!is.null(libs)) paste0(".libPaths(", paste(deparse(libs), collapse = ""), ")"), lines), script)
  # A dead proxy makes any accidental HTTP(S) access fail instead of passing.
  offline <- c("http_proxy=http://127.0.0.1:9", "https_proxy=http://127.0.0.1:9", "no_proxy=")
  seconds <- system.time(status <- system2(rscript, c("--vanilla", shQuote(script)), stdout = log, stderr = log,
    env = offline))[["elapsed"]]
  warnings <- sum(grepl("^Warning|warning", readLines(log, warn = FALSE)))
  data.frame(check = name, status = status, warnings = warnings, seconds = round(seconds, 1))
}
results <- list()

# 1. Core without tidymodels: a library with only base/recommended packages
# (symlinked) and the candidate installed from the tarball; the site library
# is removed from the search path inside the checking process.
core <- file.path(out, "core-lib"); unlink(core, recursive = TRUE); dir.create(core)
installed <- utils::installed.packages(.Library)
for (p in installed[installed[, "Priority"] %in% c("base", "recommended"), "Package"])
  file.symlink(file.path(.Library, p), file.path(core, p))
install_log <- file.path(out, "core-install.log")
status <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "-l", shQuote(core), shQuote(tarball)),
                  stdout = install_log, stderr = install_log, env = paste0("R_LIBS=", core))
results$core_install <- data.frame(check = "core-install", status = status,
  warnings = sum(grepl("warning", readLines(install_log), ignore.case = TRUE)), seconds = NA)
integration <- c("parsnip", "workflows", "hardhat", "rsample", "recipes", "tune", "dials", "yardstick",
                 "tailor", "probably", "tibble", "rlang", "withr", "generics", "tidyselect")
results$core <- run("core-without-tidymodels", c(
  paste0("assign('.lib.loc', ", deparse(core), ", envir = environment(.libPaths))"),
  paste0("integration <- ", paste(deparse(integration), collapse = "")),
  "stopifnot(!any(vapply(integration, requireNamespace, logical(1), quietly = TRUE)))",
  "library(vennabers)",
  "stopifnot(!any(integration %in% loadedNamespaces()))",
  paste0("for (f in ", paste(deparse(map$example[map$coverage == "core"]), collapse = ""), ")"),
  "  sys.source(system.file('examples', f, package = 'vennabers'), new.env())",
  "for (rd in tools::Rd_db('vennabers')) {",
  "  ex <- tempfile(fileext = '.R'); tools::Rd2ex(rd, ex)",
  "  if (file.exists(ex)) source(ex, local = new.env(), echo = FALSE)",
  "}",
  "message <- tryCatch({calibrated_workflow(NULL, 'truth'); ''}, error = conditionMessage)",
  "stopifnot(grepl('requires optional package', message))",
  "stopifnot(!any(integration %in% loadedNamespaces()))",
  "cat('manual core, all Rd examples and the optional-package error work without tidymodels\\n')"),
  libs = NULL)

# 2. Registration and load orders.
fit_lines <- c(
  "d <- data.frame(x = sin(1:80), truth = factor(rep(c('yes', 'no', 'no', 'yes'), 20)))",
  "base <- workflows::workflow() |> workflows::add_formula(truth ~ x) |> workflows::add_model(parsnip::logistic_reg(engine = 'glm'))",
  "fit <- generics::fit(vennabers::calibrated_workflow(base, 'truth', seed = 1), d)",
  "stopifnot(nrow(predict(fit, d[1:3, 'x', drop = FALSE], type = 'prob')) == 3L)")
results$vennabers_first <- run("load-vennabers-then-parsnip", c("library(vennabers); library(parsnip)", fit_lines))
results$parsnip_first <- run("load-parsnip-then-vennabers", c("library(parsnip); library(vennabers)", fit_lines))
results$namespace_only <- run("namespace-only", c(fit_lines, "stopifnot(!'package:vennabers' %in% search())"))
results$foreign <- run("foreign-registration-refused", c(
  "loadNamespace('parsnip'); parsnip::set_new_model('vennabers')",
  "message <- tryCatch({loadNamespace('vennabers'); ''}, error = conditionMessage)",
  "stopifnot(grepl(\"foreign parsnip registration already owns model 'vennabers'\", message))"))

# 3. Additional installed examples in fresh processes. The passing suite owns
# the complete examples it sources; core examples ran above, and helpers are
# exercised by their callers. Unknown examples default to standalone execution.
for (e in examples[coverage$coverage == "standalone"]) results[[basename(e)]] <- run(paste0("example-", sub("[.]R$", "", basename(e))),
  c("options(warn = 1)", paste0("sys.source(", deparse(e), ", new.env())")))

# 4. No Python or network use in package code, installed examples or tests.
sources <- c(list.files("R", full.names = TRUE), list.files("inst/examples", full.names = TRUE),
             list.files("tests/testthat", "[.]R$", full.names = TRUE))
pattern <- "reticulate|system2?\\([^)]*python|url\\(|download\\.file|curl|httr|socketConnection|install\\.packages"
hits <- as.character(unlist(lapply(sources, function(f) {
  lines <- readLines(f, warn = FALSE)
  i <- grep(pattern, lines)
  if (length(i)) paste0(f, ":", i, ": ", trimws(lines[i]))
})))
writeLines(hits, file.path(out, "python-network-scan.txt"))
results$scan <- data.frame(check = "python-network-scan", status = length(hits), warnings = 0L, seconds = NA)

summary <- do.call(rbind, results)
utils::write.csv(summary, file.path(out, "package-checks.csv"), row.names = FALSE)
print(summary, row.names = FALSE)
writeLines(utils::capture.output(utils::sessionInfo()), file.path(out, "session-info.txt"))
if (any(summary$status != 0L | summary$warnings != 0L)) quit(status = 1L)
}
