# The outer workflow only carries raw variables. Learning belongs to the base
# workflow after the local split, including any recipe preparation.
#' @export
calibrated_workflow <- function(workflow, outcome, ..., predictors = NULL,
                                method = "inductive", classification = "binary",
                                event_level = "first", calibration_prop = 0.2, v = 5L,
                                strata = NULL, splits = NULL, seed = NULL, precision = NULL,
                                loss = "log", m = NULL, epsilon = NULL, schema = NULL,
                                prediction_model = "matched", model_training = "shared") {
  .integration_dots(...)
  # Arguments before ... also need exact names (R otherwise partially matches).
  supplied <- names(sys.call())[-1L]
  bad <- supplied[nzchar(supplied) & !supplied %in% names(formals(calibrated_workflow))]
  if (length(bad)) stop("Unknown argument: ", sQuote(bad[1L]), ".", call. = FALSE)
  explicit_classification <- !missing(classification)
  explicit_event <- !missing(event_level)
  if (!is.null(schema)) {
    .validate_schema(schema)
    if (!identical(outcome, schema$encoded_outcome) ||
        explicit_classification && !identical(classification, schema$classification) ||
        explicit_event && !identical(event_level, schema$event_level)) {
      stop("Outcome, classification and event_level must agree with `schema`.", call. = FALSE)
    }
    if (schema$mode == "classification") classification <- schema$classification
    if (identical(schema$classification, "binary")) event_level <- schema$event_level
    if (!is.null(predictors) && !setequal(predictors, setdiff(schema$columns, outcome))) {
      stop("Selected predictors must agree with `schema`.", call. = FALSE)
    }
  }
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
  .validate_choice(prediction_model, c("matched", "full"), "prediction_model")
  .validate_choice(model_training, c("shared", "pairwise"), "model_training")
  pairwise <- model_training == "pairwise"
  if (pairwise && classification != "ovo") {
    stop("`model_training = 'pairwise'` requires classification = 'ovo'.", call. = FALSE)
  }
  .integration_packages()
  mode <- .validate_base_workflow(workflow, outcome, classification)
  if (!is.null(schema)) {
    if (!identical(mode, schema$mode)) stop("Base workflow mode must agree with `schema`.", call. = FALSE)
    pre <- workflows::extract_preprocessor(workflow)
    if (inherits(pre, "recipe") && !is.null(pre$template)) .schema_encoded_data(pre$template, schema, truth = TRUE)
  }
  regression <- mode == "regression"
  if ((regression || classification == "binary") && !missing(model_training)) {
    stop("`model_training` requires classification = 'ovo' or 'ovr'.", call. = FALSE)
  }
  if (regression && (explicit_classification || explicit_event ||
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
  if (classification != "binary" && explicit_event) {
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
    if (pairwise && !is.function(splits) &&
        (!is.list(splits) || inherits(splits, c("rsplit", "rset", "data.frame")))) {
      stop("Pairwise `splits` must be a function of local pair data or a named list of pair plans.", call. = FALSE)
    }
    if (!pairwise && !inherits(splits, if (method == "cross") "rset" else "rsplit") && !is.function(splits)) {
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
                    m = m, epsilon = epsilon, prediction_model = prediction_model,
                    model_training = if (!regression && classification != "binary") model_training else NULL)
  explicit <- c(predictors = !missing(predictors), method = !missing(method),
                classification = explicit_classification, event_level = explicit_event,
                calibration_prop = !missing(calibration_prop), v = !missing(v), strata = !missing(strata),
                splits = !missing(splits), seed = !missing(seed), precision = !missing(precision), loss = !missing(loss),
                m = !missing(m), epsilon = !missing(epsilon), prediction_model = !missing(prediction_model),
                model_training = !missing(model_training))
  spec <- parsnip::new_model_spec("vennabers", args = list(), eng_args = NULL,
                                mode = mode, method = NULL, engine = method)
  spec <- parsnip::set_engine(spec, method, base_workflow = workflow,
                             outcome = outcome, parameters = list(requested = requested, explicit = explicit, schema = schema))
  selection <- if (!is.null(predictors)) predictors else if (!is.null(schema)) setdiff(unname(schema$columns), outcome) else quote(everything())
  carrier <- rlang::inject(workflows::add_variables(
    workflows::workflow(), outcomes = .integration_select_outcome(!!outcome, !!classification, !!mode, !!schema), predictors = !!selection,
    blueprint = hardhat::default_xy_blueprint(intercept = FALSE, allow_novel_levels = TRUE)))
  carrier <- workflows::add_model(carrier, spec)
  # Check schema bindings before workflows::predict() discards input attributes.
  if (!is.null(schema)) class(carrier) <- c("vennabers_workflow", class(carrier))
  carrier
}

#' @export
predict.vennabers_workflow <- function(object, new_data, ...) {
  .schema_encoded_data(new_data, workflows::extract_fit_engine(object)$schema)
  NextMethod()
}

.integration_select_outcome <- function(outcome, classification, mode, schema = NULL) {
  .integration_names(tidyselect::peek_vars(), "input column")
  data <- tidyselect::peek_data()
  if (!is.null(schema)) .schema_encoded_data(data, schema, truth = TRUE)
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
#' @export
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
  if (!is.null(parameters$schema)) {
    .schema_encoded_data(raw, parameters$schema, truth = TRUE)
    raw <- .bind_schema(raw, parameters$schema)
  }
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
  state <- structure(list(parameters = parameters, schema = parameters$schema, outcome = outcome,
    predictors = names(x), columns = names(raw), class_levels = classes,
    event_class = event, loss = effective$loss,
    versions = c(R = as.character(getRversion()),
      vapply(unique(c("vennabers", names(.integration_versions), generics::required_pkgs(base_workflow))),
        function(p) as.character(utils::packageVersion(p)), "")),
    rng_kind = rng_kind), class = "vennabers_fit")
  if (identical(settings$model_training, "pairwise")) {
    return(.fit_pairwise(base_workflow, raw, state))
  }
  cross <- settings$method == "cross"
  moderation <- list()
  if (regression) {
    if (!is.null(settings$m)) moderation$m <- settings$m
    if (!is.null(settings$epsilon)) moderation$epsilon <- settings$epsilon
  }
  domain <- list(data = raw, workflow = base_workflow, plan = settings$splits,
    outcome = outcome, strata = effective$strata, classes = classes, event = event, y = y,
    rows_word = "local rows", seed_wrap = FALSE,
    precheck = if (cross && is.null(settings$splits)) function(local) {
      if (settings$v > nrow(local)) {
        stop("`v` cannot exceed the number of local rows; the fold count is not reduced.", call. = FALSE)
      }
    } else NULL,
    resolve_error = function(e) stop(settings$method,
      " rsample split failed (nonempty training and calibration required): ",
      conditionMessage(e), call. = FALSE),
    folds_error = NULL,
    post = function(folds, local) {
      if (multiclass) {
        held <- lapply(folds, `[[`, "assessment")
        fold <- if (cross) rep(names(folds), lengths(held)) else NULL
        .multiclass_eligibility(y[unlist(held, use.names = FALSE)], settings$classification, fold)
      }
      if (regression) {
        # Validate every fold before the first recipe/model fit, using the core domain.
        for (id in names(folds)) {
          k <- length(folds[[id]]$assessment)
          folds[[id]]$moderation <- tryCatch(
            do.call(.regression_moderation, c(list(k = k), moderation)),
            error = function(e) stop(id, " calibration size ", k, ": ", conditionMessage(e), call. = FALSE))
        }
      }
      folds
    },
    fit_error = function(fold, e) stop(fold, " base workflow training: ", conditionMessage(e), call. = FALSE),
    full_error = function(e) stop("Full1 base workflow training: ", conditionMessage(e), call. = FALSE),
    pred_id = function(fold) fold,
    fields = function() list())
  task <- .component_task(if (regression) "regression" else if (multiclass) "multiclass" else "binary",
                          settings, moderation)
  result <- .fit_domains(list(domain), task, settings)
  if (regression) {
    parameters$effective$m <- vapply(result$plans[[1L]], function(f) f$moderation$m, 0)
    parameters$effective$epsilon <- vapply(result$plans[[1L]], function(f) f$moderation$epsilon, 0)
  }
  component <- result$fitted[[1L]]
  state$parameters <- parameters
  state$folds <- component$folds
  state$models <- component$models
  state$sources <- component$sources
  state$calibrator <- component$calibrator
  state$calibration <- component$calibration
  state
}

# Every fit is a list of components: one shared component, or one per class
# pair with its recipe-retargeted workflow. Three phase functions, each applied
# in turn, give one path for all task and model-training combinations. Domains
# carry their own error decoration so the phases stay branch-free; fail-fast
# ordering and RNG scoping match the former per-path implementations.
.fit_domains <- function(domains, task, settings) {
  plans <- lapply(domains, function(domain) .plan_component(domain, settings))
  fitted <- lapply(seq_along(domains), function(i) .fit_component_sources(plans[[i]], domains[[i]], task, settings))
  if (identical(settings$prediction_model, "full")) {
    fitted <- lapply(seq_along(domains), function(i) .fit_component_full(fitted[[i]], domains[[i]], task, settings))
  }
  list(plans = plans, fitted = fitted)
}

.resolve_split <- function(domain, settings, local, cross) {
  plan <- domain$plan
  if (is.function(plan)) return(plan(local))
  if (!is.null(plan)) return(plan)
  outcome <- domain$outcome
  if (cross) {
    if (settings$v > nrow(local)) {
      stop("`v` cannot exceed the number of ", domain$rows_word,
           "; the fold count is not reduced.", call. = FALSE)
    }
    if (identical(domain$strata, FALSE)) rsample::vfold_cv(local, v = settings$v) else
      rlang::inject(rsample::vfold_cv(local, v = settings$v, strata = !!outcome, pool = 0))
  } else if (identical(domain$strata, FALSE)) {
    rsample::initial_split(local, prop = 1 - settings$calibration_prop)
  } else {
    rlang::inject(rsample::initial_split(local, prop = 1 - settings$calibration_prop,
                                         strata = !!outcome, pool = 0))
  }
}

.plan_component <- function(domain, settings) {
  local <- domain$data
  cross <- settings$method == "cross"
  if (!is.null(domain$precheck)) domain$precheck(local)
  resolve <- function() {
    # A fixed local seed makes pair plans independent of preceding model draws.
    if (!is.null(settings$seed) && isTRUE(domain$seed_wrap)) {
      withr::with_seed(settings$seed, .resolve_split(domain, settings, local, cross))
    } else .resolve_split(domain, settings, local, cross)
  }
  split <- if (is.null(domain$resolve_error)) resolve() else tryCatch(resolve(), error = domain$resolve_error)
  validate <- function() {
    folds <- if (cross) .cross_splits(split, local) else list(Inductive1 = .inductive_split(split, local))
    for (fold_id in names(folds)) {
      folds[[fold_id]]$training_size <- length(folds[[fold_id]]$analysis)
      folds[[fold_id]]$calibration_size <- length(folds[[fold_id]]$assessment)
    }
    domain$post(folds, local)
  }
  if (is.null(domain$folds_error)) validate() else
    tryCatch(validate(), error = function(e) domain$folds_error(e, if (cross) "Cross" else "Inductive1"))
}

.fit_component_sources <- function(folds, domain, task, settings) {
  local <- domain$data
  workflow <- domain$workflow
  classes <- domain$classes
  event <- domain$event
  y <- domain$y
  models <- calibration_predictions <- truths <- fold_ids <- vector("list", length(folds))
  names(models) <- names(folds)
  for (id in names(folds)) {
    analysis <- folds[[id]]$analysis
    assessment <- folds[[id]]$assessment
    models[[id]] <- tryCatch(generics::fit(workflow, local[analysis, , drop = FALSE]),
      error = function(e) domain$fit_error(id, e))
    k <- match(id, names(folds))
    calibration_predictions[[k]] <- task$pred(models[[id]], local[assessment, , drop = FALSE], domain$pred_id(id), classes, event)
    truths[[k]] <- task$truth(y, assessment, classes, event)
    fold_ids[[k]] <- rep(id, length(assessment))
  }
  calibrator <- task$calibrate(truths, calibration_predictions, fold_ids, folds, settings)
  calibration <- stats::setNames(lapply(seq_along(folds), function(k) {
    task$record(folds[[k]]$assessment, truths[[k]], calibration_predictions[[k]])
  }), names(folds))
  # `sources` maps every fold slot to the model that predicts it: itself when
  # matched, the shared Full1 refit when full.
  c(domain$fields(), list(folds = folds, models = models,
    sources = stats::setNames(names(folds), names(folds)),
    calibrator = calibrator, calibration = calibration))
}

.fit_component_full <- function(component, domain, task, settings) {
  local <- domain$data
  model <- tryCatch(generics::fit(domain$workflow, local), error = domain$full_error)
  # Check the prediction contract without using full-model values for calibration.
  task$pred(model, local[1L, , drop = FALSE], domain$pred_id("Full1"), domain$classes, domain$event)
  # Discard temporary source workflows only after the complete fit succeeds.
  component$models <- list(Full1 = model)
  component$sources[] <- "Full1"
  component
}

# The binary/multiclass/regression variation in one place: held-out truth and
# prediction transforms, calibrator construction and calibration record shape.
.component_task <- function(kind, settings, moderation) {
  regression <- kind == "regression"
  multiclass <- kind == "multiclass"
  list(kind = kind,
    pred = function(model, data, id, classes, event) {
      if (regression) .base_numeric(model, data, id) else
        .base_probability(model, data, classes, event, id)
    },
    truth = function(y, assessment, classes, event) {
      if (regression || multiclass) y[assessment] else y[assessment] == event
    },
    calibrate = function(truths, predictions, fold_ids, folds, settings) {
      if (regression) {
        if (settings$method == "cross") {
          do.call(cross_venn_abers_regression,
            c(list(truth = unlist(truths), prediction = unlist(predictions), fold = unlist(fold_ids)), moderation))
        } else do.call(venn_abers_regression,
          c(list(truth = truths[[1L]], prediction = predictions[[1L]]), moderation))
      } else if (multiclass) {
        if (settings$method == "cross") {
          cross_venn_abers(do.call(c, truths), do.call(rbind, predictions), unlist(fold_ids),
            precision = settings$precision, method = settings$classification)
        } else venn_abers(truths[[1L]], predictions[[1L]], precision = settings$precision,
          method = settings$classification)
      } else if (settings$method == "cross") {
        core <- cross_venn_abers(unlist(truths), unlist(predictions), unlist(fold_ids), precision = settings$precision)
        names(core$calibrators) <- core$folds
        core
      } else venn_abers(truths[[1L]], predictions[[1L]], precision = settings$precision)
    },
    record = function(rows, truth, prediction) {
      if (regression) data.frame(row = rows, truth = truth, prediction = prediction) else
      if (multiclass) list(row = rows, truth = truth, probability = prediction) else
        data.frame(row = rows, truth = truth, probability = prediction)
    })
}

# `sources` maps every fold slot to the model it predicts with, so full-model
# reuse is just a repeated lookup instead of a `full` branch.
.source_predictions <- function(models, sources, new_data, predict_one, empty_one) {
  by_model <- lapply(names(models), function(id) {
    if (nrow(new_data)) predict_one(models[[id]], id) else empty_one()
  })
  names(by_model) <- names(models)
  stats::setNames(by_model[sources], names(sources))
}

.calibrate_binary_points <- function(calibrator, p, cross, loss, n, include_details) {
  if (cross) {
    result <- stats::predict(calibrator, do.call(cbind, p), loss = loss,
      type = if (include_details) "details" else "response")
    probability <- if (include_details) result$prediction$probability else result$probability
    details <- if (include_details) result$folds
  } else {
    bounds <- stats::predict(calibrator, p[[1L]], loss = loss)
    probability <- bounds$probability
    if (include_details) details <- data.frame(row = seq_len(n), fold = rep("Inductive1", n), bounds)
  }
  list(probability = probability, details = if (include_details) details)
}

.base_probability <- function(model, data, classes, event, id = "Inductive1") {
  p <- tryCatch(stats::predict(model, data, type = "prob"),
                error = function(e) stop(id, " base workflow probability prediction for original classes ",
                  paste(sQuote(classes), collapse = ", "), " and input columns ",
                  paste(sQuote(names(data)), collapse = ", "), ": ", conditionMessage(e), call. = FALSE))
  .integration_names(names(p), paste(id, "base probability column"))
  expected <- paste0(".pred_", classes)
  if (is.data.frame(p) && nrow(p) != nrow(data)) {
    stop(id, " base workflow probability prediction returned ", nrow(p),
         " rows for ", nrow(data), " input rows.", call. = FALSE)
  }
  if (!is.data.frame(p) || !setequal(names(p), expected) ||
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

.integration_prediction <- function(object, new_data, include_details = FALSE) {
  if (identical(object$parameters$requested$model_training, "pairwise")) {
    return(.predict_pairwise(object, new_data, include_details))
  }
  if (object$parameters$requested$mode == "regression") {
    return(.integration_regression_prediction(object, new_data, include_details))
  }
  multiclass <- object$parameters$requested$classification != "binary"
  cross <- object$parameters$requested$method == "cross"
  p <- .source_predictions(object$models, object$sources, new_data,
    function(model, id) .base_probability(model, new_data, object$class_levels, object$event_class, id),
    function() if (multiclass) matrix(numeric(), 0L, length(object$class_levels),
      dimnames = list(NULL, object$class_levels)) else numeric())
  if (multiclass) {
    result <- stats::predict(object$calibrator, if (cross) p else p[[1L]], loss = object$loss,
                             type = if (include_details) "details" else "response")
    prediction <- if (include_details) result$prediction else result
    colnames(prediction) <- paste0(".pred_", object$class_levels)
    prediction <- tibble::as_tibble(prediction, .name_repair = "minimal")
    if (!include_details) return(list(prediction = prediction))
    method <- object$parameters$requested$classification
    details <- if (method == "ovo") result$pairs else result$classes
    names(details)[names(details) == "non_event"] <- "class_1"
    names(details)[names(details) == "event"] <- if (method == "ovo") "class_2" else "class"
    if (!cross) details$fold <- rep("Inductive1", nrow(details))
    details$method <- rep(method, nrow(details))
    details$event_class <- if (method == "ovo") details$class_2 else details$class
    extra <- character(0)
    if (!is.null(object$parameters$requested$model_training)) {
      details$model_training <- rep(object$parameters$requested$model_training, nrow(details))
      extra <- c(extra, "model_training")
    }
    if (!is.null(object$parameters$requested$prediction_model)) {
      details$prediction_model <- rep(object$parameters$requested$prediction_model, nrow(details))
      details$model_source <- unname(object$sources[details$fold])
      extra <- c(extra, "prediction_model", "model_source")
    }
    identity <- if (method == "ovo") c("class_1", "class_2") else "class"
    return(list(prediction = prediction,
                details = tibble::as_tibble(details[c("row", "fold", "method", "event_class", identity,
                                                    "lower", "upper", "probability", extra)])))
  }
  binary <- .calibrate_binary_points(object$calibrator, p, cross, object$loss, nrow(new_data), include_details)
  probability <- binary$probability
  if (include_details) details <- binary$details
  probabilities <- lapply(object$class_levels, function(cl) {
    if (cl == object$event_class) probability else 1 - probability
  })
  names(probabilities) <- paste0(".pred_", object$class_levels)
  prediction <- tibble::as_tibble(probabilities, .name_repair = "minimal")
  if (!include_details) return(list(prediction = prediction))
  details$event_class <- rep(object$event_class, nrow(details))
  extra <- character(0)
  if (!is.null(object$parameters$requested$prediction_model)) {
    details$prediction_model <- rep(object$parameters$requested$prediction_model, nrow(details))
    details$model_source <- unname(object$sources[details$fold])
    extra <- c("prediction_model", "model_source")
  }
  list(prediction = prediction,
       details = tibble::as_tibble(details[c("row", "fold", "event_class", "lower", "upper", "probability", extra)]))
}

#' @export
print.vennabers_fit <- function(x, ...) {
  settings <- x$parameters$requested
  cat("Venn-Abers", settings$method, "calibrated predictor\n")
  if (!is.null(settings$model_training)) cat("Model training:", settings$model_training, "\n")
  if (!is.null(settings$prediction_model)) {
    cat("Prediction model:", settings$prediction_model,
        if (settings$prediction_model == "full") "(full-model transfer)" else "", "\n")
  }
  components <- if (identical(settings$model_training, "pairwise")) x$pair_models else list(x)
  source_fits <- sum(vapply(components, function(part) length(part$folds), 1L))
  retained <- sum(vapply(components, function(part) length(part$models), 1L))
  calibration_rows <- sum(vapply(components, function(part) {
    sum(vapply(part$calibration, function(values) length(values$row), 1L))
  }, 0))
  cat("Base fits:", source_fits + if (identical(settings$prediction_model, "full")) length(components) else 0L, "\n")
  cat("Models per nonempty prediction:", retained, "\n")
  cat("Stored calibration rows:", calibration_rows, "(held-out truth and model predictions)\n")
  if (identical(settings$model_training, "pairwise")) {
    for (id in names(x$pair_models)) {
      component <- x$pair_models[[id]]
      for (fold in names(component$sources)) cat(" ", id, fold, "->", id, component$sources[[fold]], "\n")
    }
  }
  for (id in names(x$sources)) cat(" ", id, "->", x$sources[[id]], "\n")
  invisible(x)
}

.integration_regression_prediction <- function(object, new_data, include_details = FALSE) {
  cross <- object$parameters$requested$method == "cross"
  mode <- object$parameters$requested$prediction_model
  p <- .source_predictions(object$models, object$sources, new_data,
    function(model, id) .base_numeric(model, new_data, id), numeric)
  if (cross) {
    result <- stats::predict(object$calibrator, do.call(cbind, p),
                             type = if (include_details) "details" else "response")
    points <- if (include_details) result$prediction else result
    if (include_details) folds <- result$folds
  } else {
    points <- stats::predict(object$calibrator, p[[1L]])
    if (include_details) folds <- list(Inductive1 = points)
  }
  prediction <- tibble::tibble(.pred = as.double(points$prediction))
  if (!include_details) return(list(prediction = prediction))
  details <- do.call(rbind, lapply(names(folds), function(id) {
    data.frame(row = seq_len(nrow(new_data)), fold = rep(id, nrow(new_data)), folds[[id]])
  }))
  if (!is.null(mode)) {
    details$prediction_model <- rep(mode, nrow(details))
    details$model_source <- unname(object$sources[details$fold])
  }
  result <- list(prediction = prediction,
                 details = tibble::as_tibble(details))
  if (cross) {
    result$aggregate <- tibble::tibble(row = seq_len(nrow(new_data)), lower = points$lower, upper = points$upper)
    if (!is.null(mode)) {
      result$aggregate$prediction_model <- rep(mode, nrow(new_data))
      result$aggregate$model_source <- rep(list(names(object$models)), nrow(new_data))
    }
  }
  result
}

#' @export
predict_vennabers_numeric <- function(object, new_data) {
  .integration_prediction(object, new_data)$prediction$.pred
}

#' @export
predict_vennabers_prob <- function(object, new_data) {
  .integration_prediction(object, new_data)$prediction
}

#' @export
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

#' @export
predict._vennabers_fit <- function(object, new_data, type = NULL, opts = list(), ..., loss = NULL) {
  .integration_dots(...)
  if (!is.null(object$fit$schema)) .schema_encoded_data(new_data, object$fit$schema)
  if (!missing(loss)) {
    if (object$fit$parameters$requested$mode == "regression") {
      stop("Regression does not accept `loss`.", call. = FALSE)
    }
    .validate_choice(loss, c("log", "brier"), "loss")
    object$fit$loss <- loss
  }
  if (!is.null(type)) .validate_choice(type,
    if (object$fit$parameters$requested$mode == "regression") "numeric" else c("prob", "class"), "type")
  .bind_schema(parsnip::predict.model_fit(object, new_data, type = type, opts = opts), object$fit$schema)
}

#' @export
venn_abers_details <- function(object, new_data, ..., loss = NULL) {
  .integration_dots(...)
  .integration_packages()
  frozen <- inherits(object, "vennabers_frozen")
  state <- if (frozen) object else workflows::extract_fit_engine(object)
  if (!inherits(state, "vennabers_fit")) {
    stop("`object` must be a fitted calibrated_workflow() or calibrate_workflow().", call. = FALSE)
  }
  if (!frozen && !is.null(state$schema)) .schema_encoded_data(new_data, state$schema)
  if (!missing(loss)) {
    if (state$parameters$requested$mode == "regression") {
      stop("Regression does not accept `loss`.", call. = FALSE)
    }
    .validate_choice(loss, c("log", "brier"), "loss")
    state$loss <- loss
  }
  predictors <- if (frozen) .frozen_data(state, new_data) else
    hardhat::forge(new_data, blueprint = workflows::extract_mold(object)$blueprint)$predictors
  result <- .integration_prediction(state, predictors, include_details = TRUE)
  result$prediction <- .bind_schema(result$prediction, state$schema)
  .bind_schema(result, state$schema)
}
