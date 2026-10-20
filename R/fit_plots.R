#' @export
plot.venn_abers <- function(x, which = "map", loss = "log", ...) {
  which <- .plot_which(which)
  .validate_choice(loss, c("log", "brier"), "loss")
  .stop_multiclass_plot(x)
  .validate_stored_map(x)
  .plot_fit_panels(.map_table(x, loss), which, loss, ...)
}

#' @export
plot.cross_venn_abers <- function(x, which = "map", loss = "log", ...) {
  which <- .plot_which(which)
  .validate_choice(loss, c("log", "brier"), "loss")
  .stop_multiclass_plot(x)
  if (is.null(x$folds) || length(x$calibrators) != length(x$folds)) .stop_stored_map()
  for (calibrator in x$calibrators) .validate_stored_map(calibrator)
  tables <- lapply(seq_along(x$folds), function(k) {
    table <- .map_table(x$calibrators[[k]], loss)
    data.frame(fold = rep(x$folds[k], nrow(table)), table)
  })
  .plot_fit_panels(do.call(rbind, tables), which, loss, ...)
}

# The diagrams of a fit diagnosis, always drawn map before width.
.plot_which <- function(which) {
  choices <- c("map", "width")
  if (!is.character(which) || !is.vector(which) || !length(which) ||
      anyNA(which) || anyDuplicated(which) || !all(which %in% choices)) {
    stop("`which` must be one or more distinct values of: ",
         paste(choices, collapse = ", "), ".", call. = FALSE)
  }
  choices[choices %in% which]
}

.stop_multiclass_plot <- function(x) {
  if (!is.null(x$classes)) {
    stop("`plot()` does not support multiclass calibrators yet.", call. = FALSE)
  }
}

.stop_stored_map <- function() {
  stop("`x` has no stored calibration map (`knots`, `lower`, `upper`); ",
       "refit it with vennabers 1.0.0.", call. = FALSE)
}

.validate_stored_map <- function(calibrator) {
  if (!all(c("knots", "lower", "upper") %in% names(calibrator))) .stop_stored_map()
}

# One row per knot plus the range ends, valued by predict() so the knot
# convention holds exactly.
.map_table <- function(calibrator, loss) {
  score <- sort(unique(c(0, calibrator$knots, 1)))
  map <- stats::predict(calibrator, score, loss = loss)
  data.frame(score = score, map, width = map$upper - map$lower)
}

# Draws the chosen diagrams of one map table, one panel each, overlaying
# fold maps, and returns the table invisibly whatever `which` holds.
.plot_fit_panels <- function(table, which, loss, ...) {
  if (length(which) > 1L) {
    old <- graphics::par(mfrow = c(length(which), 1L))
    on.exit(graphics::par(old))
  }
  maps <- if (is.null(table$fold)) list(table) else split(table, factor(table$fold, unique(table$fold)))
  paths <- lapply(maps, .map_paths, loss = loss)
  colors <- if (length(maps) > 1L) grDevices::hcl.colors(length(maps), "Dark 3") else "black"
  width <- max(unlist(lapply(paths, function(path) path$width$y)), .Machine$double.eps)
  for (diagram in which) {
    options <- utils::modifyList(list(
      x = 0:1, y = 0:1, type = "n",
      xlim = c(0, 1), ylim = c(0, if (diagram == "map") 1 else 1.05 * width),
      xaxs = "i", yaxs = "i",
      xlab = "Uncalibrated probability",
      ylab = if (diagram == "map") "Calibrated probability" else "Upper minus lower",
      main = if (diagram == "map") "Calibration map" else "VA width"
    ), list(...))
    do.call(graphics::plot, options)
    if (diagram == "map") graphics::abline(a = 0, b = 1, lty = 3, col = "grey60")
    for (k in seq_along(paths)) {
      curves <- if (diagram == "map") paths[[k]][c("lower", "upper", "probability")] else paths[[k]]["width"]
      for (curve in names(curves)) {
        graphics::lines(curves[[curve]], col = colors[k], lty = if (curve == "probability") 2 else 1)
      }
    }
    .fit_legend(diagram, names(maps), colors)
  }
  invisible(table)
}

# Exact drawing paths of a map table. Between neighbouring rows the lower
# value of the left row and the upper value of the right row hold, so each
# curve is constant there and jumps vertically to its value at a knot.
.map_paths <- function(map, loss) {
  last <- nrow(map)
  lower <- map$lower[-last]
  upper <- map$upper[-1L]
  between <- list(lower = lower, upper = upper,
                  probability = .regularized_probability(lower, upper, loss),
                  width = upper - lower)
  x <- c(rbind(map$score[-last], map$score[-last], map$score[-1L]), map$score[last])
  lapply(stats::setNames(names(between), names(between)), function(curve) {
    list(x = x, y = c(rbind(map[[curve]][-last], between[[curve]], between[[curve]]), map[[curve]][last]))
  })
}

.fit_legend <- function(diagram, folds, colors) {
  if (length(folds)) folds <- paste("Fold", folds)
  if (diagram == "map") {
    labels <- c("VA bounds", "Regularized probability")
    graphics::legend("topleft", c(labels, folds), lty = c(1, 2, rep(1, length(folds))),
                     col = c("black", "black", if (length(folds)) colors), bty = "n", cex = .8)
  } else if (length(folds)) {
    graphics::legend("topright", folds, lty = 1, col = colors, bty = "n", cex = .8)
  }
}
