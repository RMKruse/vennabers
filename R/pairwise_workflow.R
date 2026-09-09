.fit_pairwise <- function(base_workflow, data, state) {
  settings <- state$parameters$requested
  cross <- settings$method == "cross"
  full <- settings$prediction_model == "full"
  full_workflows <- list()
  pairs <- utils::combn(state$class_levels, 2L, simplify = FALSE)
  ids <- paste0("pair_", seq_along(pairs))
  state$pairs <- data.frame(pair_id = ids,
    class_1 = vapply(pairs, `[`, "", 1L), class_2 = vapply(pairs, `[`, "", 2L))
  plans <- settings$splits
  if (!is.null(plans) && !is.function(plans) &&
      (is.null(names(plans)) || anyNA(names(plans)) || anyDuplicated(names(plans)) ||
       !setequal(names(plans), ids))) {
    stop("Pair plans must be named uniquely by exactly the required pair IDs: ",
         paste(ids, collapse = ", "), ".", call. = FALSE)
  }
  local_data <- components <- stats::setNames(vector("list", length(pairs)), ids)
  # Resolve and validate every pair before any recipe or model learns.
  for (i in seq_along(pairs)) {
    id <- ids[i]
    pair <- pairs[[i]]
    rows <- which(data[[state$outcome]] %in% pair)
    local <- data[rows, , drop = FALSE]
    local[[state$outcome]] <- factor(local[[state$outcome]], levels = pair,
                                   ordered = is.ordered(data[[state$outcome]]))
    local_data[[id]] <- local
    folds <- tryCatch({
      # A fixed local seed makes plans independent of preceding model draws.
      resolve <- function() {
        if (is.function(plans)) return(plans(local))
        if (!is.null(plans)) return(plans[[id]])
        if (cross) {
          if (settings$v > nrow(local)) {
            stop("`v` cannot exceed the number of local pair rows; the fold count is not reduced.", call. = FALSE)
          }
          if (identical(settings$strata, FALSE)) rsample::vfold_cv(local, v = settings$v) else
            rlang::inject(rsample::vfold_cv(local, v = settings$v, strata = !!state$outcome, pool = 0))
        } else if (identical(settings$strata, FALSE)) {
          rsample::initial_split(local, prop = 1 - settings$calibration_prop)
        } else rlang::inject(rsample::initial_split(local,
          prop = 1 - settings$calibration_prop, strata = !!state$outcome, pool = 0))
      }
      split <- if (is.null(settings$seed)) resolve() else withr::with_seed(settings$seed, resolve())
      fs <- if (cross) .cross_splits(split, local) else list(Inductive1 = .inductive_split(split, local))
      for (fold_id in names(fs)) {
        f <- fs[[fold_id]]
        if (!cross) for (part in c("analysis", "assessment")) {
          if (any(tabulate(local[[state$outcome]][f[[part]]], nbins = 2L) == 0L)) {
            stop("Both pair classes must occur in ", part, " (training/calibration).", call. = FALSE)
          }
        }
        f$training_size <- length(f$analysis)
        f$calibration_size <- length(f$assessment)
        fs[[fold_id]] <- f
      }
      fs
    }, error = function(e) stop(id, if (cross) " Cross: " else " Inductive1: ", conditionMessage(e), call. = FALSE))
    components[[id]] <- list(pair_id = id, class_levels = pair, event_class = pair[2L],
      rows = rows, folds = folds)
  }
  for (id in ids) {
    component <- components[[id]]
    local <- local_data[[id]]
    workflow <- base_workflow
    recipe <- workflows::extract_preprocessor(workflow)
    if (inherits(recipe, "recipe")) {
      # recipes has no public ptype setter. Change only the outcome domain;
      # retain all steps, roles and blueprint options, without pre-learning them.
      recipe$template <- recipe$template[0L, , drop = FALSE]
      recipe$template[[state$outcome]] <- local[[state$outcome]][0L]
      if (!is.null(recipe$ptype)) recipe$ptype[[state$outcome]] <- local[[state$outcome]][0L]
      workflow <- workflows::update_recipe(workflow, recipe,
        blueprint = workflow$pre$actions$recipe$blueprint)
    }
    component$models <- component$calibration <- stats::setNames(
      vector("list", length(component$folds)), names(component$folds))
    for (fold_id in names(component$folds)) {
      fold <- component$folds[[fold_id]]
      identity <- list(pair_id = id, fold = fold_id, rows = component$rows,
                       class_levels = component$class_levels, positions = fold)
      model <- tryCatch(generics::fit(workflow, local[fold$analysis, , drop = FALSE]),
        error = function(e) stop(id, " ", fold_id, " base workflow training: ", conditionMessage(e), call. = FALSE))
      attr(model, "vennabers_pair_fold") <- identity
      component$models[[fold_id]] <- model
      p <- .base_probability(model, local[fold$assessment, , drop = FALSE],
                             component$class_levels, component$event_class, paste(id, fold_id))
      truth <- local[[state$outcome]][fold$assessment] == component$event_class
      component$calibration[[fold_id]] <- data.frame(row = fold$assessment, truth = truth, probability = p)
    }
    calibration <- do.call(rbind, component$calibration)
    component$calibrator <- if (cross) {
      core <- cross_venn_abers(calibration$truth, calibration$probability,
        rep(names(component$folds), vapply(component$folds, function(f) f$calibration_size, 1L)),
        precision = settings$precision)
      names(core$calibrators) <- core$folds
      for (fold_id in core$folds) attr(core$calibrators[[fold_id]], "vennabers_pair_fold") <-
        attr(component$models[[fold_id]], "vennabers_pair_fold", exact = TRUE)
      core
    } else {
      core <- venn_abers(calibration$truth, calibration$probability, precision = settings$precision)
      attr(core, "vennabers_pair_fold") <- attr(component$models$Inductive1, "vennabers_pair_fold", exact = TRUE)
      core
    }
    components[[id]] <- component
    if (full) full_workflows[[id]] <- workflow
  }
  # Finish every source fit first so full-model RNG draws cannot change calibration.
  if (full) {
    for (id in ids) {
      component <- components[[id]]
      local <- local_data[[id]]
      model <- tryCatch(generics::fit(full_workflows[[id]], local),
        error = function(e) stop(id, " Full1 base workflow training: ", conditionMessage(e), call. = FALSE))
      .base_probability(model, local[1L, , drop = FALSE], component$class_levels,
                        component$event_class, paste(id, "Full1"))
      attr(model, "vennabers_pair_fold") <- list(pair_id = id, fold = "Full1", rows = component$rows,
        class_levels = component$class_levels, positions = list(analysis = seq_len(nrow(local)), assessment = integer()))
      full_workflows[[id]] <- model
    }
    # Release temporary sources only after every full workflow has succeeded.
    for (id in ids) components[[id]]$models <- list(Full1 = full_workflows[[id]])
  }
  state$pair_models <- components
  state
}

.predict_pairwise <- function(object, new_data, include_details) {
  pairs <- utils::combn(object$class_levels, 2L, simplify = FALSE)
  ids <- paste0("pair_", seq_along(pairs))
  expected <- data.frame(pair_id = ids,
    class_1 = vapply(pairs, `[`, "", 1L), class_2 = vapply(pairs, `[`, "", 2L))
  if (!identical(object$pairs, expected) || !identical(names(object$pair_models), ids)) {
    stop("Pair/class mapping does not match the fitted global class order.", call. = FALSE)
  }
  n <- nrow(new_data)
  points <- matrix(0, n, length(pairs))
  details <- vector("list", length(pairs))
  full <- object$parameters$requested$prediction_model == "full"
  for (i in seq_along(pairs)) {
    id <- ids[i]
    component <- object$pair_models[[id]]
    cross <- object$parameters$requested$method == "cross"
    fold_ids <- if (cross) component$calibrator$folds else "Inductive1"
    if (!identical(component$pair_id, id) || !identical(component$class_levels, pairs[[i]]) ||
        !identical(component$event_class, pairs[[i]][2L]) ||
        !identical(names(component$models), if (full) "Full1" else fold_ids) ||
        !identical(names(component$folds), fold_ids) ||
        !identical(names(component$calibration), fold_ids) ||
        (cross && (length(fold_ids) < 2L || anyNA(fold_ids) || any(!nzchar(fold_ids)) ||
                   anyDuplicated(fold_ids) || !identical(names(component$calibrator$calibrators), fold_ids)))) {
      stop(id, " model/pair/fold identity does not match the fitted mapping.", call. = FALSE)
    }
    for (fold_id in fold_ids) {
      identity <- list(pair_id = id, fold = fold_id, rows = component$rows,
                       class_levels = component$class_levels, positions = component$folds[[fold_id]])
      calibrator <- if (cross) component$calibrator$calibrators[[fold_id]] else component$calibrator
      if (!identical(attr(calibrator, "vennabers_pair_fold", exact = TRUE), identity)) {
        stop(id, " ", fold_id, " calibrator/pair/fold identity does not match the fitted mapping.", call. = FALSE)
      }
    }
    p <- lapply(names(component$models), function(model_id) {
      model <- component$models[[model_id]]
      positions <- if (full) list(analysis = seq_along(component$rows), assessment = integer()) else component$folds[[model_id]]
      identity <- list(pair_id = id, fold = model_id, rows = component$rows,
                       class_levels = component$class_levels, positions = positions)
      if (!identical(levels(workflows::extract_mold(model)$outcomes[[1L]]), pairs[[i]]) ||
          !identical(attr(model, "vennabers_pair_fold", exact = TRUE), identity)) {
        stop(id, " ", model_id, " model/pair/fold identity does not match the fitted mapping.", call. = FALSE)
      }
      if (n) .base_probability(model, new_data, component$class_levels,
                              component$event_class, paste(id, model_id)) else numeric()
    })
    if (full) p <- rep(p, length(fold_ids))
    names(p) <- fold_ids
    if (cross) {
      binary <- stats::predict(component$calibrator, do.call(cbind, p), loss = object$loss,
                               type = if (include_details) "details" else "response")
      points[, i] <- if (include_details) binary$prediction$probability else binary$probability
      if (include_details) part <- binary$folds
    } else {
      binary <- stats::predict(component$calibrator, p[[1L]], loss = object$loss)
      points[, i] <- binary$probability
      if (include_details) part <- data.frame(row = seq_len(n), fold = rep("Inductive1", n), binary)
    }
    if (include_details) {
      k <- nrow(part)
      details[[i]] <- data.frame(row = part$row, pair_id = rep(id, k),
        fold = part$fold, method = rep("ovo", k), event_class = rep(component$event_class, k),
        class_1 = rep(pairs[[i]][1L], k), class_2 = rep(pairs[[i]][2L], k),
        part[c("lower", "upper", "probability")], model_training = rep("pairwise", k),
        prediction_model = rep(if (full) "full" else "matched", k),
        model_source = rep(if (full) paste0(id, "/Full1") else id, k))
    }
  }
  prediction <- .couple_ovo(points, pairs, object$class_levels)
  colnames(prediction) <- paste0(".pred_", object$class_levels)
  result <- list(prediction = tibble::as_tibble(prediction, .name_repair = "minimal"))
  if (include_details) result$details <- tibble::as_tibble(do.call(rbind, details))
  result
}
