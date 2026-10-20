testthat::test_that("CORP reliability diagrams and Brier score decompositions", {
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
columns <- c("probability", "estimate", "count", "band_lower", "band_upper",
             "valid_replicates", "band", "level", "replicates", "seed")
components <- c("brier", "mcb", "dsc", "unc")

# PAV pools the descending events 1, 1, 0, 0 into one block, the tie at 0.3
# included, and keeps one row per unique probability in increasing order.
truth <- c(0, 1, 1, 0, 1)
probability <- c(.5, .3, .1, .3, .7)
drawn <- withVisible(corp_plot(truth, probability, band = "none"))
table <- drawn$value
assert_conditions(!drawn$visible, is.data.frame(table), identical(names(table), columns),
                  identical(table$probability, c(.1, .3, .5, .7)),
                  identical(table$estimate, c(.5, .5, .5, 1)),
                  identical(table$count, c(1L, 2L, 1L, 1L)),
                  identical(rownames(table), as.character(1:4)),
                  all(is.na(table$band_lower)), is.double(table$band_lower),
                  all(is.na(table$band_upper)), is.double(table$band_upper),
                  all(is.na(table$valid_replicates)), is.integer(table$valid_replicates),
                  identical(table$band, rep("none", 4L)), identical(table$level, rep(.9, 4L)),
                  identical(table$replicates, rep(1000L, 4L)), identical(table$seed, rep(NA_integer_, 4L)),
                  identical(graphics::par("mfrow"), layout))

# A tie split by its events pools into one estimate; logical truth is the event.
tied <- corp_plot(c(FALSE, FALSE, TRUE, FALSE, TRUE), c(.2, .2, .6, .6, .9), band = "none",
                  level = .8, replicates = 10, seed = -3)
assert_conditions(identical(tied$probability, c(.2, .6, .9)), identical(tied$estimate, c(0, .5, 1)),
                  identical(tied$count, c(2L, 2L, 1L)), identical(tied$level, rep(.8, 3L)),
                  identical(tied$replicates, rep(10L, 3L)), identical(tied$seed, rep(-3L, 3L)))
single <- corp_plot(1, .4, band = "none")
assert_conditions(identical(single$estimate, 1), identical(single$count, 1L))

# The decomposition by hand: Brier 0.122 against 0.1 for the PAV estimate
# (0, 0, 0.5, 0.5, 1) and 0.24 for the event rate 0.4.
decomposition <- withVisible(corp_decomposition_plot(c(0, 0, 1, 0, 1), c(.2, .2, .6, .6, .9)))
parts <- decomposition$value
assert_conditions(!decomposition$visible, is.data.frame(parts), identical(names(parts), components),
                  nrow(parts) == 1L,
                  isTRUE(all.equal(unlist(parts), c(brier = .122, mcb = .022, dsc = .14, unc = .24))),
                  isTRUE(all.equal(parts$brier, brier_score(c(0, 0, 1, 0, 1), c(.2, .2, .6, .6, .9)))))

# The identity holds up to rounding on continuous and discrete probabilities.
set.seed(20261020)
for (values in list(stats::runif(200), round(stats::runif(200), 1))) {
  events <- stats::rbinom(200, 1, values^2)
  parts <- corp_decomposition_plot(events, values)
  curve <- corp_plot(events, values, band = "none")
  assert_conditions(abs(parts$brier - (parts$mcb - parts$dsc + parts$unc)) < 1e-12,
                    parts$mcb > -1e-12, parts$dsc > -1e-12,
                    identical(curve$probability, sort(unique(values))),
                    sum(curve$count) == 200L, !is.unsorted(curve$estimate))
}

# Multiclass: every factor, even with two levels, evaluates each class
# against the rest on normalized rows, one panel per class in its own grid.
classes <- c("a", "b", "c")
truth <- factor(c("a", "b", "c", "a", "b", "c", "a", "a"), levels = classes)
probability <- matrix(c(.6, .2, .2, .2, .5, .3, .1, .3, .6, .4, .4, .2,
                        .3, .3, .4, .2, .2, .6, .5, .25, .25, .6, .2, .2),
                      ncol = 3, byrow = TRUE, dimnames = list(NULL, classes))
curves <- corp_plot(truth, probability, band = "none", seed = 7)
assert_conditions(identical(names(curves), c("class", columns)),
                  identical(levels(curves$class), classes), identical(unique(as.character(curves$class)), classes),
                  identical(rownames(curves), as.character(seq_len(nrow(curves)))),
                  identical(curves$seed, rep(7L, nrow(curves))),
                  identical(graphics::par("mfrow"), layout))
for (class in classes) {
  own <- curves[curves$class == class, columns]
  rownames(own) <- NULL
  assert_conditions(identical(own, corp_plot(truth == class, probability[, class], band = "none", seed = 7)))
}
parts <- corp_decomposition_plot(truth, probability)
assert_conditions(identical(names(parts), c("class", components)),
                  identical(parts$class, factor(classes, levels = classes)),
                  isTRUE(all.equal(sum(parts$brier), brier_score(truth, probability))),
                  all(abs(parts$brier - (parts$mcb - parts$dsc + parts$unc)) < 1e-12),
                  identical(graphics::par("mfrow"), layout))
for (class in classes) {
  own <- parts[parts$class == class, components]
  rownames(own) <- NULL
  assert_conditions(identical(own, corp_decomposition_plot(truth == class, probability[, class])))
}
two <- factor(c("no", "yes", "yes", "no"))
binary <- cbind(no = c(.8, .3, .4, .6), yes = c(.2, .7, .6, .4))
assert_conditions(identical(unique(as.character(corp_plot(two, binary, band = "none")$class)), c("no", "yes")),
                  identical(as.character(corp_decomposition_plot(two, binary)$class), c("no", "yes")))

# Graphical options override the defaults: a single panel leaves its
# coordinates, so `xlim` shows through `usr`.
corp_plot(c(0, 1, 1), c(.2, .5, .9), band = "none", xlim = c(.2, .8), main = "Own title")
assert_conditions(identical(graphics::par("usr")[1:2], c(.2, .8)))
corp_decomposition_plot(truth, probability, ylim = c(0, 2))
assert_conditions(identical(graphics::par("usr")[4], 2))

# A failing draw restores the grid as well.
error(corp_plot(truth, probability, band = "none", ylim = "bad"), "ylim")
assert_conditions(identical(graphics::par("mfrow"), layout))

# Inputs follow the scoring contract and its messages, without `na.rm`.
for (fun in list(function(...) corp_plot(..., band = "none"), corp_decomposition_plot)) {
  error(fun(c(0, 2), c(.1, .2)), "`truth` must be a logical or numeric vector containing only 0 and 1.")
  error(fun(c(0, NA), c(.1, .2)), "`truth` must be a logical or numeric vector containing only 0 and 1.")
  error(fun(numeric(), numeric()), "`truth` must be non-empty.")
  error(fun(c(0, 1), c(.1, 1.2)), "`probability` must be a numeric vector of finite values between 0 and 1.")
  error(fun(c(0, 1), c(.1, NA)), "`probability` must be a numeric vector of finite values between 0 and 1.")
  error(fun(c(0, 1), .1), "`probability` must have the same length as `truth`.")
  error(fun(factor(c("a", NA)), probability[1:2, ]), "`truth` must be a non-empty factor")
  error(fun(truth, unname(probability)), "`probability` column names must be non-empty, unique, and match the classes.")
  error(fun(truth, probability[-1L, ]), "`probability` must have one row per `truth` value.")
  error(fun(truth, probability * 2), "`probability` must be a numeric matrix of finite values between 0 and 1.")
}

# Every control is validated, also without a band.
for (bad in list("bootstrap", c("none", "confidence"), NA_character_, 1)) {
  error(corp_plot(c(0, 1), c(.1, .2), band = bad), "`band` must be one of: consistency, confidence, none.")
}
for (bad in list(0, 1, -.1, NA_real_, c(.8, .9), "0.9", Inf)) {
  error(corp_plot(c(0, 1), c(.1, .2), band = "none", level = bad),
        "`level` must be one number strictly between 0 and 1.")
}
for (bad in list(0, 1.5, -1, NA_real_, c(1000, 2000), "1000", Inf)) {
  error(corp_plot(c(0, 1), c(.1, .2), band = "none", replicates = bad),
        "`replicates` must be one finite whole number of at least 1.")
}
for (case in list(c(19, .9), c(1000, .999), c(1, .5))) {
  error(corp_plot(c(0, 1), c(.1, .2), band = "none", replicates = case[1L], level = case[2L]),
        "`replicates * (1 - level) / 2` must be at least 1; increase `replicates` or lower `level`.")
}
# Exactly one replicate beyond each quantile is enough.
assert_conditions(nrow(corp_plot(c(0, 1), c(.1, .2), band = "none", replicates = 20)) == 2L,
                  nrow(corp_plot(c(0, 1), c(.1, .2), band = "none", replicates = 2000, level = .999)) == 2L)
for (bad in list(1.5, NA_real_, c(1, 2), "1", .Machine$integer.max + 1, -.Machine$integer.max - 1)) {
  error(corp_plot(c(0, 1), c(.1, .2), band = "none", seed = bad),
        "`seed` must be NULL or one integer in R's seed range.")
}

# Bands are not computed yet; both stop clearly, including by default.
error(corp_plot(c(0, 1), c(.1, .2)), "`band = \"consistency\"` is not available yet; use `band = \"none\"`.")
error(corp_plot(c(0, 1), c(.1, .2), band = "confidence"),
      "`band = \"confidence\"` is not available yet; use `band = \"none\"`.")
})
