# The outer workflow only carries raw variables. Learning belongs to the base
# workflow after the local split, including any recipe preparation.
calibrated_workflow <- function(workflow, outcome, ..., predictors = NULL,
                                method = "inductive", classification = "binary",
                                event_level = "first", calibration_prop = 0.2, v = 5L,
                                strata = NULL, splits = NULL, seed = NULL, precision = NULL,
                                loss = "log", m = NULL, epsilon = NULL) {
  .integration_dots(...)
  # Arguments before ... also need exact names (R otherwise partially matches).
  supplied <- names(sys.call())[-1L]
  bad <- supplied[nzchar(supplied) & !supplied %in% names(formals(calibrated_workflow))]
  if (length(bad)) stop("Unknown argument: ", sQuote(bad[1L]), ".", call. = FALSE)
  .integration_names(outcome, "outcome")
  if (length(outcome) != 1L) stop("`outcome` must name one column.", call. = FALSE)
  if (grepl("^(\\.pred($|_)|\\.row$|\\.config$|id([1-9][0-9]*)?$)", outcome)) {
    stop("Outcome ", sQuote(outcome), " is reserved for prediction/resample metadata; rename it explicitly.", call. = FALSE)
  }
  if (!is.null(predictors)) {
    .integration_names(predictors, "predictor")
    if (outcome %in% predictors) stop("Outcome ", sQuote(outcome), " is also a predictor.", call. = FALSE)
  }
  .validate_choice(method, c("inductive", "cross"), "method")
  .validate_choice(classification, c("binary", "ovo", "ovr"), "classification")
  .integration_packages()
  mode <- .validate_base_workflow(workflow, outcome, classification)
  regression <- mode == "regression"
  if (regression && (!missing(classification) || !missing(event_level) ||
                     !missing(precision) || !missing(loss))) {
    stop("Regression does not accept explicit classification, event_level, precision or loss options.", call. = FALSE)
  }
  if (!regression && (!missing(m) || !missing(epsilon))) {
    stop("`m` and `epsilon` require a regression base workflow.", call. = FALSE)
  }
  if (!is.null(m) && !is.null(epsilon)) stop("Supply only one of `m` and `epsilon`.", call. = FALSE)
  if (!is.null(m)) {
    .validate_regression_vector(m, "m")
    if (length(m) != 1L || m != floor(m) || m < 1) {
      stop("`m` must be one positive whole number.", call. = FALSE)
    }
  }
  if (!is.null(epsilon)) {
    .validate_regression_vector(epsilon, "epsilon")
    if (length(epsilon) != 1L || epsilon <= 0 || epsilon >= 1) {
      stop("`epsilon` must be one finite numeric value strictly between 0 and 1.", call. = FALSE)
    }
  }
  if (classification != "binary" && !missing(event_level)) {
    stop("`event_level` requires classification = 'binary'.", call. = FALSE)
  }
  .validate_choice(event_level, c("first", "second"), "event_level")
  .validate_choice(loss, c("log", "brier"), "loss")
  if (method == "inductive" && !missing(v)) stop("`v` requires method = 'cross'.", call. = FALSE)
  if (method == "cross" && !missing(calibration_prop)) {
    stop("`calibration_prop` requires method = 'inductive'.", call. = FALSE)
  }
  if (!is.numeric(v) || !is.vector(v) || length(v) != 1L || !is.finite(v) ||
      v != floor(v) || v < 2 || v > .Machine$integer.max) {
    stop("`v` must be one finite whole number of at least two folds.", call. = FALSE)
  }
  if (!is.numeric(calibration_prop) || !is.vector(calibration_prop) ||
      length(calibration_prop) != 1L || !is.finite(calibration_prop) ||
      calibration_prop <= 0 || calibration_prop >= 1) {
    stop("`calibration_prop` must be one number strictly between 0 and 1.", call. = FALSE)
  }
  if (!is.null(strata) && !identical(strata, FALSE)) {
    stop("`strata` must be NULL (classification outcome stratification; none for regression) or FALSE.", call. = FALSE)
  }
  if (!is.null(seed) && (!is.numeric(seed) || !is.vector(seed) || length(seed) != 1L ||
                        !is.finite(seed) || seed != floor(seed) || abs(seed) > .Machine$integer.max)) {
    stop("`seed` must be NULL or one integer in R's seed range.", call. = FALSE)
  }
  if (!is.null(precision) && (!is.numeric(precision) || !is.vector(precision) ||
                            length(precision) != 1L || !is.finite(precision) || precision != floor(precision))) {
    stop("`precision` must be NULL or one finite numeric whole number.", call. = FALSE)
  }
  if (!is.null(splits)) {
    if (!inherits(splits, if (method == "cross") "rset" else "rsplit") && !is.function(splits)) {
      stop("`splits` must be NULL, an IID ", if (method == "cross") "Cross rset" else "holdout rsplit",
           ", or a function of local data.", call. = FALSE)
    }
    if (!missing(calibration_prop) || !missing(v) || !missing(strata)) {
      stop("Explicit `splits` cannot be combined with `calibration_prop`, `v` or `strata`.", call. = FALSE)
    }
  }
  .register_vennabers()
  requested <- list(mode = mode, predictors = predictors, method = method, classification = classification,
                    event_level = event_level, calibration_prop = calibration_prop, v = v,
                    strata = strata, splits = splits, seed = seed, precision = precision, loss = loss,
                    m = m, epsilon = epsilon)
  explicit <- c(predictors = !missing(predictors), method = !missing(method),
                classification = !missing(classification), event_level = !missing(event_level),
                calibration_prop = !missing(calibration_prop), v = !missing(v), strata = !missing(strata),
                splits = !missing(splits), seed = !missing(seed), precision = !missing(precision), loss = !missing(loss),
                m = !missing(m), epsilon = !missing(epsilon))
  spec <- parsnip::new_model_spec("vennabers", args = list(), eng_args = NULL,
                                mode = mode, method = NULL, engine = method)
  spec <- parsnip::set_engine(spec, method, base_workflow = workflow,
                             outcome = outcome, parameters = list(requested = requested, explicit = explicit))
  selection <- if (is.null(predictors)) quote(everything()) else predictors
  carrier <- rlang::inject(workflows::add_variables(
    workflows::workflow(), outcomes = .integration_select_outcome(!!outcome, !!classification, !!mode), predictors = !!selection,
    blueprint = hardhat::default_xy_blueprint(intercept = FALSE, allow_novel_levels = TRUE)))
  workflows::add_model(carrier, spec)
}

.integration_select_outcome <- function(outcome, classification, mode) {
  .integration_names(tidyselect::peek_vars(), "input column")
  data <- tidyselect::peek_data()
  if (outcome %in% names(data)) .integration_truth(data[[outcome]], outcome, classification, mode)
  outcome
}

.integration_dots <- function(...) {
  if (...length()) stop("`...` must be empty; unsupported argument: ",
                        paste(names(list(...)), collapse = ", "), ".", call. = FALSE)
}

.integration_names <- function(x, role) {
  if (!is.character(x) || !is.vector(x) || !length(x)) {
    stop("The ", role, " names must be a nonempty character vector.", call. = FALSE)
  }
  bad <- is.na(x) | !nzchar(x) | duplicated(x)
  if (any(bad)) stop("Invalid ", role, " name ", sQuote(x[which(bad)[1L]]),
                     ": names must be unique, nonmissing and nonempty; rename explicitly.", call. = FALSE)
}

.validate_base_workflow <- function(workflow, outcome, classification) {
  if (!inherits(workflow, "workflow")) stop("`workflow` must be an unfitted workflow.", call. = FALSE)
  fitted <- tryCatch(workflows::extract_fit_parsnip(workflow), error = function(e) NULL)
  if (!is.null(fitted)) stop("`workflow` is already fitted.", call. = FALSE)
  post <- tryCatch(workflows::extract_postprocessor(workflow), error = function(e) NULL)
  if (!is.null(post)) stop("Additional workflow postprocessors are not supported.", call. = FALSE)
  spec <- workflows::extract_spec_parsnip(workflow)
  if (!spec$mode %in% c("classification", "regression")) {
    stop("The base workflow model mode must be classification or regression.", call. = FALSE)
  }
  if (is.null(spec$engine)) stop("Configure the base workflow model engine before calibration.", call. = FALSE)
  pre <- workflows::extract_preprocessor(workflow)
  if (inherits(pre, "recipe")) {
    if (recipes::fully_trained(pre) || any(vapply(pre$steps, function(x) isTRUE(recipes::is_trained(x)), logical(1)))) {
      stop("The base workflow recipe is already prepped/trained.", call. = FALSE)
    }
    targets <- pre$var_info$variable[pre$var_info$role == "outcome"]
    if (!identical(targets, outcome)) stop("Base recipe outcome must be ", sQuote(outcome), ".", call. = FALSE)
    if (outcome %in% names(pre$template)) .integration_truth(pre$template[[outcome]], outcome, classification, spec$mode)
  } else if (inherits(pre, "formula")) {
    if (length(pre) != 3L || !identical(pre[[2L]], as.name(outcome))) {
      stop("Base formula outcome must be the raw column ", sQuote(outcome), ".", call. = FALSE)
    }
  }
  if (nrow(generics::tune_args(workflow))) stop("Resolve all tune() placeholders before calibration.", call. = FALSE)
  spec$mode
}

.integration_truth <- function(y, outcome, classification, mode) {
  if (mode == "regression") {
    .validate_regression_vector(y, paste0(outcome, " regression truth"))
    return(NULL)
  }
  .integration_class_levels(y, outcome, classification)
}

.integration_class_levels <- function(y, outcome, classification) {
  binary <- classification == "binary"
  if (!is.factor(y) || anyNA(y) || nlevels(y) < 2L || (binary && nlevels(y) != 2L)) {
    stop("Outcome ", sQuote(outcome), " must be a nonmissing factor with ",
         if (binary) "exactly two" else "at least two", " levels.", call. = FALSE)
  }
  classes <- levels(y)
  .integration_names(classes, "class")
  bad <- classes == "class" | startsWith(classes, ".pred_")
  if (any(bad)) stop("Class ", sQuote(classes[which(bad)[1L]]),
                     " is reserved for native predictions; rename it explicitly.", call. = FALSE)
  classes
}

# Public only as a parsnip engine entry point; use calibrated_workflow().
fit_vennabers <- function(x, y, base_workflow, outcome, parameters) {
  .integration_packages()
  settings <- parameters$requested
  regression <- settings$mode == "regression"
  multiclass <- !regression && settings$classification != "binary"
  .validate_base_workflow(base_workflow, outcome, settings$classification)
  .integration_names(names(x), "input column")
  if (is.data.frame(y) && ncol(y) == 1L) y <- y[[1L]]
  classes <- .integration_truth(y, outcome, settings$classification, settings$mode)
  if (!regression && any(tabulate(y, nbins = length(classes)) == 0L)) {
    stop("Outcome ", sQuote(outcome), " must contain all classes in the development data.", call. = FALSE)
  }
  raw <- as.data.frame(x)
  raw[[outcome]] <- y
  pre <- workflows::extract_preprocessor(base_workflow)
  if (inherits(pre, "workflow_variables") &&
      !identical(names(tidyselect::eval_select(pre$outcomes, raw)), outcome)) {
    stop("Base workflow outcome must be ", sQuote(outcome), ".", call. = FALSE)
  }
  effective <- settings
  if (multiclass) effective$event_level <- NULL
  if (regression) effective[c("classification", "event_level", "loss", "precision")] <- NULL
  effective$predictors <- names(x)
  effective$strata <- if (!regression && is.null(settings$strata)) outcome else FALSE
  if (settings$method == "cross") effective$calibration_prop <- NULL else effective$v <- NULL
  if (!is.null(settings$splits)) {
    effective$calibration_prop <- effective$v <- effective$strata <- NULL
  }
  parameters$effective <- effective
  event <- if (regression || multiclass) NULL else classes[if (settings$event_level == "first") 1L else 2L]
  # One local RNG scope includes the resolver, split generation and model learning.
  if (!is.null(settings$seed)) withr::local_seed(settings$seed)
  rng_kind <- RNGkind()
  if (settings$method == "cross" && is.null(settings$splits) && settings$v > nrow(raw)) {
    stop("`v` cannot exceed the number of local rows; the fold count is not reduced.", call. = FALSE)
  }
  split <- tryCatch(if (is.function(settings$splits)) {
    settings$splits(raw)
  } else if (!is.null(settings$splits)) {
    settings$splits
  } else if (settings$method == "cross") {
    if (identical(effective$strata, FALSE)) rsample::vfold_cv(raw, v = settings$v) else
      rlang::inject(rsample::vfold_cv(raw, v = settings$v, strata = !!outcome, pool = 0))
  } else if (identical(effective$strata, FALSE)) {
    rsample::initial_split(raw, prop = 1 - settings$calibration_prop)
  } else {
    rlang::inject(rsample::initial_split(raw, prop = 1 - settings$calibration_prop,
                                       strata = !!outcome, pool = 0))
  }, error = function(e) stop(settings$method, " rsample split failed (nonempty training and calibration required): ",
                              conditionMessage(e), call. = FALSE))
  folds <- if (settings$method == "cross") .cross_splits(split, raw) else
    list(Inductive1 = .inductive_split(split, raw))
  if (multiclass && settings$method == "inductive") {
    held <- folds$Inductive1$assessment
    absent <- classes[tabulate(y[held], nbins = length(classes)) == 0L]
    if (length(absent)) stop("Inductive1 calibration must contain every stored class; missing: ",
                             paste(sQuote(absent), collapse = ", "), ".", call. = FALSE)
  }
  if (multiclass && settings$method == "cross" && settings$classification == "ovo") {
    for (pair in utils::combn(classes, 2L, simplify = FALSE)) for (id in names(folds)) {
      if (!any(y[folds[[id]]$assessment] %in% pair)) {
        stop("Empty calibration for pair [", paste(pair, collapse = ", "),
             "] in fold [", id, "].", call. = FALSE)
      }
    }
  }
  moderation <- list()
  if (regression) {
    if (!is.null(settings$m)) moderation$m <- settings$m
    if (!is.null(settings$epsilon)) moderation$epsilon <- settings$epsilon
    # Validate every fold before the first recipe/model fit, using the core domain.
    for (id in names(folds)) {
      k <- length(folds[[id]]$assessment)
      folds[[id]]$moderation <- tryCatch(
        do.call(.regression_moderation, c(list(k = k), moderation)),
        error = function(e) stop(id, " calibration size ", k, ": ", conditionMessage(e), call. = FALSE))
    }
    parameters$effective$m <- vapply(folds, function(f) f$moderation$m, 0)
    parameters$effective$epsilon <- vapply(folds, function(f) f$moderation$epsilon, 0)
  }
  models <- calibration_predictions <- truths <- fold_ids <- vector("list", length(folds))
  names(models) <- names(folds)
  for (id in names(folds)) {
    analysis <- folds[[id]]$analysis
    assessment <- folds[[id]]$assessment
    models[[id]] <- tryCatch(generics::fit(base_workflow, raw[analysis, , drop = FALSE]),
      error = function(e) stop(id, " base workflow training: ", conditionMessage(e), call. = FALSE))
    k <- match(id, names(folds))
    calibration_predictions[[k]] <- if (regression) .base_numeric(models[[id]], raw[assessment, , drop = FALSE], id) else
      .base_probability(models[[id]], raw[assessment, , drop = FALSE], classes, event, id)
    truths[[k]] <- if (regression || multiclass) y[assessment] else y[assessment] == event
    fold_ids[[k]] <- rep(id, length(assessment))
    folds[[id]]$training_size <- length(analysis)
    folds[[id]]$calibration_size <- length(assessment)
  }
  calibrator <- if (regression) {
    if (settings$method == "cross") {
      do.call(cross_venn_abers_regression,
              c(list(truth = unlist(truths), prediction = unlist(calibration_predictions), fold = unlist(fold_ids)), moderation))
    } else do.call(venn_abers_regression,
                   c(list(truth = truths[[1L]], prediction = calibration_predictions[[1L]]), moderation))
  } else if (multiclass) {
    if (settings$method == "cross") {
      cross_venn_abers(do.call(c, truths), do.call(rbind, calibration_predictions), unlist(fold_ids),
                       precision = settings$precision, method = settings$classification)
    } else venn_abers(truths[[1L]], calibration_predictions[[1L]], precision = settings$precision,
                      method = settings$classification)
  } else if (settings$method == "cross") {
    core <- cross_venn_abers(unlist(truths), unlist(calibration_predictions), unlist(fold_ids), precision = settings$precision)
    names(core$calibrators) <- core$folds
    core
  } else venn_abers(truths[[1L]], calibration_predictions[[1L]], precision = settings$precision)
  structure(list(parameters = parameters, outcome = outcome,
                 predictors = names(x), columns = names(raw), class_levels = classes,
                 event_class = event, loss = effective$loss,
                 folds = folds, models = models, calibrator = calibrator,
                 versions = c(R = as.character(getRversion()),
                              vapply(c("vennabers", names(.integration_versions)),
                                     function(p) as.character(utils::packageVersion(p)), "")),
                 rng_kind = rng_kind), class = "vennabers_fit")
}

.base_probability <- function(model, data, classes, event, id = "Inductive1") {
  p <- tryCatch(stats::predict(model, data, type = "prob"),
                error = function(e) stop(id, " base workflow probability prediction: ", conditionMessage(e), call. = FALSE))
  .integration_names(names(p), paste(id, "base probability column"))
  expected <- paste0(".pred_", classes)
  if (!setequal(names(p), expected) || nrow(p) != nrow(data) ||
      !all(vapply(p, .valid_probability, logical(1))) ||
      any(abs(rowSums(p) - 1) > 1e-8)) {
    stop(id, " base workflow must return finite probabilities for original classes ",
         paste(sQuote(classes), collapse = ", "), " in columns ",
         paste(sQuote(expected), collapse = ", "), ".", call. = FALSE)
  }
  if (!is.null(event)) return(as.double(p[[paste0(".pred_", event)]]))
  p <- as.matrix(p[expected])
  colnames(p) <- classes
  # The matrix core normalizes once; repeating it can perturb tied scores.
  p
}

.base_numeric <- function(model, data, id) {
  p <- tryCatch(stats::predict(model, data, type = "numeric"),
                error = function(e) stop(id, " base workflow numeric prediction: ", conditionMessage(e), call. = FALSE))
  if (!is.data.frame(p) || !identical(names(p), ".pred") || nrow(p) != nrow(data)) {
    stop(id, " base workflow must return one .pred column with one value per row.", call. = FALSE)
  }
  .validate_regression_vector(p$.pred, paste(id, "base regression prediction"))
  as.double(p$.pred)
}

.integration_prediction <- function(object, new_data) {
  if (object$parameters$requested$mode == "regression") {
    return(.integration_regression_prediction(object, new_data))
  }
  multiclass <- object$parameters$requested$classification != "binary"
  cross <- object$parameters$requested$method == "cross"
  p <- lapply(names(object$models), function(id) {
    if (nrow(new_data)) .base_probability(object$models[[id]], new_data, object$class_levels, object$event_class, id)
    else if (multiclass) matrix(numeric(), 0L, length(object$class_levels), dimnames = list(NULL, object$class_levels))
    else numeric()
  })
  names(p) <- names(object$models)
  if (multiclass) {
    result <- stats::predict(object$calibrator, if (cross) p else p[[1L]], loss = object$loss, type = "details")
    method <- object$parameters$requested$classification
    details <- if (method == "ovo") result$pairs else result$classes
    names(details)[names(details) == "non_event"] <- "class_1"
    names(details)[names(details) == "event"] <- if (method == "ovo") "class_2" else "class"
    if (!cross) details$fold <- rep("Inductive1", nrow(details))
    details$method <- rep(method, nrow(details))
    details$event_class <- if (method == "ovo") details$class_2 else details$class
    identity <- if (method == "ovo") c("class_1", "class_2") else "class"
    colnames(result$prediction) <- paste0(".pred_", object$class_levels)
    return(list(prediction = tibble::as_tibble(result$prediction, .name_repair = "minimal"),
                details = tibble::as_tibble(details[c("row", "fold", "method", "event_class", identity,
                                                    "lower", "upper", "probability")])))
  }
  if (cross) {
    p <- do.call(cbind, p)
    colnames(p) <- names(object$models)
    result <- stats::predict(object$calibrator, p, loss = object$loss, type = "details")
    probability <- result$prediction$probability
    details <- result$folds
  } else {
    bounds <- stats::predict(object$calibrator, p[[1L]], loss = object$loss)
    probability <- bounds$probability
    details <- data.frame(row = seq_len(nrow(new_data)), fold = rep("Inductive1", nrow(new_data)), bounds)
  }
  details$event_class <- rep(object$event_class, nrow(details))
  probabilities <- lapply(object$class_levels, function(cl) {
    if (cl == object$event_class) probability else 1 - probability
  })
  names(probabilities) <- paste0(".pred_", object$class_levels)
  list(prediction = tibble::as_tibble(probabilities, .name_repair = "minimal"),
       details = tibble::as_tibble(details[c("row", "fold", "event_class", "lower", "upper", "probability")]))
}

.integration_regression_prediction <- function(object, new_data) {
  cross <- object$parameters$requested$method == "cross"
  p <- lapply(names(object$models), function(id) {
    if (nrow(new_data)) .base_numeric(object$models[[id]], new_data, id) else numeric()
  })
  names(p) <- names(object$models)
  if (cross) {
    result <- stats::predict(object$calibrator, do.call(cbind, p), type = "details")
    points <- result$prediction
    folds <- result$folds
  } else {
    points <- stats::predict(object$calibrator, p[[1L]])
    folds <- list(Inductive1 = points)
  }
  details <- do.call(rbind, lapply(names(folds), function(id) {
    data.frame(row = seq_len(nrow(new_data)), fold = rep(id, nrow(new_data)), folds[[id]])
  }))
  result <- list(prediction = tibble::tibble(.pred = as.double(points$prediction)),
                 details = tibble::as_tibble(details))
  if (cross) result$aggregate <- tibble::tibble(row = seq_len(nrow(new_data)),
                                               lower = points$lower, upper = points$upper)
  result
}

predict_vennabers_numeric <- function(object, new_data) {
  .integration_prediction(object, new_data)$prediction$.pred
}

predict_vennabers_prob <- function(object, new_data) {
  .integration_prediction(object, new_data)$prediction
}

predict_vennabers_class <- function(object, new_data) {
  probabilities <- .integration_prediction(object, new_data)$prediction
  if (object$parameters$requested$classification != "binary") {
    return(factor(object$class_levels[max.col(as.matrix(probabilities), ties.method = "first")],
                  levels = object$class_levels))
  }
  p <- probabilities[[paste0(".pred_", object$event_class)]]
  factor(ifelse(p >= .5, object$event_class,
                object$class_levels[object$class_levels != object$event_class]), levels = object$class_levels)
}

predict._vennabers_fit <- function(object, new_data, type = NULL, opts = list(), ..., loss = NULL) {
  .integration_dots(...)
  if (!missing(loss)) {
    if (object$fit$parameters$requested$mode == "regression") {
      stop("Regression does not accept `loss`.", call. = FALSE)
    }
    .validate_choice(loss, c("log", "brier"), "loss")
    object$fit$loss <- loss
  }
  if (!is.null(type)) .validate_choice(type,
    if (object$fit$parameters$requested$mode == "regression") "numeric" else c("prob", "class"), "type")
  parsnip::predict.model_fit(object, new_data, type = type, opts = opts)
}

venn_abers_details <- function(object, new_data, ..., loss = NULL) {
  .integration_dots(...)
  .integration_packages()
  state <- workflows::extract_fit_engine(object)
  if (!inherits(state, "vennabers_fit")) stop("`object` must be a fitted calibrated_workflow().", call. = FALSE)
  if (!missing(loss)) {
    if (state$parameters$requested$mode == "regression") {
      stop("Regression does not accept `loss`.", call. = FALSE)
    }
    .validate_choice(loss, c("log", "brier"), "loss")
    state$loss <- loss
  }
  forged <- hardhat::forge(new_data, blueprint = workflows::extract_mold(object)$blueprint)
  .integration_prediction(state, forged$predictors)
}
