cross_venn_abers_regression <- function(truth, prediction, fold, ..., m = 1, epsilon = NULL) {
  if (length(list(...))) stop("`...` must be empty; unsupported fit argument.", call. = FALSE)
  .validate_regression_vector(truth, "truth")
  .validate_regression_vector(prediction, "prediction")
  if (!length(truth) || length(prediction) != length(truth)) {
    stop("`truth` and `prediction` must have the same nonzero length.", call. = FALSE)
  }
  fold <- .calibration_folds(fold, length(truth))
  # Forward only explicit options, preserving IVAR's missing-argument contract.
  options <- list()
  if (!missing(m)) options["m"] <- list(m)
  if (!missing(epsilon)) options["epsilon"] <- list(epsilon)
  identities <- unique(fold)
  calibrators <- lapply(identities, function(id) {
    rows <- fold == id
    tryCatch(do.call(venn_abers_regression,
                     c(list(truth = truth[rows], prediction = prediction[rows]), options)),
             error = function(error) stop("Fold ", sQuote(id), ": ", conditionMessage(error), call. = FALSE))
  })
  names(calibrators) <- identities
  structure(list(folds = identities, calibrators = calibrators,
                 observations = length(truth)), class = "cross_venn_abers_regression")
}

predict.cross_venn_abers_regression <- function(object, newdata, ..., type = "response") {
  if (length(list(...))) stop("`...` must be empty; unsupported prediction argument.", call. = FALSE)
  .validate_choice(type, c("response", "details"), "type")
  if (!is.matrix(newdata) || !is.numeric(newdata) || any(!is.finite(newdata))) {
    stop("`newdata` must be a numeric matrix of finite values.", call. = FALSE)
  }
  columns <- colnames(newdata)
  if (is.null(columns) || anyNA(columns) || any(!nzchar(columns)) ||
      anyDuplicated(columns) || !setequal(columns, object$folds)) {
    stop("`newdata` column names must be non-empty, unique, and match the fitted fold IDs.", call. = FALSE)
  }
  folds <- lapply(object$folds, function(id) {
    stats::predict(object$calibrators[[id]], newdata[, id])
  })
  names(folds) <- object$folds
  prediction <- lapply(c("prediction", "lower", "upper"), function(column) {
    values <- do.call(cbind, lapply(folds, `[[`, column))
    # Scale to prevent overflow; Neumaier compensation retains small residuals
    # when large opposite-signed fold results cancel, even without long doubles.
    vapply(seq_len(nrow(newdata)), function(i) {
      scale <- max(abs(values[i, ]))
      if (scale == 0) return(0)
      total <- correction <- 0
      for (value in values[i, ] / scale) {
        next_total <- total + value
        correction <- correction + if (abs(total) >= abs(value)) {
          (total - next_total) + value
        } else {
          (value - next_total) + total
        }
        total <- next_total
      }
      ((total + correction) / ncol(values)) * scale
    }, 0)
  })
  names(prediction) <- c("prediction", "lower", "upper")
  prediction <- as.data.frame(prediction)
  if (type == "response") return(prediction)
  list(prediction = prediction, folds = folds)
}
