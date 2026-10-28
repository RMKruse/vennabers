# Separate from package checks. Part performance of tools/performance-comparison.R
# (see tools/RELEASE.md); the v0.3-v0.7 cases are unchanged. Library mode:
#   Rscript --vanilla tools/performance.R CURRENT-LIBRARY PREVIOUS-LIBRARY OUTPUT [--previous-version VERSION] [--smoke]
# Dependencies come from R_LIBS. A 1.x candidate runs all v0.7 cases on both
# libraries, needs --previous-version and uses one process per case and library.
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
    frozen <- isTRUE(case$frozen)
    pairwise <- identical(case$model_training, "pairwise")
    encoded <- !is.null(case$schema)
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
      if (encoded) stopifnot(identical(readRDS(paste0(prefix, "-decoded.rds")),
        venn_abers_decode(do.call(predict, c(list(model), predict_args)), case$schema)),
        identical((if (frozen) model else workflows::extract_fit_engine(model))$schema, case$schema))
      cat("Fresh-process RDS predictions identical.\n")
      return(invisible(NULL))
    }
    fit_function <- if (regression) {
      if (case$cross) cross_venn_abers_regression else venn_abers_regression
    } else if (case$cross) cross_venn_abers else venn_abers
    if (integration) {
      # Construct/validate the public procedure inside each timing window.
      procedure <- function(outer = FALSE) {
        splits <- if (outer) local_calibration_splits(if (pairwise) unlist(case$inner, recursive = FALSE) else case$inner, names(case$data)) else case$split
        do.call(calibrated_workflow, c(list(workflow = case$base, outcome = if (encoded) case$schema$encoded_outcome else "truth",
          method = if (case$cross) "cross" else "inductive", splits = splits, seed = case$seed),
          if (encoded) list(schema = case$schema),
          if (!is.null(case$prediction_model)) list(prediction_model = case$prediction_model),
          if (pairwise) list(model_training = "pairwise"),
          if (regression) case$moderation else list(classification = case$method, loss = case$loss)))
      }
      fit_function <- function() generics::fit(procedure(), case$data)
      if (frozen) {
        # Original workflow learning is outside every measured calibration window.
        earlier <- withr::with_seed(case$seed, generics::fit(case$base, case$training))
        fit_function <- function() do.call(calibrate_workflow, c(list(
          fitted_workflow = earlier, data_calibration = case$data,
          outcome = if (encoded) case$schema$encoded_outcome else "truth", schema = case$schema),
          if (regression) case$moderation else list(classification = case$method, loss = case$loss)))
      }
      fit_args <- list()
      metrics <- if (regression) yardstick::metric_set(yardstick::rmse, yardstick::mae) else
        yardstick::metric_set(yardstick::brier_class, yardstick::mn_log_loss)
      control <- tune::control_resamples(save_pred = TRUE, allow_par = FALSE)
    }
    # Count actual engine calls, including complete outer fitting, without replacing engines.
    counter <- new.env(parent = emptyenv())
    counter$n <- 0L
    if (integration) {
      engine <- if (regression) "lm" else if (case$method == "binary" || pairwise) "glm" else "multinom"
      namespace <- if (engine == "multinom") asNamespace("nnet") else asNamespace("stats")
      trace(engine, where = namespace, tracer = bquote(assign("n", .(counter)$n + 1L, envir = .(counter))), print = FALSE)
      on.exit(untrace(engine, where = namespace), add = TRUE)
    }
    iterations <- if (length(args) >= 6L) as.integer(args[6L]) else 0:3
    stopifnot(all(iterations %in% 0:3))
    rows <- list()
    for (iteration in iterations) {
      gc()
      schema_time <- encode_time <- decode_time <- 0
      if (encoded) {
        schema_time <- system.time(schema <- do.call(venn_abers_schema, c(list(data = case$schema_data, outcome = "truth"),
          if (!regression) list(classification = case$method))))[["elapsed"]]
        stopifnot(identical(schema, case$schema))
        encode_time <- system.time({
          data <- venn_abers_encode(case$original_data, schema)
          new <- venn_abers_encode(case$original_newdata, schema)
        })[["elapsed"]]
        stopifnot(identical(data, case$data), identical(new, case$newdata))
      }
      before <- counter$n
      fit_time <- system.time(model <- do.call(fit_function, fit_args))[["elapsed"]]
      fit_count <- counter$n - before
      retained_models <- if (!integration) 0L else if (frozen) length(model$models) else {
        state <- workflows::extract_fit_engine(model)
        if (pairwise) sum(vapply(state$pair_models, function(x) length(x$models), 1L)) else length(state$models)
      }
      predict_time <- system.time(prediction <- do.call(predict, c(list(model), predict_args)))[["elapsed"]]
      stopifnot(counter$n == before + fit_count)
      outer_fit_count <- 0L
      outer_time <- 0 # Not applicable to caller-supplied manual predictions.
      if (integration && !frozen) {
        before <- counter$n
        outer_time <- system.time(evaluation <- withr::with_seed(case$seed,
          tune::fit_resamples(procedure(TRUE), case$outer, metrics = metrics, control = control)))[["elapsed"]]
        outer_fit_count <- counter$n - before
        collected <- tune::collect_predictions(evaluation)
        measured <- tune::collect_metrics(evaluation, summarize = FALSE)
        stopifnot(nrow(tune::collect_notes(evaluation)) == 0L,
                  nrow(collected) == 2000L, !anyDuplicated(collected$.row),
                  setequal(collected$.row, seq_len(2000L)),
                  nrow(measured) == 6L, all(is.finite(measured$.estimate)))
        saveRDS(evaluation, paste0(prefix, "-outer.rds"), compress = "gzip", version = 3)
        rm(evaluation, collected, measured)
      }
      if (frozen) stopifnot(identical(model$models[[1L]], earlier),
                            model$calibration_size == 2000L)
      if (encoded) {
        decode_time <- system.time(decoded <- venn_abers_decode(prediction, case$schema))[["elapsed"]]
        saveRDS(decoded, paste0(prefix, "-decoded.rds"), compress = "gzip", version = 3)
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
      rows[[length(rows) + 1L]] <- data.frame(iteration, fit_count, retained_models, outer_fit_count, fit_seconds = fit_time,
        predict_seconds = predict_time, outer_seconds = outer_time,
        schema_seconds = schema_time, encode_seconds = encode_time, decode_seconds = decode_time, rds_bytes = file.info(paste0(prefix, "-model.rds"))$size)
      rm(model, restored, prediction, values)
    }
    write.csv(do.call(rbind, rows), paste0(prefix, "-runs.csv"), row.names = FALSE)
    capture.output(sessionInfo(), file = paste0(prefix, "-session.txt"))
    return(invisible(NULL))
  }

  prepare_only <- "--prepare-only" %in% args
  args <- args[args != "--prepare-only"]
  smoke <- "--smoke" %in% args
  args <- args[args != "--smoke"]
  at <- match("--previous-version", args)
  previous_version <- if (is.na(at)) NULL else args[at + 1L]
  if (!is.na(at)) args <- args[-c(at, at + 1L)]
  if (length(args) != 3L || identical(previous_version, NA_character_)) {
    stop("Usage: Rscript tools/performance.R CURRENT-LIBRARY PREVIOUS-LIBRARY OUTPUT [--previous-version VERSION] [--smoke]")
  }
  linux <- Sys.info()[["sysname"]] == "Linux"
  if (!(linux && R.version$arch == "x86_64") && !smoke) stop("Release measurements require Linux x86_64. Use --smoke for non-release validation.")
  if (!file.exists("/usr/bin/time")) stop("Install the system time command before measuring.")
  libraries <- normalizePath(args[1:2], mustWork = TRUE)
  output <- args[3L]
  if (dir.exists(output) && length(list.files(output, all.files = TRUE, no.. = TRUE))) stop("OUTPUT must be empty.")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  output <- normalizePath(output)
  versions <- vapply(libraries, function(lib) read.dcf(file.path(lib, "vennabers", "DESCRIPTION"), fields = "Version")[[1L]], "",
                     USE.NAMES = FALSE)
  current_version <- versions[[1L]]
  # 1.x keeps every v0.7 case; from 1.0 on the previous release is passed in.
  v1 <- startsWith(current_version, "1.")
  stopifnot(current_version %in% c("0.4.0", "0.5.0", "0.6.0", "0.7.0") || v1)
  if (v1 && is.null(previous_version)) stop("A 1.x candidate needs --previous-version.")
  v07 <- current_version == "0.7.0" || v1
  v06 <- current_version %in% c("0.6.0", "0.7.0") || v1
  v05 <- current_version %in% c("0.5.0", "0.6.0", "0.7.0") || v1
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
  # The caller installed both libraries and records the archives' SHA-256.
  write.csv(data.frame(role = c("current", "previous"), library = libraries, version = versions),
            file.path(output, "artifacts.csv"), row.names = FALSE)
  stopifnot(versions[[2L]] == if (v1) previous_version else if (v07) "0.6.0" else if (v06) "0.5.0" else if (v05) "0.4.0" else "0.3.0")
  if (v06) {
    .libPaths(c(libraries[1L], .libPaths()))
    library(vennabers, lib.loc = libraries[1L])
  }

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
  # Formula/selector environments must not serialize the benchmark runner
  # and its other cases into every saved input and fitted model.
  base_env_recipe <- function(data) {
    formula <- stats::as.formula("truth ~ .", env = baseenv())
    selector <- rlang::new_quosure(quote(recipes::all_numeric_predictors()), env = baseenv())
    recipes::recipe(formula, data) |> recipes::step_normalize(!!selector)
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
      base <- workflows::workflow() |>
        workflows::add_recipe(base_env_recipe(data)) |> workflows::add_model(spec)
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
  if (v06) {
    # Keep all v0.5 cases. New cases share their exact numeric data and options.
    # Earlier frozen training uses independent draws, never the 2,000 calibration rows.
    set.seed(20260911)
    training_x <- as.data.frame(matrix(rnorm(1000L * 10L), 1000L, 10L))
    names(training_x) <- paste0("x", 1:10)
    training_y <- list(binary = factor(ifelse(runif(1000L) < plogis(training_x$x1), "yes", "no")),
      ovo = factor(sample(c("a", "b", "c"), 1000L, replace = TRUE)),
      regression = 2 * training_x$x1 - training_x$x2 + rnorm(1000L))
    training_y$ovr <- training_y$ovo
    for (method in c("binary", "ovo", "ovr", "regression")) {
      for (variant in c("encoded_inductive", "encoded_cross", "ordered", "encoded_ordered", "frozen", "frozen_encoded")) {
        encoded <- grepl("encoded", variant)
        frozen <- grepl("frozen", variant)
        cross <- variant == "encoded_cross"
        case <- cases[[paste("workflow", method, if (cross) "cross" else "inductive", sep = "_")]]
        case$frozen <- frozen
        case$variant <- variant
        case$generator_seed <- 20260910L
        if (frozen) {
          case$training <- training_x
          case$training$truth <- training_y[[method]]
          case$training_seed <- 20260911L
        }
        if (encoded) {
          case$original_data <- case$data
          case$original_newdata <- case$newdata
          case$schema_data <- if (frozen) case$training else case$data
          case$schema <- do.call(venn_abers_schema, c(list(data = case$schema_data, outcome = "truth"),
            if (method != "regression") list(classification = method)))
          case$data <- venn_abers_encode(case$data, case$schema)
          case$newdata <- venn_abers_encode(case$newdata, case$schema)
          if (frozen) case$training <- venn_abers_encode(case$training, case$schema)
          formula <- stats::as.formula(paste(case$schema$encoded_outcome, "~ ."), env = baseenv())
          selector <- rlang::new_quosure(quote(recipes::all_numeric_predictors()), env = baseenv())
          case$base <- workflows::workflow() |>
            workflows::add_recipe(recipes::recipe(formula, case$data) |>
              recipes::step_normalize(!!selector)) |>
            workflows::add_model(workflows::extract_spec_parsnip(case$base))
        }
        case$truth <- case$data[[if (encoded) case$schema$encoded_outcome else "truth"]]
        if (frozen) {
          case$split <- case$outer <- case$inner <- NULL
        } else {
          split_local <- function(data) {
            if (cross) rsample::vfold_cv(data, v = 5) else
              if (grepl("ordered", variant)) {
                cut <- nrow(data) - ceiling(nrow(data) * .2)
                rsample::make_splits(list(analysis = seq_len(cut),
                  assessment = seq.int(cut + 1L, nrow(data))), data)
              } else
                rsample::initial_split(data, prop = .8)
          }
          case$split <- withr::with_seed(3501, split_local(case$data))
          case$outer <- withr::with_seed(3502, rsample::vfold_cv(case$data, v = 3))
          case$inner <- withr::with_seed(3503, lapply(case$outer$splits, function(s) split_local(rsample::analysis(s))))
        }
        cases[[paste("workflow", method, variant, sep = "_")]] <- case
      }
    }
  }
  if (v07) {
    # Eight shared full paths reuse the exact historical data/partitions.
    for (method in c("binary", "ovo", "ovr", "regression")) for (cross in c(FALSE, TRUE)) {
      id <- paste("workflow", method, if (cross) "cross" else "inductive", sep = "_")
      case <- cases[[id]]
      case$prediction_model <- "full"
      cases[[paste0(id, "_full")]] <- case
    }
    # Pair models learn GLMs and normalization separately on each actual local pair.
    set.seed(20260912)
    ten_truth <- factor(sample(paste0("class", 1:10), 2000L, replace = TRUE))
    for (k in c(3L, 10L)) for (cross in c(FALSE, TRUE)) {
      case <- cases[[paste("workflow_ovo", if (cross) "cross" else "inductive", sep = "_")]]
      if (k == 10L) case$data$truth <- case$truth <- ten_truth
      case$model_training <- "pairwise"
      case$generator_seed <- if (k == 10L) 20260912L else 20260910L
      case$base <- workflows::update_model(case$base, parsnip::logistic_reg(engine = "glm"))
      # The template's outcome domain must follow the ten-class input too.
      case$base <- workflows::update_recipe(case$base, base_env_recipe(case$data))
      pair_plans <- function(data) {
        pairs <- combn(levels(data$truth), 2L, simplify = FALSE)
        setNames(lapply(pairs, function(pair) {
          local <- data[data$truth %in% pair, , drop = FALSE]
          local$truth <- factor(local$truth, levels = pair)
          withr::with_seed(3501, if (cross) rsample::vfold_cv(local, v = 5) else
            rsample::initial_split(local, prop = .8))
        }), paste0("pair_", seq_along(pairs)))
      }
      case$split <- pair_plans(case$data)
      case$outer <- withr::with_seed(3502, rsample::vfold_cv(case$data, v = 3))
      case$inner <- lapply(case$outer$splits, function(s) pair_plans(rsample::analysis(s)))
      case$fold <- NULL # Pair fold membership is stored in each bound local split.
      for (mode in c("matched", "full")) {
        case$prediction_model <- mode
        cases[[paste("workflow_pair", k, if (cross) "cross" else "inductive", mode, sep = "_")]] <- case
      }
    }
  }
  for (id in names(cases)) saveRDS(cases[[id]], file.path(output, paste0(id, "-input.rds")), version = 3)
  plan <- do.call(rbind, lapply(names(cases), function(id) {
    x <- cases[[id]]
    data.frame(case = id, calibration = length(x$truth), prediction = x$n_new,
               classes = if (x$method == "regression") NA_integer_ else if (is.factor(x$truth)) nlevels(x$truth) else 2L,
               folds = if (identical(x$model_training, "pairwise")) { if (x$cross) 5L else 1L } else if (x$cross) length(unique(x$fold)) else 1L,
               method = x$method, loss = x$loss,
               precision = if (is.null(x$precision)) NA_real_ else x$precision,
               m = if (is.null(x$moderation$m)) NA_real_ else x$moderation$m,
               epsilon = if (is.null(x$moderation$epsilon)) NA_real_ else x$moderation$epsilon,
               previous_supported = if (v1) TRUE else if (v07) is.null(x$prediction_model) else if (v06) is.null(x$variant) else !isTRUE(x$integration) && (v05 || x$method != "regression"),
               input_sha256 = unname(tools::sha256sum(file.path(output, paste0(id, "-input.rds")))))
  }))
  write.csv(plan, file.path(output, "plan.csv"), row.names = FALSE)
  rm(cases, ivap, binary, extra, p, newdata, truth,
     regression_prediction, regression_truth, regression_new)
  gc()

  if (prepare_only) {
    cat("Inputs prepared; no measurements or release evidence.\n")
    return(invisible(NULL))
  }
  all_runs <- list()
  for (release in c("current", "previous")) {
    i <- match(release, c("current", "previous"))
    lib <- libraries[i]
    version <- versions[[i]]
    selected <- if (release == "current") plan$case else plan$case[plan$previous_supported]
    for (id in selected) {
      cat(release, id, "\n")
      prefix <- file.path(output, paste(release, id, sep = "-"))
      worker <- c(shQuote(rscript), "--vanilla", shQuote(script), "--case",
                  shQuote(file.path(output, paste0(id, "-input.rds"))), shQuote(lib), shQuote(prefix), version)
      # v0.7 uses a fresh process for EVERY warmup/measurement, on both libraries;
      # 1.x one process per case and library for warm-up and measurements.
      batches <- if (v07 && !v1) as.list(0:3) else list(NULL)
      measured_runs <- list()
      for (iteration in batches) {
        suffix <- if (is.null(iteration)) "" else paste0("-", iteration)
        process_log <- paste0(prefix, suffix, "-process.log")
        run("/usr/bin/time", c(if (linux) "-v" else "-l", worker, iteration), process_log)
        restore <- worker[-1L]
        restore[restore == "--case"] <- "--restore"
        run(rscript, restore, paste0(prefix, suffix, "-restore.log"))
        log <- readLines(process_log)
        peak_line <- grep(if (linux) "Maximum resident set size" else "maximum resident set size", log, value = TRUE)
        stopifnot(length(peak_line) == 1L)
        peak <- if (linux) as.numeric(sub(".*: *", "", peak_line)) * 1024 else as.numeric(sub("^ *([0-9]+).*", "\\1", peak_line))
        stopifnot(is.finite(peak), peak > 0)
        runs <- read.csv(paste0(prefix, "-runs.csv"))
        runs$release <- release; runs$case <- id; runs$process_peak_bytes <- peak
        measured_runs[[length(measured_runs) + 1L]] <- runs
      }
      runs <- do.call(rbind, measured_runs)
      write.csv(runs, paste0(prefix, "-runs.csv"), row.names = FALSE)
      all_runs[[paste(release, id)]] <- runs
    }
  }
  runs <- do.call(rbind, all_runs)
  write.csv(runs, file.path(output, "runs.csv"), row.names = FALSE)
  medians <- aggregate(cbind(fit_count, retained_models, outer_fit_count, fit_seconds, predict_seconds, outer_seconds, schema_seconds, encode_seconds, decode_seconds, rds_bytes, process_peak_bytes) ~ release + case,
                       runs[runs$iteration > 0L, ], median)
  write.csv(medians, file.path(output, "medians.csv"), row.names = FALSE)
  comparison <- merge(medians[medians$release == "current", -1L], medians[medians$release == "previous", -1L],
                      by = "case", all.x = TRUE, suffixes = c("_current", "_previous"))
  for (metric in c("fit_count", "retained_models", "outer_fit_count", "fit_seconds", "predict_seconds", "outer_seconds", "schema_seconds", "encode_seconds", "decode_seconds", "rds_bytes", "process_peak_bytes")) {
    previous <- comparison[[paste0(metric, "_previous")]]
    comparison[[paste0(metric, "_ratio")]] <- ifelse(previous > 0, comparison[[paste0(metric, "_current")]] / previous, NA_real_)
  }
  comparison$status <- ifelse(is.na(comparison$fit_seconds_previous), "new capability baseline", "requires regression review")
  write.csv(comparison, file.path(output, "comparison.csv"), row.names = FALSE)
  cat(if (smoke) "Smoke completed; NOT release performance evidence.\n" else "Measurements completed; investigate regressions before release approval.\n")
})
