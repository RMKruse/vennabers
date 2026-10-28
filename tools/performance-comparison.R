# Performance comparison of two releases (RELEASE-ROADMAP-1.x.md §3.4 and §4,
# RELEASE-ROADMAP.md §3.5). Run from the repository root:
#   Rscript --vanilla tools/performance-comparison.R [--parts new,performance,shared,v09] [--quick] \
#     <previous.tar.gz> <candidate.tar.gz> <deps-lib> <out>
#   Rscript --vanilla tools/performance-comparison.R --summarize <out>
# <out> must be empty or missing. Keep it under venn-abers-candidates/; only
# summary.md goes to .scratch. Both archives are installed once into <out>,
# and every measuring process runs with R_LIBS=<lib>:<deps-lib>.
#
# The comparison has four parts, run serially in this order: new (the nine
# performance cases of 1.1), performance (v0.3-v0.7), shared (v0.8) and v09.
# Each part has a start function run_part_<name>(context) and a reader
# read_part_<name>(dir) that turns its raw outputs into the long form. A failed
# part does not stop the others, but the run then exits with status 1. Flags
# never fail a run. --summarize rebuilds measurements.csv, comparison.csv,
# summary.md and the derived fields of run.csv from the raw outputs without
# measuring. Not part of R CMD check.

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

# Parts that later tickets build. Their start function and reader fail with
# the ticket that builds them; the starter rejects them before it starts.
pc_placeholder <- function(part, ticket) {
  structure(function(...) stop("Part '", part, "' is not built yet (", ticket, ").", call. = FALSE),
            placeholder = ticket)
}
run_part_shared <- pc_placeholder("shared", "ticket 11, #88")
read_part_shared <- pc_placeholder("shared", "ticket 11, #88")
run_part_v09 <- pc_placeholder("v09", "ticket 11, #88")
read_part_v09 <- pc_placeholder("v09", "ticket 11, #88")

pc_part_function <- function(kind, part) get(paste0(kind, "_part_", part), mode = "function")

# The requested parts that are still placeholders, named by part.
pc_unbuilt <- function(parts) {
  tickets <- vapply(parts, function(part) attr(pc_part_function("run", part), "placeholder") %||% NA_character_, "")
  tickets[!is.na(tickets)]
}

pc_usage <- paste(
  "Usage: Rscript --vanilla tools/performance-comparison.R [--parts new,performance,shared,v09] [--quick]",
  "<previous.tar.gz> <candidate.tar.gz> <deps-lib> <out>",
  "\n       Rscript --vanilla tools/performance-comparison.R --summarize <out>")

pc_parse_args <- function(args) {
  if (length(args) && args[[1L]] == "--summarize") {
    if (length(args) != 2L) stop(pc_usage, call. = FALSE)
    return(list(summarize = TRUE, out = args[[2L]]))
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
  unbuilt <- pc_unbuilt(pc_parts[pc_parts %in% parts])
  if (length(unbuilt)) {
    stop("Not built yet: ", paste(sprintf("part '%s' (%s)", names(unbuilt), unbuilt), collapse = ", "),
         ". Pass --parts with built parts only, such as --parts new.", call. = FALSE)
  }
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
  c("end_utc", "wall_seconds_total", paste0(rep(c("wall_seconds_", "exit_", "failed_cases_"), length(parts)),
                                           rep(parts, each = 3L)))
}

# Derived fields of run.csv from each part's status.csv.
pc_derive <- function(run, out) {
  parts <- strsplit(run$parts, ",", fixed = TRUE)[[1L]]
  derived <- list()
  ends <- character()
  for (part in parts) {
    status <- pc_read_keys(file.path(out, part, "status.csv"))
    derived[[paste0("wall_seconds_", part)]] <- status$wall_seconds %||% ""
    derived[[paste0("exit_", part)]] <- status$exit %||% "not run"
    derived[[paste0("failed_cases_", part)]] <- status$failed_cases %||% ""
    if (!is.null(status$end_utc)) ends <- c(ends, status$end_utc)
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
    c("--vanilla", shQuote(script), if (context$quick) "--quick", shQuote(context$previous_lib),
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
# candidate first as the script expects. It refuses measurements outside
# Linux x86_64, so other platforms get --smoke; --quick changes nothing here.
pc_performance_command <- function(context) {
  list(args = c("--vanilla", shQuote(file.path(context$tools, "performance.R")), shQuote(context$candidate_lib),
                shQuote(context$previous_lib), shQuote(file.path(context$dir, "output")),
                "--previous-version", context$previous_version, if (!context$linux_x86_64) "--smoke"),
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

pc_performance_seconds <- c("fit_seconds", "predict_seconds", "outer_seconds", "schema_seconds", "encode_seconds",
                            "decode_seconds")
pc_performance_counters <- c("fit_count", "retained_models", "outer_fit_count")

# The single values per iteration from <release>-<case>-runs.csv, in plan
# order, previous before candidate (current). Iteration 0 is the warm-up. The
# script records times it does not measure as 0. One process per case and
# library makes its peak one value with an empty run.
read_part_performance <- function(dir) {
  output <- file.path(dir, "output")
  files <- list.files(output, pattern = "^(current|previous)-.+-runs\\.csv$")
  release <- sub("^(current|previous)-.*$", "\\1", files)
  case <- sub("^(current|previous)-(.+)-runs\\.csv$", "\\2", files)
  plan <- file.path(output, "plan.csv")
  cases <- unique(c(if (file.exists(plan)) utils::read.csv(plan)$case, case))
  metrics <- c(pc_performance_seconds, "rds_bytes", pc_performance_counters)
  units <- ifelse(metrics %in% pc_performance_seconds, "seconds", ifelse(metrics == "rds_bytes", "bytes", "count"))
  long <- lapply(order(match(case, cases), match(release, c("previous", "current"))), function(i) {
    runs <- utils::read.csv(file.path(output, files[[i]]))
    runs <- runs[runs$iteration > 0L, ]
    library <- if (release[[i]] == "current") "candidate" else "previous"
    values <- do.call(rbind, lapply(seq_along(metrics), function(m) {
      data.frame(case = rep(case[[i]], nrow(runs)), library = library, run = runs$iteration, metric = metrics[[m]],
                 value = as.numeric(runs[[metrics[[m]]]]), unit = units[[m]])
    }))
    peak <- unique(runs$process_peak_bytes)
    if (length(peak) > 1L) stop(files[[i]], " has more than one process peak.", call. = FALSE)
    rbind(values, if (length(peak)) data.frame(case = case[[i]], library = library, run = NA_integer_,
                                               metric = "process_peak_bytes", value = peak, unit = "bytes"))
  })
  long <- do.call(rbind, c(list(pc_empty_long()[-1L]), long))
  data.frame(part = rep("performance", nrow(long)), long)
}

pc_mib <- function(x) ifelse(is.na(x), "–", sprintf("%.1f", x / 1048576))
pc_seconds <- function(x) ifelse(is.na(x), "–", sprintf("%.3f", x))
pc_ratio <- function(x) ifelse(is.na(x), "–", sprintf("%.2f", x))
pc_count <- function(x) ifelse(is.na(x), "–", formatC(x, format = "d", big.mark = ","))
pc_value <- function(x, unit) {
  ifelse(is.na(x), "–", ifelse(unit == "seconds", paste(pc_seconds(x), "s"),
                               ifelse(unit == "bytes", paste(pc_mib(x), "MiB"), pc_count(x))))
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
    planned <- plan[plan$case == case, ]
    flagged <- unique(metric_label[values$metric[nzchar(values$flag)]])
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
  failed <- if (length(failed_parts)) {
    paste(vapply(failed_parts, function(part) {
      cases <- run[[paste0("failed_cases_", part)]] %||% ""
      if (nzchar(cases)) sprintf("%s (cases: %s)", part, gsub(";", ", ", cases)) else part
    }, ""), collapse = "; ")
  } else "none"
  ram <- suppressWarnings(as.numeric(run$ram_bytes))
  archive <- function(role) sprintf("%s vennabers %s (`%s`, SHA-256 %s…)", role, run[[paste0(role, "_version")]],
                                    run[[paste0(role, "_file")]], substr(run[[paste0(role, "_sha256")]], 1L, 12L))
  historical <- setdiff(parts, "new")
  history <- if (length(historical)) {
    counts <- vapply(historical, function(part) {
      values <- comparison[comparison$part == part, ]
      sprintf("- %s: %d cases, %d flagged", part, length(unique(values$case)),
              length(unique(values$case[nzchar(values$flag)])))
    }, "")
    flagged <- comparison[comparison$part %in% historical & nzchar(comparison$flag), ]
    c("", "## Historical parts", "", unname(counts),
      if (nrow(flagged)) c("", "| Part | Case | Metric | Previous | Candidate | Ratio | Flag |",
        "| --- | --- | --- | ---: | ---: | ---: | --- |",
        sprintf("| %s | `%s` | %s | %s | %s | %s | %s |", flagged$part, flagged$case, flagged$metric,
                pc_value(flagged$median_previous, flagged$unit), pc_value(flagged$median_candidate, flagged$unit),
                pc_ratio(flagged$ratio), flagged$flag)))
  }
  c("# Performance comparison",
    "",
    sprintf("**%s**", pc_headline(run)),
    "",
    sprintf("- Platform: %s; %s, %s cores, %s RAM; %s", run$platform, run$cpu, run$cores,
            if (is.na(ram)) "unknown" else sprintf("%.0f GiB", ram / 1024^3), run$os),
    sprintf("- R: %s; BLAS %s; LAPACK %s; %s", run$r, run$blas, run$lapack, run$threads),
    sprintf("- Archives: %s; %s", archive("previous"), archive("candidate")),
    sprintf("- Wall time: %s; total %s", paste(walls, collapse = ", "), pc_clock(run$wall_seconds_total)),
    sprintf("- Failed: %s", failed),
    "",
    "## New performance cases",
    "",
    pc_new_table(comparison, plan),
    history)
}

# Rebuilds measurements.csv, comparison.csv, summary.md and the derived fields
# of run.csv from the raw outputs under `out`. It never measures.
pc_summarize <- function(out) {
  run <- pc_read_keys(file.path(out, "run.csv"))
  if (!length(run)) stop("No run.csv in ", out, call. = FALSE)
  run <- c(run[setdiff(names(run), pc_derived_keys(run))], pc_derive(run, out))
  pc_write_keys(run, file.path(out, "run.csv"))
  parts <- strsplit(run$parts, ",", fixed = TRUE)[[1L]]
  measurements <- do.call(rbind, c(list(pc_empty_long()), lapply(parts, function(part) {
    dir <- file.path(out, part)
    if (dir.exists(dir)) pc_part_function("read", part)(dir)
  })))
  utils::write.csv(measurements, file.path(out, "measurements.csv"), row.names = FALSE, na = "")
  comparison <- pc_compare(measurements, smoke = identical(run$size, "quick"))
  utils::write.csv(comparison, file.path(out, "comparison.csv"), row.names = FALSE, na = "")
  plan_file <- file.path(out, "new", "plan.csv")
  plan <- if (file.exists(plan_file)) utils::read.csv(plan_file) else data.frame(case = character())
  summary <- pc_summary(run, comparison, plan)
  writeLines(summary, file.path(out, "summary.md"))
  invisible(summary)
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
  for (part in options$parts) {
    dir <- file.path(out, part)
    dir.create(dir)
    start <- Sys.time()
    message("Running part ", part, " ...")
    result <- tryCatch(pc_part_function("run", part)(list(
      previous_lib = libs[["previous"]], candidate_lib = libs[["candidate"]], deps = deps, dir = dir,
      previous_version = archives$previous$version,
      quick = options$quick, linux_x86_64 = identical(kind$linux_x86_64, "TRUE"), tools = tools)),
      error = function(e) {
        message("Part ", part, " failed: ", conditionMessage(e))
        list(exit = 1L, failed_cases = character())
      })
    end <- Sys.time()
    pc_write_keys(list(start_utc = pc_utc(start), end_utc = pc_utc(end),
                       wall_seconds = format(round(as.numeric(difftime(end, start, units = "secs")), 3)),
                       exit = as.character(result$exit), failed_cases = paste(result$failed_cases, collapse = ";")),
                  file.path(dir, "status.csv"))
    message("Part ", part, " ended with exit ", result$exit)
  }
  writeLines(pc_summarize(out))
  run <- pc_read_keys(file.path(out, "run.csv"))
  if (all(vapply(options$parts, function(part) identical(run[[paste0("exit_", part)]], "0"), TRUE))) 0L else 1L
}

if (sys.nframe() == 0L) {
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
  status <- pc_main(commandArgs(trailingOnly = TRUE), dirname(script))
  if (status != 0L) quit(status = status)
}
