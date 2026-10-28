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

# Arguments: parts run in their fixed order, all by default.
parsed <- pc_parse_args(c("--parts", "new", "--quick", "p.tar.gz", "c.tar.gz", "deps", "out"))
stopifnot(identical(parsed$parts, "new"), isTRUE(parsed$quick), identical(parsed$out, "out"),
  isFALSE(pc_parse_args(c("--parts", "new", "p", "c", "d", "o"))$quick),
  identical(pc_parse_args(c("--summarize", "out")), list(summarize = TRUE, out = "out")),
  identical(pc_parse_args(c("--parts", "performance,new", "p", "c", "d", "o"))$parts, c("new", "performance")),
  identical(pc_parse_args(c("p", "c", "d", "o"))$parts, pc_parts),
  identical(pc_parse_args(c("--parts", "v09,shared", "--quick", "p", "c", "d", "o"))$parts, c("shared", "v09")),
  grepl("Unknown part", error_of(pc_parse_args(c("--parts", "old", "p", "c", "d", "o")))),
  grepl("Usage", error_of(pc_parse_args(c("--parts", "new", "p", "c", "d")))),
  grepl("Usage", error_of(pc_parse_args(c("--parts", "new", "--fast", "p", "c", "d", "o")))))

# Part performance: performance.R takes the starter's libraries, candidate
# first; outside Linux x86_64 it gets --smoke, and --quick changes nothing.
part_context <- function(linux, quick = FALSE, part = "performance") {
  list(previous_lib = "/o/previous-lib", candidate_lib = "/o/candidate-lib", deps = "/deps", dir = file.path("/o", part),
       quick = quick, linux_x86_64 = linux, tools = "/t", previous_version = "1.0.0")
}
mac <- pc_performance_command(part_context(FALSE))
linux <- pc_performance_command(part_context(TRUE))
stopifnot(identical(mac$args, c("--vanilla", shQuote("/t/performance.R"), shQuote("/o/candidate-lib"),
                                shQuote("/o/previous-lib"), shQuote("/o/performance/output"),
                                "--previous-version", "1.0.0", "--smoke")),
  identical(mac$env, paste0("R_LIBS=", shQuote(paste("/o/candidate-lib", "/deps", sep = .Platform$path.sep)))),
  identical(linux$args, mac$args[-length(mac$args)]), identical(linux$env, mac$env),
  identical(pc_performance_command(part_context(TRUE, quick = TRUE)), linux),
  identical(pc_performance_command(part_context(FALSE, quick = TRUE)), mac),
  identical(pc_performance_failed(c("Release evidence: FALSE ", "current binary_inductive ", "current 3_cross_ovo ",
                                    "Error: Command failed; see /o/current-3_cross_ovo-process.log")), "3_cross_ovo"),
  identical(pc_performance_failed("Error: OUTPUT must be empty."), character()))

# A case has only the phases its input runs: outer resampling for unfrozen
# workflows, schema and encoding with a schema.
applicable <- function(...) pc_performance_metrics(list(...))
core <- c("fit_seconds", "predict_seconds", "rds_bytes", pc_performance_counters)
stopifnot(identical(applicable(method = "binary"), core),
  identical(applicable(integration = TRUE), c(core[1:2], "outer_seconds", core[-(1:2)])),
  identical(applicable(integration = TRUE, frozen = TRUE), core),
  identical(applicable(integration = TRUE, frozen = TRUE, schema = list(outcome = "truth")),
            c(core[1:2], "schema_seconds", "encode_seconds", "decode_seconds", core[-(1:2)])),
  identical(length(applicable(integration = TRUE, schema = list())), 10L))

# Its reader takes the single values per iteration from <release>-<case>-runs.csv
# in plan order, without the warm-up; the process peak counts once per case.
examples <- file.path(tools, "performance-comparison-examples")
long <- read_part_performance(file.path(examples, "performance"))
peaks <- long[long$metric == "process_peak_bytes", ]
workflow <- long[long$case == "workflow_binary_inductive", ]
stopifnot(identical(names(long), c("part", pc_long_columns)), identical(unique(long$part), "performance"),
  identical(unique(long$case), c("workflow_binary_inductive", "binary_inductive")),
  identical(nrow(long), 2L * (7L * 3L + 1L) + 2L * (6L * 3L + 1L)), identical(sort(unique(long$run)), 1:3),
  identical(unique(workflow$metric), c(applicable(integration = TRUE), "process_peak_bytes")),
  !any(c("outer_seconds", "schema_seconds") %in% long$metric[long$case == "binary_inductive"]),
  identical(unique(long$library), c("previous", "candidate")),
  identical(peaks$value, c(3e8, 4e8, 1.5e8, 1.51e8)), all(is.na(peaks$run)), identical(unique(peaks$unit), "bytes"),
  identical(workflow$value[workflow$library == "candidate" & workflow$metric == "fit_seconds"], c(0.25, 0.26, 0.27)),
  identical(workflow$value[workflow$library == "previous" & workflow$metric == "retained_models"], c(1, 1, 1)),
  identical(unique(long$unit[long$metric %in% c("fit_count", "retained_models", "outer_fit_count")]), "count"),
  identical(unique(long$unit[endsWith(long$metric, "_seconds")]), "seconds"),
  identical(unique(long$unit[long$metric == "rds_bytes"]), "bytes"),
  identical(nrow(read_part_performance(tempfile())), 0L))

# run-benchmarks-v09.sh, with a stub Rscript that fails the candidate's
# pairwise-fixed: each part runs only its cases, previous before candidate;
# BENCH_QUICK=1 sets BENCH_REPS=1 and skips the tuned cases; a failed case
# makes the exit status 1; /usr/bin/time reports the process peak.
stub <- tempfile()
dir.create(stub)
writeLines(c("#!/bin/sh", 'echo "$R_LIBS ${BENCH_REPS:-unset} $*"',
             'case "$R_LIBS $*" in cand:*" pairwise fixed "*) exit 3 ;; esac'), file.path(stub, "Rscript"))
Sys.chmod(file.path(stub, "Rscript"), "755")
runner <- function(part, quick) {
  out <- tempfile()
  lines <- suppressWarnings(system2("sh", c(shQuote(file.path(tools, "run-benchmarks-v09.sh")), "cand", "prev", "deps",
                                            shQuote(out), part), stdout = TRUE, stderr = TRUE,
    env = c(paste0("PATH=", shQuote(paste(stub, Sys.getenv("PATH"), sep = ":"))), paste0("BENCH_QUICK=", quick))))
  list(lines = as.vector(lines), status = attr(lines, "status") %||% 0L, out = out)
}
labels <- function(part, cases) paste0(part, "-", c("previous", "candidate"), "-", rep(cases, each = 2L))
fixed <- c("ivap-fixed", "binary-fixed", "pairwise-fixed", "ovo-fixed", "ovr-fixed", "regression-fixed")
v09 <- paste0(rep(c("binary", "pairwise", "ovo", "regression"), each = 4L), "-",
              rep(c("holdout", "ensemble"), each = 2L), "-", c("matched", "full"))
shared_quick <- runner("shared", 1)
shared_full <- runner("shared", 0)
v09_quick <- runner("v09", 1)
v09_full <- runner("v09", 0)
expected <- paste("done", labels("shared", fixed))
expected[expected == "done shared-candidate-pairwise-fixed"] <- "FAILED shared-candidate-pairwise-fixed"
stopifnot(identical(shared_quick$lines, expected), identical(shared_quick$status, 1L),
  identical(length(shared_full$lines), 24L), identical(shared_full$status, 1L),
  identical(sum(grepl("-(grid|bayes)$", shared_full$lines)), 12L),
  identical(v09_quick$lines, paste("done", labels("v09", v09))), identical(v09_quick$status, 0L),
  identical(v09_full$lines, paste("done", labels("v09", c(v09, "tuned-ensemble-full")))), identical(v09_full$status, 0L),
  identical(readLines(file.path(shared_quick$out, "shared-previous-binary-fixed.log")),
            paste("prev:deps 1 tools/benchmark-shared-v09.R binary fixed",
                  file.path(shared_quick$out, "shared-previous-binary-fixed.rds"))),
  identical(sub("^(\\S+) \\S+ ", "\\1 ", readLines(file.path(v09_full$out, "v09-candidate-tuned-ensemble-full.log"))),
            paste("cand:deps tools/benchmark-v09.R tuned ensemble full",
                  file.path(v09_full$out, "v09-candidate-tuned-ensemble-full.rds"))),
  !is.na(pc_parse_time(readLines(file.path(v09_quick$out, "v09-candidate-ovo-holdout-full.time")))),
  grepl("Unknown part", paste(runner("new", 0)$lines, collapse = " ")))
unlink(c(stub, shared_quick$out, shared_full$out, v09_quick$out, v09_full$out), recursive = TRUE)

# The starter runs the runner from the repository root with its own Rscript
# first on PATH, only the part's cases, and BENCH_QUICK under --quick.
command <- pc_runner_command(part_context(FALSE, part = "shared"), "shared")
stopifnot(identical(command$args, c(shQuote("/t/run-benchmarks-v09.sh"), shQuote("/o/candidate-lib"),
                                    shQuote("/o/previous-lib"), shQuote("/deps"), shQuote("/o/shared/output"),
                                    "shared")),
  identical(command$env, c(paste0("PATH=", shQuote(paste(R.home("bin"), Sys.getenv("PATH"), sep = .Platform$path.sep))),
                           "BENCH_QUICK=0")),
  identical(pc_runner_command(part_context(TRUE, quick = TRUE, part = "v09"), "v09")$env[[2L]], "BENCH_QUICK=1"),
  identical(pc_runner_command(part_context(TRUE, part = "v09"), "v09")$args[[6L]], "v09"),
  identical(pc_runner_cases(c("done shared-previous-binary-grid", "FAILED shared-candidate-binary-grid",
                              "FAILED shared-previous-ovo-fixed", "FAILED shared-candidate-ovo-fixed",
                              "FAILED v09-candidate-ovo-holdout-full", "Unknown part: x"), "shared", "FAILED"),
            c("binary-grid", "ovo-fixed")),
  identical(pc_runner_cases(c("done v09-previous-tuned-ensemble-full", "FAILED v09-candidate-binary-holdout-full"),
                            "v09"), c("tuned-ensemble-full", "binary-holdout-full")))

# Readers of parts shared and v09: the single values of each case and library
# from its RDS, in log order; the process peak from its .time file (BSD bytes
# or GNU kilobytes) once per case and library; no row for a phase or counter
# the case does not have.
shared <- read_part_shared(file.path(examples, "shared"))
ivap <- shared[shared$case == "ivap-fixed", ]
grid <- shared[shared$case == "binary-grid", ]
stopifnot(identical(names(shared), c("part", pc_long_columns)), identical(unique(shared$part), "shared"),
  identical(unique(shared$case), c("ivap-fixed", "binary-grid")), identical(unique(shared$library), c("previous", "candidate")),
  identical(unique(grid$metric), c("fit_seconds", "predict_seconds", "outer_seconds", "rds_bytes", "base_fits",
                                   "retained", "process_peak_bytes")),
  identical(unique(ivap$metric), c("fit_seconds", "predict_seconds", "rds_bytes", "process_peak_bytes")),
  identical(nrow(shared), 2L * (3L * 3L + 1L) + 2L * (6L * 3L + 1L)),
  identical(grid$value[grid$library == "candidate" & grid$metric == "fit_seconds"], c(1.3, 1.25, 1.2)),
  identical(grid$run[grid$library == "candidate" & grid$metric == "fit_seconds"], 1:3),
  identical(grid$value[grid$metric == "process_peak_bytes"], c(314572800, 1536 * 1024 * 200)),
  all(is.na(shared$run[shared$metric == "process_peak_bytes"])),
  identical(unique(shared$unit[shared$metric %in% c("base_fits", "retained")]), "count"),
  identical(unique(shared$unit[shared$metric == "rds_bytes"]), "bytes"),
  identical(nrow(read_part_shared(tempfile())), 0L))
v09_long <- read_part_v09(file.path(examples, "v09"))
holdout <- v09_long[v09_long$case == "binary-holdout-matched", ]
tuned <- v09_long[v09_long$case == "tuned-ensemble-full", ]
v09_counters <- c("composition_base_fits", "postprocessor_fits", "retained_pairs")
stopifnot(identical(names(v09_long), c("part", pc_long_columns)), identical(unique(v09_long$part), "v09"),
  identical(unique(v09_long$case), c("binary-holdout-matched", "tuned-ensemble-full")),
  identical(unique(holdout$metric), c("fit_seconds", "predict_seconds", "outer_seconds", "fit_heap_bytes",
                                      "predict_heap_bytes", "outer_heap_bytes", "rds_bytes", v09_counters,
                                      "process_peak_bytes")),
  identical(unique(tuned$metric), c(unique(holdout$metric)[1:10], "tuning_observed_base_fits", "process_peak_bytes")),
  identical(holdout$value[holdout$library == "previous" & holdout$metric == "fit_heap_bytes"], c(50.3, 50.4, 50.3) * 1048576),
  identical(unique(v09_long$unit[endsWith(v09_long$metric, "_heap_bytes")]), "bytes"),
  identical(unique(v09_long$unit[v09_long$metric %in% c(v09_counters, "tuning_observed_base_fits")]), "count"),
  identical(tuned$value[tuned$metric == "tuning_observed_base_fits"], c(16, 16, 16, 20, 20, 20)),
  identical(holdout$value[holdout$metric == "process_peak_bytes"], c(2e8, 2048 * 1024 * 100)),
  identical(nrow(read_part_v09(tempfile())), 0L))

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
# --summarize over parts new and performance: the historical part shows its
# count and only its flagged rows.
both <- summarize_copy(function(out) {
  run <- pc_read_keys(file.path(out, "run.csv"))
  run$parts <- "new,performance"
  pc_write_keys(run, file.path(out, "run.csv"))
})
run <- pc_read_keys(file.path(both, "run.csv"))
comparison <- utils::read.csv(file.path(both, "comparison.csv"), na.strings = "")
historical <- comparison[comparison$part == "performance", ]
flagged <- historical[!is.na(historical$flag), ]
summary <- readLines(file.path(both, "summary.md"))
stopifnot(identical(run$exit_performance, "0"), identical(run$wall_seconds_performance, "444"),
  identical(run$wall_seconds_total, "1200"),
  identical(unique(utils::read.csv(file.path(both, "measurements.csv"))$part), c("new", "performance")),
  identical(unique(historical$case), c("workflow_binary_inductive", "binary_inductive")),
  identical(flagged$metric, c("fit_seconds", "process_peak_bytes", "outer_fit_count")),
  identical(flagged$flag, c("> 1.10", "> 1.10", "counters differ")),
  all(flagged$case == "workflow_binary_inductive"),
  identical(historical$note[historical$case == "binary_inductive" & historical$metric == "predict_seconds"], "below 10 ms"),
  identical(sum(!is.na(historical$note)), 1L),
  "**Not acceptance evidence (macOS arm64, parts: new,performance)**" %in% summary,
  any(grepl("Wall time: new 0:12:30 (exit 0), performance 0:07:24 (exit 0); total 0:20:00", summary, fixed = TRUE)),
  "- performance: 2 cases, 1 flagged" %in% summary,
  "| performance | `workflow_binary_inductive` | fit_seconds | 0.210 s | 0.260 s | 1.24 | > 1.10 |" %in% summary,
  "| performance | `workflow_binary_inductive` | process_peak_bytes | 286.1 MiB | 381.5 MiB | 1.33 | > 1.10 |" %in% summary,
  "| performance | `workflow_binary_inductive` | outer_fit_count | 3 | 3 | – | counters differ |" %in% summary,
  identical(length(grep("^\\| `", summary)), 9L))
# --summarize over all parts: shared and v09 show their counts, flagged rows
# and failed cases like part performance.
all_parts <- summarize_copy(function(out) {
  run <- pc_read_keys(file.path(out, "run.csv"))
  run$parts <- paste(pc_parts, collapse = ",")
  pc_write_keys(run, file.path(out, "run.csv"))
})
run <- pc_read_keys(file.path(all_parts, "run.csv"))
measurements <- utils::read.csv(file.path(all_parts, "measurements.csv"), na.strings = "")
comparison <- utils::read.csv(file.path(all_parts, "comparison.csv"), na.strings = "")
summary <- readLines(file.path(all_parts, "summary.md"))
stopifnot(identical(unique(measurements$part), pc_parts),
  identical(unique(comparison$part), pc_parts),
  identical(run$exit_shared, "0"), identical(run$exit_v09, "1"), identical(run$failed_cases_v09, "ovo-holdout-full"),
  identical(run$wall_seconds_total, "1620"),
  identical(comparison$flag[comparison$part %in% c("shared", "v09") & !is.na(comparison$flag)],
            c("> 1.10", "counters differ")),
  "- shared: 2 cases, 1 flagged" %in% summary, "- v09: 2 cases, 1 flagged" %in% summary,
  "| shared | `binary-grid` | fit_seconds | 1.000 s | 1.250 s | 1.25 | > 1.10 |" %in% summary,
  "| v09 | `tuned-ensemble-full` | tuning_observed_base_fits | 16 | 20 | – | counters differ |" %in% summary,
  "- Failed: v09 (cases: ovo-holdout-full)" %in% summary,
  any(grepl("shared 0:02:00 (exit 0), v09 0:05:00 (exit 1); total 0:27:00", summary, fixed = TRUE)))
# Without part new the table of the nine new cases stays, empty.
alone <- summarize_copy(function(out) {
  run <- pc_read_keys(file.path(out, "run.csv"))
  run$parts <- "performance"
  pc_write_keys(run, file.path(out, "run.csv"))
  unlink(file.path(out, "new"), recursive = TRUE)
})
summary <- readLines(file.path(alone, "summary.md"))
stopifnot("- performance: 2 cases, 1 flagged" %in% summary,
  identical(length(grep("^\\| `[^`]+` \\| – \\| – \\| – \\|", summary)), 9L))
unlink(c(out, smoke, both, all_parts, alone), recursive = TRUE)
cat("Performance comparison checks passed.\n")
