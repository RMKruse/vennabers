testthat::test_that("regression-mean-oracle", {
# The 1.0.0 fold mean, kept verbatim as the release-fidelity oracle (ADR 0002).
regression_mean_1.0 <- function(values) {
  values <- sort(values)
  left <- 1L
  right <- length(values)
  total <- correction <- 0
  while (left <= right) {
    if (total > 0) {
      value <- values[left]
      left <- left + 1L
    } else {
      value <- values[right]
      right <- right - 1L
    }
    next_total <- total + value
    if (!is.finite(next_total)) {
      total <- next_total
      break
    }
    correction <- correction + if (abs(total) >= abs(value)) {
      (total - next_total) + value
    } else {
      (value - next_total) + total
    }
    total <- next_total
  }
  result <- (total + correction) / length(values)
  if (is.finite(result)) return(result)
  scale <- max(abs(values))
  regression_mean_1.0(values / scale) * scale
}

mean_rows <- vennabers:::.regression_mean_rows
# num.eq = FALSE compares bits, so -0 and 0 differ.
same <- function(values) {
  expected <- vapply(seq_len(nrow(values)), function(i) regression_mean_1.0(values[i, ]), 0)
  identical(mean_rows(values), expected, num.eq = FALSE)
}

big <- .Machine$double.xmax
tiny <- .Machine$double.xmin
set.seed(20261028)
for (k in 2:10) {
  n <- 400L
  draw <- list(
    normal = function() stats::rnorm(n * k),
    cvar_like = function() rep(stats::rnorm(n), k) + stats::rnorm(n * k, sd = 1e-3),
    wide_scale = function() stats::rnorm(n * k) * 10^stats::runif(n * k, -300, 300),
    mixed_sign_cancel = function() {
      stats::rnorm(n * k) * 1e15 * sample(c(-1, 1), n * k, TRUE) + stats::runif(n * k)
    },
    # Overflow in the loop or the final sum takes the scaling path.
    overflow_same_sign = function() big * stats::runif(n * k, .5, 1) * sample(c(-1, 1), n, TRUE),
    overflow_mixed = function() big * stats::runif(n * k, -1, 1),
    near_overflow_sum = function() big / k * stats::runif(n * k, .9, 1.1),
    subnormal = function() tiny * stats::runif(n * k, -2^-40, 2^-40),
    subnormal_mixed = function() c(tiny * 2^-50, -tiny * 2^-51, 5e-324, -5e-324, 0, -0)[sample.int(6L, n * k, TRUE)],
    ties_zeros = function() sample(c(-1, 0, -0, 1, 2^-1074, big), n * k, TRUE),
    integers = function() as.numeric(sample(-3:3, n * k, TRUE)),
    huge_and_tiny = function() {
      ifelse(stats::runif(n * k) < .5, big * stats::runif(n * k, -1, 1), tiny * stats::rnorm(n * k))
    }
  )
  for (case in names(draw)) {
    values <- matrix(draw[[case]](), n, k)
    if (!same(values)) stop("k = ", k, ", ", case, ": differs from the 1.0.0 fold mean.", call. = FALSE)
  }
}

# Fixed rows: cancellation before overflow, pure overflow, an overflowing
# final sum, a -0 mean from subnormal underflow, signed zeros and ties.
rows <- list(c(1e308, 1e308, 1e-300, -1e308, -1e308), c(-1e308, 1e308, 5 * 5e-324, -1e308, 1e308),
             rep(big, 3), rep(-big, 3), c(big, big / 2, -big / 4), c(-5e-324, 0), c(-5e-324, -0, 0),
             c(0, -0), c(-0, -0), c(5e-324, 0, 0), c(1e16, 1, 1), c(-1, 1, -1, 1), c(2, 2, 2))
for (row in rows) {
  stopifnot(same(matrix(row, 1L)), same(matrix(rev(row), 1L)))
}
# Several rows at once, so fallback rows sit between vectorized ones.
stopifnot(same(rbind(c(1, 2, 3), rep(big, 3), c(-5e-324, 0, -0), c(big, -big, 1), c(4, 5, 6))))
stopifnot(identical(mean_rows(matrix(numeric(), 0L, 3L)), numeric()),
          identical(mean_rows(matrix(c(1, 2), 1L)), 1.5),
          identical(1 / mean_rows(matrix(c(-5e-324, 0), 1L)), -Inf))

  testthat::expect_true(TRUE)
})
