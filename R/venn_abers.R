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
  .validate_binary_input(truth, probability)
  mean((truth - probability)^2)
}

log_loss <- function(truth, probability) {
  .validate_binary_input(truth, probability)
  -mean(ifelse(truth == 1, log(probability), log1p(-probability)))
}

calibration_plot <- function(truth, probability, bins = 10, ...) {
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

venn_abers <- function(truth, probability) {
  .validate_binary_input(truth, probability)

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

predict.venn_abers <- function(object, newdata, ...) {
  if (length(list(...))) {
    stop("`...` must be empty; prediction options are not supported.", call. = FALSE)
  }
  if (!.valid_probability(newdata)) {
    stop("`newdata` must be a numeric vector of finite values between 0 and 1.", call. = FALSE)
  }

  lower <- object$lower[findInterval(newdata, object$knots) + 1L]
  upper <- object$upper[findInterval(newdata, object$knots, left.open = TRUE) + 1L]
  data.frame(
    lower = lower,
    upper = upper,
    probability = upper / (1 - lower + upper)
  )
}

print.venn_abers <- function(x, ...) {
  cat(
    "<venn_abers>\n",
    "Calibration observations: ", x$observations, "\n",
    "Event observations: ", x$events, "\n",
    "Unique probability knots: ", length(x$knots), "\n",
    sep = ""
  )
  invisible(x)
}
