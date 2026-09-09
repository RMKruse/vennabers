#' @export
calibrate_workflow <- function(fitted_workflow, data_calibration, outcome, ...,
                               classification = "binary", event_level = "first",
                               precision = NULL, loss = "log") {
  supplied <- names(sys.call())[-1L]
  bad <- supplied[nzchar(supplied) & !supplied %in% names(formals(calibrate_workflow))]
  if (length(bad)) stop("Unknown argument: ", sQuote(bad[1L]), ".", call. = FALSE)
  .integration_dots(...)
  .integration_packages()
  .validate_choice(classification, "binary", "classification")
  .validate_choice(event_level, c("first", "second"), "event_level")
  .validate_choice(loss, c("log", "brier"), "loss")
  .integration_names(outcome, "outcome")
  if (length(outcome) != 1L) stop("`outcome` must name one column.", call. = FALSE)
  if (!inherits(fitted_workflow, "workflow") || !workflows::is_trained_workflow(fitted_workflow)) {
    stop("`fitted_workflow` must be a fully fitted workflow.", call. = FALSE)
  }
  fit <- workflows::extract_fit_parsnip(fitted_workflow)
  mold <- workflows::extract_mold(fitted_workflow)
  if (!inherits(fit, "model_fit") || is.null(fit$fit) || inherits(fit$fit, "try-error") ||
      !identical(fit$spec$mode, "classification")) {
    stop("`fitted_workflow` must contain a fitted classification model.", call. = FALSE)
  }
  targets <- mold$blueprint$ptypes$outcomes
  if (!identical(names(targets), outcome)) {
    stop("Frozen workflow outcome must be ", paste(sQuote(names(targets)), collapse = ", "),
         "; received ", sQuote(outcome), ".", call. = FALSE)
  }
  classes <- levels(targets[[outcome]])
  .integration_names(classes, "frozen class")
  if (length(classes) != 2L || !identical(fit$lvl, classes)) {
    stop("Frozen workflow must retain exactly two classes in the trained outcome order.", call. = FALSE)
  }
  pre <- workflows::extract_preprocessor(fitted_workflow)
  if (inherits(pre, "recipe") && !recipes::fully_trained(workflows::extract_recipe(fitted_workflow))) {
    stop("Frozen workflow recipe must be fully trained.", call. = FALSE)
  }
  # A trained workflow flag alone does not prove an attached postprocessor is fitted.
  post <- tryCatch(workflows::extract_postprocessor(fitted_workflow), error = function(e) NULL)
  if (!is.null(post)) {
    post <- workflows::extract_postprocessor(fitted_workflow, estimated = TRUE)
    if (length(post$adjustments) && !tailor::tailor_fully_trained(post)) {
      stop("Frozen workflow postprocessor must be fully trained.", call. = FALSE)
    }
  }
  settings <- list(mode = "classification", method = "inductive", classification = classification,
                   event_level = event_level, precision = precision, loss = loss)
  state <- structure(list(parameters = list(requested = settings, effective = settings),
                          schema = NULL, outcome = outcome,
                          predictors = names(mold$blueprint$ptypes$predictors),
                          class_levels = classes,
                          event_class = classes[if (event_level == "first") 1L else 2L],
                          loss = loss, models = list(Inductive1 = fitted_workflow)),
                     class = c("vennabers_frozen", "vennabers_fit"))
  input <- .frozen_data(state, data_calibration, "calibration")
  if (!nrow(input)) stop("Frozen calibration data must be nonempty.", call. = FALSE)
  truth <- data_calibration[[outcome]]
  if (!is.factor(truth) || anyNA(truth) || !setequal(levels(truth), classes)) {
    stop("Frozen calibration outcome ", sQuote(outcome), " must be a nonmissing factor with trained classes ",
         paste(sQuote(classes), collapse = ", "), ".", call. = FALSE)
  }
  probability <- .base_probability(fitted_workflow, input, classes, state$event_class, "Frozen calibration")
  state$calibrator <- venn_abers(truth == state$event_class, probability, precision = precision)
  state$columns <- c(state$predictors, outcome)
  state$calibration_size <- nrow(input)
  packages <- unique(c("vennabers", names(.integration_versions), generics::required_pkgs(fitted_workflow)))
  state$versions <- c(R = as.character(getRversion()),
                      vapply(packages, function(p) as.character(utils::packageVersion(p)), ""))
  state
}

.frozen_data <- function(object, data, stage = "prediction") {
  if (!is.data.frame(data)) stop("Frozen ", stage, " data must be a data frame.", call. = FALSE)
  if (ncol(data)) .integration_names(names(data), paste("frozen", stage, "input column"))
  required <- c(object$predictors, if (stage == "calibration") object$outcome)
  absent <- setdiff(required, names(data))
  if (length(absent)) stop("Frozen ", stage, " is missing original column ",
                           sQuote(absent[1L]), ".", call. = FALSE)
  # Keep raw inputs, including additional recipe roles; only the truth is separated.
  data[setdiff(names(data), object$outcome)]
}

#' @export
predict.vennabers_frozen <- function(object, new_data, type = "prob", ..., loss = NULL) {
  .integration_dots(...)
  .integration_packages()
  .validate_choice(type, c("prob", "class"), "type")
  if (!missing(loss)) {
    .validate_choice(loss, c("log", "brier"), "loss")
    object$loss <- loss
  }
  new_data <- .frozen_data(object, new_data)
  if (type == "class") return(tibble::tibble(.pred_class = predict_vennabers_class(object, new_data)))
  predict_vennabers_prob(object, new_data)
}
