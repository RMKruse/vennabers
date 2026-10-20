testthat::test_that("fit diagnoses draw binary and Cross calibration maps", {
library(vennabers)
source(system.file("examples", "assertions.R", package = "vennabers"))
error <- function(expr, pattern) {
  result <- tryCatch({force(expr); NULL}, error = identity)
  stopifnot(inherits(result, "error"), grepl(pattern, conditionMessage(result), fixed = TRUE))
}
path <- tempfile(fileext = ".pdf")
grDevices::pdf(path)
on.exit({ grDevices::dev.off(); unlink(path) })
layout <- graphics::par("mfrow")
values <- c("lower", "upper", "probability")

# Binary: one row per knot plus both range ends, valued exactly by predict().
truth <- c(0, 1, 0, 1, 1, 0, 1, 1)
probability <- c(.1, .2, .3, .4, .4, .6, .7, .9)
fit <- venn_abers(truth, probability)
drawn <- withVisible(plot(fit))
table <- drawn$value
assert_conditions(!drawn$visible, is.data.frame(table),
                  identical(names(table), c("score", values, "width")),
                  identical(table$score, c(0, fit$knots, 1)),
                  identical(table[values], predict(fit, table$score)),
                  identical(table$width, table$upper - table$lower),
                  identical(graphics::par("mfrow"), layout))

# The table does not depend on `which`; both diagrams draw map before width
# in their own grid and leave the caller's layout in place.
# The width panel, drawn last, keeps its own axis: the widest gap between
# knots (upper of the right knot minus lower of the left one) plus 5 %.
assert_conditions(identical(graphics::par("usr")[3:4], c(0, 1)))
gap <- max(table$upper[-1L] - table$lower[-nrow(table)])
for (which in list("width", c("map", "width"), c("width", "map"))) {
  assert_conditions(identical(plot(fit, which = which), table),
                    identical(graphics::par("mfrow"), layout),
                    isTRUE(all.equal(graphics::par("usr")[3:4], c(0, 1.05 * gap))))
}
brier <- plot(fit, "map", loss = "brier")
assert_conditions(identical(brier[values], predict(fit, brier$score, loss = "brier")))

# Knots at the range ends are not repeated.
edges <- plot(venn_abers(c(0, 1, 1), c(0, .5, 1)))
assert_conditions(identical(edges$score, c(0, .5, 1)))

# Graphical options override the defaults: a single panel leaves its
# coordinates, so `xlim` shows through `usr`.
plot(fit, xlim = c(.2, .8), main = "Own title")
assert_conditions(identical(graphics::par("usr")[1:2], c(.2, .8)))

# Cross: stored fold IDs lead, folds keep their stored order, and each fold
# map equals its own calibrator.
fold <- c(2, 1, 2, 1, 2, 1, 2, 1)
cross <- cross_venn_abers(truth, probability, fold = fold)
for (loss in c("log", "brier")) {
  maps <- plot(cross, c("width", "map"), loss = loss)
  assert_conditions(identical(names(maps), c("fold", "score", values, "width")),
                    identical(unique(maps$fold), cross$folds), identical(cross$folds, c("2", "1")),
                    identical(rownames(maps), as.character(seq_len(nrow(maps)))),
                    identical(maps$width, maps$upper - maps$lower),
                    identical(graphics::par("mfrow"), layout))
  for (id in cross$folds) {
    calibrator <- cross$calibrators[[id]]
    own <- maps[maps$fold == id, ]
    assert_conditions(identical(own$score, c(0, calibrator$knots, 1)),
                      identical(as.list(own[values]), as.list(predict(calibrator, own$score, loss = loss))))
  }
}

# A failing draw restores the grid as well.
error(plot(fit, c("map", "width"), ylim = "bad"), "ylim")
assert_conditions(identical(graphics::par("mfrow"), layout))

# Choices are validated like other options.
for (bad in list(character(), c("map", "map"), "fit", NA_character_, c("map", NA), 1, list("map"))) {
  error(plot(fit, which = bad), "`which` must be one or more distinct values of: map, width.")
  error(plot(cross, which = bad), "`which` must be one or more distinct values of: map, width.")
}
for (bad in list("hinge", c("log", "brier"), NA_character_, 1)) {
  error(plot(fit, loss = bad), "`loss` must be one of: log, brier.")
  error(plot(cross, loss = bad), "`loss` must be one of: log, brier.")
}

# Fits without a stored calibration map stop clearly.
stored <- "`x` has no stored calibration map (`knots`, `lower`, `upper`); refit it with vennabers 1.0.0."
for (field in c("knots", "lower", "upper")) {
  old <- fit
  old[[field]] <- NULL
  error(plot(old), stored)
  old_cross <- cross
  old_cross$calibrators[[2L]][[field]] <- NULL
  error(plot(old_cross), stored)
}
old_cross <- cross
old_cross$calibrators <- NULL
error(plot(old_cross), stored)

# Multiclass fits are not part of the binary diagnoses yet.
classes <- c("a", "b", "c")
class_truth <- factor(rep(classes, 3), levels = classes)
class_probability <- matrix(c(.6, .2, .2, .2, .6, .2, .2, .2, .6), 9, 3, byrow = TRUE,
                            dimnames = list(NULL, classes))
error(plot(venn_abers(class_truth, class_probability)), "multiclass")
error(plot(cross_venn_abers(class_truth, class_probability, fold = rep(1:3, each = 3))), "multiclass")
assert_conditions(identical(graphics::par("mfrow"), layout))

testthat::expect_true(TRUE)
})
