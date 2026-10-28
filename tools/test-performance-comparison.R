# Small runnable check without any measurement:
#   Rscript --vanilla tools/test-performance-comparison.R
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
tools <- dirname(normalizePath(script))
source(file.path(tools, "performance-comparison.R"))
source(file.path(tools, "benchmark-v11.R"))
error_of <- function(expr) tryCatch({ expr; "" }, error = conditionMessage)

# /usr/bin/time: macOS -l reports bytes, GNU -v kilobytes.
bsd <- c("        0.00 real         0.00 user         0.00 sys",
         "             2048000  maximum resident set size",
         "                   0  average shared memory size",
         "             1261856  peak memory footprint")
gnu <- c("Command exited with non-zero status 3",
         "\tCommand being timed: \"sh -c exit 3\"",
         "\tElapsed (wall clock) time (h:mm:ss or m:ss): 0:00.00",
         "\tMaximum resident set size (kbytes): 1536",
         "\tAverage resident set size (kbytes): 0",
         "\tExit status: 3")
stopifnot(identical(pc_parse_time(bsd), 2048000), identical(pc_parse_time(gnu), 1536 * 1024),
  is.na(pc_parse_time(bsd[-2L])), is.na(pc_parse_time(character())),
  identical(pc_time_flag("Darwin"), "-l"), identical(pc_time_flag("Linux"), "-v"))

# Flags: ratio above 1.10 and at least 0.01 s or 1 MiB difference; counters on
# equality only; never in a smoke run.
pair <- function(previous, candidate, unit = "seconds", metric = "fit_seconds") {
  data.frame(part = "new", case = "x", library = rep(c("previous", "candidate"), c(length(previous), length(candidate))),
             run = c(seq_along(previous), seq_along(candidate)), metric = metric, value = c(previous, candidate),
             unit = unit)
}
compare <- function(..., smoke = FALSE) pc_compare(pair(...), smoke)
flag <- function(...) compare(...)$flag
mib <- 1048576
stopifnot(identical(flag(1, 1.1), ""), identical(flag(0.5, 0.55), ""), identical(flag(1, 1.101), "> 1.10"),
  identical(flag(0.05, 0.06), "> 1.10"), identical(flag(0.05, 0.0599), ""),
  identical(flag(10 * mib, 12 * mib, "bytes", "process_peak_bytes"), "> 1.10"),
  identical(flag(5 * mib, 6 * mib, "bytes", "fit_heap_bytes"), "> 1.10"),
  identical(flag(mib, 1.9 * mib, "bytes", "rds_bytes"), ""),
  identical(flag(0, 1), ""), is.na(compare(0, 1)$ratio),
  identical(flag(c(4, 4, 4), c(4, 5, 4), "count", "fits"), "counters differ"),
  is.na(compare(c(4, 4, 4), c(4, 5, 4), "count", "fits")$ratio),
  identical(flag(c(4, 4), c(4, 4), "count", "fits"), ""),
  identical(compare(1, 2, smoke = TRUE)$flag, ""), identical(compare(4, 5, "count", "fits", smoke = TRUE)$flag, ""),
  identical(compare(0.005, 0.02)$note, "below 10 ms"), identical(compare(0.005, 0.02)$flag, "> 1.10"),
  identical(compare(0.01, 0.01)$note, ""),
  identical(compare(c(1, 3, 2), c(2, 9, 2))$median_candidate, 2), identical(compare(c(1, 3, 2), c(2, 9, 2))$ratio, 1))

# Run kind: only Linux x86_64, all parts, measurement size is a reference run.
kind <- function(...) pc_run_kind(...)
stopifnot(identical(kind("Linux", "x86_64", pc_parts, FALSE)$reference, "TRUE"),
  identical(pc_headline(kind("Linux", "x86_64", pc_parts, FALSE)), "Reference run"),
  identical(kind("Linux", "x86_64", "new", FALSE)$reference, "FALSE"),
  identical(pc_headline(kind("Linux", "x86_64", "new", FALSE)), "Not acceptance evidence (Linux x86_64, parts: new)"),
  identical(kind("Linux", "aarch64", pc_parts, FALSE)$linux_x86_64, "FALSE"),
  identical(kind("Darwin", "arm64", pc_parts, FALSE)$platform, "macOS arm64"),
  identical(kind("Darwin", "arm64", pc_parts, FALSE)$reference, "FALSE"),
  identical(kind("Linux", "x86_64", pc_parts, TRUE)$reference, "FALSE"),
  identical(kind("Linux", "x86_64", pc_parts, TRUE)$size, "quick"),
  identical(pc_headline(kind("Linux", "x86_64", pc_parts, TRUE)), "Smoke run – not a measurement"))

# Arguments: unbuilt parts are rejected up front, also by the default.
parsed <- pc_parse_args(c("--parts", "new", "--quick", "p.tar.gz", "c.tar.gz", "deps", "out"))
stopifnot(identical(parsed$parts, "new"), isTRUE(parsed$quick), identical(parsed$out, "out"),
  isFALSE(pc_parse_args(c("--parts", "new", "p", "c", "d", "o"))$quick),
  identical(pc_parse_args(c("--summarize", "out")), list(summarize = TRUE, out = "out")),
  grepl("part 'performance' (ticket 10, #87)", error_of(pc_parse_args(c("p", "c", "d", "o"))), fixed = TRUE),
  grepl("part 'v09' (ticket 11, #88)", error_of(pc_parse_args(c("p", "c", "d", "o"))), fixed = TRUE),
  grepl("part 'shared' (ticket 11, #88)", error_of(pc_parse_args(c("--parts", "shared,new", "p", "c", "d", "o"))),
        fixed = TRUE),
  grepl("Unknown part", error_of(pc_parse_args(c("--parts", "old", "p", "c", "d", "o")))),
  grepl("Usage", error_of(pc_parse_args(c("--parts", "new", "p", "c", "d")))),
  grepl("Usage", error_of(pc_parse_args(c("--parts", "new", "--fast", "p", "c", "d", "o")))),
  identical(names(pc_unbuilt(pc_parts)), c("performance", "shared", "v09")))

# Sizes: --quick divides the rows by 100; the CVAR prediction keeps 1e4 calibration rows.
quick <- v11_sizes(pc_new_cases, quick = TRUE)
full <- v11_sizes(pc_new_cases, quick = FALSE)
predict_case <- pc_new_cases$method == "cvar_predict"
stopifnot(identical(nrow(pc_new_cases), 9L), !anyDuplicated(pc_new_cases$case),
  identical(quick$rows, pc_new_cases$rows / 100), identical(full$rows, pc_new_cases$rows),
  identical(quick$rows[predict_case], c(1e3, 1e4)), all(quick$calibration_rows[predict_case] == 1e4),
  all(full$calibration_rows[predict_case] == 1e4),
  identical(quick$calibration_rows[!predict_case], quick$rows[!predict_case]))

# Plan: fixed seeds, one RDS per case with its SHA-256, knots from the input.
tiny <- v11_sizes(data.frame(case = c("binary", "cross", "ties", "predict"),
                             method = c("ivap", "cvar", "ivap_ties", "cvar_predict"), rows = c(200, 200, 2000, 50)),
                  quick = FALSE)
dir <- tempfile()
dir.create(dir)
plan <- v11_write_plan(tiny, dir)
inputs <- file.path(dir, "inputs", paste0(plan$case, ".rds"))
stopifnot(identical(plan$case, tiny$case), identical(plan$rows, as.integer(tiny$rows)),
  identical(plan$knots, c(200L, 200L, length(unique(readRDS(inputs[[3L]])$score)), 10000L)), plan$knots[[3L]] < 1000L,
  identical(plan$sha256, unname(tools::sha256sum(inputs))),
  identical(utils::read.csv(file.path(dir, "plan.csv"))$sha256, plan$sha256),
  identical(readRDS(inputs[[1L]]), v11_input("ivap", 200, 200)),
  identical(sort(unique(readRDS(inputs[[2L]])$fold)), 1:5), identical(as.vector(table(readRDS(inputs[[2L]])$fold)), rep(40L, 5)),
  isTRUE(all(readRDS(inputs[[3L]])$score == round(readRDS(inputs[[3L]])$score, 3))),
  identical(dim(readRDS(inputs[[4L]])$new), c(50L, 5L)), identical(colnames(readRDS(inputs[[4L]])$new), as.character(1:5)),
  identical(length(readRDS(inputs[[4L]])$truth), 10000L),
  grepl("2 distinct scores, expected 3", error_of(v11_knots("x", "ivap", c(.1, .1, .2))), fixed = TRUE),
  identical(v11_knots("x", "ivap_ties", c(.1, .1, .2)), 2L))
unlink(dir, recursive = TRUE)

# --summarize on example raw outputs of part new rebuilds the summary byte for byte.
examples <- file.path(tools, "performance-comparison-examples")
summarize_copy <- function(edit = function(out) NULL) {
  out <- tempfile()
  dir.create(out)
  file.copy(list.files(examples, full.names = TRUE), out, recursive = TRUE)
  edit(out)
  pc_summarize(out)
  out
}
read_bytes <- function(path) readBin(path, "raw", file.size(path))
rebuilt <- c("measurements.csv", "comparison.csv", "summary.md", "run.csv")
out <- summarize_copy()
first <- lapply(file.path(out, rebuilt), read_bytes)
pc_summarize(out)
stopifnot(identical(first, lapply(file.path(out, rebuilt), read_bytes)))
run <- pc_read_keys(file.path(out, "run.csv"))
comparison <- utils::read.csv(file.path(out, "comparison.csv"), na.strings = "")
summary <- readLines(file.path(out, "summary.md"))
case_rows <- grep("^\\| `", summary, value = TRUE)
peak <- comparison[comparison$case == "cvar-predict-1e5" & comparison$metric == "process_peak_bytes", ]
stopifnot(identical(run$wall_seconds_new, "750.5"), identical(run$exit_new, "0"), identical(run$failed_cases_new, ""),
  identical(run$end_utc, "2026-10-28T10:12:35.500Z"), identical(run$wall_seconds_total, "755.5"),
  identical(unique(utils::read.csv(file.path(out, "measurements.csv"))$part), "new"),
  identical(peak$flag, "> 1.10"), identical(peak$ratio, round(400 / 300, 4)),
  identical(comparison$metric[!is.na(comparison$flag)], c("predict_heap_bytes", "process_peak_bytes")),
  identical(comparison$note[comparison$case == "ivap-ties-1e7" & comparison$metric == "fit_seconds"], "below 10 ms"),
  "**Not acceptance evidence (macOS arm64, parts: new)**" %in% summary,
  any(grepl("Wall time: new 0:12:30 (exit 0); total 0:12:36", summary, fixed = TRUE)),
  "- Failed: none" %in% summary,
  identical(length(case_rows), 9L), identical(sub("^\\| `([^`]+)`.*$", "\\1", case_rows), pc_new_cases$case),
  any(grepl("^\\| `cvar-predict-1e5` \\| 100,000 \\| 10,000 \\| 4\\.100 \\| 0\\.110 \\| 0\\.03 \\| 300\\.0 \\| 400\\.0 \\| 1\\.33 \\|.*\\| – \\| > 1\\.10 \\(heap, peak\\) \\|$",
            case_rows)),
  any(grepl("^\\| `ivap-1e6` \\| 1,000,000 \\| 1,000,000 \\| 1\\.000 \\| 0\\.510 \\| 0\\.51 \\|.*\\| 16\\.0 \\|  \\|$", case_rows)),
  any(grepl("^\\| `ivar-1e7` \\| – \\| – \\| – \\|", case_rows)),
  any(grepl("below 10 ms", case_rows[grepl("ivap-ties-1e7", case_rows)])),
  !any(grepl("Historical parts", summary)))

# A smoke run has no flags; a failed part is named with its cases.
smoke <- summarize_copy(function(out) {
  run <- pc_read_keys(file.path(out, "run.csv"))
  run$size <- "quick"
  pc_write_keys(run, file.path(out, "run.csv"))
  status <- pc_read_keys(file.path(out, "new", "status.csv"))
  status$exit <- "1"
  status$failed_cases <- "ivap-1e7;ivar-1e7"
  pc_write_keys(status, file.path(out, "new", "status.csv"))
})
summary <- readLines(file.path(smoke, "summary.md"))
stopifnot("**Smoke run – not a measurement**" %in% summary,
  all(is.na(utils::read.csv(file.path(smoke, "comparison.csv"), na.strings = "")$flag)),
  "- Failed: new (cases: ivap-1e7, ivar-1e7)" %in% summary,
  identical(pc_read_keys(file.path(smoke, "run.csv"))$exit_new, "1"))
unlink(c(out, smoke), recursive = TRUE)
cat("Performance comparison checks passed.\n")
