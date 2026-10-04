# Summarize tools/run-benchmarks-v09.sh output as Markdown tables.
#   Rscript tools/summarize-benchmarks-v09.R <temporary-out-dir> <candidate-commit>
out <- commandArgs(trailingOnly = TRUE)[[1L]]
candidate <- commandArgs(trailingOnly = TRUE)[[2L]]
fmt <- function(x, digits = 3) {
  x <- unlist(x)
  if (all(is.na(x))) return("—")
  # Median, then every measured run in order.
  sprintf(paste0("%.", digits, "f (%s)"), stats::median(x), paste(sprintf(paste0("%.", digits, "f"), x), collapse = ", "))
}
rss <- function(label) {
  lines <- readLines(file.path(out, paste0(label, ".time")), warn = FALSE)
  bytes <- as.numeric(sub("^\\s*([0-9]+).*", "\\1", grep("maximum resident set size", lines, value = TRUE)))
  sprintf("%.1f", bytes / 2^20)
}
shared <- sub("[.]rds$", "", list.files(out, "^shared-.*[.]rds$"))
cat("Timings: median (run 1, run 2, run 3) after one warm-up run.\n\n")
cat("| Case | Artifact | Fit s | Predict s | Three-fold outer s | RDS MiB | Process peak RSS MiB | Base fits / retained models |\n")
cat("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |\n")
cases <- unique(sub("^shared-(v08|candidate)-", "", shared))
for (case in cases) for (artifact in c("v08", "candidate")) {
  label <- paste0("shared-", artifact, "-", case)
  if (!file.exists(file.path(out, paste0(label, ".rds")))) {
    cat("|", case, "|", artifact, "| failed | | | | | |\n"); next
  }
  r <- readRDS(file.path(out, paste0(label, ".rds")))$repetitions
  get <- function(field) lapply(r, `[[`, field)
  cat("|", case, "|", if (artifact == "v08") "v0.8 `b1ec354`" else paste0("candidate `", candidate, "`"), "|",
      fmt(get("fit")), "|", fmt(get("predict")), "|", fmt(get("outer")), "|",
      sprintf("%.2f", stats::median(unlist(get("bytes"))) / 2^20), "|", rss(label), "|",
      if (is.null(r[[1L]]$base_fits)) "—" else {
        counts <- unique(vapply(r, function(m) paste(m$base_fits, "/", m$retained), ""))
        stopifnot(length(counts) == 1L)
        counts
      }, "|\n")
}
cat("\n| v0.9 case | Fit s | Predict s | Three-fold outer s | RDS MiB | Heap max fit / predict / outer MiB | Peak RSS MiB | Engine / postprocessor fits | Retained pairs | Expected (base / retained) | Tuning base fits |\n")
cat("| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | ---: |\n")
for (label in sub("[.]rds$", "", list.files(out, "^v09-.*[.]rds$"))) {
  x <- readRDS(file.path(out, paste0(label, ".rds")))
  r <- x$repetitions
  get <- function(field) lapply(r, `[[`, field)
  count <- r[[1L]]$counters
  stopifnot(all(vapply(r, function(m) identical(m$counters, count), TRUE)))
  heap <- sprintf("%.0f / %.0f / %.0f", stats::median(unlist(get("fit_heap_mib"))),
    stats::median(unlist(get("predict_heap_mib"))), stats::median(unlist(get("outer_heap_mib"))))
  cat("|", sub("^v09-", "", label), "|", fmt(get("fit")), "|", fmt(get("predict")), "|", fmt(get("outer")), "|",
      sprintf("%.2f", stats::median(unlist(get("rds_bytes"))) / 2^20), "|", heap, "|", rss(label), "|",
      paste(count$composition_base_fits, "/", count$postprocessor_fits), "|", count$retained_pairs, "|",
      if (is.null(x$expected)) "—" else paste(x$expected$base, "/", x$expected$retained), "|",
      if (is.null(count$tuning_observed_base_fits)) "—" else count$tuning_observed_base_fits, "|\n")
}
x <- readRDS(file.path(out, list.files(out, "^v09-.*[.]rds$")[[1L]]))
cat("\nThreads:", paste(names(x$threads), x$threads, sep = "=", collapse = ", "), "; BLAS:", x$blas, "\n")
