# Native Grid and Bayes search orchestration.

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

# Public only as the parsnip proxy engine entry point.
#' @export
fit_vennabers_proxy <- function(x, y, outcome, parameters, ...) {
  candidate_values <- list(...)
  if (!is.null(parameters$candidates)) {
    index <- match(candidate_values$candidate_id, parameters$candidates$id)
    if (length(index) != 1L || is.na(index)) stop("Unknown grid candidate ID.", call. = FALSE)
    candidate_values <- as.list(parameters$candidates[index,
      setdiff(names(parameters$candidates), "id"), drop = FALSE])
  }
  if (is.data.frame(y) && ncol(y) == 1L) y <- y[[1L]]
  candidate <- parameters$candidate_plan(candidate_values)
  if (is.null(candidate$parameters)) {
    data <- as.data.frame(x)
    data[[outcome]] <- y
    fitted <- .fit_base_model(candidate$workflow, data, parameters$counter)
  } else {
    data <- .calibrated_fit_data(x, y, candidate$workflow, outcome, candidate$parameters)
    seed <- candidate$parameters$requested$seed
    if (!is.null(seed)) withr::local_seed(seed)
    fitted <- .fit_calibrated_components(candidate$workflow, data, outcome,
      candidate$parameters, candidate$tuning_plan)
  }
  structure(list(fitted = fitted, class_levels = levels(y),
    event_level = parameters$event_level, classification = parameters$classification),
    class = "vennabers_grid_fit")
}

.bayes_proxy_workflow <- function(data, outcome, event_level, classification,
                                  candidate_plan, counter, ids) {
  .register_grid_proxy()
  mode <- if (is.numeric(data[[outcome]])) "regression" else "classification"
  spec <- parsnip::new_model_spec("vennabers_grid", args = list(), eng_args = NULL,
                                  mode = mode, method = NULL, engine = "proxy")
  spec <- parsnip::set_engine(spec, "proxy", outcome = outcome,
    parameters = list(candidate_plan = candidate_plan,
      candidates = NULL, event_level = event_level, classification = classification,
      counter = counter))
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
                                 candidates, candidate_plan, counter) {
  .register_grid_proxy()
  mode <- if (is.numeric(data[[outcome]])) "regression" else "classification"
  spec <- parsnip::new_model_spec("vennabers_grid", args = list(), eng_args = NULL,
                                  mode = mode, method = NULL, engine = "proxy")
  spec <- parsnip::set_engine(spec, "proxy", candidate_id = tune::tune("candidate_id"),
                              outcome = outcome,
                              parameters = list(candidate_plan = candidate_plan,
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

.grid_budget <- function(search, plans, candidate_plan, classes) {
  candidate <- candidate_plan(as.list(search$grid[1L, , drop = FALSE]))
  paths <- 1
  model_candidates <- 0L
  model_resamples <- 0L
  inner_paths <- 1
  inner <- 1L
  pair_count <- 1L
  if (!is.null(candidate$parameters)) {
    settings <- candidate$parameters$requested
    if (identical(settings$model_training, "pairwise")) pair_count <- choose(length(classes), 2L)
    folds <- if (is.function(settings$splits)) NA_integer_ else
      if (settings$method == "cross") settings$v else 1L
    # Each VA/full path holds J inner B/P pairs, and each B runs its own search.
    post <- settings$postprocessing
    if (!is.null(post) && post$strategy == "ensemble") inner <- if (is.null(post$splits)) as.integer(post$v) else NA_integer_
    sources <- folds + as.integer(identical(settings$prediction_model, "full"))
    paths <- pair_count * sources * inner
    model <- candidate$tuning_plan$model
    if (!is.null(model)) {
      model_candidates <- if (identical(model$method, "bayes")) model$initial + model$iter else
        if (!is.null(model$grid_size)) model$grid_size else nrow(model$grid)
      model_resamples <- if (is.function(model$resamples)) NA_integer_ else nrow(model$resamples)
      if (candidate$tuning_plan$strategy == "joint") inner_paths <- sources * inner
    }
  }
  unit <- paths * (1 + model_candidates * model_resamples * inner_paths)
  list(candidates = nrow(search$grid), resamples = length(plans), pair_count = pair_count,
       gross_base_fit_estimate = nrow(search$grid) * length(plans) * unit,
       paths = paths, inner_pairs = inner,
       model_candidates = model_candidates,
       model_resamples = model_resamples, inner_paths = inner_paths,
       reused_base_fits = 0L)
}

.grid_select <- function(search, data, outcome, event_level, classification,
                         candidate_plan, label, counter) {
  # yardstick caches column selections in tune's shared progress environment.
  # Nested binary searches must not reuse or overwrite multiclass selections.
  rlang::local_bindings(known_selections = NULL,
    .env = utils::getFromNamespace("tune_env", "tune"))
  if (!is.null(search$grid_size)) {
    params <- dials::finalize(search$param_info, data)
    generated <- if (is.null(search$seed)) dials::grid_space_filling(params, size = search$grid_size) else
      withr::with_seed(search$seed, dials::grid_space_filling(params, size = search$grid_size))
    search$grid <- .checked_grid(generated, search$ids, label)
    search$candidate_ids <- sprintf("%s_%03d", label, seq_len(nrow(search$grid)))
  }
  plan <- .tuning_resamples(search$resamples, data, label)
  plans <- plan$positions
  budget <- .grid_budget(search, plans, candidate_plan, classes = levels(data[[outcome]]))
  initial_fits <- counter$n
  candidates <- data.frame(id = search$candidate_ids)
  candidates_with_values <- cbind(candidates["id"], search$grid)
  native_metrics <- if (inherits(search$primary_metric, "class_metric"))
    yardstick::metric_set(search$primary_metric, yardstick::brier_class) else
    yardstick::metric_set(search$primary_metric)
  control <- if (is.null(search$control)) tune::control_grid(save_pred = TRUE) else search$control
  control$allow_par <- FALSE
  control$event_level <- event_level
  control$extract <- function(w) {
    proxy <- workflows::extract_fit_engine(w)
    state <- proxy$fitted
    if (inherits(state, "vennabers_fit")) list(decision = state$tuning$models) else
      list(decision = NULL)
  }
  result <- tryCatch(suppressMessages(suppressWarnings(tune::tune_grid(
    .grid_proxy_workflow(data, outcome, event_level, classification,
                         candidates_with_values, candidate_plan, counter),
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
  scored <- .score_tuning_candidates(search, result, data, plans, outcome, event_level,
    classification, candidates, data.frame(candidate_id = candidates$id), counter, initial_fits, budget)
  candidates <- scored$candidates
  eligible <- scored$eligible
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
         scores = scored$scores,
         report_metrics = scored$report_metrics,
         decisions = scored$decisions,
         native = result,
         resamples = plans, primary_metric = search$primary_metric,
         direction = direction,
         budget = budget,
         cost = scored$cost,
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

.note_rows <- function(step = character(), resample = NA_character_, location = NA_character_, note = character()) {
  if (!length(note)) step <- resample <- location <- character()
  data.frame(step = step, resample = resample, location = location, note = note, stringsAsFactors = FALSE)
}

# Native notes of excluded candidates would be lost with the filtered GP input.
.bayes_notes <- function(result, step, rows = seq_len(nrow(result))) {
  ids <- if ("id2" %in% names(result)) paste(result$id, result$id2, sep = "/") else result$id
  notes <- lapply(rows, function(i) {
    x <- result$.notes[[i]]
    if (!is.data.frame(x) || !nrow(x) || !"note" %in% names(x)) return(NULL)
    .note_rows(step, ids[[i]], if ("location" %in% names(x)) x$location else NA_character_, x$note)
  })
  do.call(rbind, c(list(.note_rows()), notes))
}

# A proposal dropped by tune_bayes has no native scores; it is excluded as a whole.
.excluded_candidates <- function(values, reason, plans) {
  values$id <- rep(NA_character_, nrow(values))
  values$status <- rep("excluded", nrow(values))
  values$estimate <- rep(NA_real_, nrow(values))
  values$reason <- rep(reason, nrow(values))
  missing <- stats::setNames(rep(NA_real_, length(plans)), names(plans))
  empty <- stats::setNames(vector("list", length(plans)), names(plans))
  list(candidates = values, scores = rep(list(missing), nrow(values)),
       report_metrics = rep(list(empty), nrow(values)), decisions = rep(list(empty), nrow(values)))
}

.append_history <- function(history, scored) {
  history$candidates <- rbind(history$candidates, scored$candidates)
  for (part in c("scores", "report_metrics", "decisions")) history[[part]] <- c(history[[part]], scored[[part]])
  history
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

.bayes_select <- function(search, data, outcome, event_level, classification,
                          candidate_plan, label, counter) {
  # Keep the same metric-cache boundary as Grid, including Bayes initialization.
  rlang::local_bindings(known_selections = NULL,
    .env = utils::getFromNamespace("tune_env", "tune"))
  plan <- .tuning_resamples(search$resamples, data, label)
  plans <- plan$positions
  initial_fits <- counter$n
  started <- proc.time()[3L]
  control <- search$control
  control$time_limit <- NA_real_
  control$event_level <- event_level
  control$extract <- function(w) {
    proxy <- workflows::extract_fit_engine(w)
    state <- proxy$fitted
    if (inherits(state, "vennabers_fit")) list(decision = state$tuning$models) else list(decision = NULL)
  }
  # tune_bayes silently drops a proposal that failed on every resample; the
  # values the proxy was asked to fit are the only record of that attempt.
  proposals <- new.env()
  proposals$values <- list()
  proxy <- .bayes_proxy_workflow(data, outcome, event_level, classification, function(values) {
    proposals$values[[length(proposals$values) + 1L]] <- values[unname(search$ids)]
    candidate_plan(values)
  }, counter, search$ids)
  params <- dials::finalize(search$param_info, data)
  initial_grid <- withr::with_seed(control$seed, dials::grid_space_filling(params, size = search$initial))
  budget <- .grid_budget(list(grid = initial_grid), plans, candidate_plan, classes = levels(data[[outcome]]))
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
  candidates <- as.data.frame(initial_grid)
  candidates$id <- sprintf("%s_%03d", label, seq_len(nrow(candidates)))
  scored <- .score_tuning_candidates(search, initial, data, plans, outcome, event_level, classification,
    candidates, as.data.frame(initial_grid), counter, initial_fits, budget)
  required <- nrow(params) + 1L
  if (!nrow(scored$candidates)) {
    stop("Bayes needs at least ", required, " complete initial ", label,
         " candidates; found 0.", call. = FALSE)
  }
  identified <- .stable_bayes_ids(scored, search$ids, label)
  scored <- identified$scored
  history <- scored
  known_ids <- identified$known
  notes <- .bayes_notes(initial, "initial")
  if (length(scored$eligible) < required) {
    # As in Grid: excluded candidates and native notes explain the shortfall.
    reasons <- unique(c(stats::na.omit(scored$candidates$reason), notes$note))
    stop("Bayes needs at least ", required, " complete initial ", label, " candidates; found ",
         length(scored$eligible), if (length(reasons)) paste0(": ", paste(reasons, collapse = " | ")) else ".",
         call. = FALSE)
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
    before <- length(proposals$values)
    # Keep tune's own step log: it is the only trace of a proposal it dropped.
    step_log <- character()
    record <- function(restart) function(condition) {
      step_log <<- c(step_log, trimws(conditionMessage(condition)))
      invokeRestart(restart)
    }
    next_result <- tryCatch(withCallingHandlers(tune::tune_bayes(proxy, resamples = plan$rset,
      initial = valid, iter = 1L, param_info = params, metrics = native_metrics, control = step_control),
      message = record("muffleMessage"), warning = record("muffleWarning")), error = identity)
    if (inherits(next_result, "error")) {
      stale <- stale + 1L
      steps[[paste0("step_", step)]] <- list(error = conditionMessage(next_result))
    } else {
      has_iter <- ".iter" %in% names(next_result)
      new_iteration <- has_iter && max(next_result$.iter) > (if (".iter" %in% names(valid)) max(valid$.iter) else 0L)
      rows <- if (has_iter) which(next_result$.iter == max(next_result$.iter)) else seq_len(nrow(next_result))
      # Without a new iteration the last rows are earlier results with their notes.
      step_notes <- .bayes_notes(next_result, paste0("step_", step), if (new_iteration) rows else integer())
      notes <- rbind(notes, step_notes)
      known <- names(known_ids)
      errors <- unique(stats::na.omit(step_notes$note[nzchar(step_notes$note)]))
      attempted <- proposals$values[seq_along(proposals$values) > before]
      proposed <- if (new_iteration || !length(attempted)) .bayes_step_candidates(next_result, search$ids) else
        unique(as.data.frame(do.call(rbind, lapply(attempted, as.data.frame, stringsAsFactors = FALSE))))
      if (!new_iteration && length(attempted) && !all(.candidate_key(proposed) %in% known)) {
        # A dropped new proposal failed on every resample: an excluded attempt.
        notes <- rbind(notes, .note_rows(paste0("step_", step), note = unique(step_log)))
        identified <- .stable_bayes_ids(.excluded_candidates(proposed,
          paste(c("All resamples failed", unique(step_log)), collapse = " | "), plans), search$ids, label, known_ids)
        known_ids <- identified$known
        history <- .append_history(history, identified$scored)
        stale <- stale + 1L
        steps[[paste0("step_", step)]] <- identified$scored$candidates
        if (stale >= search$control$no_improve) {
          reason <- "no_improve"
          break
        }
        next
      } else if (!nrow(proposed) && length(errors)) {
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
      candidates <- proposed
      candidates$id <- sprintf("%s_%03d", label, seq_len(nrow(candidates)))
      scored <- .score_tuning_candidates(search, next_result[rows, , drop = FALSE], data, plans,
        outcome, event_level, classification, candidates, proposed, counter, initial_fits, budget)
      identified <- .stable_bayes_ids(scored, search$ids, label, known_ids)
      scored <- identified$scored
      known_ids <- identified$known
      history <- .append_history(history, scored)
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
    seed = control$seed, bayes_seed = control$seed, steps = steps, notes = notes, stop_reason = reason,
    attempts = attempts, no_improve = stale, elapsed_seconds = proc.time()[3L] - started),
    history[c("budget", "cost")]))
}
