.validate_regression_vector <- function(x, argument) {
  if (!is.numeric(x) || !is.vector(x) || any(!is.finite(x))) {
    stop("`", argument, "` must be a numeric vector of finite values.", call. = FALSE)
  }
}

# Convex interpolation without overflowing a difference or losing a small
# same-sign value by halving it. Also preserves exactly coincident endpoints.
.regression_interpolate <- function(lower, upper, fraction) {
  opposite <- sign(lower) != sign(upper)
  result <- lower + (upper - lower) * fraction
  # Anchor at the nearer endpoint to preserve it exactly and avoid cancellation.
  near_upper <- fraction > .5
  result[near_upper] <- (upper - (upper - lower) * (1 - fraction))[near_upper]
  result[opposite] <- (lower * (1 - fraction) + upper * fraction)[opposite]
  result
}

.regression_point <- function(lower, upper, a, b) {
  left <- lower - a
  right <- b - upper
  overflow <- is.infinite(left) | is.infinite(right)
  left[overflow] <- (lower / 2 - a / 2)[overflow]
  right[overflow] <- (b / 2 - upper / 2)[overflow]
  scale <- pmax(left, right)
  fraction <- rep(.5, length(lower))
  positive <- scale > 0
  left <- left[positive] / scale[positive]
  right <- right[positive] / scale[positive]
  fraction[positive] <- right / (left + right)
  .regression_interpolate(lower, upper, fraction)
}

venn_abers_regression <- function(truth, prediction, ..., m = 1, epsilon = NULL) {
  if (length(list(...))) stop("`...` must be empty; unsupported fit argument.", call. = FALSE)
  .validate_regression_vector(truth, "truth")
  .validate_regression_vector(prediction, "prediction")
  k <- length(truth)
  if (!k || length(prediction) != k) {
    stop("`truth` and `prediction` must have the same nonzero length.", call. = FALSE)
  }
  if (!missing(m) && !missing(epsilon)) {
    stop("Supply only one of `m` and `epsilon`.", call. = FALSE)
  }
  requested <- if (!missing(epsilon)) list(epsilon = epsilon) else if (!missing(m)) list(m = m) else list()
  if (!missing(epsilon)) {
    .validate_regression_vector(epsilon, "epsilon")
    if (length(epsilon) != 1L || epsilon <= 0 || epsilon >= 1) {
      stop("`epsilon` must be one finite numeric value strictly between 0 and 1.", call. = FALSE)
    }
    m <- floor(epsilon * (k + 1) / 2)
  }
  .validate_regression_vector(m, "m")
  if (length(m) != 1L || m != floor(m) || m < 1 || m > floor((k - 1) / 2)) {
    stop("`m` must be a whole number with 1 <= m <= floor((k - 1) / 2); at least three calibration observations are required.", call. = FALSE)
  }

  ranked <- sort(as.numeric(truth))
  a <- ranked[m]
  b <- ranked[k - m + 1L]
  ordered <- order(prediction, method = "radix")
  runs <- rle(as.numeric(prediction[ordered]))
  ends <- cumsum(runs$lengths)
  starts <- c(1L, ends[-length(ends)] + 1L)
  # Asymmetric replacement retains all k observations, including tied scores.
  lower_truth <- pmin(pmax(truth[ordered], a), ranked[k - m])
  upper_truth <- pmin(pmax(truth[ordered], ranked[m + 1L]), b)
  lower <- rep(a, length(starts) + 1L)
  upper <- rep(b, length(starts) + 1L)
  if (a != b) {
    # Scale before cumulative sums; halve only when the full range overflows.
    divisor <- if (is.finite(b - a)) 1 else 2
    span <- b / divisor - a / divisor
    lower_truth <- (lower_truth / divisor - a / divisor) / span
    upper_truth <- (upper_truth / divisor - a / divisor) / span
    lower_sum <- vapply(seq_along(starts), function(i) sum(lower_truth[starts[i]:ends[i]]), 0)
    upper_sum <- vapply(seq_along(starts), function(i) sum(upper_truth[starts[i]:ends[i]]), 0)
    weight <- as.numeric(runs$lengths)
    lower_unit <- c(0, -rev(.upper_scan(rev(weight), -rev(lower_sum), upper = 0)))
    upper_unit <- c(.upper_scan(weight, upper_sum), 1)
    # Only roundoff in computed slopes is bounded; supplied values are unchanged.
    lower <- .regression_interpolate(a, b, pmin(1, pmax(0, lower_unit)))
    upper <- .regression_interpolate(a, b, pmin(1, pmax(0, upper_unit)))
  }
  structure(list(knots = runs$values, lower = lower, upper = upper,
                 a = a, b = b, observations = k, requested = requested,
                 m = as.numeric(m), epsilon = 2 * m / (k + 1)),
            class = "venn_abers_regression")
}

predict.venn_abers_regression <- function(object, newdata, ...) {
  if (length(list(...))) stop("`...` must be empty; unsupported prediction argument.", call. = FALSE)
  .validate_regression_vector(newdata, "newdata")
  lower <- object$lower[findInterval(newdata, object$knots) + 1L]
  upper <- object$upper[findInterval(newdata, object$knots, left.open = TRUE) + 1L]
  data.frame(prediction = .regression_point(lower, upper, object$a, object$b),
             lower = lower, upper = upper)
}
