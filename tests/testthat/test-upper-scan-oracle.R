testthat::test_that("upper-scan-oracle", {
# The 1.0.0 hull scan, kept verbatim as the release-fidelity oracle (ADR 0002).
cross_1.0 <- function(x, y, a, b, c) {
  (x[b] - x[a]) * (y[c] - y[b]) - (y[b] - y[a]) * (x[c] - x[b])
}

upper_scan_1.0 <- function(weight, events, upper = 1) {
  k <- length(weight)
  x <- c(-1, 0, cumsum(weight))
  y <- c(-upper, 0, cumsum(events))
  stack <- integer(k + 2L)
  stack[1:2] <- 1:2
  size <- 2L

  for (i in seq_len(k)) {
    point <- i + 2L
    while (size > 1L && cross_1.0(x, y, stack[size - 1L], stack[size], point) <= 0) {
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
    if (cross_1.0(x, y, top, next_top, point) >= 0) next

    size <- size - 1L
    while (size > 1L && cross_1.0(x, y, point, stack[size], stack[size - 1L]) <= 0) {
      size <- size - 1L
    }
    size <- size + 1L
    stack[size] <- point
  }
  result
}

upper_scan <- vennabers:::.upper_scan
same <- function(weight, events, upper = 1) {
  identical(upper_scan(weight, events, upper), upper_scan_1.0(weight, events, upper),
            num.eq = FALSE)
}
# Binary and regression call shapes: upper side, and the lower side with
# negated events against `upper = 0`.
both_sides <- function(weight, events) {
  same(weight, events) && same(weight, weight - events) &&
    same(rev(weight), -rev(events), upper = 0)
}

set.seed(20261028)
for (k in c(1L, 2L, 3L, 5L, 50L, 500L)) {
  for (replicate in 1:20) {
    # Distinct knots: unit weights, 0/1 events.
    weight <- rep(1, k)
    stopifnot(both_sides(weight, rbinom(k, 1, runif(1))))
    # Ties: run lengths with event counts.
    weight <- as.numeric(sample.int(6L, k, replace = TRUE))
    stopifnot(both_sides(weight, as.numeric(rbinom(k, weight, runif(k)))))
    # Regression sums: unit-scaled outcomes summed per run.
    stopifnot(both_sides(weight, weight * runif(k)))
    # Very small and very large weights with proportional events.
    for (scale in c(1e-300, 1e-12, 1e12, 1e150)) {
      weight <- scale * runif(k, .5, 2)
      stopifnot(both_sides(weight, weight * runif(k)))
    }
  }
}

# Degenerate shapes: all events, no events, collinear runs, single knots.
for (k in 1:4) {
  weight <- rep(1, k)
  stopifnot(both_sides(weight, weight), both_sides(weight, numeric(k)),
            both_sides(weight, weight / 2), both_sides(c(2, rep(1, k - 1L)), c(1, rep(.5, k - 1L))))
}
# Nearly collinear runs whose cumulative sums round, so sign tests sit at zero.
for (k in c(3L, 10L, 100L)) {
  for (ratio in c(.07, .3, 1 / 3, .7)) {
    weight <- rep(.1, k)
    stopifnot(both_sides(weight, ratio * weight), both_sides(weight, ratio * weight + 1e-17 * (-1)^(1:k)))
  }
}
# Short runs on a decimal grid; this case tells `> 0` from `>= 0` in the first pass.
stopifnot(same(rep(.1, 6), -c(.07, .07, .1, 0, 0, 0), upper = 0))
for (replicate in 1:2000) {
  k <- sample(2:12, 1L)
  stopifnot(both_sides(rep(.1, k), sample(c(0, .03, .07, .1), k, replace = TRUE)))
}
stopifnot(same(1, 0, upper = 0), same(1, 1, upper = 0), same(c(1, 1), c(0, -1), upper = 0),
          same(c(3, 1), c(-3, 0), upper = 0))

  testthat::expect_true(TRUE)
})
