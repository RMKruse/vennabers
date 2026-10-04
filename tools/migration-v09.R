# Executable migration check from vennabers 0.9.0. Run from the repository root:
#   Rscript tools/migration-v09.R <v09-lib> <candidate-lib> <deps-lib> <temporary-out-dir>
# <v09-lib> holds vennabers 0.9.0 installed from `git archive 8ef60f9`, and
# <candidate-lib> the candidate; <deps-lib> adds optional packages missing from
# the site library (probably and its imports). Keep <temporary-out-dir> outside
# .scratch and remove it after summarizing.
#
# A fresh 0.9.0 process fits one object per main path and saves it with its
# predictions, venn_abers_details() and, for tuned fits, venn_abers_tuning().
# Fresh candidate processes then (1) predict from the saved 0.9.0 objects,
# which must reproduce all three exactly, and (2) refit the same cases, which
# must also match exactly except for the
# documented Sigmoid optimizer correction (NEWS): Sigmoid cases carry the
# direct Sigmoid reference tolerance.

migration_cases <- function() {
  library(vennabers)
  bin <- withr::with_seed(8, {
    x <- stats::rnorm(600)
    data.frame(x = x, z = stats::rnorm(600), truth = factor(ifelse(stats::runif(600) < stats::plogis(x), "yes", "no")))
  })
  cls <- withr::with_seed(7, {
    truth <- factor(rep(c("a", "b", "c"), 200))
    data.frame(x = stats::rnorm(600, sd = 2) + c(-1, 1, -1)[truth],
      z = stats::rnorm(600, sd = 2) + c(-1, -1, 1)[truth], truth = truth)
  })
  num <- withr::with_seed(9, {
    x <- stats::rnorm(600)
    data.frame(x = x, z = stats::rnorm(600), truth = 3 + x + stats::rnorm(600, sd = .5))
  })
  base <- function(model) workflows::workflow() |> workflows::add_formula(truth ~ x + z) |>
    workflows::add_model(model)
  glm <- parsnip::logistic_reg(engine = "glm")
  nnet <- parsnip::multinom_reg(penalty = .1) |> parsnip::set_engine("nnet", trace = FALSE, maxit = 1000)
  tuned_nnet <- parsnip::multinom_reg(penalty = tune::tune()) |>
    parsnip::set_engine("nnet", trace = FALSE, maxit = 1000)
  lm <- parsnip::linear_reg()
  fit <- function(d, model, ...) {
    list(object = generics::fit(calibrated_workflow(base(model), "truth", seed = 11, ...), d),
         new = d[1:5, c("x", "z")], type = if (is.numeric(d$truth)) "numeric" else "prob",
         tuned = !is.null(list(...)$tuning))
  }
  post <- function(method, ...) list(method = method, ...)
  p <- withr::with_seed(2, stats::runif(200))
  y <- withr::with_seed(3, stats::runif(200) < p)
  pm <- withr::with_seed(4, matrix(stats::runif(600), 200))
  pm <- pm / rowSums(pm)
  colnames(pm) <- c("a", "b", "c")
  ym <- factor(withr::with_seed(5, sample(c("a", "b", "c"), 200, TRUE)))
  folds <- function(values) matrix(values, 3, 4, dimnames = list(NULL, 1:4))
  frozen <- generics::fit(base(glm) |> workflows::add_tailor(tailor::tailor() |>
    tailor::adjust_probability_calibration(method = "logistic", smooth = FALSE)),
    bin[1:300, ], data_calibration = bin[301:400, ])
  grid <- list(strategy = "joint", model = list(method = "grid", grid = data.frame(penalty = c(.01, .1)),
    resamples = function(d) rsample::vfold_cv(d, v = 2, strata = truth)))
  bayes <- list(strategy = "two_stage", model = list(method = "bayes", initial = 3L, iter = 2L,
    param_info = dials::parameters(dials::penalty(range = c(-3, -1))),
    resamples = function(d) rsample::vfold_cv(d, v = 2, strata = truth),
    control = tune::control_bayes(seed = 4, save_pred = TRUE)))
  # Reserved names travel through the encoded namespace and back.
  special <- stats::setNames(bin, c("vaV0001", "z", ".pred_class"))
  schema <- venn_abers_schema(special, outcome = ".pred_class")
  encoded <- venn_abers_encode(special, schema)
  encoded_base <- workflows::workflow() |> workflows::add_formula(stats::reformulate(
    setdiff(names(encoded), schema$encoded_outcome), schema$encoded_outcome)) |> workflows::add_model(glm)
  list(
    manual_binary = list(object = venn_abers(y, p), new = c(.1, .5, .9)),
    manual_ovo = list(object = venn_abers(ym, pm), new = pm[1:5, ]),
    manual_cross = list(object = cross_venn_abers(y, p, rep(1:4, 50)), new = folds(c(.1, .5, .9))),
    manual_ivar = list(object = venn_abers_regression(num$truth[1:200], num$x[1:200]), new = c(-1, 0, 1)),
    manual_cvar = list(object = cross_venn_abers_regression(num$truth[1:200], num$x[1:200], rep(1:4, 50)),
      new = folds(c(-1, 0, 1))),
    workflow_binary = fit(bin, glm),
    workflow_cross_ovr = fit(cls, nnet, method = "cross", v = 3, classification = "ovr"),
    workflow_pairwise_full = fit(cls, glm, classification = "ovo", model_training = "pairwise",
      prediction_model = "full"),
    workflow_regression = fit(num, lm),
    tailor_logistic_holdout = fit(bin, glm, postprocessing = post("tailor_logistic", strategy = "holdout", prop = .3)),
    tailor_logistic_cross_ensemble = fit(bin, glm, method = "cross", v = 3,
      postprocessing = post("tailor_logistic", strategy = "ensemble", v = 2)),
    tailor_multinomial_ovo = fit(cls, nnet, classification = "ovo",
      postprocessing = post("tailor_multinomial", strategy = "holdout", prop = .3)),
    tailor_multinomial_ovr_full_ensemble = fit(cls, nnet, classification = "ovr", prediction_model = "full",
      postprocessing = post("tailor_multinomial", strategy = "ensemble", v = 2)),
    tailor_linear = fit(num, lm, postprocessing = post("tailor_linear", strategy = "holdout", prop = .3)),
    isotonic_cross_ensemble = fit(num, lm, method = "cross", v = 3,
      postprocessing = post("isotonic_numeric", strategy = "ensemble", v = 2)),
    # Refits may differ by the documented Sigmoid optimizer correction, within
    # the direct Sigmoid reference tolerance.
    sigmoid_probability = c(fit(bin, glm, postprocessing = post("sigmoid", strategy = "holdout", prop = .3,
      sigmoid_input = "probability")), tolerance = 1e-7),
    sigmoid_pairwise_link = c(fit(cls, glm, classification = "ovo", model_training = "pairwise",
      postprocessing = post("sigmoid", strategy = "holdout", prop = .3, sigmoid_input = "glm_link")),
      tolerance = 1e-7),
    grid_tailor_multinomial = fit(cls, tuned_nnet, classification = "ovo", tuning = grid,
      postprocessing = post("tailor_multinomial", strategy = "holdout", prop = .3)),
    bayes_tailor_multinomial_ovr = fit(cls, tuned_nnet, classification = "ovr", tuning = bayes,
      postprocessing = post("tailor_multinomial", strategy = "holdout", prop = .3)),
    bayes_shared_ovo = fit(cls, tuned_nnet, classification = "ovo", method = "cross", v = 3, tuning = bayes),
    schema_binary_cross = list(object = generics::fit(calibrated_workflow(encoded_base, schema$encoded_outcome,
      schema = schema, method = "cross", v = 3, seed = 11), encoded),
      new = venn_abers_encode(special[1:5, c("vaV0001", "z")], schema), type = "prob", schema = schema),
    frozen_tailor = list(object = calibrate_workflow(frozen, bin[401:500, ], "truth"),
      new = bin[501:505, c("x", "z")], type = "prob"))
}

migration_prediction <- function(case) {
  # Manual calibrators have no type; workflows predict their documented type.
  if (is.null(case$type)) return(list(main = predict(case$object, case$new), details = NULL, tuning = NULL))
  main <- predict(case$object, case$new, type = case$type)
  details <- venn_abers_details(case$object, case$new)
  if (!is.null(case$schema)) {
    main <- venn_abers_decode(main, case$schema)
    details <- venn_abers_decode(details, case$schema)
  }
  list(main = main, details = details,
       tuning = if (isTRUE(case$tuned)) migration_tuning(venn_abers_tuning(case$object)))
}

# venn_abers_tuning() without run-dependent parts: elapsed time, native tune
# results and functions, including those inside dials parameter tables
# (closures carry their environments).
migration_tuning <- function(x) {
  if (is.function(x) || inherits(x, "tune_results")) return(NULL)
  if (!is.list(x)) return(x)
  if (!is.data.frame(x) && !is.null(names(x))) x <- x[!names(x) %in% c("native", "elapsed_seconds")]
  x[] <- lapply(x, migration_tuning)
  x
}

# Largest absolute difference over all numeric leaves; NA when shapes differ.
migration_max_diff <- function(a, b) {
  leaves <- function(x) {
    if (is.numeric(x)) return(as.numeric(x))
    if (!is.list(x)) return(numeric())
    as.numeric(rapply(x, as.numeric, classes = c("numeric", "integer"), how = "unlist"))
  }
  a <- leaves(a)
  b <- leaves(b)
  if (length(a) != length(b)) return(NA_real_)
  max(c(0, abs(a - b)))
}

# A refit is accepted when identical, or within its case's documented tolerance.
migration_compare <- function(expected, actual, case, tolerance = NULL) {
  identical_main <- identical(expected$main, actual$main)
  identical_details <- identical(expected$details, actual$details)
  identical_tuning <- identical(expected$tuning, actual$tuning)
  diff <- max(migration_max_diff(expected$main, actual$main), migration_max_diff(expected$details, actual$details))
  within <- !is.null(tolerance) && identical_tuning && !is.na(diff) && diff <= tolerance
  data.frame(case = case, identical_prediction = identical_main, identical_details = identical_details,
    identical_tuning = identical_tuning, max_abs_diff = diff,
    accepted = (identical_main && identical_details && identical_tuning) || within)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 2L && args[[1L]] %in% c("save", "compare")) {
    # Worker mode inside one fresh process; .libPaths() was set by the caller.
    out <- args[[2L]]
    if (args[[1L]] == "save") {
      cases <- migration_cases()
      saved <- lapply(cases, function(case) c(case, list(prediction = migration_prediction(case))))
      saveRDS(list(version = format(utils::packageVersion("vennabers")), cases = saved), file.path(out, "v09.rds"))
    } else {
      library(vennabers)
      saved <- readRDS(file.path(out, "v09.rds"))
      stopifnot(identical(saved$version, "0.9.0"))
      restored <- do.call(rbind, lapply(names(saved$cases), function(case) {
        cbind(check = "saved-0.9.0-object",
          migration_compare(saved$cases[[case]]$prediction, migration_prediction(saved$cases[[case]]), case))
      }))
      refits <- migration_cases()
      refitted <- do.call(rbind, lapply(names(saved$cases), function(case) {
        cbind(check = "candidate-refit",
          migration_compare(saved$cases[[case]]$prediction, migration_prediction(refits[[case]]), case,
            refits[[case]]$tolerance))
      }))
      result <- rbind(restored, refitted)
      result$candidate_version <- format(utils::packageVersion("vennabers"))
      utils::write.csv(result, file.path(out, "migration.csv"), row.names = FALSE)
    }
  } else {
    stopifnot(length(args) == 4L)
    libs <- normalizePath(args[1:3])
    out <- args[[4L]]
    dir.create(out, showWarnings = FALSE, recursive = TRUE)
    out <- normalizePath(out)
    script <- normalizePath("tools/migration-v09.R")
    run <- function(mode, lib) {
      log <- file.path(out, paste0(mode, ".log"))
      # A dead proxy makes any accidental HTTP(S) access fail instead of passing.
      offline <- c("http_proxy=http://127.0.0.1:9", "https_proxy=http://127.0.0.1:9", "no_proxy=",
                   paste0("R_LIBS=", paste(c(lib, libs[[3L]]), collapse = .Platform$path.sep)))
      status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script), mode, shQuote(out)),
        stdout = log, stderr = log, env = offline)
      if (status != 0L) stop(mode, " failed; see ", log, call. = FALSE)
    }
    run("save", libs[[1L]])
    run("compare", libs[[2L]])
    result <- utils::read.csv(file.path(out, "migration.csv"))
    print(result, row.names = FALSE)
    if (!all(result$accepted)) quit(status = 1L)
  }
}
