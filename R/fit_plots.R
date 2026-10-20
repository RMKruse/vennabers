#' @export
plot.venn_abers <- function(x, which = "map", loss = "log", ...) {
  which <- .plot_which(which)
  .validate_choice(loss, c("log", "brier"), "loss")
  if (!is.null(x$classes)) return(.plot_multiclass(x, which, loss, ...))
  .plot_fit_panels(list(.fit_map_table(x, loss)), "", which, loss, ...)
}

#' @export
plot.cross_venn_abers <- function(x, which = "map", loss = "log", ...) {
  which <- .plot_which(which)
  .validate_choice(loss, c("log", "brier"), "loss")
  if (!is.null(x$classes)) return(.plot_multiclass(x, which, loss, ...))
  .plot_fit_panels(list(.fit_map_table(x, loss)), "", which, loss, ...)
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

.stop_stored_map <- function() {
  stop("`x` has no stored calibration map (`knots`, `lower`, `upper`); ",
       "refit it with vennabers 1.0.0.", call. = FALSE)
}

.validate_stored_map <- function(calibrator) {
  if (!all(c("knots", "lower", "upper") %in% names(calibrator))) .stop_stored_map()
}

# The map table of a binary calibrator, Cross fits leading with their stored
# fold IDs and stacking the map of every fold calibrator.
.fit_map_table <- function(x, loss) {
  if (!inherits(x, "cross_venn_abers")) {
    .validate_stored_map(x)
    return(.map_table(x, loss))
  }
  if (is.null(x$folds) || length(x$calibrators) != length(x$folds)) .stop_stored_map()
  for (calibrator in x$calibrators) .validate_stored_map(calibrator)
  tables <- lapply(seq_along(x$folds), function(k) {
    table <- .map_table(x$calibrators[[k]], loss)
    data.frame(fold = rep(x$folds[k], nrow(table)), table)
  })
  do.call(rbind, tables)
}

# One panel per OvR class or OvO pair; identity columns follow the fold and
# precede the values, named as in venn_abers_details(). Each subproblem
# stores its folds in the order they occur among its own rows, so Cross folds
# are put in the stored order of the fit to keep their colors across panels.
.plot_multiclass <- function(x, which, loss, ...) {
  ovr <- identical(x$method, "ovr")
  problems <- if (ovr) as.list(x$classes) else x$pairs
  if (length(x$calibrators) != length(problems)) .stop_stored_map()
  tables <- lapply(seq_along(problems), function(i) {
    table <- .fit_map_table(x$calibrators[[i]], loss)
    if (!is.null(table$fold)) table <- table[order(match(table$fold, x$folds)), ]
    problem <- problems[[i]]
    n <- nrow(table)
    identity <- if (ovr) data.frame(class = rep(problem, n)) else
      data.frame(class_1 = rep(problem[1L], n), class_2 = rep(problem[2L], n))
    lead <- names(table) == "fold"
    data.frame(table[lead], identity, table[!lead])
  })
  titles <- vapply(problems, paste, "", collapse = " vs ")
  .plot_fit_panels(tables, paste0(": ", titles), which, loss, ...)
}

# One row per knot plus the range ends, valued by predict() so the knot
# convention holds exactly.
.map_table <- function(calibrator, loss) {
  score <- sort(unique(c(0, calibrator$knots, 1)))
  map <- stats::predict(calibrator, score, loss = loss)
  data.frame(score = score, map, width = map$upper - map$lower)
}

# Draws the chosen diagrams of each map table, one panel each, overlaying fold
# maps. Tables fill a grid row by row, and below each row of maps follow the
# widths of the same tables. Returns the stacked tables invisibly whatever
# `which` holds.
.plot_fit_panels <- function(tables, titles, which, loss, ...) {
  rows <- ceiling(sqrt(length(tables)))
  columns <- ceiling(length(tables) / rows)
  if (length(tables) * length(which) > 1L) {
    old <- graphics::par(mfrow = c(rows * length(which), columns))
    on.exit(graphics::par(old))
  }
  for (start in seq(1L, length(tables), by = columns)) {
    row <- start:min(start + columns - 1L, length(tables))
    for (diagram in which) {
      for (i in row) .plot_fit_diagram(tables[[i]], titles[i], diagram, loss, ...)
      if (diagram != which[length(which)]) for (i in seq_len(columns - length(row))) graphics::plot.new()
    }
  }
  table <- do.call(rbind, tables)
  rownames(table) <- NULL
  invisible(table)
}

.plot_fit_diagram <- function(table, title, diagram, loss, ...) {
  maps <- if (is.null(table$fold)) list(table) else split(table, factor(table$fold, unique(table$fold)))
  paths <- lapply(maps, .map_paths, loss = loss)
  colors <- if (length(maps) > 1L) grDevices::hcl.colors(length(maps), "Dark 3") else "black"
  width <- max(unlist(lapply(paths, function(path) path$width$y)), .Machine$double.eps)
  options <- utils::modifyList(list(
    x = 0:1, y = 0:1, type = "n",
    xlim = c(0, 1), ylim = c(0, if (diagram == "map") 1 else 1.05 * width),
    xaxs = "i", yaxs = "i",
    xlab = "Uncalibrated probability",
    ylab = if (diagram == "map") "Calibrated probability" else "Upper minus lower",
    main = paste0(if (diagram == "map") "Calibration map" else "VA width", title)
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
