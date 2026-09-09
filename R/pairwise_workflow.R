.fit_pairwise <- function(base_workflow, data, state) {
  settings <- state$parameters$requested
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
    fold <- tryCatch({
      # A fixed local seed makes plans independent of preceding model draws.
      resolve <- function() {
        if (is.function(plans)) plans(local) else if (!is.null(plans)) plans[[id]] else
          if (identical(settings$strata, FALSE)) {
            rsample::initial_split(local, prop = 1 - settings$calibration_prop)
          } else rlang::inject(rsample::initial_split(local,
            prop = 1 - settings$calibration_prop, strata = !!state$outcome, pool = 0))
      }
      split <- if (is.null(settings$seed)) resolve() else withr::with_seed(settings$seed, resolve())
      f <- .inductive_split(split, local)
      for (part in c("analysis", "assessment")) {
        if (any(tabulate(local[[state$outcome]][f[[part]]], nbins = 2L) == 0L)) {
          stop("Both pair classes must occur in ", part, " (training/calibration).", call. = FALSE)
        }
      }
      f$training_size <- length(f$analysis)
      f$calibration_size <- length(f$assessment)
      f
    }, error = function(e) stop(id, " Inductive1: ", conditionMessage(e), call. = FALSE))
    components[[id]] <- list(pair_id = id, class_levels = pair, event_class = pair[2L],
      rows = rows, folds = list(Inductive1 = fold))
  }
  for (id in ids) {
    component <- components[[id]]
    local <- local_data[[id]]
    fold <- component$folds$Inductive1
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
    component$models <- list(Inductive1 = tryCatch(
      generics::fit(workflow, local[fold$analysis, , drop = FALSE]),
      error = function(e) stop(id, " Inductive1 base workflow training: ", conditionMessage(e), call. = FALSE)))
    p <- .base_probability(component$models$Inductive1, local[fold$assessment, , drop = FALSE],
                           component$class_levels, component$event_class, paste(id, "Inductive1"))
    truth <- local[[state$outcome]][fold$assessment] == component$event_class
    component$calibrator <- venn_abers(truth, p, precision = settings$precision)
    component$calibration <- list(Inductive1 = data.frame(row = fold$assessment,
      truth = truth, probability = p))
    components[[id]] <- component
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
  for (i in seq_along(pairs)) {
    id <- ids[i]
    component <- object$pair_models[[id]]
    if (!identical(component$pair_id, id) || !identical(component$class_levels, pairs[[i]]) ||
        !identical(component$event_class, pairs[[i]][2L]) ||
        !identical(names(component$models), "Inductive1") ||
        !identical(names(component$folds), "Inductive1") ||
        !identical(levels(workflows::extract_mold(component$models$Inductive1)$outcomes[[1L]]), pairs[[i]])) {
      stop(id, " model/pair/fold identity does not match the fitted mapping.", call. = FALSE)
    }
    p <- if (n) .base_probability(component$models$Inductive1, new_data,
      component$class_levels, component$event_class, paste(id, "Inductive1")) else numeric()
    binary <- stats::predict(component$calibrator, p, loss = object$loss)
    points[, i] <- binary$probability
    if (include_details) details[[i]] <- data.frame(row = seq_len(n), pair_id = rep(id, n),
      fold = rep("Inductive1", n), method = rep("ovo", n),
      event_class = rep(component$event_class, n), class_1 = rep(pairs[[i]][1L], n),
      class_2 = rep(pairs[[i]][2L], n), binary, model_training = rep("pairwise", n),
      prediction_model = rep("matched", n), model_source = rep(id, n))
  }
  prediction <- .couple_ovo(points, pairs, object$class_levels)
  colnames(prediction) <- paste0(".pred_", object$class_levels)
  result <- list(prediction = tibble::as_tibble(prediction, .name_repair = "minimal"))
  if (include_details) result$details <- tibble::as_tibble(do.call(rbind, details))
  result
}
