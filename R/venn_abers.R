.cross <- function(x, y, a, b, c) {
  (x[b] - x[a]) * (y[c] - y[b]) - (y[b] - y[a]) * (x[c] - x[b])
}

.upper_scan <- function(weight, events) {
  k <- length(weight)
  x <- c(-1, 0, cumsum(weight))
  y <- c(-1, 0, cumsum(events))
  stack <- integer(k + 2L)
  stack[1:2] <- 1:2
  size <- 2L

  for (i in seq_len(k)) {
    point <- i + 2L
    while (size > 1L && .cross(x, y, stack[size - 1L], stack[size], point) <= 0) {
      size <- size - 1L
    }
    size <- size + 1L
    stack[size] <- point
  }

  stack[seq_len(size)] <- rev(stack[seq_len(size)])
  result <- numeric(k)
  for (i in seq_len(k)) {
    top <- stack[size]
    next_top <- stack[size - 1L]
    result[i] <- (y[next_top] - y[top]) / (x[next_top] - x[top])

    point <- i + 1L
    x[point] <- x[i] + x[i + 2L] - x[point]
    y[point] <- y[i] + y[i + 2L] - y[point]
    if (.cross(x, y, top, next_top, point) >= 0) next

    size <- size - 1L
    while (size > 1L && .cross(x, y, point, stack[size], stack[size - 1L]) <= 0) {
      size <- size - 1L
    }
    size <- size + 1L
    stack[size] <- point
  }
  result
}

.valid_probability <- function(x) {
  is.vector(x) && is.numeric(x) && all(is.finite(x) & x >= 0 & x <= 1)
}

.validate_binary_input <- function(truth, probability) {
  if (!is.vector(truth) || !(is.logical(truth) || is.numeric(truth)) ||
      anyNA(truth) || any(!is.finite(truth)) || any(!truth %in% c(0, 1))) {
    stop("`truth` must be a logical or numeric vector containing only 0 and 1.", call. = FALSE)
  }
  if (!length(truth)) {
    stop("`truth` must be non-empty.", call. = FALSE)
  }
  if (!.valid_probability(probability)) {
    stop("`probability` must be a numeric vector of finite values between 0 and 1.", call. = FALSE)
  }
  if (length(probability) != length(truth)) {
    stop("`probability` must have the same length as `truth`.", call. = FALSE)
  }
}

brier_score <- function(truth, probability) {
  if (is.factor(truth)) {
    probability <- .validate_multiclass_input(truth, probability)
    probability[cbind(seq_along(truth), as.integer(truth))] <-
      probability[cbind(seq_along(truth), as.integer(truth))] - 1
    return(mean(rowSums(probability^2)))
  }
  .validate_binary_input(truth, probability)
  mean((truth - probability)^2)
}

log_loss <- function(truth, probability) {
  if (is.factor(truth)) {
    probability <- .validate_multiclass_input(truth, probability)
    return(-mean(log(probability[cbind(seq_along(truth), as.integer(truth))])))
  }
  .validate_binary_input(truth, probability)
  -mean(ifelse(truth == 1, log(probability), log1p(-probability)))
}

calibration_plot <- function(truth, probability, bins = 10, ...) {
  if (is.factor(truth)) {
    probability <- .validate_multiclass_input(truth, probability)
    classes <- levels(truth)
    old <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(old))
    rows <- ceiling(sqrt(length(classes)))
    graphics::par(mfrow = c(rows, ceiling(length(classes) / rows)))
    summaries <- lapply(classes, function(class) {
      options <- utils::modifyList(list(main = paste("Calibration:", class)), list(...))
      summary <- do.call(calibration_plot, c(list(
        truth = truth == class, probability = probability[, class], bins = bins
      ), options))
      data.frame(class = factor(rep(class, nrow(summary)), levels = classes), summary)
    })
    return(invisible(do.call(rbind, summaries)))
  }
  .validate_binary_input(truth, probability)
  if (!is.numeric(bins) || !is.null(dim(bins)) || length(bins) != 1L || !is.finite(bins) ||
      bins < 1 || bins != floor(bins)) {
    stop("`bins` must be one finite whole number of at least 1.", call. = FALSE)
  }

  upper_break <- ceiling(probability * bins)
  bin <- pmin(pmax(upper_break + (probability >= upper_break / bins), 1), bins)
  observations <- split(seq_along(probability), bin)
  summary <- data.frame(
    mean_probability = vapply(observations, function(i) mean(probability[i]), 0),
    event_rate = vapply(observations, function(i) mean(truth[i]), 0),
    count = vapply(observations, length, 0L),
    row.names = NULL
  )

  options <- utils::modifyList(list(
    type = "o",
    xlim = c(0, 1),
    ylim = c(0, 1),
    xaxs = "i",
    yaxs = "i",
    xlab = "Mean predicted probability",
    ylab = "Observed event rate",
    main = "Calibration plot"
  ), list(...))
  options$x <- summary$mean_probability
  options$y <- summary$event_rate
  do.call(graphics::plot, options)
  graphics::abline(a = 0, b = 1, lty = 2)
  invisible(summary)
}

venn_abers <- function(truth, probability, precision = NULL, method = "ovo") {
  .validate_choice(method, c("ovo", "ovr"), "method")
  if (is.factor(truth)) {
    return(.fit_inductive_multiclass(truth, probability, precision, method))
  }
  if (!missing(method)) stop("`method` requires factor truth and a class matrix.", call. = FALSE)
  .validate_binary_input(truth, probability)
  if (!is.null(precision)) {
    if (!is.numeric(precision) || !is.vector(precision) || length(precision) != 1L ||
        !is.finite(precision) || precision != floor(precision)) {
      stop("`precision` must be NULL or one finite numeric whole number.", call. = FALSE)
    }
    probability <- round(probability, digits = precision)
  }

  ordered <- order(probability, method = "radix")
  probability <- probability[ordered]
  truth <- as.numeric(truth[ordered])
  runs <- rle(probability)
  ends <- cumsum(runs$lengths)
  starts <- c(1L, ends[-length(ends)] + 1L)
  events <- vapply(seq_along(starts), function(i) sum(truth[starts[i]:ends[i]]), 0)
  weight <- as.numeric(runs$lengths)

  upper <- .upper_scan(weight, events)
  lower <- 1 - rev(.upper_scan(rev(weight), rev(weight - events)))
  structure(
    list(
      knots = runs$values,
      lower = c(0, lower),
      upper = c(upper, 1),
      observations = length(truth),
      events = sum(truth)
    ),
    class = "venn_abers"
  )
}

.validate_choice <- function(value, choices, argument) {
  if (!is.character(value) || !is.vector(value) || length(value) != 1L ||
      is.na(value) || !value %in% choices) {
    stop("`", argument, "` must be one of: ", paste(choices, collapse = ", "), ".", call. = FALSE)
  }
}

.regularized_probability <- function(lower, upper, loss) {
  if (loss == "brier") upper + (lower^2 - upper^2) / 2 else upper / (1 - lower + upper)
}

predict.venn_abers <- function(object, newdata, ..., loss = "log", type = "response") {
  if (length(list(...))) {
    stop("`...` must be empty; unsupported prediction argument.", call. = FALSE)
  }
  .validate_choice(loss, c("log", "brier"), "loss")
  if (!is.null(object$classes)) return(.predict_inductive_multiclass(object, newdata, loss, type))
  .validate_choice(type, c("response", "class"), "type")
  if (!.valid_probability(newdata)) {
    stop("`newdata` must be a numeric vector of finite values between 0 and 1.", call. = FALSE)
  }

  lower <- object$lower[findInterval(newdata, object$knots) + 1L]
  upper <- object$upper[findInterval(newdata, object$knots, left.open = TRUE) + 1L]
  probability <- .regularized_probability(lower, upper, loss)
  if (type == "class") return(probability >= .5)
  data.frame(
    lower = lower,
    upper = upper,
    probability = probability
  )
}

print.venn_abers <- function(x, ...) {
  if (!is.null(x$classes)) {
    method <- if (identical(x$method, "ovr")) "ovr" else "ovo"
    cat("<venn_abers: ", method, ">\nCalibration observations: ", x$observations,
        "\nClasses: ", paste(x$classes, collapse = ", "),
        if (method == "ovr") "\nClasses against rest: " else "\nClass pairs: ",
        length(x$calibrators), "\n", sep = "")
    return(invisible(x))
  }
  cat(
    "<venn_abers>\n",
    "Calibration observations: ", x$observations, "\n",
    "Event observations: ", x$events, "\n",
    "Unique probability knots: ", length(x$knots), "\n",
    sep = ""
  )
  invisible(x)
}
