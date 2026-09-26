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
  if (!post$method %in% c("tailor_logistic", "tailor_multinomial") || post$strategy != "holdout") {
    stop("Only tailor_logistic or tailor_multinomial with holdout postprocessing is implemented.", call. = FALSE)
  }
  for (package in c("tailor", "probably")) {
    minimum <- if (package == "tailor") "0.1.0" else "1.1.0"
    if (!requireNamespace(package, quietly = TRUE) || utils::packageVersion(package) < minimum) {
      stop("Postprocessing requires optional package ", sQuote(package), " >= ", minimum, ".", call. = FALSE)
    }
  }
  post
}

.postprocessing_workflow <- function(workflow, postprocessing) {
  method <- sub("^tailor_", "", postprocessing$method)
  canonical <- tailor::tailor() |> tailor::adjust_probability_calibration(method = method, smooth = FALSE)
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
  class(step) <- setdiff(class(step), "vennabers_probability_calibration")
  expected <- canonical$adjustments[[1L]]
  if (!setequal(names(step$arguments), names(expected$arguments))) {
    stop("Postprocessing Tailor arguments must be exactly method='", method, "', smooth=FALSE.", call. = FALSE)
  }
  step$arguments <- step$arguments[names(expected$arguments)]
  if (!identical(step, expected)) stop("Postprocessing Tailor step must match the untrained canonical ", method, " step.", call. = FALSE)
  # A validation-only dispatch layer preserves the canonical adjustment and
  # its public fit/predict path, without another step or another prediction.
  class(step) <- c("vennabers_probability_calibration", class(step))
  post$adjustments[[1L]] <- step
  workflows::update_tailor(workflow, post)
}

.validate_tailor_input <- function(data, tailor) {
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

.plan_postprocessing <- function(folds, domain, settings) {
  post <- settings$postprocessing
  k <- length(domain$classes)
  expected <- if (k == 2L) "tailor_logistic" else "tailor_multinomial"
  if (post$method != expected) {
    stop(post$method, " B/P plan: ", k, " model classes require explicitly selecting ", expected, ".", call. = FALSE)
  }
  for (id in names(folds)) {
    folds[[id]]$postprocessing <- tryCatch({
      Q <- folds[[id]]$analysis
      local <- domain$data[Q, , drop = FALSE]
      plan <- post$splits
      if (is.function(plan)) plan <- plan(local)
      if (!"splits" %in% names(post)) {
        outcome <- domain$outcome
        plan <- rlang::inject(rsample::initial_split(local, prop = 1 - post$prop, strata = !!outcome, pool = 0))
      }
      if (inherits(plan, "rsplit") && !identical(names(plan$data), names(local))) {
        stop("Split data binding columns and their order must match local Q.", call. = FALSE)
      }
      positions <- .inductive_split(plan, local)
      for (role in c("analysis", "assessment")) {
        rows <- positions[[role]]
        label <- if (role == "analysis") "B" else "P"
        if (any(tabulate(local[[domain$outcome]][rows], nbins = length(domain$classes)) == 0L)) {
          stop(label, " (", length(rows), " rows) must contain all model classes: ", paste(domain$classes, collapse = ", "), ".", call. = FALSE)
        }
      }
      if (length(positions$assessment) <= k) stop("P has ", length(positions$assessment), " rows; requires at least ", k + 1L, " (more than design rank ", k, ").", call. = FALSE)
      list(Q = Q, B = Q[positions$analysis], P = Q[positions$assessment],
        analysis = positions$analysis, assessment = positions$assessment)
    }, error = function(e) stop(id, " / Holdout1 ", post$method, " B/P plan: ", conditionMessage(e), call. = FALSE))
  }
  folds
}

.fit_postprocessing <- function(workflow, data, fold, domain, settings, id) {
  plan <- fold$postprocessing
  method <- sub("^tailor_", "", settings$postprocessing$method)
  context <- paste0(id, " / Holdout1 ", settings$postprocessing$method, " (B=", length(plan$B), ", P=", length(plan$P), ")")
  warnings <- character()
  result <- tryCatch(withCallingHandlers({
    model <- generics::fit(workflow, data[plan$B, , drop = FALSE], data_calibration = data[plan$P, , drop = FALSE])
    step <- workflows::extract_tailor(model)$adjustments[[1L]]
    fit <- step$results$fit
    if (!isTRUE(step$trained) || !identical(step$arguments$method, method) ||
        !inherits(fit, paste0("cal_estimate_", method)) || length(fit$estimates) != 1L) {
      stop("P has no learned ", method, " state; failed fits and switches to none are not allowed.", call. = FALSE)
    }
    estimate <- fit$estimates[[1L]]$estimate
    rank <- length(domain$classes)
    if (!inherits(estimate, if (method == "logistic") "glm" else "multinom") ||
        !identical(estimate$rank, rank) || length(plan$P) <= rank) {
      stop("P requires full design rank ", rank, " and more rows than rank.", call. = FALSE)
    }
    converged <- if (method == "logistic") isTRUE(estimate$converged) else isTRUE(estimate$convergence == 0L)
    if (!converged || !all(is.finite(stats::coef(estimate)))) {
      stop("P ", method, " fit did not converge to finite coefficients.", call. = FALSE)
    }
    engine <- workflows::extract_fit_engine(model)
    if (is.list(engine) && (identical(engine$converged, FALSE) ||
        inherits(engine, "nnet") && !isTRUE(engine$convergence == 0))) {
      stop("B engine did not converge.", call. = FALSE)
    }
    list(model = model, rank = estimate$rank, coefficients = stats::coef(estimate))
  }, warning = function(w) {
    message <- paste0(context, ": ", conditionMessage(w))
    warnings <<- c(warnings, message)
    warning(message, call. = FALSE)
    invokeRestart("muffleWarning")
  }), error = function(e) stop(context, ": ", conditionMessage(e), call. = FALSE))
  list(model = result$model, diagnostics = c(plan, list(format_version = 1L,
    method = settings$postprocessing$method, strategy = "holdout", input = "probability", inner_fold = "Holdout1",
    VA_fold = id, C = fold$assessment, B_size = length(plan$B), P_size = length(plan$P),
    classes = domain$classes, event_class = domain$event, schema = domain$schema,
    columns = names(data), column_types = lapply(data, function(x) list(class = class(x), typeof = typeof(x), levels = levels(x))),
    seed = settings$seed, rng_kind = RNGkind(), rank = result$rank, coefficients = result$coefficients,
    converged = TRUE, warnings = warnings, observed_base_fits = 1L, observed_postprocessor_fits = 1L)))
}
