# Separate from package checks. See tools/acceptance-v03.md for the protocol.
local({
  args <- commandArgs(TRUE)
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
  rscript <- file.path(R.home("bin"), "Rscript")
  threads <- c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
               "VECLIB_MAXIMUM_THREADS", "BLIS_NUM_THREADS")
  do.call(Sys.setenv, as.list(setNames(rep("1", length(threads)), threads)))

  # One fresh process per case/release. Inputs were generated and checked by
  # the parent before launching this process; public API validation stays timed.
  if (length(args) && args[1L] %in% c("--case", "--restore")) {
    case <- readRDS(args[2L])
    lib <- normalizePath(args[3L], mustWork = TRUE)
    prefix <- args[4L]
    library(vennabers, lib.loc = lib)
    stopifnot(identical(normalizePath(find.package("vennabers")), file.path(lib, "vennabers")),
              as.character(packageVersion("vennabers")) == args[5L])
    fit_args <- list(truth = case$truth, probability = case$probability)
    if (case$cross) fit_args$fold <- case$fold
    if (is.factor(case$truth)) fit_args$method <- case$method
    if (!is.null(case$precision)) fit_args$precision <- case$precision
    predict_args <- list(newdata = case$newdata)
    # v0.2 did not expose loss; omission is its compatible default log path.
    if (case$loss != "log") predict_args$loss <- case$loss
    if (args[1L] == "--restore") {
      model <- readRDS(paste0(prefix, "-model.rds"))
      stopifnot(identical(readRDS(paste0(prefix, "-prediction.rds")),
                          do.call(predict, c(list(model), predict_args))))
      cat("Fresh-process RDS predictions identical.\n")
      return(invisible(NULL))
    }
    fit_function <- if (case$cross) cross_venn_abers else venn_abers
    rows <- vector("list", 4L)
    for (iteration in 0:3) {
      gc()
      fit_time <- system.time(model <- do.call(fit_function, fit_args))[["elapsed"]]
      predict_time <- system.time(prediction <- do.call(predict, c(list(model), predict_args)))[["elapsed"]]
      values <- as.matrix(prediction)
      stopifnot(nrow(values) == case$n_new, all(is.finite(values)),
                all(values >= 0 & values <= 1))
      if (is.factor(case$truth)) stopifnot(all(abs(rowSums(values) - 1) <= 1e-10))
      saveRDS(model, paste0(prefix, "-model.rds"), compress = "gzip", version = 3)
      saveRDS(prediction, paste0(prefix, "-prediction.rds"), compress = "gzip", version = 3)
      restored <- readRDS(paste0(prefix, "-model.rds"))
      stopifnot(identical(prediction, do.call(predict, c(list(restored), predict_args))))
      rows[[iteration + 1L]] <- data.frame(iteration, fit_seconds = fit_time,
        predict_seconds = predict_time, rds_bytes = file.info(paste0(prefix, "-model.rds"))$size)
      rm(model, restored, prediction, values)
    }
    write.csv(do.call(rbind, rows), paste0(prefix, "-runs.csv"), row.names = FALSE)
    capture.output(sessionInfo(), file = paste0(prefix, "-session.txt"))
    return(invisible(NULL))
  }

  smoke <- "--smoke" %in% args
  args <- args[args != "--smoke"]
  if (length(args) != 3L) stop("Usage: Rscript tools/performance.R CURRENT.tar.gz PREVIOUS.tar.gz OUTPUT [--smoke]")
  linux <- Sys.info()[["sysname"]] == "Linux"
  if (!(linux && R.version$arch == "x86_64") && !smoke) stop("Release measurements require Linux x86_64. Use --smoke for non-release validation.")
  if (!file.exists("/usr/bin/time")) stop("Install the system time command before measuring.")
  artifacts <- normalizePath(args[1:2], mustWork = TRUE)
  output <- args[3L]
  if (dir.exists(output) && length(list.files(output, all.files = TRUE, no.. = TRUE))) stop("OUTPUT must be empty.")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  output <- normalizePath(output)
  run <- function(command, arguments, log) {
    status <- system2(command, arguments, stdout = log, stderr = log)
    if (status != 0L) stop("Command failed; see ", log)
  }
  capture.output({
    cat("Release evidence:", !smoke, "\nUTC:", format(Sys.time(), tz = "UTC"), "\n")
    print(Sys.info()); print(sessionInfo()); print(Sys.getenv(threads))
    print(installed.packages()[, c("Package", "Version"), drop = FALSE])
    if (linux) {
      cat(readLines("/etc/os-release"), sep = "\n")
      cat(readLines("/proc/cpuinfo"), sep = "\n")
      cat(readLines("/proc/meminfo"), sep = "\n")
    }
  }, file = file.path(output, "environment.txt"))
  file.copy(script, file.path(output, "performance.R"))
  # Archive identity and input MD5s are portable. The release manifest also
  # records SHA-256 externally, including both tarballs and this runner.
  write.csv(data.frame(role = c("current", "previous"), artifact = artifacts,
                      md5 = unname(tools::md5sum(artifacts))),
            file.path(output, "artifacts.csv"), row.names = FALSE)

  # Keep the historical IVAP RNG order and dimensions exactly unchanged.
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(20260906)
  ivap <- list(truth = sample(c(FALSE, TRUE), 100000L, replace = TRUE),
               probability = runif(100000L), newdata = runif(100000L),
               cross = FALSE, method = "binary", loss = "log", precision = NULL, n_new = 100000L)
  cases <- list(binary_inductive = ivap)
  set.seed(20260907)
  fold <- rep(paste0("fold", 1:5), length.out = 10000L)
  binary <- list(truth = rep(c(FALSE, TRUE), 5000L), probability = runif(10000L),
                 newdata = matrix(runif(5000L), 1000L, 5L, dimnames = list(NULL, unique(fold))),
                 cross = TRUE, fold = fold, method = "binary", loss = "log", precision = NULL, n_new = 1000L)
  cases$binary_cross <- binary
  for (k in c(3L, 10L)) {
    classes <- paste0("class", seq_len(k))
    # Class blocks inside each fold prevent k=10 from aliasing the five folds.
    truth <- factor(classes[(seq_len(10000L) - 1L) %/% 5L %% k + 1L], levels = classes)
    probabilities <- function(n) {
      p <- matrix(rexp(n * k), n, k, dimnames = list(NULL, classes))
      p / rowSums(p)
    }
    p <- probabilities(10000L)
    newdata <- setNames(lapply(unique(fold), function(id) probabilities(1000L)), unique(fold))
    stopifnot(all(table(truth, fold) > 0L), all(abs(rowSums(p) - 1) < 1e-8),
              all(vapply(newdata, function(x) all(abs(rowSums(x) - 1) < 1e-8), FALSE)))
    for (cross in c(FALSE, TRUE)) for (method in c("ovo", "ovr")) {
      id <- paste(k, if (cross) "cross" else "inductive", method, sep = "_")
      cases[[id]] <- list(truth = truth, probability = p,
        newdata = if (cross) newdata else newdata[[1L]], cross = cross, fold = fold,
        method = method, loss = "log", precision = NULL, n_new = 1000L)
    }
  }
  for (id in c("binary_cross", "3_cross_ovo")) {
    extra <- cases[[id]]
    extra$loss <- "brier"
    extra$precision <- 2
    cases[[paste0(id, "_brier_p2")]] <- extra
  }
  for (id in names(cases)) saveRDS(cases[[id]], file.path(output, paste0(id, "-input.rds")), version = 3)
  plan <- do.call(rbind, lapply(names(cases), function(id) {
    x <- cases[[id]]
    data.frame(case = id, calibration = length(x$truth), prediction = x$n_new,
               classes = if (is.factor(x$truth)) nlevels(x$truth) else 2L,
               folds = if (x$cross) length(unique(x$fold)) else 1L,
               method = x$method, loss = x$loss,
               precision = if (is.null(x$precision)) NA_real_ else x$precision,
               previous_supported = id %in% c("binary_inductive", "binary_cross"),
               input_md5 = unname(tools::md5sum(file.path(output, paste0(id, "-input.rds")))))
  }))
  write.csv(plan, file.path(output, "plan.csv"), row.names = FALSE)
  rm(cases, ivap, binary, extra, p, newdata, truth)
  gc()

  all_runs <- list()
  for (release in c("current", "previous")) {
    i <- match(release, c("current", "previous"))
    lib <- file.path(output, paste0(release, "-library"))
    dir.create(lib)
    run(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", paste0("--library=", shQuote(lib)), shQuote(artifacts[i])),
        file.path(output, paste0(release, "-install.log")))
    version <- read.dcf(file.path(lib, "vennabers", "DESCRIPTION"), fields = "Version")[[1L]]
    stopifnot(version == if (release == "current") "0.3.0" else "0.2.0")
    selected <- if (release == "current") plan$case else plan$case[plan$previous_supported]
    for (id in selected) {
      cat(release, id, "\n")
      prefix <- file.path(output, paste(release, id, sep = "-"))
      worker <- c(shQuote(rscript), "--vanilla", shQuote(script), "--case",
                  shQuote(file.path(output, paste0(id, "-input.rds"))), shQuote(lib), shQuote(prefix), version)
      run("/usr/bin/time", c(if (linux) "-v" else "-l", worker), paste0(prefix, "-process.log"))
      restore <- worker[-1L]
      restore[restore == "--case"] <- "--restore"
      run(rscript, restore, paste0(prefix, "-restore.log"))
      log <- readLines(paste0(prefix, "-process.log"))
      peak_line <- grep(if (linux) "Maximum resident set size" else "maximum resident set size", log, value = TRUE)
      stopifnot(length(peak_line) == 1L)
      peak <- if (linux) as.numeric(sub(".*: *", "", peak_line)) * 1024 else as.numeric(sub("^ *([0-9]+).*", "\\1", peak_line))
      stopifnot(is.finite(peak), peak > 0)
      runs <- read.csv(paste0(prefix, "-runs.csv"))
      runs$release <- release; runs$case <- id; runs$process_peak_bytes <- peak
      all_runs[[paste(release, id)]] <- runs
    }
  }
  runs <- do.call(rbind, all_runs)
  write.csv(runs, file.path(output, "runs.csv"), row.names = FALSE)
  medians <- aggregate(cbind(fit_seconds, predict_seconds, rds_bytes, process_peak_bytes) ~ release + case,
                       runs[runs$iteration > 0L, ], median)
  write.csv(medians, file.path(output, "medians.csv"), row.names = FALSE)
  comparison <- merge(medians[medians$release == "current", -1L], medians[medians$release == "previous", -1L],
                      by = "case", all.x = TRUE, suffixes = c("_current", "_previous"))
  for (metric in c("fit_seconds", "predict_seconds", "rds_bytes", "process_peak_bytes")) {
    previous <- comparison[[paste0(metric, "_previous")]]
    comparison[[paste0(metric, "_ratio")]] <- ifelse(previous > 0, comparison[[paste0(metric, "_current")]] / previous, NA_real_)
  }
  comparison$status <- ifelse(is.na(comparison$fit_seconds_previous), "new capability baseline", "requires regression review")
  write.csv(comparison, file.path(output, "comparison.csv"), row.names = FALSE)
  cat(if (smoke) "Smoke completed; NOT release performance evidence.\n" else "Measurements completed; investigate regressions before release approval.\n")
})
