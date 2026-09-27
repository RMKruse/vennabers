.validate_postprocessing <- function(post) {
  if (is.null(post)) return(NULL)
  .tuning_names(post, c("method", "strategy", "prop", "v", "splits", "sigmoid_input"), "postprocessing")
  .validate_choice(post$method, c("tailor_logistic", "tailor_multinomial", "tailor_linear", "sigmoid", "isotonic_numeric"), "postprocessing$method")
  .validate_choice(post$strategy, c("holdout", "ensemble"), "postprocessing$strategy")
  if (post$method == "sigmoid") {
    .validate_choice(post$sigmoid_input, c("probability", "glm_link"), "postprocessing$sigmoid_input")
  } else if ("sigmoid_input" %in% names(post)) {
    stop("`postprocessing$sigmoid_input` requires sigmoid.", call. = FALSE)
  }
  if ("splits" %in% names(post)) {
    if (any(c("prop", "v") %in% names(post))) stop("Postprocessing splits cannot be combined with prop/v.", call. = FALSE)
    if (!is.function(post$splits) && !inherits(post$splits, if (post$strategy == "holdout") "rsplit" else "rset")) {
      stop("`postprocessing$splits` must supply a local plan or function(data).", call. = FALSE)
    }
  } else if (post$strategy == "holdout") {
    if ("v" %in% names(post)) stop("Postprocessing holdout does not accept v.", call. = FALSE)
    p <- post$prop
    if (!is.numeric(p) || !is.vector(p) || length(p) != 1L || !is.finite(p) || p <= 0 || p >= 1) {
      stop("`postprocessing$prop` must be one finite numeric P proportion strictly between 0 and 1.", call. = FALSE)
    }
  } else {
    if ("prop" %in% names(post)) stop("Postprocessing ensemble does not accept prop.", call. = FALSE)
    v <- post$v
    if (!is.numeric(v) || !is.vector(v) || length(v) != 1L || !is.finite(v) || v < 2 || v != floor(v) || v > .Machine$integer.max) {
      stop("`postprocessing$v` must be one whole number of at least two.", call. = FALSE)
    }
  }
  if (post$strategy == "ensemble" && !post$method %in% c("tailor_logistic", "sigmoid")) {
    stop("Ensemble postprocessing currently supports only binary tailor_logistic or sigmoid.", call. = FALSE)
  }
  for (package in if (post$method %in% c("sigmoid", "isotonic_numeric")) character() else c("tailor", "probably")) {
    minimum <- if (package == "tailor") "0.1.0" else "1.1.0"
    if (!requireNamespace(package, quietly = TRUE) || utils::packageVersion(package) < minimum) {
      stop("Postprocessing requires optional package ", sQuote(package), " >= ", minimum, ".", call. = FALSE)
    }
  }
  post
}

.postprocessing_workflow <- function(workflow, postprocessing) {
  if (postprocessing$method == "isotonic_numeric") {
    if (!is.null(tryCatch(workflows::extract_postprocessor(workflow), error = function(e) NULL))) {
      stop("isotonic_numeric requires a base workflow without a postprocessor.", call. = FALSE)
    }
    return(workflow)
  }
  if (postprocessing$method == "sigmoid") {
    .validate_sigmoid_workflow(workflow, postprocessing$sigmoid_input)
    return(workflow)
  }
  method <- sub("^tailor_", "", postprocessing$method)
  numeric <- method == "linear"
  canonical <- if (numeric) tailor::tailor() |> tailor::adjust_numeric_calibration(method = method, smooth = FALSE) else
    tailor::tailor() |> tailor::adjust_probability_calibration(method = method, smooth = FALSE)
  adapter <- if (numeric) "vennabers_numeric_calibration" else "vennabers_probability_calibration"
  post <- tryCatch(workflows::extract_postprocessor(workflow), error = function(e) NULL)
  if (is.null(post)) {
    workflow <- workflows::add_tailor(workflow, canonical)
    post <- canonical
  }
  # Compare configuration, including untrained state, without depending on list order.
  if (!inherits(post, "tailor") || length(post$adjustments) != 1L ||
      !identical(post$type, canonical$type) || !is.null(post$columns) || ncol(post$ptype)) {
    stop("Postprocessing requires exactly one untrained canonical Tailor ", method, " step with smooth=FALSE.", call. = FALSE)
  }
  step <- post$adjustments[[1L]]
  class(step) <- setdiff(class(step), adapter)
  expected <- canonical$adjustments[[1L]]
  if (!setequal(names(step$arguments), names(expected$arguments))) {
    stop("Postprocessing Tailor arguments must be exactly method='", method, "', smooth=FALSE.", call. = FALSE)
  }
  step$arguments <- step$arguments[names(expected$arguments)]
  if (!identical(step, expected)) stop("Postprocessing Tailor step must match the untrained canonical ", method, " step.", call. = FALSE)
  # A validation-only dispatch layer preserves the canonical adjustment and
  # its public fit/predict path, without another step or another prediction.
  class(step) <- c(adapter, class(step))
  post$adjustments[[1L]] <- step
  workflows::update_tailor(workflow, post)
}

.validate_tailor_input <- function(data, tailor) {
  if (tailor$type == "regression") {
    return(.validate_regression_vector(data[[tailor$columns$estimate]], "Tailor numeric input"))
  }
  classes <- levels(tailor$ptype[[tailor$columns$outcome]])
  .validate_base_probabilities(data[tailor$columns$probabilities], nrow(data), classes, "Tailor input")
}

#' @exportS3Method generics::fit
fit.vennabers_probability_calibration <- function(object, data, tailor = NULL, ...) {
  .validate_tailor_input(data, tailor)
  fitted <- NextMethod()
  if (!is.list(fitted$results$fit)) return(fitted)
  estimates <- fitted$results$fit$estimates
  estimate <- if (length(estimates) == 1L && is.list(estimates[[1L]])) estimates[[1L]]$estimate
  if (inherits(estimate, "multinom")) {
    # probably expects a matrix; nnet drops dimensions for a single row.
    class(estimate) <- c("vennabers_multinom", class(estimate))
    fitted$results$fit$estimates[[1L]]$estimate <- estimate
  }
  fitted
}

#' @export
predict.vennabers_multinom <- function(object, newdata, type = "class", ...) {
  result <- NextMethod()
  if (identical(type, "probs") && is.null(dim(result)) && nrow(newdata) == 1L) {
    result <- matrix(result, nrow = 1L, dimnames = list(rownames(newdata), names(result)))
  }
  result
}

#' @export
predict.vennabers_probability_calibration <- function(object, new_data, tailor, ...) {
  .validate_tailor_input(new_data, tailor)
  NextMethod()
}

#' @exportS3Method generics::fit
fit.vennabers_numeric_calibration <- function(object, data, tailor = NULL, ...) {
  .validate_tailor_input(data, tailor)
  NextMethod()
}

#' @export
predict.vennabers_numeric_calibration <- function(object, new_data, tailor, ...) {
  .validate_tailor_input(new_data, tailor)
  NextMethod()
}

.plan_postprocessing <- function(folds, domain, settings) {
  post <- settings$postprocessing
  numeric <- is.null(domain$classes)
  k <- if (numeric) 2L else length(domain$classes)
  expected <- if (numeric) "tailor_linear" else if (k == 2L) "tailor_logistic" else "tailor_multinomial"
  if (post$method != expected && !(post$method == "isotonic_numeric" && numeric) &&
      !(post$method == "sigmoid" && !numeric && k == 2L && settings$classification == "binary")) {
    stop(post$method, " B/P plan: ", if (numeric) "Regression requires" else paste(k, "model classes require"),
      " explicitly selecting ", if (numeric) "tailor_linear or isotonic_numeric" else expected, ".", call. = FALSE)
  }
  ensemble <- post$strategy == "ensemble"
  if (ensemble && (numeric || settings$classification != "binary")) {
    stop("Ensemble postprocessing currently requires binary classification.", call. = FALSE)
  }
  for (id in names(folds)) {
    inner_id <- if (ensemble) "ensemble" else "Holdout1"
    folds[[id]]$postprocessing <- tryCatch({
      Q <- folds[[id]]$analysis
      local <- domain$data[Q, , drop = FALSE]
      plan <- post$splits
      if (is.function(plan)) plan <- plan(local)
      if (!"splits" %in% names(post)) {
        outcome <- if (numeric) NULL else domain$outcome
        if (ensemble && post$v > nrow(local)) stop("v cannot exceed local Q rows; folds are not reduced.", call. = FALSE)
        plan <- if (ensemble) rlang::inject(rsample::vfold_cv(local, v = post$v, strata = !!outcome, pool = 0)) else
          rlang::inject(rsample::initial_split(local, prop = 1 - post$prop, strata = !!outcome, pool = 0))
      }
      bindings <- if (inherits(plan, "rset")) plan$splits else list(plan)
      for (split in bindings) if (inherits(split, "rsplit") && !identical(names(split$data), names(local))) {
        stop("Split data binding columns and their order must match local Q.", call. = FALSE)
      }
      positions <- if (ensemble) .cross_splits(plan, local) else list(Holdout1 = .inductive_split(plan, local))
      pairs <- positions
      for (inner_id in names(positions)) {
        pair <- positions[[inner_id]]
        if (!numeric) for (role in c("analysis", "assessment")) {
          rows <- pair[[role]]
          label <- if (role == "analysis") "B" else "P"
          if (any(tabulate(local[[domain$outcome]][rows], nbins = length(domain$classes)) == 0L)) {
            stop(label, " (", length(rows), " rows) must contain all model classes: ", paste(domain$classes, collapse = ", "), ".", call. = FALSE)
          }
        }
        minimum <- if (post$method %in% c("sigmoid", "isotonic_numeric")) 1L else k
        if (length(pair$assessment) <= minimum) {
          stop("P has ", length(pair$assessment), " rows; requires at least ", minimum + 1L,
            if (!post$method %in% c("sigmoid", "isotonic_numeric")) paste0(" (more than design rank ", k, ")"), ".", call. = FALSE)
        }
        pairs[[inner_id]] <- list(Q = Q, B = Q[pair$analysis], P = Q[pair$assessment],
          analysis = pair$analysis, assessment = pair$assessment)
      }
      if (ensemble) pairs else pairs[[1L]]
    }, error = function(e) stop(id, " / ", inner_id, " ", post$method, " B/P plan: ", conditionMessage(e), call. = FALSE))
  }
  folds
}

.fit_postprocessing <- function(workflow, data, fold, domain, settings, id, inner_id = "Holdout1") {
  if (settings$postprocessing$strategy == "ensemble") {
    pairs <- lapply(names(fold$postprocessing), function(j) {
      local_fold <- fold
      local_fold$postprocessing <- fold$postprocessing[[j]]
      holdout <- settings
      holdout$postprocessing$strategy <- "holdout"
      .fit_postprocessing(workflow, data, local_fold, domain, holdout, id, j)
    })
    names(pairs) <- names(fold$postprocessing)
    diagnostics <- lapply(pairs, `[[`, "diagnostics")
    model <- structure(list(models = lapply(pairs, `[[`, "model"), classes = domain$classes,
      inner_folds = names(pairs), method = settings$postprocessing$method, context = paste(id, settings$postprocessing$method)), class = "vennabers_ensemble")
    return(list(model = model, diagnostics = list(format_version = 1L,
      method = settings$postprocessing$method, strategy = "ensemble", input = diagnostics[[1L]]$input,
      Q = fold$analysis, C = fold$assessment, VA_fold = id, inner_folds = diagnostics,
      observed_base_fits = length(pairs), observed_postprocessor_fits = length(pairs))))
  }
  plan <- fold$postprocessing
  method <- sub("^tailor_", "", settings$postprocessing$method)
  context <- paste0(id, " / ", inner_id, " ", settings$postprocessing$method, " (B=", length(plan$B), ", P=", length(plan$P), ")")
  warnings <- character()
  result <- tryCatch(withCallingHandlers({
    if (method == "isotonic_numeric") {
      base <- generics::fit(workflow, data[plan$B, , drop = FALSE])
      prediction <- .base_numeric(base, data[plan$P, , drop = FALSE], context)
      truth <- data[[domain$outcome]][plan$P]
      iso <- stats::isoreg(prediction, truth)
      sorted_rows <- order(prediction)
      distinct_support <- !duplicated(prediction[sorted_rows])
      knots <- list(x = prediction[sorted_rows][distinct_support], y = iso$yf[distinct_support])
      model <- structure(list(workflow = base, isotonic = knots), class = "vennabers_isotonic_workflow")
      result <- list(model = model)
    } else if (method == "sigmoid") {
      result <- .fit_sigmoid_workflow(workflow, data, plan, domain, settings$postprocessing$sigmoid_input, context)
      model <- result$model$workflow
    } else {
      model <- generics::fit(workflow, data[plan$B, , drop = FALSE], data_calibration = data[plan$P, , drop = FALSE])
      step <- workflows::extract_tailor(model)$adjustments[[1L]]
      fit <- step$results$fit
      if (!isTRUE(step$trained) || !identical(step$arguments$method, method) ||
          !inherits(fit, paste0("cal_estimate_", method)) || length(fit$estimates) != 1L) {
        stop("P has no learned ", method, " state; failed fits and switches to none are not allowed.", call. = FALSE)
      }
      estimate <- fit$estimates[[1L]]$estimate
      rank <- if (method == "linear") 2L else length(domain$classes)
      if (!inherits(estimate, if (method == "multinomial") "multinom" else "glm") ||
          !identical(estimate$rank, rank) || length(plan$P) <= rank) {
        stop("P requires full design rank ", rank, " and more rows than rank.", call. = FALSE)
      }
      converged <- if (method == "multinomial") isTRUE(estimate$convergence == 0L) else isTRUE(estimate$converged)
      if (!converged || !all(is.finite(stats::coef(estimate)))) {
        stop("P ", method, " fit did not converge to finite coefficients.", call. = FALSE)
      }
      result <- list(model = model, rank = estimate$rank, coefficients = stats::coef(estimate))
    }
    engine <- workflows::extract_fit_engine(if (method == "isotonic_numeric") model$workflow else model)
    if (is.list(engine) && (identical(engine$converged, FALSE) ||
        inherits(engine, "nnet") && !isTRUE(engine$convergence == 0))) {
      stop("B engine did not converge.", call. = FALSE)
    }
    result
  }, warning = function(w) {
    message <- paste0(context, ": ", conditionMessage(w))
    warnings <<- c(warnings, message)
    warning(message, call. = FALSE)
    invokeRestart("muffleWarning")
  }), error = function(e) stop(context, ": ", conditionMessage(e), call. = FALSE))
  list(model = result$model, diagnostics = c(plan, list(format_version = 1L,
    method = settings$postprocessing$method, strategy = "holdout",
    input = if (method == "sigmoid") settings$postprocessing$sigmoid_input else if (method %in% c("linear", "isotonic_numeric")) "numeric" else "probability", inner_fold = inner_id,
    VA_fold = id, C = fold$assessment, B_size = length(plan$B), P_size = length(plan$P),
    classes = domain$classes, event_class = domain$event, schema = domain$schema,
    columns = names(data), column_types = lapply(data, function(x) list(class = class(x), typeof = typeof(x), levels = levels(x))),
    seed = settings$seed, rng_kind = RNGkind(), rank = result$rank, coefficients = result$coefficients,
    scale = result$scale, sigmoid_class = if (method == "sigmoid") domain$classes[2L],
    converged = TRUE, warnings = warnings, observed_base_fits = 1L, observed_postprocessor_fits = 1L)))
}

#' @export
predict.vennabers_isotonic_workflow <- function(object, newdata, type = "numeric", ...) {
  .validate_choice(type, "numeric", "type")
  if (!nrow(newdata)) return(tibble::tibble(.pred = numeric()))
  prediction <- .base_numeric(object$workflow, newdata, "isotonic_numeric")
  knots <- object$isotonic
  adjusted <- if (length(knots$x) == 1L) rep(knots$y, length(prediction)) else
    stats::approx(knots$x, knots$y, xout = prediction, rule = 2)$y
  tibble::tibble(.pred = adjusted)
}

#' @export
predict.vennabers_ensemble <- function(object, newdata, type = "prob", ...) {
  .integration_dots(...)
  .validate_choice(type, "prob", "type")
  if (!identical(names(object$models), object$inner_folds) || length(object$models) < 2L ||
      any(vapply(object$models, is.null, logical(1)))) {
    stop(object$context, " incomplete inner ensemble.", call. = FALSE)
  }
  if (!nrow(newdata)) return(tibble::as_tibble(stats::setNames(
    rep(list(numeric()), length(object$classes)), paste0(".pred_", object$classes))))
  # RDS restores S3 objects without necessarily loading their optional methods.
  if (object$method == "tailor_logistic" && !requireNamespace("tailor", quietly = TRUE)) {
    stop(object$context, " prediction requires optional package 'tailor'.", call. = FALSE)
  }
  probabilities <- lapply(object$inner_folds, function(j) {
    .base_probability(object$models[[j]], newdata, object$classes, NULL, paste(object$context, "/", j))
  })
  averaged <- Reduce(`+`, probabilities) / length(probabilities)
  colnames(averaged) <- paste0(".pred_", object$classes)
  tibble::as_tibble(averaged)
}
