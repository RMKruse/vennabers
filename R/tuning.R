.tune_id <- function(x) {
  if (!rlang::is_call(x, "tune")) return(NULL)
  if (length(x) != 2L || !is.character(x[[2L]]) || length(x[[2L]]) != 1L ||
      is.na(x[[2L]]) || !nzchar(x[[2L]])) {
    stop("Calibration tune() placeholders need one explicit nonempty ID.", call. = FALSE)
  }
  x[[2L]]
}

.fit_base_model <- function(workflow, data, settings) {
  if (!is.null(settings$.fit_counter)) settings$.fit_counter$n <- settings$.fit_counter$n + 1L
  generics::fit(workflow, data)
}

.tuning_names <- function(x, allowed, label) {
  if (!is.list(x) || is.null(names(x)) || anyNA(names(x)) ||
      any(!nzchar(names(x))) || anyDuplicated(names(x)) ||
      !all(names(x) %in% allowed)) {
    stop("`", label, "` must be a named list using only: ",
         paste(allowed, collapse = ", "), ".", call. = FALSE)
  }
}

.local_pair_joint_token <- new.env(parent = emptyenv())

.pairwise_grid_joint <- function(tuning, pairwise) {
  isTRUE(pairwise) && identical(tuning$strategy, "joint") &&
    !is.null(tuning$model) && identical(tuning$model$method, "grid") &&
    (is.null(tuning$calibration) || identical(tuning$calibration$method, "grid")) &&
    !identical(attr(tuning, "vennabers_local_pair_joint"), .local_pair_joint_token)
}

.validate_tuning <- function(tuning, workflow, mode, model_training,
                             loss, precision, seed, m, epsilon) {
  model_ids <- generics::tune_args(workflow)$id
  calibration_ids <- if (mode == "regression") c(m = .tune_id(m), epsilon = .tune_id(epsilon)) else
    c(loss = .tune_id(loss), precision = .tune_id(precision))
  if (is.null(tuning)) {
    if (length(calibration_ids)) stop("Calibration tune() placeholders require `tuning$calibration`.", call. = FALSE)
    return(NULL)
  }
  .tuning_names(tuning, c("strategy", "model", "calibration", "selection_prop", "selection_split",
                          "joint_resamples"), "tuning")
  .validate_choice(tuning$strategy, c("joint", "two_stage"), "tuning$strategy")
  if (anyNA(model_ids) || any(!nzchar(model_ids)) || anyDuplicated(model_ids) ||
      anyDuplicated(calibration_ids) || any(model_ids %in% calibration_ids)) {
    stop("Model/recipe and calibration tune() IDs must be nonempty and unique.", call. = FALSE)
  }
  if (xor(length(model_ids) > 0L, !is.null(tuning$model))) {
    stop("`tuning$model` is required exactly when the base workflow has tune() placeholders.", call. = FALSE)
  }
  if (xor(length(calibration_ids) > 0L, !is.null(tuning$calibration))) {
    stop("`tuning$calibration` is required exactly when a calibration option uses tune().", call. = FALSE)
  }
  if (!length(model_ids) && !length(calibration_ids)) {
    stop("`tuning` needs at least one model/recipe or calibration tune() placeholder.", call. = FALSE)
  }
  pair_joint <- identical(model_training, "pairwise") && identical(tuning$strategy, "joint") && length(model_ids)
  pair_grid_joint <- .pairwise_grid_joint(tuning, identical(model_training, "pairwise"))
  if (!is.null(tuning$joint_resamples) &&
      (!pair_joint || length(calibration_ids) ||
       !(is.function(tuning$joint_resamples) || inherits(tuning$joint_resamples, "rset")))) {
    stop("`tuning$joint_resamples` requires model-only pairwise joint tuning and a global rset or provider function.", call. = FALSE)
  }
  if (pair_joint && !length(calibration_ids) && is.null(tuning$joint_resamples) &&
      !identical(attr(tuning, "vennabers_local_pair_joint"), .local_pair_joint_token)) {
    stop("Pairwise joint model tuning without calibration options requires `tuning$joint_resamples` on global data.", call. = FALSE)
  }
  if (length(calibration_ids)) {
    if (is.null(tuning$selection_prop) == is.null(tuning$selection_split)) {
      stop("Supply exactly one of `selection_prop` and `selection_split` for calibration selection.", call. = FALSE)
    }
    if (!is.null(tuning$selection_prop) &&
        (!is.numeric(tuning$selection_prop) || length(tuning$selection_prop) != 1L ||
         !is.finite(tuning$selection_prop) || tuning$selection_prop <= 0 || tuning$selection_prop >= 1)) {
      stop("`selection_prop` must be one number strictly between 0 and 1.", call. = FALSE)
    }
    if (!is.null(tuning$selection_split) &&
        !inherits(tuning$selection_split, "rsplit") && !is.function(tuning$selection_split)) {
      stop("`selection_split` must be an rsplit or function of local data.", call. = FALSE)
    }
  } else if (!is.null(tuning$selection_prop) || !is.null(tuning$selection_split)) {
    stop("A selection S/F split requires automatic calibration selection.", call. = FALSE)
  }
  if (length(model_ids)) tuning$model <- .validate_search(tuning$model, model_ids, workflow, seed,
    "model", require_resamples = !pair_grid_joint)
  if (length(calibration_ids)) tuning$calibration <- .validate_search(
    tuning$calibration, calibration_ids, workflow, seed, "calibration")
  if (pair_grid_joint && !is.null(tuning$model$resamples)) {
    stop("Pairwise joint model grids use global calibration resamples or `joint_resamples`; omit `tuning$model$resamples`.", call. = FALSE)
  }
  if (pair_grid_joint && length(calibration_ids) &&
      !identical(tuning$model$primary_metric, tuning$calibration$primary_metric)) {
    stop("Pairwise joint model and calibration grids need the same primary metric.", call. = FALSE)
  }
  if (pair_grid_joint && length(calibration_ids) && !is.null(tuning$model$control) &&
      !is.null(tuning$calibration$control) &&
      !identical(tuning$model$control, tuning$calibration$control)) {
    stop("Pairwise joint model and calibration grids need one consistent control.", call. = FALSE)
  }
  tuning
}

.validate_search <- function(search, ids, workflow, seed, label, require_resamples = TRUE) {
  if (!is.list(search) || is.null(search$method)) {
    stop("`tuning", "$", label, "$method` is required.", call. = FALSE)
  }
  if (identical(search$method, "grid")) {
    return(.validate_grid_search(search, ids, workflow, seed, label, require_resamples))
  }
  .validate_bayes_search(search, ids, workflow, label, require_resamples)
}

.validate_bayes_search <- function(search, ids, workflow, label, require_resamples = TRUE) {
  .tuning_names(search, c("method", "initial", "iter", "param_info", "resamples", "primary_metric",
                          "report_metrics", "control"), paste0("tuning$", label))
  .validate_choice(search$method, "bayes", paste0("tuning$", label, "$method"))
  for (name in c("initial", "iter")) {
    value <- search[[name]]
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
        value < 1L || value != floor(value)) {
      stop("`tuning$", label, "$", name, "` must be one positive whole number.", call. = FALSE)
    }
    search[[name]] <- as.integer(value)
  }
  if ((require_resamples && is.null(search$resamples)) ||
      (!is.null(search$resamples) &&
       !(is.function(search$resamples) || inherits(search$resamples, "rset")))) {
    stop("`tuning$", label, "$resamples` must be an rset or function of local data.", call. = FALSE)
  }
  if (!inherits(search$param_info, "parameters") || !setequal(search$param_info$id, unname(ids))) {
    stop("Bayes `tuning$", label, "$param_info` must describe exactly the tune() IDs.", call. = FALSE)
  }
  if (search$initial <= nrow(search$param_info)) {
    stop("Bayes `tuning$", label, "$initial` must exceed the number of tuned parameters.", call. = FALSE)
  }
  if (is.null(search$control)) search$control <- tune::control_bayes()
  control <- search$control
  if (!inherits(control, "control_bayes") || !isTRUE(control$save_pred) ||
      !identical(control$uncertain, Inf) || !is.numeric(control$seed) || length(control$seed) != 1L ||
      !is.finite(control$seed) || control$seed < 0 || control$seed != floor(control$seed) ||
      !is.numeric(control$no_improve) || length(control$no_improve) != 1L || control$no_improve < 1 ||
      (!is.na(control$time_limit) && (!is.numeric(control$time_limit) || length(control$time_limit) != 1L ||
                                      !is.finite(control$time_limit) || control$time_limit <= 0))) {
    stop("Bayes control needs save_pred = TRUE, uncertain = Inf, a whole seed, positive no_improve, and a positive or NA time_limit.", call. = FALSE)
  }
  if (!is.null(control$extract)) stop("Custom `control_bayes(extract = ...)` conflicts with selection diagnostics.", call. = FALSE)
  search$control$allow_par <- FALSE
  if (is.null(search$primary_metric)) search$primary_metric <-
    if (workflows::extract_spec_parsnip(workflow)$mode == "regression") yardstick::rmse else yardstick::mn_log_loss
  if (!inherits(search$primary_metric, "metric")) {
    stop("`tuning$", label, "$primary_metric` must be one yardstick metric.", call. = FALSE)
  }
  reports <- search$report_metrics
  if (inherits(reports, "metric_set")) reports <- attr(reports, "metrics")
  if (inherits(reports, "metric")) reports <- list(reports)
  if (is.null(reports)) reports <- list()
  if (!is.list(reports) || !all(vapply(reports, inherits, logical(1), "metric"))) {
    stop("`tuning$", label, "$report_metrics` must contain yardstick metrics.", call. = FALSE)
  }
  if (length(reports) && is.null(names(reports))) names(reports) <- paste0("report_", seq_along(reports))
  search$report_metrics <- reports
  search$ids <- ids
  search
}

.validate_grid_search <- function(search, ids, workflow, seed, label, require_resamples = TRUE) {
  .tuning_names(search, c("method", "grid", "param_info", "resamples", "primary_metric",
                          "report_metrics", "control"), paste0("tuning$", label))
  .validate_choice(search$method, "grid", paste0("tuning$", label, "$method"))
  if (is.null(search$grid)) stop("`tuning$", label, "$grid` is required.", call. = FALSE)
  if ((require_resamples && is.null(search$resamples)) ||
      (!is.null(search$resamples) &&
       !(is.function(search$resamples) || inherits(search$resamples, "rset")))) {
    stop("`tuning$", label, "$resamples` must be an rset or function of local data.", call. = FALSE)
  }
  if (!is.null(search$control) &&
      (!inherits(search$control, "control_grid") || !isTRUE(search$control$save_pred))) {
    stop("`tuning$", label, "$control` must be control_grid(save_pred = TRUE).", call. = FALSE)
  }
  if (!is.null(search$control$extract)) {
    stop("Custom `control_grid(extract = ...)` conflicts with selection diagnostics.", call. = FALSE)
  }
  if (is.null(search$primary_metric)) search$primary_metric <-
    if (workflows::extract_spec_parsnip(workflow)$mode == "regression") yardstick::rmse else yardstick::mn_log_loss
  if (!inherits(search$primary_metric, "metric")) {
    stop("`tuning$", label, "$primary_metric` must be one yardstick metric.", call. = FALSE)
  }
  reports <- search$report_metrics
  if (inherits(reports, "metric_set")) reports <- attr(reports, "metrics")
  if (inherits(reports, "metric")) reports <- list(reports)
  if (is.null(reports)) reports <- list()
  if (!is.list(reports) || !all(vapply(reports, inherits, logical(1), "metric"))) {
    stop("`tuning$", label, "$report_metrics` must contain yardstick metrics.", call. = FALSE)
  }
  if (length(reports) && is.null(names(reports))) {
    names(reports) <- paste0("report_", seq_along(reports))
  }
  search$report_metrics <- reports
  grid <- search$grid
  if (is.numeric(grid) && length(grid) == 1L && is.finite(grid) &&
      grid == floor(grid) && grid > 0) {
    params <- search$param_info
    if (is.null(params) && label == "model") params <- tune::extract_parameter_set_dials(workflow)
    if (!inherits(params, "parameters") || !setequal(params$id, unname(ids))) {
      stop("An integer `tuning$", label, "$grid` needs dials `param_info`.", call. = FALSE)
    }
    search$param_info <- params
    search$grid_size <- as.integer(grid)
    search$grid <- NULL
    search$seed <- seed
    search$ids <- ids
    return(search)
  }
  search$grid <- .checked_grid(grid, ids, label)
  search$ids <- ids
  search$candidate_ids <- sprintf("%s_%03d", label, seq_len(nrow(search$grid)))
  search
}

.checked_grid <- function(grid, ids, label) {
  if (!is.data.frame(grid) || !nrow(grid) || anyNA(names(grid)) ||
      anyDuplicated(names(grid)) || !setequal(names(grid), unname(ids))) {
    stop("`tuning$", label, "$grid` needs rows with exactly these ID columns: ",
         paste(unname(ids), collapse = ", "), ".", call. = FALSE)
  }
  grid <- as.data.frame(grid[unname(ids)], stringsAsFactors = FALSE)
  if (any(vapply(grid, function(x) anyNA(x), logical(1)))) {
    stop("`tuning$", label, "$grid` cannot contain missing values.", call. = FALSE)
  }
  if (label == "calibration") {
    for (option in intersect(c("m", "epsilon"), names(ids))) {
      value <- grid[[ids[[option]]]]
      .validate_regression_vector(value, option)
      if (option == "m" && any(value < 1 | value != floor(value))) {
        stop("Calibration m grid requires positive whole numbers.", call. = FALSE)
      }
      if (option == "epsilon" && any(value <= 0 | value >= 1)) {
        stop("Calibration epsilon grid requires values strictly between 0 and 1.", call. = FALSE)
      }
    }
    if ("loss" %in% names(ids)) {
      value <- as.character(grid[[ids[["loss"]]]])
      if (!all(value %in% c("log", "brier"))) stop("Calibration loss grid allows only log and brier.", call. = FALSE)
      grid[[ids[["loss"]]]] <- value
    }
    if ("precision" %in% names(ids)) {
      value <- as.character(grid[[ids[["precision"]]]])
      if (!all(value %in% c("none", "0", "2", "-2"))) {
        stop("Calibration precision grid allows only none, 0, 2 and -2.", call. = FALSE)
      }
      grid[[ids[["precision"]]]] <- value
    }
  }
  grid
}

.tuning_resamples <- function(resamples, data, label) {
  plan <- if (is.function(resamples)) resamples(data) else resamples
  if (!inherits(plan, "rset") || !nrow(plan) ||
      !all(c("id", "splits") %in% names(plan))) {
    stop(label, " resamples must be a nonempty rsample rset.", call. = FALSE)
  }
  ids <- if ("id2" %in% names(plan)) paste(plan$id, plan$id2, sep = "/") else as.character(plan$id)
  .integration_names(ids, paste(label, "resample ID"))
  splits <- lapply(seq_len(nrow(plan)), function(i) .split_positions(plan$splits[[i]], data, ids[i]))
  list(rset = plan, positions = stats::setNames(splits, ids))
}

.tuning_score <- function(metric, predictions, truth, outcome, classes, event_level,
                          classification) {
  regression <- is.null(classes)
  expected <- if (regression) ".pred" else paste0(".pred_", classes)
  if (!is.data.frame(predictions) || nrow(predictions) != length(truth) ||
      !identical(sort(names(predictions)), sort(expected)) ||
      !all(vapply(predictions, function(x) is.numeric(x) && length(x) == length(truth) &&
                    all(is.finite(x)) && (regression || all(x >= 0 & x <= 1)), logical(1))) ||
      (!regression && any(abs(rowSums(predictions[expected]) - 1) > 1e-8))) {
    stop("Candidate predictions must contain every assessment row and finite ",
         if (regression) "numeric predictions." else "class probabilities.", call. = FALSE)
  }
  frame <- data.frame(truth, predictions[expected], check.names = FALSE)
  names(frame)[1L] <- outcome
  if (regression) {
    if (!inherits(metric, "numeric_metric")) stop("Regression tuning requires a numeric metric.", call. = FALSE)
    result <- rlang::inject(metric(frame, truth = !!rlang::sym(outcome), estimate = !!rlang::sym(".pred")))
  } else if (inherits(metric, "class_metric")) {
    event <- classes[if (event_level == "first") 1L else 2L]
    other <- setdiff(classes, event)
    frame$.pred_class <- if (classification == "binary")
      factor(ifelse(predictions[[paste0(".pred_", event)]] >= .5, event, other), levels = classes) else
      factor(classes[max.col(as.matrix(predictions[expected]), ties.method = "first")], levels = classes)
    result <- rlang::inject(metric(frame, truth = !!rlang::sym(outcome),
                                   estimate = !!rlang::sym(".pred_class"), event_level = event_level))
  } else if (inherits(metric, "prob_metric")) {
    columns <- if (length(classes) == 2L) expected[if (event_level == "first") 1L else 2L] else expected
    result <- rlang::inject(metric(frame, truth = !!rlang::sym(outcome),
                                   !!!rlang::syms(columns), event_level = event_level))
  } else stop("Only probability or class metrics are supported for classification tuning.", call. = FALSE)
  if (nrow(result) != 1L || !is.numeric(result$.estimate) ||
      length(result$.estimate) != 1L || !is.finite(result$.estimate)) {
    stop("The selection metric must return one finite estimate.", call. = FALSE)
  }
  result$.estimate[[1L]]
}

.fit_grid_candidate <- function(x, y, outcome, candidate_id, candidate_workflow,
                                candidates, event_level, classification, counter,
                                candidate_values = NULL) {
  if (is.null(candidate_values)) {
    index <- match(candidate_id, candidates$id)
    if (is.na(index)) stop("Unknown grid candidate ID.", call. = FALSE)
    candidate_values <- as.list(candidates[index, setdiff(names(candidates), "id"), drop = FALSE])
  }
  data <- as.data.frame(x)
  data[[outcome]] <- y
  workflow <- candidate_workflow(candidate_values)
  spec <- workflows::extract_spec_parsnip(workflow)
  if (inherits(spec, "vennabers")) {
    parameters <- rlang::eval_tidy(spec$eng_args$parameters)
    parameters$requested$.fit_counter <- counter
    spec$eng_args$parameters <- rlang::new_quosure(parameters, env = emptyenv())
    workflow <- workflows::update_model(workflow, spec)
  } else counter$n <- counter$n + 1L
  structure(list(fitted = generics::fit(workflow, data),
                 class_levels = levels(y), event_level = event_level,
                 classification = classification),
            class = "vennabers_grid_fit")
}

.bayes_proxy_workflow <- function(data, outcome, event_level, classification,
                                  candidate_workflow, counter, ids) {
  .register_grid_proxy()
  mode <- if (is.numeric(data[[outcome]])) "regression" else "classification"
  spec <- parsnip::new_model_spec("vennabers_grid", args = list(), eng_args = NULL,
                                  mode = mode, method = NULL, engine = "proxy")
  spec <- parsnip::set_engine(spec, "proxy", base_workflow = "bayes", outcome = outcome,
    parameters = list(grid_proxy = TRUE, candidate_workflow = candidate_workflow,
      candidates = NULL, event_level = event_level, classification = classification,
      counter = counter, bayes_proxy = TRUE))
  for (id in unname(ids)) spec$eng_args[[id]] <- rlang::new_quosure(tune::tune(id), env = emptyenv())
  carrier <- rlang::inject(workflows::add_variables(
    workflows::workflow(),
    outcomes = .integration_select_outcome(!!outcome, !!classification, !!mode),
    predictors = tidyselect::everything(),
    blueprint = hardhat::default_xy_blueprint(intercept = FALSE, allow_novel_levels = TRUE)))
  workflows::add_model(carrier, spec)
}

# The stand-in ID lets one native tune_grid() run the complete candidate grid.
.grid_proxy_workflow <- function(data, outcome, event_level, classification,
                                 candidates, candidate_workflow, counter) {
  .register_grid_proxy()
  mode <- if (is.numeric(data[[outcome]])) "regression" else "classification"
  spec <- parsnip::new_model_spec("vennabers_grid", args = list(), eng_args = NULL,
                                  mode = mode, method = NULL, engine = "proxy")
  spec <- parsnip::set_engine(spec, "proxy", base_workflow = tune::tune("candidate_id"),
                              outcome = outcome,
                              parameters = list(grid_proxy = TRUE,
                                candidate_workflow = candidate_workflow,
                                candidates = candidates, event_level = event_level,
                                classification = classification,
                                counter = counter))
  carrier <- rlang::inject(workflows::add_variables(
    workflows::workflow(),
    outcomes = .integration_select_outcome(!!outcome, !!classification, !!mode),
    predictors = tidyselect::everything(),
    blueprint = hardhat::default_xy_blueprint(intercept = FALSE, allow_novel_levels = TRUE)))
  workflows::add_model(carrier, spec)
}

.grid_budget <- function(search, plans, candidate_workflow, classes) {
  candidate <- candidate_workflow(as.list(search$grid[1L, , drop = FALSE]))
  spec <- workflows::extract_spec_parsnip(candidate)
  paths <- 1
  model_candidates <- 0L
  model_resamples <- 0L
  inner_paths <- 1
  pair_count <- 1L
  if (inherits(spec, "vennabers")) {
    settings <- rlang::eval_tidy(spec$eng_args$parameters)$requested
    if (identical(settings$model_training, "pairwise")) pair_count <- choose(length(classes), 2L)
    folds <- if (is.function(settings$splits)) NA_integer_ else
      if (settings$method == "cross") settings$v else 1L
    paths <- pair_count * (folds + as.integer(identical(settings$prediction_model, "full")))
    model <- if (is.null(settings$.pair_grid)) settings$tuning$model else NULL
    if (!is.null(model)) {
      model_candidates <- if (identical(model$method, "bayes")) model$initial + model$iter else
        if (!is.null(model$grid_size)) model$grid_size else nrow(model$grid)
      model_resamples <- if (is.function(model$resamples)) NA_integer_ else nrow(model$resamples)
      if (settings$tuning$strategy == "joint") inner_paths <- folds + as.integer(identical(settings$prediction_model, "full"))
    }
  }
  unit <- paths * (1 + model_candidates * model_resamples * inner_paths)
  list(candidates = nrow(search$grid), resamples = length(plans), pair_count = pair_count,
       gross_base_fit_estimate = nrow(search$grid) * length(plans) * unit,
       paths = paths, model_candidates = model_candidates,
       model_resamples = model_resamples, inner_paths = inner_paths,
       reused_base_fits = 0L)
}

.grid_select <- function(search, data, outcome, event_level, classification,
                         candidate_workflow, label, counter) {
  if (!is.null(search$grid_size)) {
    params <- dials::finalize(search$param_info, data)
    generated <- if (is.null(search$seed)) dials::grid_space_filling(params, size = search$grid_size) else
      withr::with_seed(search$seed, dials::grid_space_filling(params, size = search$grid_size))
    search$grid <- .checked_grid(generated, search$ids, label)
    search$candidate_ids <- sprintf("%s_%03d", label, seq_len(nrow(search$grid)))
  }
  plan <- .tuning_resamples(search$resamples, data, label)
  plans <- plan$positions
  budget <- .grid_budget(search, plans, candidate_workflow, classes = levels(data[[outcome]]))
  initial_fits <- counter$n
  classes <- levels(data[[outcome]])
  prediction_columns <- if (is.null(classes)) ".pred" else paste0(".pred_", classes)
  candidates <- data.frame(id = search$candidate_ids, status = "excluded",
                           estimate = NA_real_, reason = NA_character_)
  scores <- reports <- decisions <- vector("list", nrow(search$grid))
  candidates_with_values <- cbind(candidates["id"], search$grid)
  native_metrics <- if (inherits(search$primary_metric, "class_metric"))
    yardstick::metric_set(search$primary_metric, yardstick::brier_class) else
    yardstick::metric_set(search$primary_metric)
  control <- if (is.null(search$control)) tune::control_grid(save_pred = TRUE) else search$control
  control$allow_par <- FALSE
  control$event_level <- event_level
  control$extract <- function(w) {
    proxy <- workflows::extract_fit_engine(w)
    state <- workflows::extract_fit_engine(proxy$fitted)
    if (inherits(state, "vennabers_fit")) list(decision = state$tuning$models) else
      list(decision = NULL)
  }
  result <- tryCatch(suppressMessages(suppressWarnings(tune::tune_grid(
    .grid_proxy_workflow(data, outcome, event_level, classification,
                         candidates_with_values, candidate_workflow, counter),
    resamples = plan$rset,
    grid = data.frame(candidate_id = candidates$id),
    param_info = dials::parameters(dials::new_qual_param(
      type = "character", values = candidates$id,
      label = c(candidate_id = "Candidate"))),
    metrics = native_metrics,
    control = control))), error = identity)
  if (inherits(result, "error")) stop("Native ", label, " grid failed: ",
                                      conditionMessage(result), call. = FALSE)
  for (option in intersect(c("m", "epsilon"), names(search$ids))) {
    for (j in seq_len(nrow(result))) {
      predictions <- result$.predictions[[j]]
      if (is.data.frame(predictions)) {
        column <- if (identical(outcome, option)) paste0("va_", option) else option
        predictions[[column]] <- search$grid[[search$ids[[option]]]][
          match(predictions$candidate_id, candidates$id)]
        result$.predictions[[j]] <- predictions
      }
    }
  }
  result_ids <- if ("id2" %in% names(result)) paste(result$id, result$id2, sep = "/") else result$id
  for (i in seq_len(nrow(search$grid))) {
    scores[[i]] <- stats::setNames(rep(NA_real_, length(plans)), names(plans))
    reports[[i]] <- vector("list", length(plans))
    decisions[[i]] <- vector("list", length(plans))
    names(reports[[i]]) <- names(plans)
    names(decisions[[i]]) <- names(plans)
    errors <- character()
    if (!identical(result_ids, names(plans))) errors <- c(errors, "Native resample IDs changed.")
    for (j in seq_along(plans)) {
      id <- names(plans)[j]
      split <- plans[[j]]
      checked <- tryCatch({
        predictions <- result$.predictions[[j]]
        predictions <- predictions[predictions$candidate_id == candidates$id[i], , drop = FALSE]
        rows <- predictions$.row
        if (!is.data.frame(predictions) || is.null(rows) || anyNA(rows) ||
            anyDuplicated(rows) || !identical(sort(as.integer(rows)), sort(split$assessment)) ||
            !identical(predictions[[outcome]], data[[outcome]][rows])) {
          stop("Native predictions omit, duplicate, or mismatch assessment rows.", call. = FALSE)
        }
        values <- predictions[match(split$assessment, rows), prediction_columns, drop = FALSE]
        primary <- .tuning_score(search$primary_metric, values,
          data[[outcome]][split$assessment], outcome, classes, event_level, classification)
        extra <- lapply(search$report_metrics, function(metric) tryCatch(
          .tuning_score(metric, values, data[[outcome]][split$assessment],
                        outcome, classes, event_level, classification), error = conditionMessage))
        extract <- result$.extracts[[j]]
        extract <- extract[extract$candidate_id == candidates$id[i], , drop = FALSE]
        details <- if (nrow(extract)) extract$.extracts[[1L]] else NULL
        list(primary = primary, extra = extra, details = details)
      }, error = identity)
      if (inherits(checked, "error")) errors <- c(errors, paste0(id, ": ", conditionMessage(checked))) else {
        scores[[i]][[id]] <- checked$primary
        reports[[i]][[id]] <- checked$extra
        decisions[[i]][id] <- list(checked$details$decision)
      }
    }
    if (length(errors)) candidates$reason[i] <- paste(errors, collapse = " | ") else {
      candidates$status[i] <- "eligible"
      candidates$estimate[i] <- mean(scores[[i]])
    }
  }
  eligible <- which(candidates$status == "eligible")
  if (!length(eligible)) stop("No eligible ", label, " grid candidate: ",
    paste(c(stats::na.omit(candidates$reason), unique(tune::collect_notes(result)$note)),
      collapse = " | "), call. = FALSE)
  direction <- attr(search$primary_metric, "direction")
  if (!direction %in% c("minimize", "maximize")) stop("Selection metric needs a direction.", call. = FALSE)
  best <- eligible[if (direction == "minimize") which.min(candidates$estimate[eligible]) else
                     which.max(candidates$estimate[eligible])]
  list(values = as.list(search$grid[best, , drop = FALSE]),
       diagnostics = list(chosen = candidates$id[best], candidates = candidates, grid = search$grid,
         tie_break = "first candidate in grid order",
         scores = stats::setNames(scores, candidates$id),
         report_metrics = stats::setNames(reports, candidates$id),
         decisions = stats::setNames(decisions, candidates$id),
         native = result,
         resamples = plans, primary_metric = search$primary_metric,
         direction = direction,
         budget = budget,
         cost = list(candidate_evaluations = nrow(search$grid) * length(plans),
                     eligible_candidates = length(eligible),
                     excluded_candidates = nrow(search$grid) - length(eligible),
                     observed_base_fits = counter$n - initial_fits),
         seed = NULL))
}

.bayes_candidates <- function(result, ids) {
  metrics <- tryCatch(tune::collect_metrics(result, summarize = FALSE), error = identity)
  if (inherits(metrics, "error") || !nrow(metrics) || !all(unname(ids) %in% names(metrics))) {
    return(data.frame())
  }
  unique(as.data.frame(metrics[unname(ids)], stringsAsFactors = FALSE))
}

.bayes_step_candidates <- function(result, ids) {
  metrics <- tryCatch(tune::collect_metrics(result, summarize = FALSE), error = identity)
  if (inherits(metrics, "error") || !nrow(metrics) || !all(unname(ids) %in% names(metrics))) return(data.frame())
  if (".iter" %in% names(metrics)) metrics <- metrics[metrics$.iter == max(metrics$.iter), , drop = FALSE]
  unique(as.data.frame(metrics[unname(ids)], stringsAsFactors = FALSE))
}

.bayes_step_errors <- function(result) {
  rows <- if (".iter" %in% names(result)) which(result$.iter == max(result$.iter)) else seq_len(nrow(result))
  notes <- unlist(lapply(result$.notes[rows], function(x) if (is.data.frame(x) && "note" %in% names(x)) x$note else character()),
                  use.names = FALSE)
  unique(stats::na.omit(notes[nzchar(notes)]))
}

.candidate_key <- function(values) {
  apply(values, 1L, function(row) paste(names(values), as.character(row), sep = "=", collapse = "\r"))
}

.stable_bayes_ids <- function(scored, ids, label, known = character()) {
  keys <- .candidate_key(scored$candidates[unname(ids)])
  for (key in keys) if (!key %in% names(known)) known[key] <- sprintf("%s_%03d", label, length(known) + 1L)
  current <- unname(known[keys])
  scored$candidates$id <- current
  names(scored$scores) <- names(scored$report_metrics) <- names(scored$decisions) <- current
  list(scored = scored, known = known)
}

.same_candidate <- function(predictions, values) {
  if (!is.data.frame(predictions) || !all(names(values) %in% names(predictions))) return(rep(FALSE, nrow(predictions)))
  Reduce(`&`, Map(function(name) as.character(predictions[[name]]) == as.character(values[[name]]), names(values)))
}

.score_bayes_candidates <- function(search, result, data, plans, outcome, event_level, classification,
                                    candidates, label, counter, initial_fits, budget) {
  classes <- levels(data[[outcome]])
  prediction_columns <- if (is.null(classes)) ".pred" else paste0(".pred_", classes)
  candidates$id <- sprintf("%s_%03d", label, seq_len(nrow(candidates)))
  candidates$status <- rep("excluded", nrow(candidates))
  candidates$estimate <- rep(NA_real_, nrow(candidates))
  candidates$reason <- rep(NA_character_, nrow(candidates))
  scores <- reports <- decisions <- vector("list", nrow(candidates))
  result_ids <- if ("id2" %in% names(result)) paste(result$id, result$id2, sep = "/") else result$id
  for (i in seq_len(nrow(candidates))) {
    scores[[i]] <- stats::setNames(rep(NA_real_, length(plans)), names(plans))
    reports[[i]] <- decisions[[i]] <- vector("list", length(plans))
    names(reports[[i]]) <- names(decisions[[i]]) <- names(plans)
    errors <- if (!identical(result_ids, names(plans))) "Native resample IDs changed." else character()
    candidate_values <- candidates[i, unname(search$ids), drop = FALSE]
    for (j in seq_along(plans)) {
      id <- names(plans)[j]
      split <- plans[[j]]
      checked <- tryCatch({
        predictions <- result$.predictions[[j]]
        if (!is.data.frame(predictions)) {
          stop("Native predictions are missing for this resample.", call. = FALSE)
        }
        predictions <- predictions[.same_candidate(predictions, candidate_values), , drop = FALSE]
        rows <- predictions$.row
        if (is.null(rows) || anyNA(rows) || anyDuplicated(rows) ||
            !identical(sort(as.integer(rows)), sort(split$assessment)) ||
            !identical(predictions[[outcome]], data[[outcome]][rows])) {
          stop("Native predictions omit, duplicate, or mismatch assessment rows (",
               nrow(predictions), " predictions for ", length(split$assessment), " assessment rows).", call. = FALSE)
        }
        score_values <- predictions[match(split$assessment, rows), prediction_columns, drop = FALSE]
        primary <- .tuning_score(search$primary_metric, score_values,
          data[[outcome]][split$assessment], outcome, classes, event_level, classification)
        extra <- lapply(search$report_metrics, function(metric) tryCatch(
          .tuning_score(metric, score_values, data[[outcome]][split$assessment],
                        outcome, classes, event_level, classification), error = conditionMessage))
        extract <- result$.extracts[[j]]
        extract <- extract[.same_candidate(extract, candidates[i, unname(search$ids), drop = FALSE]), , drop = FALSE]
        details <- if (nrow(extract)) extract$.extracts[[1L]] else NULL
        list(primary = primary, extra = extra, details = details)
      }, error = identity)
      if (inherits(checked, "error")) errors <- c(errors, paste0(id, ": ", conditionMessage(checked))) else {
        scores[[i]][[id]] <- checked$primary
        reports[[i]][[id]] <- checked$extra
        decisions[[i]][id] <- list(checked$details$decision)
      }
    }
    if (length(errors)) candidates$reason[i] <- paste(errors, collapse = " | ") else {
      candidates$status[i] <- "eligible"
      candidates$estimate[i] <- mean(scores[[i]])
    }
  }
  eligible <- which(candidates$status == "eligible")
  list(candidates = candidates, eligible = eligible, scores = stats::setNames(scores, candidates$id),
       report_metrics = stats::setNames(reports, candidates$id),
       decisions = stats::setNames(decisions, candidates$id),
       cost = list(candidate_evaluations = nrow(candidates) * length(plans),
                   eligible_candidates = length(eligible), excluded_candidates = nrow(candidates) - length(eligible),
                   observed_base_fits = counter$n - initial_fits), budget = budget)
}

.bayes_select <- function(search, data, outcome, event_level, classification,
                          candidate_workflow, label, counter) {
  plan <- .tuning_resamples(search$resamples, data, label)
  plans <- plan$positions
  initial_fits <- counter$n
  started <- proc.time()[3L]
  control <- search$control
  control$time_limit <- NA_real_
  control$event_level <- event_level
  control$extract <- function(w) {
    proxy <- workflows::extract_fit_engine(w)
    state <- workflows::extract_fit_engine(proxy$fitted)
    if (inherits(state, "vennabers_fit")) list(decision = state$tuning$models) else list(decision = NULL)
  }
  proxy <- .bayes_proxy_workflow(data, outcome, event_level, classification,
                                 candidate_workflow, counter, search$ids)
  params <- dials::finalize(search$param_info, data)
  initial_grid <- withr::with_seed(control$seed, dials::grid_space_filling(params, size = search$initial))
  budget <- .grid_budget(list(grid = initial_grid), plans, candidate_workflow, classes = levels(data[[outcome]]))
  budget$candidates <- nrow(initial_grid) + search$iter
  budget$gross_base_fit_estimate <- budget$gross_base_fit_estimate *
    budget$candidates / nrow(initial_grid)
  native_metrics <- if (inherits(search$primary_metric, "class_metric"))
    yardstick::metric_set(search$primary_metric, yardstick::brier_class) else yardstick::metric_set(search$primary_metric)
  grid_control <- tune::control_grid(save_pred = TRUE, allow_par = FALSE,
    event_level = event_level, extract = control$extract, parallel_over = NULL)
  initial <- tryCatch(suppressMessages(suppressWarnings(tune::tune_grid(proxy, resamples = plan$rset,
    grid = initial_grid, param_info = params, metrics = native_metrics, control = grid_control))), error = identity)
  if (inherits(initial, "error")) stop("Native ", label, " Bayes initialization failed: ", conditionMessage(initial), call. = FALSE)
  scored <- .score_bayes_candidates(search, initial, data, plans, outcome, event_level, classification,
    as.data.frame(initial_grid), label, counter, initial_fits, budget)
  required <- nrow(params) + 1L
  if (!nrow(scored$candidates)) {
    stop("Bayes needs at least ", required, " complete initial ", label,
         " candidates; found 0.", call. = FALSE)
  }
  identified <- .stable_bayes_ids(scored, search$ids, label)
  scored <- identified$scored
  history <- scored
  known_ids <- identified$known
  if (length(scored$eligible) < required) {
    stop("Bayes needs at least ", required, " complete initial ", label, " candidates; found ",
         length(scored$eligible), ".", call. = FALSE)
  }
  metric_names <- unique(tune::collect_metrics(initial)$.metric)
  metric_name <- if (inherits(search$primary_metric, "class_metric"))
    setdiff(metric_names, "brier_class")[[1L]] else metric_names[[1L]]
  metric_functions <- list(search$primary_metric)
  names(metric_functions) <- metric_name
  if (inherits(search$primary_metric, "class_metric")) metric_functions$brier_class <- yardstick::brier_class
  native_metrics <- do.call(yardstick::metric_set, metric_functions)
  valid <- tune::filter_parameters(initial,
    parameters = scored$candidates[scored$eligible, unname(search$ids), drop = FALSE])
  valid_values <- scored$candidates[scored$eligible, unname(search$ids), drop = FALSE]
  steps <- list(initial = scored$candidates)
  best <- if (attr(search$primary_metric, "direction") == "minimize") min(scored$candidates$estimate[scored$eligible]) else
    max(scored$candidates$estimate[scored$eligible])
  stale <- 0L
  reason <- "budget"
  for (step in seq_len(search$iter)) {
    if (!is.na(search$control$time_limit) && proc.time()[3L] - started >= search$control$time_limit) {
      reason <- "time_limit"
      break
    }
    step_control <- control
    step_control$seed <- control$seed + step
    next_result <- tryCatch(suppressMessages(suppressWarnings(tune::tune_bayes(proxy, resamples = plan$rset,
      initial = valid, iter = 1L, param_info = params, metrics = native_metrics, control = step_control))), error = identity)
    if (inherits(next_result, "error")) {
      stale <- stale + 1L
      steps[[paste0("step_", step)]] <- list(error = conditionMessage(next_result))
    } else {
      proposed <- .bayes_step_candidates(next_result, search$ids)
      known <- names(known_ids)
      errors <- .bayes_step_errors(next_result)
      if (!nrow(proposed) && length(errors)) {
        stale <- stale + 1L
        steps[[paste0("step_", step)]] <- list(error = paste(errors, collapse = " | "))
        if (stale >= search$control$no_improve) {
          reason <- "no_improve"
          break
        }
        next
      } else if (!nrow(proposed) || all(.candidate_key(proposed) %in% known)) {
        stale <- stale + 1L
        steps[[paste0("step_", step)]] <- list(repeated = proposed)
        reason <- "repeated_candidate"
        break
      }
      rows <- which(next_result$.iter == max(next_result$.iter))
      scored <- .score_bayes_candidates(search, next_result[rows, , drop = FALSE], data, plans,
        outcome, event_level, classification, proposed, label, counter, initial_fits, budget)
      identified <- .stable_bayes_ids(scored, search$ids, label, known_ids)
      scored <- identified$scored
      known_ids <- identified$known
      history$candidates <- rbind(history$candidates, scored$candidates)
      history$scores <- c(history$scores, scored$scores)
      history$report_metrics <- c(history$report_metrics, scored$report_metrics)
      history$decisions <- c(history$decisions, scored$decisions)
      if (!length(scored$eligible)) {
        stale <- stale + 1L
        steps[[paste0("step_", step)]] <- scored$candidates
      } else {
        valid_values <- rbind(valid_values,
          scored$candidates[scored$eligible, unname(search$ids), drop = FALSE])
        valid <- tune::filter_parameters(next_result, parameters = valid_values)
        direction <- attr(search$primary_metric, "direction")
        candidate_best <- if (direction == "minimize") min(scored$candidates$estimate[scored$eligible]) else
          max(scored$candidates$estimate[scored$eligible])
        improved <- if (direction == "minimize") candidate_best < best else candidate_best > best
        stale <- if (improved) 0L else stale + 1L
        best <- if (improved) candidate_best else best
        steps[[paste0("step_", step)]] <- scored$candidates
      }
    }
    if (stale >= search$control$no_improve) {
      reason <- "no_improve"
      break
    }
  }
  eligible <- which(history$candidates$status == "eligible")
  values <- history$candidates[eligible, unname(search$ids), drop = FALSE]
  direction <- attr(search$primary_metric, "direction")
  pick <- if (direction == "minimize") which.min(history$candidates$estimate[eligible]) else
    which.max(history$candidates$estimate[eligible])
  best <- eligible[pick]
  attempts <- nrow(initial_grid) + length(steps) - 1L
  history$cost$candidate_evaluations <- attempts * length(plans)
  history$cost$eligible_candidates <- length(eligible)
  history$cost$excluded_candidates <- nrow(history$candidates) - length(eligible)
  history$cost$observed_base_fits <- counter$n - initial_fits
  for (option in intersect(c("m", "epsilon"), names(search$ids))) {
    column <- if (identical(outcome, option)) paste0("va_", option) else option
    valid$.predictions <- lapply(valid$.predictions, function(predictions) {
      predictions[[column]] <- predictions[[search$ids[[option]]]]
      predictions
    })
  }
  list(values = as.list(values[pick, , drop = FALSE]), diagnostics = c(list(chosen = history$candidates$id[best],
    selected = as.list(values[pick, , drop = FALSE]), candidates = history$candidates, grid = NULL,
    tie_break = "first candidate in attempt order", scores = history$scores,
    report_metrics = history$report_metrics, decisions = history$decisions, native = valid,
    resamples = plans, primary_metric = search$primary_metric, direction = direction,
    seed = control$seed, bayes_seed = control$seed, steps = steps, stop_reason = reason,
    attempts = attempts, no_improve = stale, elapsed_seconds = proc.time()[3L] - started),
    history[c("budget", "cost")]))
}

.candidate_outer <- function(workflow, outcome, settings, schema = NULL) {
  args <- list(workflow = workflow, outcome = outcome, method = settings$method,
               prediction_model = settings$prediction_model, seed = settings$seed)
  if (settings$mode == "regression") {
    args$m <- settings$m
    args$epsilon <- settings$epsilon
  } else {
    args$classification <- settings$classification
    args$loss <- settings$loss
    args$precision <- settings$precision
    if (settings$classification == "binary") args$event_level <- settings$event_level
  }
  if (identical(settings$model_training, "pairwise")) args$model_training <- "pairwise"
  if (!is.null(schema)) args$schema <- schema
  if (is.function(settings$splits)) args$splits <- settings$splits else if (settings$method == "cross")
    args$v <- settings$v else args$calibration_prop <- settings$calibration_prop
  if (identical(settings$strata, FALSE) && is.null(args$splits)) args$strata <- FALSE
  if (!is.null(settings$tuning$model)) {
    model <- settings$tuning$model
    if (!is.null(model$grid_size)) model$grid <- model$grid_size
    model <- model[intersect(names(model), c("method", "grid", "initial", "iter", "param_info", "resamples",
                                             "primary_metric", "report_metrics", "control"))]
    args$tuning <- list(strategy = settings$tuning$strategy, model = model)
    local_pair_joint <- identical(settings$model_training, "pairwise") &&
      identical(settings$tuning$strategy, "joint") &&
      (identical(model$method, "bayes") || !is.null(model$resamples))
    if (local_pair_joint) attr(args$tuning, "vennabers_local_pair_joint") <- .local_pair_joint_token
  }
  outer <- do.call(calibrated_workflow, args)
  if (isTRUE(settings$.pair_joint_inner) ||
      (!is.null(settings$tuning$model) && isTRUE(local_pair_joint))) {
    spec <- workflows::extract_spec_parsnip(outer)
    params <- rlang::eval_tidy(spec$eng_args$parameters)
    params$requested$.pair_joint_inner <- TRUE
    spec$eng_args$parameters <- rlang::new_quosure(params, env = emptyenv())
    outer <- workflows::update_model(outer, spec)
  }
  outer
}

.assess_pairwise_bayes_joint <- function(data, workflow, outcome, parameters) {
  settings <- parameters$requested
  search <- list(grid = data.frame(pairwise = 1L), candidate_ids = "joint_0001",
    ids = c(pairwise = "pairwise"), resamples = settings$tuning$joint_resamples,
    primary_metric = settings$tuning$model$primary_metric,
    report_metrics = settings$tuning$model$report_metrics)
  result <- .grid_select(search, data, outcome, settings$event_level, settings$classification,
    function(values) {
      nested <- settings
      nested$.pair_joint_inner <- TRUE
      .candidate_outer(workflow, outcome, nested, parameters$schema)
    }, "joint", settings$.fit_counter)
  result$diagnostics$pair_ids <- paste0("pair_", seq_len(choose(nlevels(data[[outcome]]), 2L)))
  result$diagnostics$seed <- settings$seed
  list(data = data, settings = settings, diagnostics = result$diagnostics)
}

.choose_model <- function(workflow, data, domain, settings, path_id = NULL) {
  if (!is.null(settings$.pair_grid)) {
    scope <- if (identical(path_id, "Full1")) "full" else "source"
    values <- settings$.pair_grid[[domain$pair_id]][[scope]]
    return(list(workflow = tune::finalize_workflow(workflow, values),
      diagnostics = list(chosen = settings$.pair_grid_id, selected = values,
                         pair_id = domain$pair_id, fold_id = path_id)))
  }
  search <- settings$tuning$model
  if (is.null(search)) return(list(workflow = workflow, diagnostics = NULL))
  outcome <- domain$outcome
  select <- if (identical(search$method, "bayes")) .bayes_select else .grid_select
  result <- select(search, data, outcome, settings$event_level, settings$classification,
    function(values) {
      candidate <- tune::finalize_workflow(workflow, values)
      if (settings$tuning$strategy == "two_stage") candidate else {
        nested <- settings
        nested$tuning <- NULL
        if (!is.function(nested$splits)) nested$splits <- NULL
        .candidate_outer(candidate, outcome, nested, domain$schema)
      }
    }, "model", settings$.fit_counter)
  result$diagnostics$selected <- result$values
  result$diagnostics$seed <- settings$seed
  list(workflow = tune::finalize_workflow(workflow, result$values),
       diagnostics = result$diagnostics)
}

.calibration_values <- function(settings, ids, values) {
  for (option in intersect(c("m", "epsilon"), names(ids))) settings[[option]] <- values[[ids[[option]]]]
  if ("loss" %in% names(ids)) settings$loss <- values[[ids[["loss"]]]]
  if ("precision" %in% names(ids)) {
    precision <- values[[ids[["precision"]]]]
    settings$precision <- if (identical(precision, "none")) NULL else as.numeric(precision)
  }
  settings
}

.selection_roles <- function(data, outcome, settings, config) {
  split <- if (!is.null(config$selection_prop)) {
    if (settings$mode == "regression" || identical(settings$strata, FALSE)) rsample::initial_split(data, prop = 1 - config$selection_prop) else
      rlang::inject(rsample::initial_split(data, prop = 1 - config$selection_prop,
                                           strata = !!outcome, pool = 0))
  } else if (is.function(config$selection_split)) config$selection_split(data) else config$selection_split
  .split_positions(split, data, "selection S/F")
}

.choose_calibration <- function(data, workflow, outcome, parameters) {
  settings <- parameters$requested
  config <- settings$tuning
  roles <- .selection_roles(data, outcome, settings, config)
  selection <- data[roles$assessment, , drop = FALSE]
  search <- config$calibration
  select <- if (identical(search$method, "bayes")) .bayes_select else .grid_select
  result <- select(search, selection, outcome, settings$event_level, settings$classification,
    function(values) {
      nested <- .calibration_values(settings, search$ids, values)
      nested$tuning$calibration <- NULL
      if (!is.function(nested$splits)) nested$splits <- NULL
      .candidate_outer(workflow, outcome, nested, parameters$schema)
    }, "calibration", settings$.fit_counter)
  settings <- .calibration_values(settings, search$ids, result$values)
  settings$tuning$calibration <- NULL
  result$diagnostics$selected <- result$values
  result$diagnostics$seed <- settings$seed
  result$diagnostics$roles <- roles
  result$diagnostics$selection_rows <- roles$assessment
  result$diagnostics$final_rows <- roles$analysis
  list(data = data[roles$analysis, , drop = FALSE], settings = settings,
       diagnostics = result$diagnostics)
}

.choose_pairwise_joint <- function(data, workflow, outcome, parameters) {
  settings <- parameters$requested
  config <- settings$tuning
  roles <- NULL
  selection <- data
  if (!is.null(config$calibration)) {
    roles <- .selection_roles(data, outcome, settings, config)
    selection <- data[roles$assessment, , drop = FALSE]
  }
  pairs <- utils::combn(levels(data[[outcome]]), 2L, simplify = FALSE)
  pair_ids <- paste0("pair_", seq_along(pairs))
  model <- config$model
  grids <- stats::setNames(lapply(seq_along(pairs), function(i) {
    if (is.null(model$grid_size)) return(model$grid)
    local <- selection[selection[[outcome]] %in% pairs[[i]], , drop = FALSE]
    local[[outcome]] <- factor(local[[outcome]], levels = pairs[[i]])
    params <- dials::finalize(model$param_info, local)
    generated <- if (is.null(settings$seed)) dials::grid_space_filling(params, size = model$grid_size) else
      withr::with_seed(settings$seed, dials::grid_space_filling(params, size = model$grid_size))
    .checked_grid(generated, model$ids, "model")
  }), pair_ids)
  dimensions <- list()
  for (id in pair_ids) {
    dimensions[[paste0("..", id, "_source")]] <- seq_len(nrow(grids[[id]]))
    if (identical(settings$prediction_model, "full"))
      dimensions[[paste0("..", id, "_full")]] <- seq_len(nrow(grids[[id]]))
  }
  calibration <- config$calibration
  if (!is.null(calibration)) {
    if (!is.null(calibration$grid_size)) {
      params <- dials::finalize(calibration$param_info, selection)
      generated <- if (is.null(settings$seed)) dials::grid_space_filling(params, size = calibration$grid_size) else
        withr::with_seed(settings$seed, dials::grid_space_filling(params, size = calibration$grid_size))
      calibration$grid <- .checked_grid(generated, calibration$ids, "calibration")
    }
    dimensions[["..calibration"]] <- seq_len(nrow(calibration$grid))
  }
  if (!is.null(calibration) && any(names(calibration$grid) %in% c(names(dimensions), "..candidate_id"))) {
    stop("Calibration IDs conflict with reserved pairwise joint grid columns.", call. = FALSE)
  }
  count <- prod(vapply(dimensions, length, 0L))
  # ponytail: exhaustive joint search is capped; cache pair fits if larger grids are needed.
  if (!is.finite(count) || count > 4096L) {
    stop("Pairwise joint Cartesian grid exceeds 4096 combinations; reduce the grids.", call. = FALSE)
  }
  combinations <- expand.grid(dimensions, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  combinations[["..candidate_id"]] <- sprintf("joint_%04d", seq_len(nrow(combinations)))
  pair_values <- function(values) stats::setNames(lapply(pair_ids, function(id) {
    source <- as.list(grids[[id]][values[[paste0("..", id, "_source")]], , drop = FALSE])
    full <- if (identical(settings$prediction_model, "full"))
      as.list(grids[[id]][values[[paste0("..", id, "_full")]], , drop = FALSE]) else source
    list(source = source, full = full)
  }), pair_ids)
  search <- if (is.null(calibration)) model else calibration
  if (!is.null(calibration)) {
    search$control <- if (is.null(calibration$control)) model$control else calibration$control
    search$report_metrics <- c(
      if (length(calibration$report_metrics)) stats::setNames(calibration$report_metrics,
        paste0("calibration_", names(calibration$report_metrics))) else list(),
      if (length(model$report_metrics)) stats::setNames(model$report_metrics,
        paste0("model_", names(model$report_metrics))) else list())
  }
  search$grid <- combinations
  search$grid_size <- NULL
  search$candidate_ids <- combinations[["..candidate_id"]]
  search$resamples <- if (is.null(calibration)) config$joint_resamples else calibration$resamples
  result <- .grid_select(search, selection, outcome, settings$event_level, settings$classification,
    function(values) {
      nested <- settings
      if (!is.null(calibration)) nested <- .calibration_values(nested, calibration$ids,
        as.list(calibration$grid[values[["..calibration"]], , drop = FALSE]))
      nested$tuning$calibration <- NULL
      nested$tuning$strategy <- "two_stage"
      if (is.null(nested$tuning$model$resamples)) nested$tuning$model$resamples <-
        function(d) stop("Fixed joint candidates do not request local model resamples.", call. = FALSE)
      outer <- .candidate_outer(workflow, outcome, nested, parameters$schema)
      spec <- workflows::extract_spec_parsnip(outer)
      params <- rlang::eval_tidy(spec$eng_args$parameters)
      params$requested$.pair_grid <- pair_values(values)
      params$requested$.pair_grid_id <- values[["..candidate_id"]]
      spec$eng_args$parameters <- rlang::new_quosure(params, env = emptyenv())
      workflows::update_model(outer, spec)
    }, "joint", settings$.fit_counter)
  values <- result$values
  if (!is.null(calibration)) {
    settings <- .calibration_values(settings, calibration$ids,
      as.list(calibration$grid[values[["..calibration"]], , drop = FALSE]))
    settings$tuning$calibration <- NULL
  }
  settings$.pair_grid <- pair_values(values)
  settings$.pair_grid_id <- result$diagnostics$chosen
  result$diagnostics$selected <- list(pairs = settings$.pair_grid,
    calibration = if (!is.null(calibration)) list(loss = settings$loss, precision = settings$precision) else NULL)
  result$diagnostics$seed <- settings$seed
  result$diagnostics$pair_ids <- pair_ids
  if (!is.null(roles)) {
    result$diagnostics$roles <- roles
    result$diagnostics$selection_rows <- roles$assessment
    result$diagnostics$final_rows <- roles$analysis
  }
  list(data = if (is.null(roles)) data else data[roles$analysis, , drop = FALSE],
       settings = settings, diagnostics = result$diagnostics)
}

#' Inspect classification or regression grid selection after fitting
#' @param object A fitted calibrated workflow.
#' @return Search configuration, candidate scores, selected values, plans, and data roles.
#' @export
venn_abers_tuning <- function(object) {
  state <- if (inherits(object, "vennabers_fit")) object else workflows::extract_fit_engine(object)
  if (!inherits(state, "vennabers_fit") || is.null(state$tuning)) {
    stop("`object` must be a fitted tuned calibrated workflow.", call. = FALSE)
  }
  state$tuning
}
