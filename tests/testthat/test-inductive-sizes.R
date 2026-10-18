testthat::test_that("independent Inductive sizes resolve sklearn rounding on the local domain", {
  skip_if_no_integration()
  d <- data.frame(x = sin(1:100), truth = factor(rep(c("yes", "no", "no", "yes"), 25)))
  base <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  sizes <- function(...) {
    state <- workflows::extract_fit_engine(generics::fit(calibrated_workflow(base, "truth", seed = 3, ...), d))
    fold <- state$folds$Inductive1
    c(length(fold$analysis), length(fold$assessment), length(fold$unassigned))
  }
  # Training floors, calibration ceils, whole numbers are exact, a missing size is the complement.
  testthat::expect_identical(sizes(training_size = .555, calibration_size = .071), c(55L, 8L, 37L))
  testthat::expect_identical(sizes(training_size = .7), c(70L, 30L, 0L))
  testthat::expect_identical(sizes(calibration_size = .155), c(84L, 16L, 0L))
  testthat::expect_identical(sizes(calibration_size = 15), c(85L, 15L, 0L))
  testthat::expect_identical(sizes(training_size = .5, calibration_size = 10), c(50L, 10L, 40L))
  testthat::expect_identical(sizes(training_size = 10, calibration_size = 1, strata = FALSE), c(10L, 1L, 89L))

  # Exact totals under stratification, where rsample rounds each class down.
  three <- data.frame(x = sin(1:21), truth = factor(rep(c("a", "b", "c"), 7)))
  multi <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::multinom_reg(engine = "nnet"))
  rsample_rows <- length(as.integer(withr::with_seed(1, rsample::initial_split(three, prop = .8, strata = truth, pool = 0)), data = "analysis"))
  testthat::expect_identical(rsample_rows, 15L)
  for (strata in list(NULL, FALSE)) {
    state <- workflows::extract_fit_engine(generics::fit(calibrated_workflow(multi, "truth", classification = "ovr",
      seed = 1, training_size = .8, strata = strata), three))
    fold <- state$folds$Inductive1
    testthat::expect_identical(c(length(fold$analysis), length(fold$assessment)), c(16L, 5L))
    if (is.null(strata)) {
      # Largest remainders, ties in level order: 16 = 6 + 5 + 5, calibration takes the rest.
      testthat::expect_identical(as.vector(table(three$truth[fold$analysis])), c(6L, 5L, 5L))
    }
  }
  state <- workflows::extract_fit_engine(generics::fit(calibrated_workflow(multi, "truth", classification = "ovr",
    seed = 1, training_size = 9, calibration_size = 7), three))
  fold <- state$folds$Inductive1
  testthat::expect_identical(as.vector(table(three$truth[fold$analysis])), c(3L, 3L, 3L))
  testthat::expect_identical(as.vector(table(three$truth[fold$assessment])), c(3L, 2L, 2L))
  testthat::expect_identical(sort(unlist(fold[c("analysis", "assessment", "unassigned")], use.names = FALSE)), 1:21)

  # The same seed gives the same draw; a different seed a different one.
  plan <- function(seed) workflows::extract_fit_engine(generics::fit(calibrated_workflow(base, "truth", seed = seed,
    training_size = 50, calibration_size = 20), d))$folds$Inductive1
  testthat::expect_identical(plan(9), plan(9))
  testthat::expect_false(identical(plan(9)$analysis, plan(10)$analysis))
})

testthat::test_that("the 100 -> 50/20/30 scenario keeps U out of matched and inside Full1", {
  skip_if_no_integration()
  d <- data.frame(x = sin(1:100) + rep(c(1, 0, 0, 1), 25), truth = factor(rep(c("yes", "no", "no", "yes"), 25)))
  base <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  for (mode in c("matched", "full")) {
    fit <- generics::fit(calibrated_workflow(base, "truth", seed = 42, training_size = 50, calibration_size = 20,
      prediction_model = mode), d)
    state <- workflows::extract_fit_engine(fit)
    fold <- state$folds$Inductive1
    testthat::expect_identical(lengths(fold[c("analysis", "assessment", "unassigned", "training_size", "calibration_size")]),
      c(analysis = 50L, assessment = 20L, unassigned = 30L, training_size = 1L, calibration_size = 1L))
    testthat::expect_identical(c(fold$training_size, fold$calibration_size), c(50L, 20L))
    testthat::expect_identical(sort(c(fold$analysis, fold$assessment, fold$unassigned)), 1:100)
    # Stratified: 25 of each class in training, 10 in calibration.
    testthat::expect_identical(as.vector(table(d$truth[fold$analysis])), c(25L, 25L))
    testthat::expect_identical(as.vector(table(d$truth[fold$assessment])), c(10L, 10L))
    event <- state$event_class
    source <- generics::fit(base, d[fold$analysis, ])
    core <- venn_abers(d$truth[fold$assessment] == event,
      predict(source, d[fold$assessment, ], type = "prob")[[paste0(".pred_", event)]])
    testthat::expect_identical(state$calibration$Inductive1$row, fold$assessment)
    predictor <- if (mode == "full") generics::fit(base, d) else source
    expected <- predict(core, predict(predictor, d, type = "prob")[[paste0(".pred_", event)]])$probability
    testthat::expect_lte(max(abs(predict(fit, d, type = "prob")[[paste0(".pred_", event)]] - expected)), 1e-10)
    testthat::expect_identical(unname(state$sources), if (mode == "full") "Full1" else "Inductive1")
    testthat::expect_identical(state$parameters$requested[c("training_size", "calibration_size")],
      list(training_size = 50, calibration_size = 20))
    testthat::expect_identical(state$parameters$effective[c("training_size", "calibration_size", "unassigned_size")],
      list(training_size = 50L, calibration_size = 20L, unassigned_size = 30L))
    testthat::expect_null(state$parameters$effective$calibration_prop)
    printed <- utils::capture.output(print(state))
    testthat::expect_true("Inductive rows: training 50 | calibration 20 | unassigned 30 " %in% printed)
  }
})

testthat::test_that("regression and postprocessing learn only on training; Full1 uses all of F", {
  skip_if_no_integration()
  d <- data.frame(x = sin(1:100), y = cos(1:100) + sin(1:100))
  base <- workflows::workflow() |> workflows::add_formula(y ~ x) |>
    workflows::add_model(parsnip::linear_reg(engine = "lm"))
  fit <- generics::fit(calibrated_workflow(base, "y", seed = 5, training_size = .5, calibration_size = .2), d)
  state <- workflows::extract_fit_engine(fit)
  fold <- state$folds$Inductive1
  testthat::expect_identical(lengths(fold[c("analysis", "assessment", "unassigned")]),
    c(analysis = 50L, assessment = 20L, unassigned = 30L))
  source <- generics::fit(base, d[fold$analysis, ])
  core <- venn_abers_regression(d$y[fold$assessment], predict(source, d[fold$assessment, ])$.pred)
  expected <- predict(core, predict(source, d)$.pred)$prediction
  testthat::expect_lte(max(abs(predict(fit, d)$.pred - expected)), 1e-10)

  b <- data.frame(x = sin(1:100) + rep(c(1, 0, 0, 1), 25), truth = factor(rep(c("yes", "no", "no", "yes"), 25)))
  logistic <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  post <- list(method = "sigmoid", strategy = "holdout", prop = .25, sigmoid_input = "probability")
  for (mode in c("matched", "full")) {
    state <- workflows::extract_fit_engine(generics::fit(calibrated_workflow(logistic, "truth", seed = 6,
      training_size = 50, calibration_size = 20, prediction_model = mode, postprocessing = post), b))
    fold <- state$folds$Inductive1
    held <- state$postprocessing$Inductive1
    # B/P is drawn inside training only; neither C nor U takes part.
    testthat::expect_identical(held$Q, fold$analysis)
    testthat::expect_identical(sort(c(held$B, held$P)), fold$analysis)
    if (mode == "full") {
      testthat::expect_identical(state$postprocessing$Full1$Q, 1:100)
      testthat::expect_identical(state$postprocessing$Full1$B_size + state$postprocessing$Full1$P_size, 100L)
    }
  }
})

testthat::test_that("default calls, saved fits and older fits without U keep their contract", {
  skip_if_no_integration()
  d <- data.frame(x = sin(1:100), truth = factor(rep(c("yes", "no", "no", "yes"), 25)))
  base <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  # Both sizes NULL: the calibration_prop draw and the stored shape are unchanged.
  for (prop in c(.2, .35)) {
    spec <- if (prop == .2) calibrated_workflow(base, "truth", seed = 42) else
      calibrated_workflow(base, "truth", seed = 42, calibration_prop = prop)
    state <- workflows::extract_fit_engine(generics::fit(spec, d))
    split <- withr::with_seed(42, rsample::initial_split(d, prop = 1 - prop, strata = truth, pool = 0))
    testthat::expect_identical(state$folds$Inductive1[c("analysis", "assessment", "training_size", "calibration_size")],
      list(analysis = as.integer(split, data = "analysis"), assessment = as.integer(split, data = "assessment"),
           training_size = length(as.integer(split, data = "analysis")),
           calibration_size = length(as.integer(split, data = "assessment"))))
    testthat::expect_false(any(c("training_size", "calibration_size") %in% names(state$parameters$requested)))
    testthat::expect_false(any(c("training_size", "calibration_size", "unassigned_size") %in% names(state$parameters$effective)))
    testthat::expect_identical(state$parameters$effective$calibration_prop, prop)
    testthat::expect_false(any(grepl("Inductive rows", utils::capture.output(print(state)))))
  }

  fit <- generics::fit(calibrated_workflow(base, "truth", seed = 42, training_size = 50, calibration_size = 20,
    prediction_model = "full"), d)
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(fit, path)
  testthat::expect_identical(predict(readRDS(path), d, type = "prob"), predict(fit, d, type = "prob"))
  # A fit saved before U existed has no field: U is empty and nothing else changes.
  older <- fit
  older$fit$fit$fit$folds$Inductive1$unassigned <- NULL
  older$fit$fit$fit$parameters$effective[c("training_size", "calibration_size", "unassigned_size")] <- NULL
  testthat::expect_identical(predict(older, d, type = "prob"), predict(fit, d, type = "prob"))
  testthat::expect_identical(venn_abers_details(older, d), venn_abers_details(fit, d))
  testthat::expect_false(any(grepl("Inductive rows", utils::capture.output(print(workflows::extract_fit_engine(older))))))
})

testthat::test_that("invalid sizes and conflicts fail with the domain and both sizes", {
  skip_if_no_integration()
  d <- data.frame(x = sin(1:100), truth = factor(rep(c("yes", "no", "no", "yes"), 25)))
  base <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::logistic_reg(engine = "glm"))
  for (size in list(0, -1, 1.5, 1 + 1e-9, Inf, NA_real_, TRUE, "10", numeric(), c(.1, .2), matrix(.5))) {
    testthat::expect_error(calibrated_workflow(base, "truth", training_size = size), "`training_size` must be NULL")
    testthat::expect_error(calibrated_workflow(base, "truth", calibration_size = size), "`calibration_size` must be NULL")
  }
  testthat::expect_error(calibrated_workflow(base, "truth", training_size = quote(tune())), "cannot be tuned")
  testthat::expect_error(calibrated_workflow(base, "truth", calibration_size = quote(tune("c"))), "cannot be tuned")
  testthat::expect_error(calibrated_workflow(base, "truth", training_size = .7, calibration_size = .4), "sum to more than 1")
  testthat::expect_error(calibrated_workflow(base, "truth", method = "cross", training_size = .5), "method = 'inductive'")
  testthat::expect_error(calibrated_workflow(base, "truth", calibration_prop = .2, calibration_size = .2), "not both")
  testthat::expect_error(calibrated_workflow(base, "truth", training_size = .5,
    splits = function(data) rsample::initial_split(data)), "partition all rows")
  testthat::expect_error(calibrated_workflow(base, "truth", training_size = .5, training = 1), "training")

  fails <- function(text, ...) testthat::expect_error(generics::fit(calibrated_workflow(base, "truth", seed = 1, ...), d), text, fixed = TRUE)
  fails("`training_size` = 150 (150 rows) request 150 rows, but only the 100 local rows are available.", training_size = 150)
  fails("`training_size` = 50 (50 rows) and `calibration_size` = 60 (60 rows) request 110 rows, but only the 100 local rows are available.",
    training_size = 50, calibration_size = 60)
  fails("`training_size` = 0.5 (50 rows) and `calibration_size` = 51 (51 rows) request 101 rows", training_size = .5, calibration_size = 51)
  fails("`training_size` = 0.001 (0 rows) leaves 0 training rows of the 100 local rows", training_size = .001)
  fails("`training_size` = 100 (100 rows) leaves 0 calibration rows of the 100 local rows", training_size = 100)
  fails("`calibration_size` = 100 (100 rows) leaves 0 training rows", calibration_size = 100)

  # After the size check, the existing checks run unchanged: every class must reach C.
  three <- data.frame(x = sin(1:30), truth = factor(rep(c("a", "b", "c"), 10)))
  multi <- workflows::workflow() |> workflows::add_formula(truth ~ x) |>
    workflows::add_model(parsnip::multinom_reg(engine = "nnet"))
  testthat::expect_error(generics::fit(calibrated_workflow(multi, "truth", classification = "ovr", seed = 1,
    training_size = 20, calibration_size = 2), three), "class")
  # Pair domains and searches with Venn-Abers candidates are not wired yet.
  testthat::expect_error(calibrated_workflow(multi, "truth", classification = "ovo", model_training = "pairwise",
    training_size = .5), "do not yet support")
})
