# Performance comparison of two releases (RELEASE-ROADMAP-1.x.md §3.4 and §4,
# RELEASE-ROADMAP.md §3.5). Run from the repository root:
#   Rscript --vanilla tools/performance-comparison.R [--parts new,performance,shared,v09] [--quick] \
#     <previous.tar.gz> <candidate.tar.gz> <deps-lib> <out>
#   Rscript --vanilla tools/performance-comparison.R --summarize <out>
#   Rscript --vanilla tools/performance-comparison.R --combine <out> <run>...
# <out> must be empty or missing. Keep it under venn-abers-candidates/; only
# summary.md goes to .scratch. Both archives are installed once into <out>,
# and every measuring process runs with R_LIBS=<lib>:<deps-lib>.
#
# The comparison has four parts, run serially in this order: new (the nine
# performance cases of 1.1), performance (v0.3-v0.7), shared (v0.8) and v09.
# Each part has a start function run_part_<name>(context) and a reader
# read_part_<name>(dir) that turns its raw outputs into the long form. Every
# part measures each case on the previous release, then on the candidate. A
# case with a "> 1.10" flag is measured once more, both libraries, into
# <part>-remeasure/; it counts as a regression only if the remeasurement
# flags it again. A failed part does not stop the others, but the run then
# exits with status 1. Flags never fail a run. --summarize rebuilds
# measurements.csv, comparison.csv, summary.md and the derived fields of
# run.csv from the raw outputs without measuring. --combine joins summarized
# runs of disjoint parts with the same archives, platform and size (one CI
# job per part) into one run under <out>. Not part of R CMD check.

pc_parts <- c("new", "performance", "shared", "v09")

# Single-threaded measuring processes, as in the earlier benchmark runners.
pc_thread_env <- c(OMP_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
                   MKL_NUM_THREADS = "1")

# The nine performance cases of part new. `rows` is the measurement size;
# --quick divides it by 100. The CVAR prediction cases count predicted rows;
# their model always has 1e4 calibration rows.
pc_new_cases <- data.frame(
  case = c("ivap-1e6", "ivap-1e7", "ivar-1e6", "ivar-1e7", "cvap-1e6", "cvar-1e6",
           "cvar-predict-1e5", "cvar-predict-1e6", "ivap-ties-1e7"),
  method = c("ivap", "ivap", "ivar", "ivar", "cvap", "cvar", "cvar_predict", "cvar_predict", "ivap_ties"),
  rows = c(1e6, 1e7, 1e6, 1e7, 1e6, 1e6, 1e5, 1e6, 1e7))

# Canonical metrics in comparison order; counters keep their part's name.
pc_metrics <- c("fit_seconds", "predict_seconds", "outer_seconds", "schema_seconds", "encode_seconds",
                "decode_seconds", "fit_heap_bytes", "predict_heap_bytes", "outer_heap_bytes", "rds_bytes",
                "process_peak_bytes")

pc_long_columns <- c("case", "library", "run", "metric", "value", "unit")

pc_part_function <- function(kind, part) get(paste0(kind, "_part_", part), mode = "function")

pc_usage <- paste(
  "Usage: Rscript --vanilla tools/performance-comparison.R [--parts new,performance,shared,v09] [--quick]",
  "<previous.tar.gz> <candidate.tar.gz> <deps-lib> <out>",
  "\n       Rscript --vanilla tools/performance-comparison.R --summarize <out>",
  "\n       Rscript --vanilla tools/performance-comparison.R --combine <out> <run>...")

pc_parse_args <- function(args) {
  if (length(args) && args[[1L]] == "--summarize") {
    if (length(args) != 2L) stop(pc_usage, call. = FALSE)
    return(list(summarize = TRUE, out = args[[2L]]))
  }
  if (length(args) && args[[1L]] == "--combine") {
    if (length(args) < 3L) stop(pc_usage, call. = FALSE)
    return(list(summarize = FALSE, combine = TRUE, out = args[[2L]], runs = args[-(1:2)]))
  }
  quick <- "--quick" %in% args
  args <- args[args != "--quick"]
  parts <- pc_parts
  at <- which(args == "--parts")
  if (length(at)) {
    if (length(at) > 1L || at == length(args)) stop(pc_usage, call. = FALSE)
    parts <- strsplit(args[[at + 1L]], ",", fixed = TRUE)[[1L]]
    args <- args[-c(at, at + 1L)]
    unknown <- setdiff(parts, pc_parts)
    if (length(unknown) || !length(parts)) {
      stop("Unknown part(s) in --parts: ", paste(unknown, collapse = ", "), "; use ",
           paste(pc_parts, collapse = ", "), ".", call. = FALSE)
    }
  }
  if (any(startsWith(args, "--")) || length(args) != 4L) stop(pc_usage, call. = FALSE)
  list(summarize = FALSE, parts = pc_parts[pc_parts %in% parts], quick = quick, previous = args[[1L]],
       candidate = args[[2L]], deps = args[[3L]], out = args[[4L]])
}

# The three properties of a run as stored in run.csv. Only Linux x86_64 with
# all parts at measurement size is a reference run.
pc_run_kind <- function(sysname, machine, parts, quick) {
  linux <- identical(sysname, "Linux") && machine %in% c("x86_64", "amd64")
  list(platform = paste(if (identical(sysname, "Darwin")) "macOS" else sysname, machine),
       linux_x86_64 = as.character(linux), parts = paste(parts, collapse = ","),
       size = if (quick) "quick" else "measurement",
       reference = as.character(linux && setequal(parts, pc_parts) && !quick))
}

pc_headline <- function(run) {
  if (identical(run$size, "quick")) return("Smoke run – not a measurement")
  if (identical(run$reference, "TRUE")) return("Reference run")
  sprintf("Not acceptance evidence (%s, parts: %s)", run$platform, run$parts)
}

# /usr/bin/time: -l on macOS reports bytes, GNU time -v on Linux kilobytes.
pc_time_flag <- function(sysname = Sys.info()[["sysname"]]) if (identical(sysname, "Darwin")) "-l" else "-v"

# The process peak in bytes from /usr/bin/time output, NA if it is missing.
pc_parse_time <- function(lines) {
  bsd <- grep("^\\s*[0-9]+\\s+maximum resident set size\\s*$", lines, value = TRUE)
  gnu <- grep("^\\s*Maximum resident set size \\(kbytes\\):\\s*[0-9]+\\s*$", lines, value = TRUE)
  if (length(bsd) == 1L) return(as.numeric(sub("^\\s*([0-9]+).*$", "\\1", bsd)))
  if (length(gnu) == 1L) return(1024 * as.numeric(sub("^.*:\\s*([0-9]+)\\s*$", "\\1", gnu)))
  NA_real_
}

# Runs a command under /usr/bin/time; the time report goes to its own file.
pc_timed <- function(command, args, time_file, log, env = character()) {
  system2("/usr/bin/time", c(pc_time_flag(), "-o", shQuote(time_file), shQuote(command), args),
          stdout = log, stderr = log, env = env)
}

pc_check_time <- function() {
  report <- tempfile()
  on.exit(unlink(report))
  status <- suppressWarnings(tryCatch(
    system2("/usr/bin/time", c(pc_time_flag(), "-o", shQuote(report), "true"), stdout = FALSE, stderr = FALSE),
    error = function(e) 127L))
  if (status != 0L || !file.exists(report) || is.na(pc_parse_time(readLines(report)))) {
    stop("/usr/bin/time ", pc_time_flag(), " does not report the maximum resident set size; ",
         "on Linux install GNU time (package 'time').", call. = FALSE)
  }
  invisible(TRUE)
}

# Medians and flags per part, case and metric. Times are flagged above a ratio
# of 1.10 with at least 0.01 s difference, sizes with at least 1 MiB; counters
# only when the two libraries differ. A smoke run has no flags.
pc_compare <- function(measurements, smoke) {
  columns <- c("part", "case", "metric", "unit")
  empty <- data.frame(part = character(), case = character(), metric = character(), unit = character(),
                      median_previous = numeric(), median_candidate = numeric(), ratio = numeric(),
                      flag = character(), note = character())
  if (!nrow(measurements)) return(empty)
  keys <- unique(measurements[columns])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, ]
    at <- Reduce(`&`, lapply(columns, function(column) measurements[[column]] == key[[column]]))
    values <- measurements[at, ]
    previous <- values$value[values$library == "previous"]
    candidate <- values$value[values$library == "candidate"]
    median_previous <- if (length(previous)) stats::median(previous) else NA_real_
    median_candidate <- if (length(candidate)) stats::median(candidate) else NA_real_
    counter <- key$unit == "count"
    ratio <- if (!counter && !is.na(median_previous) && !is.na(median_candidate) && median_previous != 0) {
      median_candidate / median_previous
    } else NA_real_
    floor <- if (key$unit == "seconds") 0.01 else 1048576
    flag <- if (smoke) "" else if (counter) {
      if (identical(sort(previous), sort(candidate))) "" else "counters differ"
    } else if (!is.na(ratio) && round(ratio, 6) > 1.1 && round(median_candidate - median_previous, 6) >= floor) {
      "> 1.10"
    } else ""
    note <- if (key$unit == "seconds" && !is.na(median_previous) && median_previous < 0.01) "below 10 ms" else ""
    data.frame(key, median_previous = median_previous, median_candidate = median_candidate,
               ratio = round(ratio, 4), flag = flag, note = note)
  })
  result <- do.call(rbind, rows)
  rank <- match(result$metric, pc_metrics, nomatch = length(pc_metrics) + 1L)
  result <- result[order(match(result$part, pc_parts), match(result$case, unique(result$case)), rank,
                         result$metric), ]
  rownames(result) <- NULL
  result
}

# The cases a remeasurement repeats: those with a "> 1.10" flag. Counters are
# deterministic, so "counters differ" is not measured again.
pc_remeasure_cases <- function(comparison) unique(comparison$case[comparison$flag == "> 1.10"])

# The comparison of the first measurement with the remeasurement's ratio and
# flag added. `status` applies the rule to each "> 1.10" flag: "confirmed" if
# the remeasurement flags it again, "not confirmed" if not, "not remeasured"
# if the remeasurement has no value for it.
pc_compare_passes <- function(measurements, smoke) {
  first <- pc_compare(measurements[measurements$pass == "first", ], smoke)
  again <- pc_compare(measurements[measurements$pass == "remeasure", ], smoke)
  at <- match(paste(first$part, first$case, first$metric), paste(again$part, again$case, again$metric))
  first$remeasure_ratio <- again$ratio[at]
  first$remeasure_flag <- again$flag[at]
  first$status <- ifelse(first$flag != "> 1.10", "", ifelse(is.na(at), "not remeasured",
                         ifelse(first$remeasure_flag == "> 1.10", "confirmed", "not confirmed")))
  first
}

pc_utc <- function(time = Sys.time()) format(time, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
pc_parse_utc <- function(x) as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")

pc_read_keys <- function(path) {
  if (!file.exists(path)) return(list())
  table <- utils::read.csv(path, colClasses = "character", na.strings = character())
  stats::setNames(as.list(table$value), table$key)
}

pc_write_keys <- function(values, path) {
  utils::write.csv(data.frame(key = names(values), value = unlist(values, use.names = FALSE)), path,
                   row.names = FALSE)
}

pc_archive_info <- function(tarball) {
  exdir <- tempfile()
  on.exit(unlink(exdir, recursive = TRUE))
  utils::untar(tarball, files = "vennabers/DESCRIPTION", exdir = exdir)
  description <- read.dcf(file.path(exdir, "vennabers", "DESCRIPTION"), fields = c("Package", "Version"))
  if (!identical(unname(description[1L, "Package"]), "vennabers")) stop(tarball, " is not a vennabers archive.", call. = FALSE)
  list(file = basename(tarball), version = unname(description[1L, "Version"]),
       sha256 = unname(tools::sha256sum(tarball)))
}

pc_hardware <- function() {
  sysname <- Sys.info()[["sysname"]]
  read <- function(command, args) tryCatch(suppressWarnings(system2(command, args, stdout = TRUE, stderr = FALSE)),
                                           error = function(e) character())
  if (identical(sysname, "Darwin")) {
    cpu <- read("sysctl", c("-n", "machdep.cpu.brand_string"))
    ram <- read("sysctl", c("-n", "hw.memsize"))
  } else {
    info <- if (file.exists("/proc/cpuinfo")) readLines("/proc/cpuinfo") else character()
    cpu <- sub("^model name\\s*:\\s*", "", grep("^model name", info, value = TRUE)[1L])
    memory <- if (file.exists("/proc/meminfo")) grep("^MemTotal:", readLines("/proc/meminfo"), value = TRUE) else character()
    ram <- if (length(memory)) format(1024 * as.numeric(gsub("[^0-9]", "", memory)), scientific = FALSE) else character()
  }
  list(cpu = if (length(cpu) && !is.na(cpu[1L])) cpu[1L] else "unknown",
       cores = as.character(parallel::detectCores()),
       ram_bytes = if (length(ram)) ram[1L] else "unknown")
}

# The run header, written before anything is measured.
pc_run_header <- function(kind, archives, deps) {
  session <- utils::sessionInfo()
  c(kind, list(start_utc = pc_utc()), pc_hardware(),
    list(os = session$running, r = R.version.string, blas = session$BLAS, lapack = La_library(),
         threads = paste(names(pc_thread_env), pc_thread_env, sep = "=", collapse = " "),
         deps_lib = deps),
    stats::setNames(unlist(archives$previous, use.names = FALSE), paste0("previous_", names(archives$previous))),
    stats::setNames(unlist(archives$candidate, use.names = FALSE), paste0("candidate_", names(archives$candidate))))
}

pc_derived_keys <- function(run) {
  parts <- strsplit(run$parts, ",", fixed = TRUE)[[1L]]
  fields <- c("wall_seconds_", "exit_", "failed_cases_", "remeasured_", "wall_seconds_remeasure_", "exit_remeasure_")
  c("end_utc", "wall_seconds_total", paste0(rep(fields, length(parts)), rep(parts, each = length(fields))))
}

# Derived fields of run.csv from each part's status.csv and that of its
# remeasurement; a part without remeasurement has empty remeasure fields.
pc_derive <- function(run, out) {
  parts <- strsplit(run$parts, ",", fixed = TRUE)[[1L]]
  derived <- list()
  ends <- character()
  for (part in parts) {
    status <- pc_read_keys(file.path(out, part, "status.csv"))
    again <- pc_read_keys(file.path(out, paste0(part, "-remeasure"), "status.csv"))
    derived[[paste0("wall_seconds_", part)]] <- status$wall_seconds %||% ""
    derived[[paste0("exit_", part)]] <- status$exit %||% "not run"
    derived[[paste0("failed_cases_", part)]] <- status$failed_cases %||% ""
    derived[[paste0("remeasured_", part)]] <- again$cases %||% ""
    derived[[paste0("wall_seconds_remeasure_", part)]] <- again$wall_seconds %||% ""
    derived[[paste0("exit_remeasure_", part)]] <- again$exit %||% ""
    ends <- c(ends, status$end_utc, again$end_utc)
  }
  end <- if (length(ends)) max(ends) else ""
  total <- if (nzchar(end)) {
    format(round(as.numeric(difftime(pc_parse_utc(end), pc_parse_utc(run$start_utc), units = "secs")), 3))
  } else ""
  c(list(end_utc = end, wall_seconds_total = total), derived)
}

pc_empty_long <- function() {
  data.frame(part = character(), case = character(), library = character(), run = integer(), metric = character(),
             value = numeric(), unit = character())
}

pc_read_long <- function(path) {
  if (!file.exists(path)) return(pc_empty_long()[-1L])
  utils::read.csv(path, colClasses = c("character", "character", "integer", "character", "numeric", "character"),
                  na.strings = "")
}

run_part_new <- function(context) {
  script <- file.path(context$tools, "benchmark-v11.R")
  log <- file.path(context$dir, "part.log")
  status <- system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(script), if (context$quick) "--quick",
      if (length(context$cases)) c("--cases", paste(context$cases, collapse = ",")), shQuote(context$previous_lib),
      shQuote(context$candidate_lib), shQuote(context$deps), shQuote(context$dir)), stdout = log, stderr = log)
  failed <- file.path(context$dir, "failed-cases.txt")
  list(exit = status, failed_cases = if (file.exists(failed)) readLines(failed) else character())
}

# Part new writes the long form itself; the reader only adds the part.
read_part_new <- function(dir) {
  long <- pc_read_long(file.path(dir, "measurements.csv"))
  data.frame(part = rep("new", nrow(long)), long)
}

# Part performance: tools/performance.R (v0.3-v0.7) in library mode, the
# candidate library first as the script expects. It refuses measurements
# outside Linux x86_64, so other platforms get --smoke; --quick changes nothing
# here.
pc_performance_command <- function(context) {
  list(args = c("--vanilla", shQuote(file.path(context$tools, "performance.R")), shQuote(context$candidate_lib),
                shQuote(context$previous_lib), shQuote(file.path(context$dir, "output")),
                "--previous-version", context$previous_version, if (!context$linux_x86_64) "--smoke",
                if (length(context$cases)) c("--cases", paste(context$cases, collapse = ","))),
       env = paste0("R_LIBS=", shQuote(paste(context$candidate_lib, context$deps, sep = .Platform$path.sep))))
}

# performance.R stops at the first failure; its log names each case before it starts.
pc_performance_failed <- function(lines) {
  started <- grep("^(current|previous) \\S+ ?$", lines, value = TRUE)
  if (length(started)) trimws(sub("^\\S+ ", "", started[[length(started)]])) else character()
}

run_part_performance <- function(context) {
  command <- pc_performance_command(context)
  log <- file.path(context$dir, "part.log")
  status <- system2(file.path(R.home("bin"), "Rscript"), command$args, stdout = log, stderr = log, env = command$env)
  list(exit = status, failed_cases = if (status != 0L && file.exists(log)) pc_performance_failed(readLines(log)) else character())
}

pc_performance_counters <- c("fit_count", "retained_models", "outer_fit_count")
pc_performance_units <- c(stats::setNames(rep("seconds", 6L), pc_metrics[endsWith(pc_metrics, "_seconds")]),
                          rds_bytes = "bytes", stats::setNames(rep("count", 3L), pc_performance_counters))

# The metrics a case has, decided from its input as the measuring process does:
# outer resampling only for unfrozen workflows, schema and encoding only with a
# schema. The script records the phases a case skips as 0; they get no row.
pc_performance_metrics <- function(input) {
  has <- c(outer_seconds = isTRUE(input$integration) && !isTRUE(input$frozen),
           schema_seconds = !is.null(input$schema), encode_seconds = !is.null(input$schema),
           decode_seconds = !is.null(input$schema))
  metrics <- names(pc_performance_units)
  metrics[!metrics %in% names(has) | metrics %in% names(has)[has]]
}

# The single values per iteration from <release>-<case>-runs.csv, in plan
# order, previous before candidate (current). Iteration 0 is the warm-up. One
# process per case and library makes its peak one value with an empty run.
read_part_performance <- function(dir) {
  output <- file.path(dir, "output")
  files <- list.files(output)
  parsed <- regmatches(files, regexec("^(current|previous)-(.+)-runs\\.csv$", files))
  files <- files[lengths(parsed) == 3L]
  release <- vapply(parsed[lengths(parsed) == 3L], `[[`, "", 2L)
  case <- vapply(parsed[lengths(parsed) == 3L], `[[`, "", 3L)
  plan <- file.path(output, "plan.csv")
  cases <- unique(c(if (file.exists(plan)) utils::read.csv(plan)$case, case))
  metrics <- lapply(stats::setNames(nm = unique(case)), function(id) {
    pc_performance_metrics(readRDS(file.path(output, paste0(id, "-input.rds"))))
  })
  long <- lapply(order(match(case, cases), match(release, c("previous", "current"))), function(i) {
    runs <- utils::read.csv(file.path(output, files[[i]]))
    runs <- runs[runs$iteration > 0L, ]
    library <- if (release[[i]] == "current") "candidate" else "previous"
    values <- do.call(rbind, lapply(metrics[[case[[i]]]], function(metric) {
      data.frame(case = rep(case[[i]], nrow(runs)), library = library, run = runs$iteration, metric = metric,
                 value = as.numeric(runs[[metric]]), unit = pc_performance_units[[metric]])
    }))
    peak <- unique(runs$process_peak_bytes)
    if (length(peak) > 1L) stop(files[[i]], " has more than one process peak.", call. = FALSE)
    rbind(values, if (length(peak)) data.frame(case = case[[i]], library = library, run = NA_integer_,
                                               metric = "process_peak_bytes", value = peak, unit = "bytes"))
  })
  long <- do.call(rbind, c(list(pc_empty_long()[-1L]), long))
  data.frame(part = rep("performance", nrow(long)), long)
}

# Parts shared (v0.8) and v09: tools/run-benchmarks-v09.sh with only the
# part's cases, run from the repository root with this R's Rscript first on
# PATH. The runner sets R_LIBS=<lib>:<deps-lib> per case; BENCH_QUICK=1 makes
# one measured run and skips the tuned cases; BENCH_CASES limits the cases.
pc_runner_command <- function(context, part) {
  list(args = c(shQuote(file.path(context$tools, "run-benchmarks-v09.sh")), shQuote(context$candidate_lib),
                shQuote(context$previous_lib), shQuote(context$deps), shQuote(file.path(context$dir, "output")), part),
       env = c(paste0("PATH=", shQuote(paste(R.home("bin"), Sys.getenv("PATH"), sep = .Platform$path.sep))),
               paste0("BENCH_QUICK=", if (context$quick) 1L else 0L),
               if (length(context$cases)) paste0("BENCH_CASES=", paste(context$cases, collapse = ","))))
}

# The cases of `part` in the runner's log, in order, from its done and FAILED lines.
pc_runner_cases <- function(lines, part, status = c("done", "FAILED")) {
  pattern <- sprintf("^(%s) %s-(previous|candidate)-(.+)$", paste(status, collapse = "|"), part)
  unique(sub(pattern, "\\3", grep(pattern, lines, value = TRUE)))
}

pc_run_runner <- function(context, part) {
  # The measurement size is the scripts' default, whatever the calling shell set.
  Sys.unsetenv(c("BENCH_REPS", "BENCH_ROWS"))
  command <- pc_runner_command(context, part)
  log <- file.path(context$dir, "part.log")
  owd <- setwd(dirname(context$tools))
  on.exit(setwd(owd))
  status <- system2("sh", command$args, stdout = log, stderr = log, env = command$env)
  list(exit = status, failed_cases = if (file.exists(log)) pc_runner_cases(readLines(log), part, "FAILED") else character())
}

run_part_shared <- function(context) pc_run_runner(context, "shared")
run_part_v09 <- function(context) pc_run_runner(context, "v09")

# The single values of each case and library from <part>-<library>-<case>.rds
# in log order, previous before candidate, with `values` mapping one measured
# run to named metrics; NA and NULL values are phases or counters the case does
# not have. The process peak comes from the case's .time file with an empty run.
pc_read_runner <- function(dir, part, values) {
  output <- file.path(dir, "output")
  files <- list.files(output)
  parsed <- regmatches(files, regexec(sprintf("^%s-(previous|candidate)-(.+)\\.rds$", part), files))
  files <- files[lengths(parsed) == 3L]
  library <- vapply(parsed[lengths(parsed) == 3L], `[[`, "", 2L)
  case <- vapply(parsed[lengths(parsed) == 3L], `[[`, "", 3L)
  log <- file.path(dir, "part.log")
  cases <- unique(c(if (file.exists(log)) pc_runner_cases(readLines(log), part), sort(case)))
  long <- lapply(order(match(case, cases), match(library, c("previous", "candidate"))), function(i) {
    runs <- lapply(readRDS(file.path(output, files[[i]]))$repetitions, function(run) {
      value <- values(run)
      value[!is.na(value)]
    })
    metrics <- unique(unlist(lapply(runs, names)))
    rows <- do.call(rbind, lapply(metrics, function(metric) {
      data.frame(case = case[[i]], library = library[[i]], run = seq_along(runs), metric = metric,
                 value = vapply(runs, function(run) run[[metric]], 0),
                 unit = if (endsWith(metric, "_seconds")) "seconds" else if (endsWith(metric, "_bytes")) "bytes" else "count")
    }))
    time <- file.path(output, sub("\\.rds$", ".time", files[[i]]))
    peak <- if (file.exists(time)) pc_parse_time(readLines(time, warn = FALSE)) else NA_real_
    rbind(rows, if (!is.na(peak)) data.frame(case = case[[i]], library = library[[i]], run = NA_integer_,
                                             metric = "process_peak_bytes", value = peak, unit = "bytes"))
  })
  long <- do.call(rbind, c(list(pc_empty_long()[-1L]), long))
  data.frame(part = rep(part, nrow(long)), long)
}

# benchmark-shared-v09.R: no heap; IVAP has no outer resampling and no counters.
read_part_shared <- function(dir) {
  pc_read_runner(dir, "shared", function(run) {
    unlist(list(fit_seconds = run$fit, predict_seconds = run$predict, outer_seconds = run$outer,
                rds_bytes = run$bytes, base_fits = run$base_fits, retained = run$retained))
  })
}

# benchmark-v09.R: the heap per phase in MiB becomes bytes; the tuning counter
# exists only for the tuned case.
read_part_v09 <- function(dir) {
  pc_read_runner(dir, "v09", function(run) {
    unlist(c(list(fit_seconds = run$fit, predict_seconds = run$predict, outer_seconds = run$outer,
                  fit_heap_bytes = run$fit_heap_mib * 1048576, predict_heap_bytes = run$predict_heap_mib * 1048576,
                  outer_heap_bytes = run$outer_heap_mib * 1048576, rds_bytes = run$rds_bytes), run$counters))
  })
}

pc_mib <- function(x) ifelse(is.na(x), "–", sprintf("%.1f", x / 1048576))
pc_seconds <- function(x) ifelse(is.na(x), "–", sprintf("%.3f", x))
pc_ratio <- function(x) ifelse(is.na(x), "–", sprintf("%.2f", x))
pc_count <- function(x) ifelse(is.na(x), "–", formatC(x, format = "d", big.mark = ","))
pc_value <- function(x, unit) {
  ifelse(is.na(x), "–", ifelse(unit == "seconds", paste(pc_seconds(x), "s"),
                               ifelse(unit == "bytes", paste(pc_mib(x), "MiB"), pc_count(x))))
}
pc_gib <- function(bytes) {
  values <- suppressWarnings(as.numeric(strsplit(bytes %||% "", " | ", fixed = TRUE)[[1L]]))
  if (!length(values) || anyNA(values)) "unknown" else paste(sprintf("%.0f GiB", values / 1024^3), collapse = " | ")
}
pc_clock <- function(seconds) {
  if (is.null(seconds) || !nzchar(seconds)) return("–")
  s <- round(as.numeric(seconds))
  sprintf("%d:%02d:%02d", s %/% 3600, s %/% 60 %% 60, s %% 60)
}

# The full table of the nine new cases, whatever ran.
pc_new_table <- function(comparison, plan) {
  metric_label <- c(fit_seconds = "time", predict_seconds = "time", process_peak_bytes = "peak",
                    fit_heap_bytes = "heap", predict_heap_bytes = "heap", rds_bytes = "RDS")
  rows <- vapply(pc_new_cases$case, function(case) {
    values <- comparison[comparison$part == "new" & comparison$case == case, ]
    pick <- function(metrics, column) {
      found <- values[[column]][values$metric %in% metrics]
      if (length(found)) found[[1L]] else NA_real_
    }
    time <- c("fit_seconds", "predict_seconds")
    heap <- c("fit_heap_bytes", "predict_heap_bytes")
    planned <- plan[plan$case == case, , drop = FALSE]
    at <- nzchar(values$flag)
    flagged <- unique(trimws(paste(metric_label[values$metric[at]], values$status[at])))
    notes <- unique(values$note[nzchar(values$note)])
    flag <- paste(c(if (length(flagged)) sprintf("> 1.10 (%s)", paste(flagged, collapse = ", ")), notes),
                  collapse = "; ")
    sprintf("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |", case,
            pc_count(if (nrow(planned)) planned$rows else NA), pc_count(if (nrow(planned)) planned$knots else NA),
            pc_seconds(pick(time, "median_previous")), pc_seconds(pick(time, "median_candidate")),
            pc_ratio(pick(time, "ratio")),
            pc_mib(pick("process_peak_bytes", "median_previous")), pc_mib(pick("process_peak_bytes", "median_candidate")),
            pc_ratio(pick("process_peak_bytes", "ratio")),
            pc_mib(pick(heap, "median_candidate")), pc_ratio(pick(heap, "ratio")),
            pc_mib(pick("rds_bytes", "median_candidate")), flag)
  }, "")
  c("| Case | Rows | Knots | Time previous (s) | Time candidate (s) | Ratio | Peak previous (MiB) | Peak candidate (MiB) | Ratio | Heap candidate (MiB) | Ratio | RDS candidate (MiB) | Flag |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    unname(rows))
}

pc_summary <- function(run, comparison, plan) {
  parts <- strsplit(run$parts, ",", fixed = TRUE)[[1L]]
  walls <- vapply(parts, function(part) sprintf("%s %s (exit %s)", part, pc_clock(run[[paste0("wall_seconds_", part)]]),
                                                run[[paste0("exit_", part)]] %||% "not run"), "")
  failed_parts <- parts[vapply(parts, function(part) !identical(run[[paste0("exit_", part)]], "0"), TRUE)]
  failed_again <- parts[vapply(parts, function(part) !(run[[paste0("exit_remeasure_", part)]] %||% "") %in% c("", "0"), TRUE)]
  failed <- if (length(failed_parts) || length(failed_again)) {
    paste(c(vapply(failed_parts, function(part) {
      cases <- run[[paste0("failed_cases_", part)]] %||% ""
      if (nzchar(cases)) sprintf("%s (cases: %s)", part, gsub(";", ", ", cases)) else part
    }, ""), if (length(failed_again)) paste(failed_again, "remeasure")), collapse = "; ")
  } else "none"
  remeasured_parts <- parts[vapply(parts, function(part) nzchar(run[[paste0("remeasured_", part)]] %||% ""), TRUE)]
  remeasured <- if (length(remeasured_parts)) {
    paste(vapply(remeasured_parts, function(part) {
      sprintf("%s %s (exit %s; cases: %s)", part, pc_clock(run[[paste0("wall_seconds_remeasure_", part)]]),
              run[[paste0("exit_remeasure_", part)]], gsub(";", ", ", run[[paste0("remeasured_", part)]]))
    }, ""), collapse = "; ")
  } else "none"
  combined <- if (!is.null(run$combined_runs)) {
    hosts <- vapply(parts, function(part) {
      sprintf("%s on %s, %s cores, %s", part, run[[paste0("cpu_", part)]], run[[paste0("cores_", part)]],
              pc_gib(run[[paste0("ram_bytes_", part)]]))
    }, "")
    c(sprintf("- Combined from %s runs, each measuring both libraries: %s", run$combined_runs,
              paste(hosts, collapse = "; ")),
      if (identical(run$packages, "differ")) "- Dependencies differ between the runs; see packages.csv")
  }
  archive <- function(role) sprintf("%s vennabers %s (`%s`, SHA-256 %s…)", role, run[[paste0(role, "_version")]],
                                    run[[paste0(role, "_file")]], substr(run[[paste0(role, "_sha256")]], 1L, 12L))
  historical <- setdiff(parts, "new")
  history <- if (length(historical)) {
    counts <- vapply(historical, function(part) {
      values <- comparison[comparison$part == part, ]
      sprintf("- %s: %d cases, %d flagged, %d confirmed", part, length(unique(values$case)),
              length(unique(values$case[nzchar(values$flag)])), length(unique(values$case[values$status == "confirmed"])))
    }, "")
    flagged <- comparison[comparison$part %in% historical & nzchar(comparison$flag), ]
    c("", "## Historical parts", "", unname(counts),
      if (nrow(flagged)) c("", "| Part | Case | Metric | Previous | Candidate | Ratio | Flag | Remeasure | Status |",
        "| --- | --- | --- | ---: | ---: | ---: | --- | ---: | --- |",
        sprintf("| %s | `%s` | %s | %s | %s | %s | %s | %s | %s |", flagged$part, flagged$case, flagged$metric,
                pc_value(flagged$median_previous, flagged$unit), pc_value(flagged$median_candidate, flagged$unit),
                pc_ratio(flagged$ratio), flagged$flag, pc_ratio(flagged$remeasure_ratio), flagged$status)))
  }
  c("# Performance comparison",
    "",
    sprintf("**%s**", pc_headline(run)),
    "",
    sprintf("- Platform: %s; %s, %s cores, %s RAM; %s", run$platform, run$cpu, run$cores, pc_gib(run$ram_bytes),
            run$os),
    sprintf("- R: %s; BLAS %s; LAPACK %s; %s", run$r, run$blas, run$lapack, run$threads),
    sprintf("- Archives: %s; %s", archive("previous"), archive("candidate")),
    sprintf("- Wall time: %s; total %s", paste(walls, collapse = ", "), pc_clock(run$wall_seconds_total)),
    sprintf("- Remeasured: %s", remeasured),
    sprintf("- Failed: %s", failed),
    combined,
    "",
    "## New performance cases",
    "",
    pc_new_table(comparison, plan),
    history)
}

# The single values of all parts with their pass: "first" from <part>/,
# "remeasure" from <part>-remeasure/. A combined run takes them from the
# measurements.csv of each joined run under runs/.
pc_gather <- function(out, run) {
  parts <- strsplit(run$parts, ",", fixed = TRUE)[[1L]]
  if (!is.null(run$combined_runs)) {
    files <- file.path(list.dirs(file.path(out, "runs"), recursive = FALSE), "measurements.csv")
    long <- lapply(files, function(path) {
      utils::read.csv(path, colClasses = c("character", "character", "character", "integer", "character", "numeric",
                                           "character", "character"), na.strings = "")
    })
    long <- do.call(rbind, c(list(pc_empty_measurements()), long))
    long <- long[long$part %in% parts, ]
    long <- long[order(match(long$part, pc_parts), match(long$pass, c("first", "remeasure"))), ]
    rownames(long) <- NULL
    return(long)
  }
  passes <- c(first = "", remeasure = "-remeasure")
  do.call(rbind, c(list(pc_empty_measurements()), unlist(lapply(parts, function(part) {
    lapply(names(passes), function(pass) {
      dir <- file.path(out, paste0(part, passes[[pass]]))
      if (dir.exists(dir)) {
        long <- pc_part_function("read", part)(dir)
        data.frame(long, pass = rep(pass, nrow(long)))
      }
    })
  }), recursive = FALSE)))
}

pc_empty_measurements <- function() data.frame(pc_empty_long(), pass = character())

# Rebuilds measurements.csv, comparison.csv, summary.md and the derived fields
# of run.csv from the raw outputs under `out`. It never measures.
pc_summarize <- function(out) {
  run <- pc_read_keys(file.path(out, "run.csv"))
  if (!length(run)) stop("No run.csv in ", out, call. = FALSE)
  run <- c(run[setdiff(names(run), pc_derived_keys(run))], pc_derive(run, out))
  pc_write_keys(run, file.path(out, "run.csv"))
  measurements <- pc_gather(out, run)
  utils::write.csv(measurements, file.path(out, "measurements.csv"), row.names = FALSE, na = "")
  comparison <- pc_compare_passes(measurements, smoke = identical(run$size, "quick"))
  utils::write.csv(comparison, file.path(out, "comparison.csv"), row.names = FALSE, na = "")
  plan_file <- file.path(out, "new", "plan.csv")
  plan <- if (file.exists(plan_file)) utils::read.csv(plan_file) else data.frame(case = character())
  summary <- pc_summary(run, comparison, plan)
  writeLines(summary, file.path(out, "summary.md"))
  invisible(summary)
}

# Keys every joined run must share, and host keys that may differ between CI
# jobs; the latter are kept per part.
pc_shared_keys <- c("platform", "linux_x86_64", "size", "r", "threads", "previous_file", "previous_version",
                    "previous_sha256", "candidate_file", "candidate_version", "candidate_sha256")
pc_host_keys <- c("cpu", "cores", "ram_bytes", "os", "blas", "lapack", "deps_lib")

# Joins summarized runs of disjoint parts into one run under `out`: run.csv,
# packages.csv and measurements.csv of each go to runs/<parts>/, the status
# files of each part (and the plan of part new) to <out>/<part>/. Only Linux
# x86_64 runs of all four parts at measurement size make a reference run.
pc_combine <- function(out, runs) {
  if (dir.exists(out) && length(list.files(out, all.files = TRUE, no.. = TRUE))) {
    stop(out, " is not empty; combining needs an empty output directory.", call. = FALSE)
  }
  runs <- normalizePath(runs, mustWork = TRUE)
  headers <- lapply(runs, function(dir) {
    run <- pc_read_keys(file.path(dir, "run.csv"))
    if (!length(run) || !file.exists(file.path(dir, "measurements.csv"))) {
      stop(dir, " holds no summarized run.", call. = FALSE)
    }
    if (!is.null(run$combined_runs)) stop(dir, " is already a combined run.", call. = FALSE)
    run
  })
  parts <- lapply(headers, function(run) strsplit(run$parts, ",", fixed = TRUE)[[1L]])
  twice <- unique(unlist(parts)[duplicated(unlist(parts))])
  if (length(twice)) stop("More than one run has part(s) ", paste(twice, collapse = ", "), ".", call. = FALSE)
  for (key in pc_shared_keys) {
    values <- unique(vapply(headers, function(run) run[[key]] %||% "", ""))
    if (length(values) > 1L) stop("The runs differ in ", key, ": ", paste(values, collapse = " / "), call. = FALSE)
  }
  first <- headers[[1L]]
  all <- pc_parts[pc_parts %in% unlist(parts)]
  run <- first[setdiff(names(first), pc_derived_keys(first))]
  run$parts <- paste(all, collapse = ",")
  run$reference <- as.character(identical(first$linux_x86_64, "TRUE") && setequal(all, pc_parts) &&
                                  identical(first$size, "measurement"))
  run$start_utc <- min(vapply(headers, function(header) header$start_utc, ""))
  for (key in pc_host_keys) {
    run[[key]] <- paste(unique(vapply(headers, function(header) header[[key]] %||% "unknown", "")), collapse = " | ")
  }
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  out <- normalizePath(out)
  packages <- list()
  for (i in seq_along(runs)) {
    target <- file.path(out, "runs", paste(parts[[i]], collapse = "+"))
    dir.create(target, recursive = TRUE)
    file.copy(file.path(runs[[i]], c("run.csv", "packages.csv", "measurements.csv")), target)
    for (part in parts[[i]]) {
      for (key in c("cpu", "cores", "ram_bytes")) run[[paste0(key, "_", part)]] <- headers[[i]][[key]] %||% "unknown"
      for (dir in c(part, paste0(part, "-remeasure"))) {
        files <- file.path(runs[[i]], dir, c("status.csv", if (dir == "new") "plan.csv"))
        files <- files[file.exists(files)]
        if (length(files)) {
          dir.create(file.path(out, dir))
          file.copy(files, file.path(out, dir))
        }
      }
    }
    packages[[i]] <- utils::read.csv(file.path(runs[[i]], "packages.csv"), colClasses = "character")
  }
  same <- all(vapply(packages, identical, TRUE, packages[[1L]]))
  run$packages <- if (same) "identical" else "differ"
  run$combined_runs <- as.character(length(runs))
  utils::write.csv(if (same) packages[[1L]] else do.call(rbind, lapply(seq_along(packages), function(i) {
    data.frame(packages[[i]], parts = rep(paste(parts[[i]], collapse = "+"), nrow(packages[[i]])))
  })), file.path(out, "packages.csv"), row.names = FALSE)
  pc_write_keys(run, file.path(out, "run.csv"))
  pc_summarize(out)
}

# Runs one part into context$dir and writes its status.csv; a remeasurement
# (context$cases) also records its cases.
pc_run_part <- function(part, context) {
  dir.create(context$dir)
  label <- if (length(context$cases)) paste(part, "remeasure") else paste("part", part)
  start <- Sys.time()
  message("Running ", label, " ...")
  result <- tryCatch(pc_part_function("run", part)(context), error = function(e) {
    message(label, " failed: ", conditionMessage(e))
    list(exit = 1L, failed_cases = character())
  })
  end <- Sys.time()
  pc_write_keys(c(list(start_utc = pc_utc(start), end_utc = pc_utc(end),
                       wall_seconds = format(round(as.numeric(difftime(end, start, units = "secs")), 3)),
                       exit = as.character(result$exit), failed_cases = paste(result$failed_cases, collapse = ";")),
                  if (length(context$cases)) list(cases = paste(context$cases, collapse = ";"))),
                file.path(context$dir, "status.csv"))
  message(label, " ended with exit ", result$exit)
  invisible(result)
}

# Runs a part and, at measurement size, once more for its flagged cases.
pc_run_with_remeasure <- function(part, context, out) {
  pc_run_part(part, c(context, list(dir = file.path(out, part))))
  if (context$quick) return(invisible(character()))
  long <- tryCatch(pc_part_function("read", part)(file.path(out, part)), error = function(e) {
    message("Reading part ", part, " for the remeasurement failed: ", conditionMessage(e))
    NULL
  })
  cases <- if (!is.null(long)) pc_remeasure_cases(pc_compare(long, smoke = FALSE)) else character()
  if (length(cases)) pc_run_part(part, c(context, list(dir = file.path(out, paste0(part, "-remeasure")), cases = cases)))
  invisible(cases)
}

pc_install <- function(tarball, lib, log) {
  dir.create(lib, showWarnings = FALSE)
  status <- system2(file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--no-docs", "--no-html", paste0("--library=", shQuote(lib)), shQuote(tarball)),
    stdout = log, stderr = log)
  if (status != 0L) stop("Installing ", tarball, " failed; see ", log, call. = FALSE)
}

# A process with the parts' R_LIBS must load vennabers from `lib` in `version`.
pc_probe <- function(lib, deps, version) {
  found <- system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", "-e", shQuote('cat(dirname(find.package("vennabers")), format(packageVersion("vennabers")), sep = "\\n")')),
    stdout = TRUE, stderr = FALSE, env = paste0("R_LIBS=", shQuote(paste(lib, deps, sep = .Platform$path.sep))))
  if (length(found) != 2L || !identical(normalizePath(found[[1L]]), normalizePath(lib)) || !identical(found[[2L]], version)) {
    stop("With R_LIBS=", lib, ":", deps, " vennabers loads as '", paste(found, collapse = " "), "', not ", version,
         " from ", lib, call. = FALSE)
  }
}

pc_main <- function(args, tools) {
  options <- pc_parse_args(args)
  if (options$summarize) {
    writeLines(pc_summarize(normalizePath(options$out)))
    return(0L)
  }
  if (isTRUE(options$combine)) {
    writeLines(pc_combine(options$out, options$runs))
    return(0L)
  }
  if (dir.exists(options$out) && length(list.files(options$out, all.files = TRUE, no.. = TRUE))) {
    stop(options$out, " is not empty; every run needs an empty output directory.", call. = FALSE)
  }
  tarballs <- c(previous = normalizePath(options$previous, mustWork = TRUE),
                candidate = normalizePath(options$candidate, mustWork = TRUE))
  deps <- normalizePath(options$deps, mustWork = TRUE)
  pc_check_time()
  dir.create(options$out, showWarnings = FALSE, recursive = TRUE)
  out <- normalizePath(options$out)
  archives <- lapply(tarballs, pc_archive_info)
  kind <- pc_run_kind(Sys.info()[["sysname"]], Sys.info()[["machine"]], options$parts, options$quick)
  packages <- utils::installed.packages(lib.loc = deps)[, c("Package", "Version"), drop = FALSE]
  utils::write.csv(data.frame(package = packages[, "Package"], version = packages[, "Version"])[
    order(packages[, "Package"]), ], file.path(out, "packages.csv"), row.names = FALSE)
  run <- pc_run_header(kind, archives, deps)
  pc_write_keys(run, file.path(out, "run.csv"))
  libs <- c(previous = file.path(out, "previous-lib"), candidate = file.path(out, "candidate-lib"))
  for (role in names(libs)) {
    pc_install(tarballs[[role]], libs[[role]], file.path(out, paste0(role, "-install.log")))
    pc_probe(libs[[role]], deps, archives[[role]]$version)
  }
  do.call(Sys.setenv, as.list(pc_thread_env))
  context <- list(previous_lib = libs[["previous"]], candidate_lib = libs[["candidate"]], deps = deps,
                  previous_version = archives$previous$version, quick = options$quick,
                  linux_x86_64 = identical(kind$linux_x86_64, "TRUE"), tools = tools)
  for (part in options$parts) pc_run_with_remeasure(part, context, out)
  writeLines(pc_summarize(out))
  run <- pc_read_keys(file.path(out, "run.csv"))
  ok <- vapply(options$parts, function(part) {
    identical(run[[paste0("exit_", part)]], "0") && run[[paste0("exit_remeasure_", part)]] %in% c("", "0")
  }, TRUE)
  if (all(ok)) 0L else 1L
}

if (sys.nframe() == 0L) {
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
  status <- pc_main(commandArgs(trailingOnly = TRUE), dirname(script))
  if (status != 0L) quit(status = status)
}
