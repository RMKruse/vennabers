.class_probability <- function(probability, classes, argument = "probability") {
  if (!is.matrix(probability) || !is.numeric(probability) ||
      any(!is.finite(probability) | probability < 0 | probability > 1)) {
    stop("`", argument, "` must be a numeric matrix of finite values between 0 and 1.", call. = FALSE)
  }
  columns <- colnames(probability)
  if (is.null(columns) || anyNA(columns) || any(!nzchar(columns)) ||
      anyDuplicated(columns) || !setequal(columns, classes)) {
    stop("`", argument, "` column names must be non-empty, unique, and match the classes.", call. = FALSE)
  }
  probability <- probability[, classes, drop = FALSE]
  totals <- rowSums(probability)
  if (any(abs(totals - 1) > 1e-8)) {
    stop("`", argument, "` row sums must be within 1e-8 of one.", call. = FALSE)
  }
  probability / totals
}

.validate_multiclass_input <- function(truth, probability, require_all = FALSE) {
  classes <- levels(truth)
  if (!is.factor(truth) || !is.null(dim(truth)) || !length(truth) || anyNA(truth) ||
      length(classes) < 2L || anyNA(classes) || any(!nzchar(classes))) {
    stop("`truth` must be a non-empty factor without missing values and with at least two non-empty levels.", call. = FALSE)
  }
  probability <- .class_probability(probability, classes)
  if (nrow(probability) != length(truth)) {
    stop("`probability` must have one row per `truth` value.", call. = FALSE)
  }
  if (require_all && any(tabulate(as.integer(truth), nbins = length(classes)) == 0L)) {
    stop("Every class in `truth` must be observed in the calibration set.", call. = FALSE)
  }
  probability
}

.pair_probability <- function(probability, pair) {
  total <- rowSums(probability[, pair, drop = FALSE])
  result <- rep(.5, nrow(probability))
  positive <- total > 0
  result[positive] <- probability[positive, pair[2L]] / total[positive]
  result
}

.fit_inductive_multiclass <- function(truth, probability, precision, method) {
  probability <- .validate_multiclass_input(truth, probability, require_all = TRUE)
  classes <- levels(truth)
  pairs <- if (method == "ovo") utils::combn(classes, 2L, simplify = FALSE) else NULL
  calibrators <- if (method == "ovr") {
    lapply(classes, function(class) venn_abers(truth == class, probability[, class], precision))
  } else {
    lapply(pairs, function(pair) {
      rows <- truth %in% pair
      venn_abers(truth[rows] == pair[2L],
                 .pair_probability(probability[rows, , drop = FALSE], pair), precision)
    })
  }
  structure(list(classes = classes, method = method, pairs = pairs, calibrators = calibrators,
                 observations = length(truth)), class = "venn_abers")
}

.predict_inductive_multiclass <- function(object, newdata, loss, type) {
  .validate_choice(type, c("response", "class", "details"), "type")
  newdata <- .class_probability(newdata, object$classes, "newdata")
  n <- nrow(newdata)
  k <- length(object$classes)
  details <- vector("list", length(object$calibrators))
  ovr <- identical(object$method, "ovr")
  if (ovr) {
    prediction <- matrix(0, n, k, dimnames = dimnames(newdata))
    for (i in seq_along(object$classes)) {
      class <- object$classes[i]
      binary <- stats::predict(object$calibrators[[i]], newdata[, class], loss = loss)
      prediction[, class] <- binary$probability
      if (type == "details") {
        details[[i]] <- data.frame(row = seq_len(n), event = rep(class, n), binary)
      }
    }
  } else {
    reciprocal <- matrix(2 - k, n, k, dimnames = dimnames(newdata))
    for (i in seq_along(object$pairs)) {
      pair <- object$pairs[[i]]
      binary <- stats::predict(object$calibrators[[i]], .pair_probability(newdata, pair), loss = loss)
      reciprocal[, pair[1L]] <- reciprocal[, pair[1L]] + 1 / (1 - binary$probability)
      reciprocal[, pair[2L]] <- reciprocal[, pair[2L]] + 1 / binary$probability
      if (type == "details") {
        details[[i]] <- data.frame(row = seq_len(n),
                                  non_event = rep(pair[1L], n), event = rep(pair[2L], n), binary)
      }
    }
    prediction <- 1 / reciprocal
  }
  prediction <- prediction / rowSums(prediction)
  if (type == "class") {
    return(factor(object$classes[max.col(prediction, ties.method = "first")], levels = object$classes))
  }
  if (type == "response") return(prediction)
  if (ovr) list(prediction = prediction, classes = do.call(rbind, details)) else
    list(prediction = prediction, pairs = do.call(rbind, details))
}
