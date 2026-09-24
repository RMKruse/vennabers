# Global pairwise joint selection builds candidates for the common search path.

.pairwise_grid_joint <- function(tuning, pairwise) {
  isTRUE(pairwise) && identical(tuning$strategy, "joint") &&
    !is.null(tuning$model) && identical(tuning$model$method, "grid") &&
    (is.null(tuning$calibration) || identical(tuning$calibration$method, "grid"))
}

.assess_pairwise_bayes_joint <- function(data, workflow, outcome, parameters, counter) {
  settings <- parameters$requested
  search <- list(grid = data.frame(pairwise = 1L), candidate_ids = "joint_0001",
    ids = c(pairwise = "pairwise"), resamples = settings$tuning$joint_resamples,
    primary_metric = settings$tuning$model$primary_metric,
    report_metrics = settings$tuning$model$report_metrics)
  result <- .grid_select(search, data, outcome, settings$event_level, settings$classification,
    function(values) {
      .calibrated_candidate(workflow, settings, parameters$schema, counter)
    }, "joint", counter)
  result$diagnostics$pair_ids <- paste0("pair_", seq_len(choose(nlevels(data[[outcome]]), 2L)))
  result$diagnostics$seed <- settings$seed
  list(data = data, settings = settings, diagnostics = result$diagnostics)
}

.choose_pairwise_joint <- function(data, workflow, outcome, parameters, counter) {
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
      .calibrated_candidate(workflow, nested, parameters$schema, counter,
        pairs = pair_values(values), pair_grid_id = values[["..candidate_id"]])
    }, "joint", counter)
  values <- result$values
  if (!is.null(calibration)) {
    settings <- .calibration_values(settings, calibration$ids,
      as.list(calibration$grid[values[["..calibration"]], , drop = FALSE]))
    settings$tuning$calibration <- NULL
  }
  selected_pairs <- pair_values(values)
  result$diagnostics$selected <- list(pairs = selected_pairs,
    calibration = if (!is.null(calibration)) list(loss = settings$loss, precision = settings$precision) else NULL)
  result$diagnostics$seed <- settings$seed
  result$diagnostics$pair_ids <- pair_ids
  if (!is.null(roles)) {
    result$diagnostics$roles <- roles
    result$diagnostics$selection_rows <- roles$assessment
    result$diagnostics$final_rows <- roles$analysis
  }
  list(data = if (is.null(roles)) data else data[roles$analysis, , drop = FALSE],
       settings = settings, pairs = selected_pairs, pair_grid_id = result$diagnostics$chosen,
       diagnostics = result$diagnostics)
}
