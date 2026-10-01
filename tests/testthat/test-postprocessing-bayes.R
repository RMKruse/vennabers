bayes_binary_data <- function(n = 600L) {
  withr::with_seed(11, {
    x <- rnorm(n, sd = 1.5)
    truth <- factor(ifelse(stats::runif(n) < stats::plogis(x - .4 * x^2 + .5), "yes", "no"), levels = c("no", "yes"))
    data.frame(row_id = seq_len(n), x = x, truth = truth)
  })
}

bayes_tuned_base <- function(data, engine = parsnip::logistic_reg(engine = "glm")) {
  recipe <- recipes::recipe(truth ~ ., data = data) |>
    recipes::update_role(row_id, new_role = "id") |>
    recipes::step_poly(x, degree = tune::tune("degree"))
  workflows::workflow() |> workflows::add_recipe(recipe) |> workflows::add_model(engine)
}

degree_params <- function(upper) dials::parameters(dials::new_quant_param(type = "integer",
  range = c(1L, upper), inclusive = c(TRUE, TRUE), label = c(degree = "Degree")))

bayes_search <- function(upper = 3L, initial = 3L, iter = 2L, resamples = bayes_stratified, ...) {
  list(method = "bayes", initial = initial, iter = iter, param_info = degree_params(upper), resamples = resamples,
    control = tune::control_bayes(seed = 4, save_pred = TRUE, ...))
}

bayes_stratified <- function(d) rsample::vfold_cv(d, v = 2, strata = truth, pool = 0)
bayes_plain <- function(d) rsample::vfold_cv(d, v = 2)

# Positional plans keep every role fixed when target values are mutated.
bayes_positional_va <- function(data) {
  n <- nrow(data)
  rsample::make_splits(list(analysis = seq_len(n - n %/% 4L), assessment = seq.int(n - n %/% 4L + 1L, n)), data)
}
bayes_positional_holdout <- function(data) {
  n <- nrow(data)
  rsample::make_splits(list(analysis = seq_len(n - n %/% 3L), assessment = seq.int(n - n %/% 3L + 1L, n)), data)
}

bayes_positional_ensemble <- function(data) {
  n <- nrow(data)
  half <- list(seq_len(n %/% 2L), seq.int(n %/% 2L + 1L, n))
  rsample::manual_rset(lapply(half, function(P)
    rsample::make_splits(list(analysis = setdiff(seq_len(n), P), assessment = P), data)), c("first", "second"))
}

bayes_flip <- function(data, rows) {
  data$truth[rows] <- ifelse(data$truth[rows] == "yes", "no", "yes")
  data
}

# The degree of a finalized (possibly fitted) candidate workflow; NA while tuned.
workflow_degree <- function(workflow) {
  degree <- workflows::extract_preprocessor(workflow)$steps[[1L]]$degree
  if (is.numeric(degree)) as.numeric(degree) else NA_real_
}

# Every local search of a fitted state, flattened as path/inner.
local_searches <- function(selection) {
  unlist(lapply(names(selection$models), function(path) stats::setNames(selection$models[[path]],
    paste(path, names(selection$models[[path]]), sep = "/"))), recursive = FALSE)
}

testthat::test_that("local Bayes stays inside B, keeps P/C out and repeats no search inside candidates", {
  for (pkg in c("tune", "tailor", "probably")) testthat::skip_if_not_installed(pkg)
  d <- bayes_binary_data(360L)
  base <- bayes_tuned_base(d)
  post <- list(method = "tailor_logistic", strategy = "holdout", splits = bayes_positional_holdout)
  for (strategy in c("two_stage", "joint")) {
    spec <- calibrated_workflow(base, "truth", splits = bayes_positional_va, seed = 5,
      tuning = list(strategy = strategy, model = bayes_search(iter = 2L)), postprocessing = post)
    fitted <- generics::fit(spec, d)
    state <- workflows::extract_fit_engine(fitted)
    selection <- venn_abers_tuning(fitted)
    diagnostic <- state$postprocessing$Inductive1
    local <- selection$models$Inductive1$Holdout1
    info <- strategy
    testthat::expect_identical(local$B, diagnostic$B, info = info)
    testthat::expect_identical(diagnostic$selected, local$selected, info = info)
    testthat::expect_identical(sort(unlist(lapply(local$resamples, `[[`, "assessment"), use.names = FALSE)),
      seq_along(diagnostic$B), info = info)
    # The native GP input only ever held rows of this B.
    testthat::expect_identical(sort(unique(tune::collect_predictions(local$native)$.row)), seq_along(diagnostic$B), info = info)
    # Initial points 3, 1, 2 exhaust the integer range: the first proposal repeats.
    testthat::expect_identical(local$steps$initial$degree, c(3L, 1L, 2L), info = info)
    testthat::expect_identical(local$steps$initial$id, sprintf("model_%03d", 1:3), info = info)
    testthat::expect_identical(local$stop_reason, "repeated_candidate", info = info)
    testthat::expect_identical(local$attempts, 4L, info = info)
    testthat::expect_identical(local$cost$candidate_evaluations, 8L, info = info)
    testthat::expect_identical(local$bayes_seed, 4, info = info)
    testthat::expect_true(is.integer(local$search_seed), info = info)
    # Joint candidates are fixed compositions: their decisions hold no nested search.
    testthat::expect_true(all(vapply(unlist(local$decisions, recursive = FALSE), is.null, TRUE)), info = info)
    # Three candidates x two resamples x one inner B per candidate, plus the final B fit.
    testthat::expect_identical(local$cost$observed_base_fits, 6L, info = info)
    testthat::expect_identical(selection$cost$observed_base_fits, 7L, info = info)
    engine_coef <- function(s) stats::coef(workflows::extract_fit_engine(s$models$Inductive1))
    for (role in c("P", "C")) {
      changed <- generics::fit(spec, bayes_flip(d, diagnostic[[role]]))
      other <- workflows::extract_fit_engine(changed)
      again <- venn_abers_tuning(changed)$models$Inductive1$Holdout1
      keys <- c("chosen", "selected", "candidates", "scores", "resamples", "steps", "stop_reason", "search_seed")
      testthat::expect_identical(again[keys], local[keys], info = paste(info, role))
      testthat::expect_identical(engine_coef(other), engine_coef(state), info = paste(info, role))
      testthat::expect_identical(identical(other$postprocessing$Inductive1$coefficients, diagnostic$coefficients),
        role == "C", info = paste(info, role))
    }
  }
})

testthat::test_that("mutating an inner pair's P leaves its own B search unchanged", {
  for (pkg in c("tune", "tailor", "probably")) testthat::skip_if_not_installed(pkg)
  d <- bayes_binary_data(480L)
  base <- bayes_tuned_base(d)
  post <- list(method = "tailor_logistic", strategy = "ensemble", splits = bayes_positional_ensemble)
  keys <- c("chosen", "selected", "candidates", "scores", "resamples", "steps", "stop_reason", "search_seed")
  for (strategy in c("two_stage", "joint")) {
    spec <- calibrated_workflow(base, "truth", splits = bayes_positional_va, seed = 5,
      tuning = list(strategy = strategy, model = bayes_search(upper = 2L, initial = 2L)), postprocessing = post)
    state <- workflows::extract_fit_engine(generics::fit(spec, d))
    first <- state$postprocessing$Inductive1$inner_folds$first
    changed <- workflows::extract_fit_engine(generics::fit(spec, bayes_flip(d, first$P)))
    testthat::expect_identical(changed$tuning$models$Inductive1$first[keys],
      state$tuning$models$Inductive1$first[keys], info = strategy)
    testthat::expect_identical(stats::coef(workflows::extract_fit_engine(changed$models$Inductive1$models$first)),
      stats::coef(workflows::extract_fit_engine(state$models$Inductive1$models$first)), info = strategy)
    # The other pair's B contains P_first, so its search sees the mutation.
    testthat::expect_false(identical(changed$tuning$models$Inductive1$second$scores,
      state$tuning$models$Inductive1$second$scores), info = strategy)
  }
})

testthat::test_that("a failure in one inner pair excludes the whole candidate from selection and the next GP", {
  for (pkg in c("tune", "tailor", "probably")) testthat::skip_if_not_installed(pkg)
  d <- bayes_binary_data()
  base <- bayes_tuned_base(d)
  fit_postprocessing_pair <- .fit_postprocessing_pair
  fit_sigmoid <- .fit_sigmoid_workflow
  base_probability <- .base_probability
  tuning_score <- .tuning_score
  same_candidate <- .same_candidate
  seen <- new.env()
  fails <- function(kind, context_or_inner, degree) identical(seen$kind, kind) && identical(degree, 3) &&
    grepl("Fold2", context_or_inner, fixed = TRUE)
  testthat::local_mocked_bindings(
    .fit_postprocessing_pair = function(workflow, data, plan, fold, domain, settings, id, inner_id, ...) {
      if (fails("fit", inner_id, workflow_degree(workflow))) stop("injected B fit failure")
      fit_postprocessing_pair(workflow, data, plan, fold, domain, settings, id, inner_id, ...)
    },
    .fit_sigmoid_workflow = function(workflow, data, plan, domain, input, context) {
      fitted <- fit_sigmoid(workflow, data, plan, domain, input, context)
      if (fails("postprocessor", context, workflow_degree(workflow))) stop("injected postprocessor failure")
      fitted
    },
    .base_probability = function(model, data, classes, event, id = "Inductive1") {
      out <- base_probability(model, data, classes, event, id)
      degree <- if (inherits(model, c("workflow", "vennabers_tailor_workflow"))) workflow_degree(model) else NA_real_
      if (fails("predict", id, degree)) stop("injected predict failure")
      if (fails("rows", id, degree)) out <- out[-1L, , drop = FALSE]
      out
    },
    .same_candidate = function(predictions, values) {
      seen$values <- values
      same_candidate(predictions, values)
    },
    .tuning_score = function(metric, ...) {
      if (identical(seen$kind, "metric") && identical(as.numeric(seen$values$degree), 3)) {
        stop("injected metric failure")
      }
      tuning_score(metric, ...)
    }
  )
  expected <- c(fit = "injected B fit failure", postprocessor = "injected postprocessor failure",
    predict = "injected predict failure", rows = "", metric = "injected metric failure")
  for (kind in names(expected)) {
    seen$kind <- kind
    method <- if (kind == "postprocessor") "sigmoid" else "tailor_logistic"
    post <- c(list(method = method), if (method == "sigmoid") list(sigmoid_input = "probability"),
      list(strategy = "ensemble", v = 2))
    fitted <- generics::fit(calibrated_workflow(base, "truth", seed = 6, calibration_prop = .3,
      tuning = list(strategy = "joint", model = bayes_search(iter = 2L)), postprocessing = post), d)
    searches <- local_searches(venn_abers_tuning(fitted))
    testthat::expect_named(searches, c("Inductive1/Fold1", "Inductive1/Fold2"))
    for (name in names(searches)) {
      local <- searches[[name]]
      info <- paste(kind, name)
      excluded <- local$candidates[local$candidates$status == "excluded", ]
      testthat::expect_identical(excluded$degree, 3L, info = info)
      testthat::expect_identical(excluded$id, "model_001", info = info)
      testthat::expect_true(!is.na(excluded$reason) && nzchar(excluded$reason), info = info)
      testthat::expect_identical(local$cost$excluded_candidates, 1L, info = info)
      testthat::expect_false(local$selected$degree == 3L, info = info)
      # Only complete valid results feed the GP.
      testthat::expect_false(3L %in% tune::collect_metrics(local$native)$degree, info = info)
      history <- paste(c(excluded$reason, local$notes$note), collapse = " ")
      if (nzchar(expected[[kind]])) testthat::expect_match(history, expected[[kind]], fixed = TRUE, info = info)
      testthat::expect_identical(local$stop_reason, "repeated_candidate", info = info)
      testthat::expect_identical(local$attempts, 4L, info = info)
    }
    testthat::expect_true(all(is.finite(as.matrix(predict(fitted, d, type = "prob")))), info = kind)
  }
  # Too few or no complete initial points: a clear error, no fallback to Grid.
  # Two initial points on 1..3 are 2 and 3; only degree 3 fails.
  seen$kind <- "fit"
  testthat::expect_error(generics::fit(calibrated_workflow(base, "truth", seed = 6, calibration_prop = .3,
    tuning = list(strategy = "joint", model = bayes_search(initial = 2L)),
    postprocessing = list(method = "tailor_logistic", strategy = "ensemble", v = 2)), d),
    "Bayes needs at least 2 complete initial model candidates; found 1: .*injected B fit failure")
  testthat::local_mocked_bindings(.fit_postprocessing_pair = function(workflow, data, plan, fold, domain, settings, id, inner_id, ...) {
    if (!is.na(workflow_degree(workflow)) && identical(inner_id, "Fold2")) stop("injected B fit failure")
    fit_postprocessing_pair(workflow, data, plan, fold, domain, settings, id, inner_id, ...)
  })
  testthat::expect_error(generics::fit(calibrated_workflow(base, "truth", seed = 6, calibration_prop = .3,
    tuning = list(strategy = "joint", model = bayes_search()),
    postprocessing = list(method = "tailor_logistic", strategy = "ensemble", v = 2)), d),
    "Bayes needs at least 2 complete initial model candidates; found 0: .*injected B fit failure")
})

testthat::test_that("failed and repeated proposals spend budget; time limits apply between steps", {
  for (pkg in c("tune", "tailor", "probably")) testthat::skip_if_not_installed(pkg)
  d <- bayes_binary_data(360L)
  base <- bayes_tuned_base(d)
  post <- list(method = "tailor_logistic", strategy = "holdout", prop = .3)
  run <- function(search) {
    fitted <- generics::fit(calibrated_workflow(base, "truth", seed = 2,
      tuning = list(strategy = "two_stage", model = search), postprocessing = post), d)
    venn_abers_tuning(fitted)
  }
  # Initial points are 6, 1, 3; every continuation proposal fails in B.
  fit_base_model <- .fit_base_model
  testthat::local_mocked_bindings(.fit_base_model = function(workflow, data, counter) {
    degree <- workflow_degree(workflow)
    if (!is.na(degree) && !degree %in% c(1, 3, 6)) {
      if (!is.null(counter)) counter$n <- counter$n + 1L
      stop("injected continuation failure")
    }
    fit_base_model(workflow, data, counter)
  })
  failed <- run(bayes_search(upper = 6L, iter = 3L, no_improve = 10L))
  local <- failed$models$Inductive1$Holdout1
  testthat::expect_identical(local$steps$initial$degree, c(6L, 1L, 3L))
  # tune_bayes drops the failed proposal 2; it still gets the next global ID.
  continuation <- local$candidates[-(1:3), ]
  testthat::expect_identical(continuation$degree, 2L)
  testthat::expect_identical(continuation$id, "model_004")
  testthat::expect_identical(continuation$status, "excluded")
  testthat::expect_match(continuation$reason, "injected continuation failure")
  testthat::expect_identical(local$steps$step_1$id, "model_004")
  testthat::expect_identical(local$notes$step[grepl("injected continuation failure", local$notes$note)], "step_1")
  testthat::expect_false(any(local$notes$step == "step_1" & !is.na(local$notes$resample)))
  testthat::expect_setequal(tune::collect_metrics(local$native)$degree, c(6L, 1L, 3L))
  # The failed step spends budget and the search continues until a repeat.
  testthat::expect_identical(local$steps$step_2$repeated$degree, 3L)
  testthat::expect_identical(local$stop_reason, "repeated_candidate")
  testthat::expect_identical(local$attempts, 5L)
  testthat::expect_false(anyDuplicated(local$candidates$id) > 0L)
  # Every attempt, failed or repeated, was evaluated on both resamples.
  testthat::expect_identical(local$cost$candidate_evaluations, local$attempts * 2L)
  testthat::expect_identical(local$cost$observed_base_fits, local$attempts * 2L)
  testthat::expect_identical(failed$cost$observed_base_fits, local$attempts * 2L + 1L)
  # no_improve counts failed steps.
  stale <- run(bayes_search(upper = 6L, iter = 3L, no_improve = 1L))$models$Inductive1$Holdout1
  testthat::expect_identical(stale$stop_reason, "no_improve")
  testthat::expect_identical(stale$attempts, 4L)
  timed <- run(bayes_search(upper = 6L, iter = 3L, time_limit = 1e-9))$models$Inductive1$Holdout1
  testthat::expect_identical(timed$stop_reason, "time_limit")
  testthat::expect_identical(timed$attempts, 3L)
  testthat::expect_named(timed$steps, "initial")
})

testthat::test_that("postprocessing Bayes covers Cross, full and both strategies with reconstructable costs", {
  for (pkg in c("tune", "tailor", "probably")) testthat::skip_if_not_installed(pkg)
  d <- bayes_binary_data(800L)
  base <- bayes_tuned_base(d)
  for (strategy in c("two_stage", "joint")) for (kind in c("holdout", "ensemble")) for (model in c("matched", "full")) {
    post <- if (kind == "holdout") list(method = "tailor_logistic", strategy = "holdout", prop = .3) else
      list(method = "sigmoid", sigmoid_input = "probability", strategy = "ensemble", v = 2)
    fitted <- generics::fit(calibrated_workflow(base, "truth", method = "cross", v = 2, seed = 3,
      prediction_model = model, tuning = list(strategy = strategy, model = bayes_search(upper = 2L, initial = 2L)),
      postprocessing = post), d)
    state <- workflows::extract_fit_engine(fitted)
    selection <- venn_abers_tuning(fitted)
    info <- paste(strategy, kind, model)
    inner <- if (kind == "holdout") "Holdout1" else c("Fold1", "Fold2")
    paths <- c("Fold1", "Fold2", if (model == "full") "Full1")
    testthat::expect_named(selection$models, paths, info = info)
    searches <- local_searches(selection)
    testthat::expect_length(searches, length(paths) * length(inner))
    # Nested joint compositions hold the same VA/full structure as the outer one.
    per_candidate <- if (strategy == "two_stage") 1L else length(inner) * (2L + (model == "full"))
    for (name in names(searches)) {
      local <- searches[[name]]
      testthat::expect_identical(local$budget$inner_pairs, if (strategy == "joint") length(inner) else 1L, info = info)
      testthat::expect_true(local$stop_reason %in% c("budget", "no_improve", "repeated_candidate"), info = paste(info, name))
      testthat::expect_identical(local$cost$candidate_evaluations, local$attempts * 2L, info = paste(info, name))
      if (all(local$candidates$status == "eligible")) {
        testthat::expect_identical(local$cost$observed_base_fits,
          nrow(local$candidates) * 2L * per_candidate, info = paste(info, name))
      }
    }
    local_costs <- vapply(searches, function(x) x$cost$observed_base_fits, 1L)
    testthat::expect_identical(selection$cost$observed_base_fits, sum(local_costs) + length(searches), info = info)
    seeds <- vapply(searches, `[[`, 1L, "search_seed")
    testthat::expect_false(anyDuplicated(seeds) > 0L, info = info)
    for (path in paths) for (j in inner) {
      plan <- if (kind == "holdout") state$postprocessing[[path]] else state$postprocessing[[path]]$inner_folds[[j]]
      testthat::expect_identical(plan$selected, selection$models[[path]][[j]]$selected, info = paste(info, path, j))
      testthat::expect_identical(plan$B, selection$models[[path]][[j]]$B, info = paste(info, path, j))
    }
    testthat::expect_true(all(is.finite(as.matrix(predict(fitted, d, type = "prob")))), info = info)
  }
})

bayes_multiclass_data <- function(n = 900L) {
  withr::with_seed(21, {
    truth <- factor(rep(c("a", "b", "c"), length.out = n))
    data.frame(row_id = seq_len(n), x = rnorm(n, sd = 2) + c(-1, 1, -1)[truth],
      z = rnorm(n, sd = 2) + c(-1, -1, 1)[truth], truth = truth)
  })
}

testthat::test_that("pairwise Bayes with postprocessing searches in every local pair B", {
  for (pkg in c("tune", "tailor", "probably")) testthat::skip_if_not_installed(pkg)
  d <- bayes_multiclass_data()[c("row_id", "x", "truth")]
  base <- bayes_tuned_base(d)
  post <- list(method = "tailor_logistic", strategy = "ensemble", v = 2)
  for (strategy in c("joint", "two_stage")) {
    tuning <- list(strategy = strategy, model = bayes_search(upper = 2L, initial = 2L))
    if (strategy == "joint") tuning$joint_resamples <- bayes_stratified
    fitted <- generics::fit(calibrated_workflow(base, "truth", classification = "ovo", model_training = "pairwise",
      seed = 9, prediction_model = "full", tuning = tuning, postprocessing = post), d)
    state <- workflows::extract_fit_engine(fitted)
    selection <- venn_abers_tuning(fitted)
    if (strategy == "joint") {
      testthat::expect_identical(selection$joint$candidates$status, "eligible")
    } else testthat::expect_null(selection$joint)
    for (pair in names(selection$models)) {
      component <- state$pair_models[[pair]]
      testthat::expect_named(selection$models[[pair]], c("Inductive1", "Full1"))
      for (path in c("Inductive1", "Full1")) for (inner in c("Fold1", "Fold2")) {
        local <- selection$models[[pair]][[path]][[inner]]
        info <- paste(strategy, pair, path, inner)
        testthat::expect_identical(local$pair_id, pair, info = info)
        testthat::expect_identical(local$B, component$postprocessing[[path]]$inner_folds[[inner]]$B, info = info)
        testthat::expect_identical(sort(unique(tune::collect_predictions(local$native)$.row)), seq_along(local$B), info = info)
        testthat::expect_true(all(d$truth[component$rows[local$B]] %in% component$class_levels), info = info)
        testthat::expect_true(local$chosen %in% local$candidates$id[local$candidates$status == "eligible"], info = info)
      }
    }
    testthat::expect_true(all(is.finite(as.matrix(predict(fitted, d, type = "prob")))), info = strategy)
  }
})

testthat::test_that("shared multiclass Bayes option selection keeps S out of every local B and P", {
  for (pkg in c("tune", "tailor", "probably", "nnet")) testthat::skip_if_not_installed(pkg)
  d <- bayes_multiclass_data(2400L)
  base <- bayes_tuned_base(d, parsnip::multinom_reg(penalty = .1) |> parsnip::set_engine("nnet", trace = FALSE, maxit = 1000))
  loss <- dials::parameters(dials::new_qual_param(type = "character", values = c("log", "brier"), label = c(va_loss = "Loss")))
  for (strategy in c("joint", "two_stage")) {
    config <- list(strategy = strategy, selection_prop = .5, model = bayes_search(upper = 2L, initial = 2L),
      calibration = list(method = "bayes", initial = 2L, iter = 1L, param_info = loss, resamples = bayes_stratified,
        control = tune::control_bayes(seed = 5, save_pred = TRUE)))
    fitted <- generics::fit(calibrated_workflow(base, "truth", classification = "ovr", seed = 4,
      loss = tune::tune("va_loss"), tuning = config,
      postprocessing = list(method = "tailor_multinomial", strategy = "holdout", prop = .3)), d)
    state <- workflows::extract_fit_engine(fitted)
    selection <- venn_abers_tuning(fitted)
    roles <- selection$calibration
    plan <- state$postprocessing$Inductive1
    global <- function(rows) roles$final_rows[rows]
    testthat::expect_length(intersect(global(c(plan$B, plan$P, plan$C)), roles$selection_rows), 0L)
    testthat::expect_identical(selection$models$Inductive1$Holdout1$B, plan$B)
    testthat::expect_true(all(roles$candidates$status == "eligible"), info = strategy)
    # Every option candidate ran its own complete composition with local B searches.
    decision <- roles$decisions[[1L]][[1L]]$Inductive1$Holdout1
    testthat::expect_true(decision$chosen %in% decision$candidates$id, info = strategy)
    testthat::expect_identical(state$loss, roles$selected[[1L]])
    testthat::expect_true(all(is.finite(as.matrix(predict(fitted, d, type = "prob")))), info = strategy)
  }
})

testthat::test_that("regression Bayes chooses inside B for isotonic and linear Tailor", {
  for (pkg in c("tune", "tailor", "probably")) testthat::skip_if_not_installed(pkg)
  d <- withr::with_seed(8, {
    x <- rnorm(400)
    data.frame(row_id = seq_len(400), x = x, truth = 3 + x - .5 * x^2 + rnorm(400, sd = .5))
  })
  base <- bayes_tuned_base(d, parsnip::linear_reg(engine = "lm"))
  for (method in c("isotonic_numeric", "tailor_linear")) for (strategy in c("two_stage", "joint")) {
    fitted <- generics::fit(calibrated_workflow(base, "truth", method = "cross", v = 2, seed = 2, prediction_model = "full",
      tuning = list(strategy = strategy, model = bayes_search(resamples = bayes_plain, iter = 1L)),
      postprocessing = list(method = method, strategy = "ensemble", v = 2)), d)
    state <- workflows::extract_fit_engine(fitted)
    selection <- venn_abers_tuning(fitted)
    info <- paste(method, strategy)
    for (path in c("Fold1", "Fold2", "Full1")) for (inner in c("Fold1", "Fold2")) {
      plan <- state$postprocessing[[path]]$inner_folds[[inner]]
      local <- selection$models[[path]][[inner]]
      testthat::expect_identical(local$B, plan$B, info = info)
      testthat::expect_identical(plan$selected, local$selected, info = info)
      testthat::expect_true(local$chosen %in% local$candidates$id[local$candidates$status == "eligible"], info = info)
    }
    testthat::expect_true(all(is.finite(predict(fitted, d)$.pred)), info = info)
  }
})

testthat::test_that("a failed final composition fit after Bayes has no fallback candidate", {
  for (pkg in c("tune", "tailor", "probably")) testthat::skip_if_not_installed(pkg)
  d <- bayes_binary_data(240L)
  base <- bayes_tuned_base(d)
  sizes <- integer()
  fit_method <- getS3method("fit", "workflow", envir = asNamespace("generics"))
  registerS3method("fit", "workflow", function(object, data, ...) {
    if (!inherits(workflows::extract_spec_parsnip(object), c("vennabers", "vennabers_grid"))) {
      sizes <<- c(sizes, nrow(data))
      if (nrow(data) > 120L) stop("planned final B failure")
    }
    fit_method(object, data, ...)
  }, envir = asNamespace("generics"))
  on.exit(registerS3method("fit", "workflow", fit_method, envir = asNamespace("generics")), add = TRUE)
  testthat::expect_error(generics::fit(calibrated_workflow(base, "truth", seed = 1,
    tuning = list(strategy = "two_stage", model = bayes_search(upper = 2L, initial = 2L)),
    postprocessing = list(method = "sigmoid", sigmoid_input = "probability", strategy = "holdout", prop = .25)), d),
    "Holdout1 sigmoid.*planned final B failure")
  testthat::expect_identical(sum(sizes > 120L), 1L)
})
