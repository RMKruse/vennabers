library(vennabers)

expect_error <- function(expr, argument) {
  error <- tryCatch({
    force(expr)
    NULL
  }, error = identity)
  stopifnot(
    inherits(error, "error"),
    grepl(paste0("`", argument, "`"), conditionMessage(error), fixed = TRUE)
  )
}

expect_no_warning <- function(expr) {
  warned <- FALSE
  value <- withCallingHandlers(expr, warning = function(warning) {
    warned <<- TRUE
    invokeRestart("muffleWarning")
  })
  stopifnot(!warned)
  value
}

fixture <- function(truth, probability, newdata, lower, upper, regularized) {
  list(
    truth = truth,
    probability = probability,
    newdata = newdata,
    expected = data.frame(lower, upper, probability = regularized)
  )
}

# Values captured from Python venn-abers 1.5.4 with precision=None.
fixtures <- list(
  fixture(
    c(0, 1, 0), c(.1, .2, .3), c(.05, .1, .15, .2, .25, .3, .4),
    c(0, 0, 0, 1 / 3, 1 / 3, 1 / 3, 1 / 3),
    c(1 / 2, 1 / 2, 2 / 3, 2 / 3, 2 / 3, 2 / 3, 1),
    c(1 / 3, 1 / 3, 2 / 5, 1 / 2, 1 / 2, 1 / 2, 3 / 5)
  ),
  fixture(
    c(0, 1, 0, 1), c(.2, .2, .4, .4), c(.1, .2, .3, .4, .5),
    c(0, 1 / 3, 1 / 3, 2 / 5, 2 / 5),
    c(3 / 5, 3 / 5, 2 / 3, 2 / 3, 1),
    c(3 / 8, 9 / 19, 1 / 2, 10 / 19, 5 / 8)
  ),
  fixture(
    c(0, 1, 0, 1), c(.501, .502, .509, .510), c(.501, .505, .510),
    c(0, 1 / 3, 1 / 2), c(1 / 2, 2 / 3, 1), c(1 / 3, 1 / 2, 2 / 3)
  ),
  fixture(
    c(0, 0, 0), c(.2, .5, .8), c(.1, .5, .9),
    c(0, 0, 0), c(1 / 4, 1 / 3, 1), c(1 / 5, 1 / 4, 1 / 2)
  ),
  fixture(
    c(1, 1, 1), c(.2, .5, .8), c(.1, .5, .9),
    c(0, 2 / 3, 3 / 4), c(1, 1, 1), c(1 / 2, 3 / 4, 4 / 5)
  ),
  fixture(
    0, .2, c(0, .2, 1),
    c(0, 0, 0), c(1 / 2, 1 / 2, 1), c(1 / 3, 1 / 3, 1 / 2)
  ),
  fixture(
    1, .2, c(0, .2, 1),
    c(0, 1 / 2, 1 / 2), c(1, 1, 1), c(1 / 2, 2 / 3, 2 / 3)
  ),
  fixture(
    c(0, 1, 0), c(.4, .4, .4), c(0, .4, 1),
    c(0, 1 / 4, 1 / 4), c(1 / 2, 1 / 2, 1), c(1 / 3, 2 / 5, 4 / 7)
  ),
  fixture(
    c(0, 1), c(0, 1), c(0, .5, 1),
    c(0, 0, 1 / 2), c(1 / 2, 1, 1), c(1 / 3, 1 / 2, 2 / 3)
  )
)

for (case in fixtures) {
  calibrator <- expect_no_warning(venn_abers(case$truth, case$probability))
  actual <- predict(calibrator, case$newdata)
  stopifnot(
    inherits(calibrator, "venn_abers"),
    identical(names(actual), c("lower", "upper", "probability")),
    all(vapply(actual, is.double, FALSE)),
    max(abs(as.matrix(actual) - as.matrix(case$expected))) <= 1e-10,
    all(actual$lower <= actual$probability),
    all(actual$probability <= actual$upper),
    all(actual >= 0 & actual <= 1)
  )
}

calibrator <- venn_abers(c(0, 1, 0), c(.1, .2, .3))
ordered <- predict(calibrator, c(.4, .05, .2))
stopifnot(max(abs(as.matrix(ordered) - as.matrix(fixtures[[1L]]$expected[c(7, 1, 4), ]))) <= 1e-10)

logical_calibrator <- venn_abers(c(FALSE, TRUE), c(0L, 1L))
stopifnot(nrow(predict(logical_calibrator, c(1L, 0L))) == 2L)

empty <- predict(calibrator, numeric(0))
stopifnot(
  identical(names(empty), c("lower", "upper", "probability")),
  nrow(empty) == 0L,
  all(vapply(empty, is.double, FALSE))
)

expect_error(venn_abers(numeric(0), numeric(0)), "truth")
expect_error(venn_abers(c(0, 1), .5), "probability")
for (bad_truth in list("0", factor(0), list(0), 0 + 0i, c(0, NA), c(0, Inf), c(0, .5), matrix(c(0, 1)))) {
  expect_error(venn_abers(bad_truth, rep(.5, length(bad_truth))), "truth")
}
invalid_probabilities <- list(
  TRUE, "0.5", factor(.5), list(.5), .5 + 0i,
  NA_real_, NaN, Inf, -.1, 1.1, matrix(.5)
)
for (bad_probability in invalid_probabilities) {
  expect_error(venn_abers(0, bad_probability), "probability")
}

for (bad_newdata in invalid_probabilities) {
  expect_error(predict(calibrator, bad_newdata), "newdata")
}
expect_error(predict(calibrator, .5, unused = TRUE), "...")
expect_error(predict(calibrator, .5, NULL), "...")

printed <- capture.output(returned <- print(calibrator))
stopifnot(
  identical(printed, c(
    "<venn_abers>",
    "Calibration observations: 3",
    "Event observations: 1",
    "Unique probability knots: 3"
  )),
  identical(returned, calibrator)
)
