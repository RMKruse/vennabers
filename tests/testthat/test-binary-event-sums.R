testthat::test_that("binary-event-sums", {
library(vennabers)

# The 1.0.0 per-run sums stay here as the identical() oracle (ADR 0002).
oracle <- function(truth, lengths) {
  ends <- cumsum(lengths)
  starts <- c(1L, ends[-length(ends)] + 1L)
  vapply(seq_along(starts), function(i) sum(truth[starts[i]:ends[i]]), 0)
}
event_sums <- vennabers:::.event_sums

check <- function(truth, lengths) {
  stopifnot(sum(lengths) == length(truth))
  truth <- as.numeric(truth)
  stopifnot(identical(event_sums(truth, lengths), oracle(truth, lengths)))
}

check(1, 1L)
check(0, 1L)
check(c(0, 1, 1, 0, 1), 5L)
check(rep(0, 7), c(2L, 1L, 4L))
check(rep(1, 7), c(2L, 1L, 4L))
check(c(1, 0, 1, 1, 0, 0), rep(1L, 6))

set.seed(73)
for (case in seq_len(40)) {
  n <- sample(c(1:20, 200, 5000), 1)
  truth <- rbinom(n, 1, runif(1))
  breaks <- sort(sample(n - 1L, sample(0:(n - 1L), 1)))
  check(truth, diff(c(0L, breaks, n)))
}

# The kernel itself: tied scores, a single block, and only events or only
# non-events give the same fit as with the oracle sums.
fit_with <- function(sums, truth, probability) {
  local_mocked_bindings(.event_sums = sums, .package = "vennabers")
  venn_abers(truth, probability)
}
inputs <- list(
  list(c(0, 1, 1, 0, 1, 1), c(.2, .2, .5, .5, .5, .9)),
  list(c(0, 1, 0, 1), rep(.4, 4)),
  list(rep(1, 5), c(.1, .3, .3, .6, .8)),
  list(rep(0, 5), c(.1, .3, .3, .6, .8)),
  list(rbinom(300, 1, .4), round(runif(300), 1))
)
for (input in inputs) {
  stopifnot(identical(fit_with(oracle, input[[1]], input[[2]]),
                      venn_abers(input[[1]], input[[2]])))
}

  testthat::expect_true(TRUE)
})
