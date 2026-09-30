# Pairwise model training: every class pair is a component with its own local
# rows, recipe-retargeted workflow and binary calibrator; shared phases do the
# fitting and prediction, so this file only retargets recipes, builds pair
# domains and couples pair points into class probabilities.
.fit_pairwise <- function(base_workflow, data, state, tuning_plan) {
  settings <- state$parameters$requested
  cross <- settings$method == "cross"
  pairs <- utils::combn(state$class_levels, 2L, simplify = FALSE)
  ids <- paste0("pair_", seq_along(pairs))
  pair_plans <- settings$splits
  named <- !is.null(pair_plans) && !is.function(pair_plans)
  if (named && (is.null(names(pair_plans)) || anyNA(names(pair_plans)) || anyDuplicated(names(pair_plans)) ||
      !setequal(names(pair_plans), ids))) {
    stop("Pair plans must be named uniquely by exactly the required pair IDs: ",
         paste(ids, collapse = ", "), ".", call. = FALSE)
  }
  # Resolve and validate every pair before any recipe or model learns.
  planned <- lapply(seq_along(pairs), function(i) {
    id <- ids[i]
    pair <- pairs[[i]]
    rows <- which(data[[state$outcome]] %in% pair)
    local <- data[rows, , drop = FALSE]
    local[[state$outcome]] <- factor(local[[state$outcome]], levels = pair,
                                     ordered = is.ordered(data[[state$outcome]]))
    workflow <- base_workflow
    recipe <- workflows::extract_preprocessor(base_workflow)
    if (inherits(recipe, "recipe")) {
      # recipes has no public ptype setter. Change only the outcome domain;
      # retain all steps, roles and blueprint options, without pre-learning them.
      recipe$template <- recipe$template[0L, , drop = FALSE]
      recipe$template[[state$outcome]] <- local[[state$outcome]][0L]
      if (!is.null(recipe$ptype)) recipe$ptype[[state$outcome]] <- local[[state$outcome]][0L]
      workflow <- workflows::update_recipe(workflow, recipe,
        blueprint = base_workflow$pre$actions$recipe$blueprint)
    }
    list(id = id, pair = pair, rows = rows, local = local, workflow = workflow,
      plan = if (is.function(pair_plans)) pair_plans else if (named) pair_plans[[id]] else NULL)
  })
  domains <- lapply(seq_along(planned), function(i) {
    entry <- planned[[i]]
    id <- entry$id
    pair <- entry$pair
    rows <- entry$rows
    local <- entry$local
    list(data = local, workflow = entry$workflow, plan = entry$plan, pair_id = id,
      pair_rows = rows, schema = state$schema,
      outcome = state$outcome, strata = settings$strata, classes = pair, event = pair[2L], y = local[[state$outcome]],
      rows_word = "local pair rows", seed_wrap = TRUE,
      precheck = NULL,
      resolve_error = function(e) stop(id, if (cross) " Cross: " else " Inductive1: ",
        conditionMessage(e), call. = FALSE),
      folds_error = function(e, slot) stop(id, if (cross) " Cross: " else " Inductive1: ",
        conditionMessage(e), call. = FALSE),
      post = function(folds, local) {
        if (!cross) for (part in c("analysis", "assessment")) {
          for (fold_id in names(folds)) {
            if (any(tabulate(local[[state$outcome]][folds[[fold_id]][[part]]], nbins = 2L) == 0L)) {
              stop("Both pair classes must occur in ", part, " (training/calibration).", call. = FALSE)
            }
          }
        }
        folds
      },
      fit_error = function(fold, e) stop(id, " ", fold, " base workflow training: ",
        conditionMessage(e), call. = FALSE),
      full_error = function(e) stop(id, " Full1 base workflow training: ", conditionMessage(e), call. = FALSE),
      pred_id = function(fold) paste(id, fold),
      fields = function() list(pair_id = id, class_levels = pair, event_class = pair[2L], rows = rows))
  })
  task <- .component_task("binary", settings, list())
  # Finish every source fit first so full-model RNG draws cannot change calibration.
  result <- if (is.null(tuning_plan$pair_cache)) .fit_domains(domains, task, settings, tuning_plan) else
    .fit_pairwise_grid_domains(data, domains, task, settings, tuning_plan)
  components <- stats::setNames(lapply(result$fitted, function(component) component), ids)
  state$pair_models <- components
  if (!is.null(state$tuning)) {
    state$tuning$models <- lapply(components, function(component) {
      selections <- component$model_selection
      for (fold in names(selections)) if (!is.null(selections[[fold]])) {
        selections[[fold]]$pair_id <- component$pair_id
        selections[[fold]]$fold_id <- fold
      }
      selections
    })
    state$tuning$sources <- lapply(components, `[[`, "sources")
    state$tuning$fit_roles <- lapply(components, `[[`, "folds")
  }
  if (!is.null(state$tuning)) state$tuning$cost <- list(observed_base_fits = tuning_plan$counter$n)
  state
}

.predict_pairwise <- function(object, new_data, include_details) {
  pairs <- utils::combn(object$class_levels, 2L, simplify = FALSE)
  ids <- paste0("pair_", seq_along(pairs))
  if (!identical(names(object$pair_models), ids)) {
    stop("Pair/class mapping does not match the fitted global class order.", call. = FALSE)
  }
  n <- nrow(new_data)
  points <- matrix(0, n, length(pairs))
  details <- vector("list", length(pairs))
  cross <- object$parameters$requested$method == "cross"
  for (i in seq_along(pairs)) {
    id <- ids[i]
    component <- .predict_pair_component(object, new_data, id, pairs[[i]], n, include_details, cross)
    points[, i] <- component$points
    if (include_details) details[[i]] <- component$details
  }
  prediction <- .couple_ovo(points, pairs, object$class_levels)
  colnames(prediction) <- paste0(".pred_", object$class_levels)
  result <- list(prediction = tibble::as_tibble(prediction, .name_repair = "minimal"))
  if (include_details) result$details <- tibble::as_tibble(do.call(rbind, details))
  result
}

.predict_pair_component <- function(object, new_data, id, pair, n, include_details, cross) {
  component <- object$pair_models[[id]]
  fold_ids <- if (cross) component$calibrator$folds else "Inductive1"
  if (!identical(component$pair_id, id) || !identical(component$class_levels, pair) ||
      !identical(component$event_class, pair[2L]) ||
      !identical(names(component$sources), fold_ids) ||
      !identical(names(component$models), unique(unname(component$sources))) ||
      !identical(names(component$folds), fold_ids) ||
      !identical(names(component$calibration), fold_ids) ||
      (cross && (length(fold_ids) < 2L || anyNA(fold_ids) || any(!nzchar(fold_ids)) ||
                 anyDuplicated(fold_ids) || !identical(names(component$calibrator$calibrators), fold_ids)))) {
    stop(id, " model/pair/fold identity does not match the fitted mapping.", call. = FALSE)
  }
  cache <- component$prediction_cache
  p <- if (!is.null(cache) && identical(cache$data, new_data)) cache$predictions else
    .source_predictions(component$models, component$sources, new_data,
      function(model, model_id) {
        .validate_pair_model(model, pair, paste(id, model_id))
        .base_probability(model, new_data, component$class_levels, component$event_class, paste(id, model_id))
      },
      numeric)
  if (!is.null(cache)) {
    cache$data <- new_data
    cache$predictions <- p
  }
  binary <- .calibrate_binary_points(component$calibrator, p, cross, object$loss, n, include_details)
  point <- binary$probability
  details <- NULL
  if (include_details) {
    if (cross) {
      part <- binary$details
    } else {
      part <- data.frame(row = seq_len(n), fold = rep("Inductive1", n), binary$details)
    }
    k <- nrow(part)
    # The shared model id (constant per component) decides whether the source
    # label needs qualifying beyond the pair id.
    shared <- unname(component$sources[[1L]])
    details <- data.frame(row = part$row, pair_id = rep(id, k),
      fold = part$fold, method = rep("ovo", k), event_class = rep(component$event_class, k),
      class_1 = rep(pair[1L], k), class_2 = rep(pair[2L], k),
      part[c("lower", "upper", "probability")], model_training = rep("pairwise", k),
      prediction_model = rep(object$parameters$requested$prediction_model, k),
      model_source = rep(if (identical(shared, "Full1")) paste0(id, "/Full1") else id, k))
  }
  list(points = point, details = details)
}

# Check wrappers as well as every leaf workflow: swapping one inner member
# must not silently mix a different class pair into the global prediction.
.validate_pair_model <- function(model, pair, context) {
  if (inherits(model, "vennabers_ensemble")) {
    if (!identical(names(model$models), model$inner_folds) || length(model$models) < 2L ||
        any(vapply(model$models, is.null, logical(1)))) {
      stop(context, " incomplete inner ensemble.", call. = FALSE)
    }
    for (j in names(model$models)) .validate_pair_model(model$models[[j]], pair, paste(context, "/", j))
    classes <- model$classes
  } else if (inherits(model, "vennabers_sigmoid")) {
    .validate_pair_model(model$workflow, pair, context)
    classes <- model$classes
  } else {
    classes <- if (inherits(model, "workflow")) levels(workflows::extract_mold(model)$outcomes[[1L]])
  }
  if (!identical(classes, pair)) {
    stop(context, " model/pair identity does not match the fitted mapping.", call. = FALSE)
  }
  invisible(NULL)
}
