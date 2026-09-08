# Separate from package checks. See tools/acceptance-v05.md for the protocol.
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
    .libPaths(c(lib, .libPaths()))
    library(vennabers, lib.loc = lib)
    stopifnot(identical(normalizePath(find.package("vennabers")), file.path(lib, "vennabers")),
              as.character(packageVersion("vennabers")) == args[5L])
    integration <- isTRUE(case$integration)
    regression <- identical(case$method, "regression")
    fit_args <- if (regression) c(list(truth = case$truth, prediction = case$prediction), case$moderation)
                else list(truth = case$truth, probability = case$probability)
    if (case$cross) fit_args$fold <- case$fold
    if (is.factor(case$truth)) fit_args$method <- case$method
    if (!is.null(case$precision)) fit_args$precision <- case$precision
    predict_args <- list(newdata = case$newdata)
    # v0.2 did not expose loss; omission is its compatible default log path.
    if (!regression && case$loss != "log") predict_args$loss <- case$loss
    if (integration) {
      loadNamespace("workflows")
      loadNamespace(if (case$method %in% c("ovo", "ovr")) "nnet" else "stats")
      predict_args <- list(new_data = case$newdata, type = if (regression) "numeric" else "prob")
    }
    if (args[1L] == "--restore") {
      model <- readRDS(paste0(prefix, "-model.rds"))
      stopifnot(identical(readRDS(paste0(prefix, "-prediction.rds")),
                          do.call(predict, c(list(model), predict_args))))
      cat("Fresh-process RDS predictions identical.\n")
      return(invisible(NULL))
    }
    fit_function <- if (regression) {
      if (case$cross) cross_venn_abers_regression else venn_abers_regression
    } else if (case$cross) cross_venn_abers else venn_abers
    if (integration) {
      # Construct/validate the public procedure inside each timing window.
      procedure <- function(outer = FALSE) {
        splits <- if (outer) local_calibration_splits(case$inner, names(case$data)) else case$split
        do.call(calibrated_workflow, c(list(workflow = case$base, outcome = "truth",
          method = if (case$cross) "cross" else "inductive", splits = splits, seed = case$seed),
          if (regression) case$moderation else list(classification = case$method, loss = case$loss)))
      }
      fit_function <- function() generics::fit(procedure(), case$data)
      fit_args <- list()
      metrics <- if (regression) yardstick::metric_set(yardstick::rmse, yardstick::mae) else
        yardstick::metric_set(yardstick::brier_class, yardstick::mn_log_loss)
      control <- tune::control_resamples(save_pred = TRUE, allow_par = FALSE)
    }
    rows <- vector("list", 4L)
    for (iteration in 0:3) {
      gc()
      fit_time <- system.time(model <- do.call(fit_function, fit_args))[["elapsed"]]
      predict_time <- system.time(prediction <- do.call(predict, c(list(model), predict_args)))[["elapsed"]]
      outer_time <- 0 # Not applicable to caller-supplied manual predictions.
      if (integration) {
        outer_time <- system.time(evaluation <- withr::with_seed(case$seed,
          tune::fit_resamples(procedure(TRUE), case$outer, metrics = metrics, control = control)))[["elapsed"]]
        collected <- tune::collect_predictions(evaluation)
        measured <- tune::collect_metrics(evaluation, summarize = FALSE)
        stopifnot(nrow(tune::collect_notes(evaluation)) == 0L,
                  nrow(collected) == 2000L, !anyDuplicated(collected$.row),
                  setequal(collected$.row, seq_len(2000L)),
                  nrow(measured) == 6L, all(is.finite(measured$.estimate)))
        saveRDS(evaluation, paste0(prefix, "-outer.rds"), compress = "gzip", version = 3)
        rm(evaluation, collected, measured)
      }
      values <- as.matrix(prediction)
      stopifnot(nrow(values) == case$n_new, all(is.finite(values)))
      if (regression && !integration) {
        stopifnot(identical(names(prediction), c("prediction", "lower", "upper")),
                  all(vapply(prediction, is.double, FALSE)),
                  all(prediction$lower <= prediction$prediction),
                  all(prediction$prediction <= prediction$upper))
      } else if (!regression) stopifnot(all(values >= 0 & values <= 1))
      if (integration && regression) stopifnot(identical(names(prediction), ".pred"), is.double(prediction$.pred))
      if (is.factor(case$truth)) stopifnot(all(abs(rowSums(values) - 1) <= 1e-10))
      saveRDS(model, paste0(prefix, "-model.rds"), compress = "gzip", version = 3)
      saveRDS(prediction, paste0(prefix, "-prediction.rds"), compress = "gzip", version = 3)
      restored <- readRDS(paste0(prefix, "-model.rds"))
      stopifnot(identical(prediction, do.call(predict, c(list(restored), predict_args))))
      rows[[iteration + 1L]] <- data.frame(iteration, fit_seconds = fit_time,
        predict_seconds = predict_time, outer_seconds = outer_time, rds_bytes = file.info(paste0(prefix, "-model.rds"))$size)
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
  metadata <- tempfile("benchmark-metadata-")
  dir.create(metadata)
  on.exit(unlink(metadata, recursive = TRUE), add = TRUE)
  utils::untar(artifacts[1L], files = "vennabers/DESCRIPTION", exdir = metadata)
  current_version <- read.dcf(file.path(metadata, "vennabers/DESCRIPTION"), fields = "Version")[[1L]]
  stopifnot(current_version %in% c("0.4.0", "0.5.0"))
  v05 <- current_version == "0.5.0"
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
    } else {
      cat(system("sysctl -n machdep.cpu.brand_string hw.ncpu hw.memsize", intern = TRUE), sep = "\n")
      cat(system("sw_vers", intern = TRUE), sep = "\n")
    }
  }, file = file.path(output, "environment.txt"))
  file.copy(script, file.path(output, "performance.R"))
  # Archive identity and input MD5s are portable. The release manifest also
  # records SHA-256 externally, including both tarballs and this runner.
  write.csv(data.frame(role = c("current", "previous"), artifact = artifacts,
                      md5 = unname(tools::md5sum(artifacts))),
            file.path(output, "artifacts.csv"), row.names = FALSE)
  stopifnot(all(file.copy(artifacts, file.path(output, paste0(c("current", "previous"), ".tar.gz")))))

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
  # Append regression after all historical draws so classification inputs stay identical.
  set.seed(20260909)
  regression_prediction <- rnorm(10000L, mean = -2, sd = 3)
  regression_truth <- 1.5 * regression_prediction + rnorm(10000L)
  regression_new <- matrix(rnorm(5000L, mean = -2, sd = 3), 1000L, 5L,
                           dimnames = list(NULL, unique(fold)))
  for (cross in c(FALSE, TRUE)) for (option in c("m1", "epsilon01")) {
    moderation <- if (option == "m1") list(m = 1) else list(epsilon = 0.1)
    k <- if (cross) as.numeric(table(fold)) else length(regression_truth)
    m <- if (option == "m1") rep(1, length(k)) else floor(0.1 * (k + 1) / 2)
    stopifnot(all(is.finite(c(regression_truth, regression_prediction, regression_new))),
              all(m >= 1 & m <= floor((k - 1) / 2)))
    id <- paste("regression", if (cross) "cross" else "inductive", option, sep = "_")
    cases[[id]] <- list(truth = regression_truth, prediction = regression_prediction,
      newdata = if (cross) regression_new else regression_new[, 1L],
      cross = cross, fold = if (cross) fold else NULL, method = "regression",
      loss = NA_character_, precision = NULL, n_new = 1000L, moderation = moderation,
      calibration_row = seq_len(10000L), new_row = seq_len(1000L))
  }
  if (v05) {
    # Append after historical draws. Store data, every actual split and the
    # untrained recipe/model configuration, not just seeds or split sizes.
    set.seed(20260910)
    x <- as.data.frame(matrix(rnorm(2500L * 10L), 2500L, 10L))
    names(x) <- paste0("x", 1:10)
    outcomes <- list(binary = factor(ifelse(runif(2500L) < plogis(x$x1), "yes", "no")),
      ovo = factor(sample(c("a", "b", "c"), 2500L, replace = TRUE)),
      regression = 2 * x$x1 - x$x2 + rnorm(2500L))
    outcomes$ovr <- outcomes$ovo
    for (method in c("binary", "ovo", "ovr", "regression")) for (cross in c(FALSE, TRUE)) {
      data <- x[1:2000, ]
      data$truth <- outcomes[[method]][1:2000]
      spec <- if (method == "regression") parsnip::linear_reg(engine = "lm") else
        if (method == "binary") parsnip::logistic_reg(engine = "glm") else
          parsnip::multinom_reg(penalty = 0) |> parsnip::set_engine("nnet", trace = FALSE, maxit = 200)
      # Formula/selector environments must not serialize the benchmark runner
      # and its other cases into every saved input and fitted model.
      formula <- stats::as.formula("truth ~ .", env = baseenv())
      selector <- rlang::new_quosure(quote(recipes::all_numeric_predictors()), env = baseenv())
      base <- workflows::workflow() |>
        workflows::add_recipe(recipes::recipe(formula, data) |>
          recipes::step_normalize(!!selector)) |> workflows::add_model(spec)
      split_local <- function(data) {
        if (cross) rsample::vfold_cv(data, v = 5) else rsample::initial_split(data, prop = .8)
      }
      # OvO and OvR use identical data and partitions for a common multinomial base.
      split <- withr::with_seed(3501, split_local(data))
      outer <- withr::with_seed(3502, rsample::vfold_cv(data, v = 3))
      inner <- withr::with_seed(3503, lapply(outer$splits, function(s) split_local(rsample::analysis(s))))
      fold <- if (cross) {
        f <- character(nrow(data))
        for (i in seq_len(nrow(split))) f[as.integer(split$splits[[i]], data = "assessment")] <- split$id[i]
        f
      } else NULL
      id <- paste("workflow", method, if (cross) "cross" else "inductive", sep = "_")
      cases[[id]] <- list(integration = TRUE, data = data, truth = data$truth,
        newdata = x[2001:2500, ], base = base, split = split, outer = outer, inner = inner,
        seed = 3504L, cross = cross, fold = fold, method = method, n_new = 500L,
        loss = if (method == "regression") NA_character_ else "log", precision = NULL,
        moderation = if (method == "regression") list(m = 1) else NULL)
    }
  }
  for (id in names(cases)) saveRDS(cases[[id]], file.path(output, paste0(id, "-input.rds")), version = 3)
  plan <- do.call(rbind, lapply(names(cases), function(id) {
    x <- cases[[id]]
    data.frame(case = id, calibration = length(x$truth), prediction = x$n_new,
               classes = if (x$method == "regression") NA_integer_ else if (is.factor(x$truth)) nlevels(x$truth) else 2L,
               folds = if (x$cross) length(unique(x$fold)) else 1L,
               method = x$method, loss = x$loss,
               precision = if (is.null(x$precision)) NA_real_ else x$precision,
               m = if (is.null(x$moderation$m)) NA_real_ else x$moderation$m,
               epsilon = if (is.null(x$moderation$epsilon)) NA_real_ else x$moderation$epsilon,
               previous_supported = !isTRUE(x$integration) && (v05 || x$method != "regression"),
               input_md5 = unname(tools::md5sum(file.path(output, paste0(id, "-input.rds")))))
  }))
  write.csv(plan, file.path(output, "plan.csv"), row.names = FALSE)
  rm(cases, ivap, binary, extra, p, newdata, truth,
     regression_prediction, regression_truth, regression_new)
  gc()

  all_runs <- list()
  for (release in c("current", "previous")) {
    i <- match(release, c("current", "previous"))
    lib <- file.path(output, paste0(release, "-library"))
    dir.create(lib)
    run(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", paste0("--library=", shQuote(lib)), shQuote(artifacts[i])),
        file.path(output, paste0(release, "-install.log")))
    version <- read.dcf(file.path(lib, "vennabers", "DESCRIPTION"), fields = "Version")[[1L]]
    stopifnot(version == if (release == "current") current_version else if (v05) "0.4.0" else "0.3.0")
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
  medians <- aggregate(cbind(fit_seconds, predict_seconds, outer_seconds, rds_bytes, process_peak_bytes) ~ release + case,
                       runs[runs$iteration > 0L, ], median)
  write.csv(medians, file.path(output, "medians.csv"), row.names = FALSE)
  comparison <- merge(medians[medians$release == "current", -1L], medians[medians$release == "previous", -1L],
                      by = "case", all.x = TRUE, suffixes = c("_current", "_previous"))
  for (metric in c("fit_seconds", "predict_seconds", "outer_seconds", "rds_bytes", "process_peak_bytes")) {
    previous <- comparison[[paste0(metric, "_previous")]]
    comparison[[paste0(metric, "_ratio")]] <- ifelse(previous > 0, comparison[[paste0(metric, "_current")]] / previous, NA_real_)
  }
  comparison$status <- ifelse(is.na(comparison$fit_seconds_previous), "new capability baseline", "requires regression review")
  write.csv(comparison, file.path(output, "comparison.csv"), row.names = FALSE)
  cat(if (smoke) "Smoke completed; NOT release performance evidence.\n" else "Measurements completed; investigate regressions before release approval.\n")
})
