cross_venn_abers <- function(truth, probability, fold) {
  .validate_binary_input(truth, probability)
  if (!is.vector(fold) ||
      !(is.character(fold) || is.numeric(fold)) || anyNA(fold)) {
    stop("`fold` must be a character or numeric vector without missing IDs.", call. = FALSE)
  }
  if (is.character(fold)) {
    if (any(!nzchar(fold))) {
      stop("`fold` labels must be non-empty.", call. = FALSE)
    }
  } else if (any(!is.finite(fold) | fold <= 0 | fold != floor(fold))) {
    stop("`fold` numeric IDs must be finite positive whole numbers.", call. = FALSE)
  }
  if (length(fold) != length(truth)) {
    stop("`fold` must have the same length as `truth` and `probability`.", call. = FALSE)
  }
  fold <- as.character(fold)
  identities <- unique(fold)
  if (length(identities) < 2L) {
    stop("`fold` must contain at least two non-empty folds.", call. = FALSE)
  }
  calibrators <- lapply(identities, function(id) {
    rows <- fold == id
    venn_abers(truth[rows], probability[rows])
  })
  structure(
    list(folds = identities, calibrators = calibrators, observations = length(truth)),
    class = "cross_venn_abers"
  )
}

.cross_probability <- function(lower, upper) {
  stats::plogis(rowMeans(log(upper)) - rowMeans(log1p(-lower)))
}

predict.cross_venn_abers <- function(object, newdata, ...) {
  if (length(list(...))) {
    stop("`...` must be empty; prediction options are not supported.", call. = FALSE)
  }
  if (!is.matrix(newdata) || !is.numeric(newdata) ||
      any(!is.finite(newdata) | newdata < 0 | newdata > 1)) {
    stop("`newdata` must be a numeric matrix of finite values between 0 and 1.", call. = FALSE)
  }
  columns <- colnames(newdata)
  if (is.null(columns) || anyNA(columns) || any(!nzchar(columns)) ||
      anyDuplicated(columns) || !setequal(columns, object$folds)) {
    stop("`newdata` column names must be non-empty, unique, and match the fitted fold IDs.", call. = FALSE)
  }
  endpoints <- lapply(seq_along(object$folds), function(k) {
    stats::predict(object$calibrators[[k]], newdata[, object$folds[k]])
  })
  lower <- do.call(cbind, lapply(endpoints, `[[`, "lower"))
  upper <- do.call(cbind, lapply(endpoints, `[[`, "upper"))
  data.frame(probability = .cross_probability(lower, upper))
}

print.cross_venn_abers <- function(x, ...) {
  cat(
    "<cross_venn_abers>\n",
    "Folds: ", length(x$folds), "\n",
    "Calibration observations: ", x$observations, "\n",
    sep = ""
  )
  invisible(x)
}
