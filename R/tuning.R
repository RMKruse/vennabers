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
  if (!is.null(tuning$joint_resamples) &&
      (!pair_joint || length(calibration_ids) ||
       !(is.function(tuning$joint_resamples) || inherits(tuning$joint_resamples, "rset")))) {
    stop("`tuning$joint_resamples` requires model-only pairwise joint tuning and a global rset or provider function.", call. = FALSE)
  }
  if (pair_joint && !length(calibration_ids) && is.null(tuning$joint_resamples)) {
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
  if (length(model_ids)) tuning$model <- .validate_grid_search(tuning$model, model_ids, workflow, seed,
    "model", require_resamples = !pair_joint)
  if (length(calibration_ids)) tuning$calibration <- .validate_grid_search(
    tuning$calibration, calibration_ids, workflow, seed, "calibration")
  if (pair_joint && !is.null(tuning$model$resamples)) {
    stop("Pairwise joint model grids use global calibration resamples or `joint_resamples`; omit `tuning$model$resamples`.", call. = FALSE)
  }
  if (pair_joint && length(calibration_ids) &&
      !identical(tuning$model$primary_metric, tuning$calibration$primary_metric)) {
    stop("Pairwise joint model and calibration grids need the same primary metric.", call. = FALSE)
  }
  if (pair_joint && length(calibration_ids) && !is.null(tuning$model$control) &&
      !is.null(tuning$calibration$control) &&
      !identical(tuning$model$control, tuning$calibration$control)) {
    stop("Pairwise joint model and calibration grids need one consistent control.", call. = FALSE)
  }
  tuning
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
                                candidates, event_level, classification, counter) {
  index <- match(candidate_id, candidates$id)
  if (is.na(index)) stop("Unknown grid candidate ID.", call. = FALSE)
  data <- as.data.frame(x)
  data[[outcome]] <- y
  values <- as.list(candidates[index, setdiff(names(candidates), "id"), drop = FALSE])
  workflow <- candidate_workflow(values)
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
      model_candidates <- if (!is.null(model$grid_size)) model$grid_size else nrow(model$grid)
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
    model <- model[intersect(names(model), c("method", "grid", "param_info", "resamples",
                                             "primary_metric", "report_metrics", "control"))]
    args$tuning <- list(strategy = settings$tuning$strategy, model = model)
  }
  do.call(calibrated_workflow, args)
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
  result <- .grid_select(search, data, outcome, settings$event_level, settings$classification,
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
  result <- .grid_select(search, selection, outcome, settings$event_level, settings$classification,
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
