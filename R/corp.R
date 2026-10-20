#' @export
corp_plot <- function(truth, probability, band = "consistency", level = 0.9,
                      replicates = 1000, seed = NULL, ...) {
  probability <- .validate_corp_input(truth, probability)
  .validate_choice(band, c("consistency", "confidence", "none"), "band")
  if (!.is_proportion(level)) {
    stop("`level` must be one number strictly between 0 and 1.", call. = FALSE)
  }
  if (!.is_count(replicates)) {
    stop("`replicates` must be one finite whole number of at least 1.", call. = FALSE)
  }
  # Each band quantile needs a replicate beyond it. The tolerance keeps exact
  # boundaries such as 20 replicates at level 0.9, where 1 - 0.9 < 0.1.
  if (replicates * (1 - level) / 2 < 1 - 1e-10) {
    stop("`replicates * (1 - level) / 2` must be at least 1; increase `replicates` or lower `level`.",
         call. = FALSE)
  }
  if (!is.null(seed) && !.is_count(seed, -.Machine$integer.max)) {
    stop("`seed` must be NULL or one integer in R's seed range.", call. = FALSE)
  }
  if (band != "none") {
    stop("`band = \"", band, "\"` is not available yet; use `band = \"none\"`.", call. = FALSE)
  }
  controls <- list(band = band, level = level, replicates = as.integer(replicates),
                   seed = if (is.null(seed)) NA_integer_ else as.integer(seed))
  .corp_panels(truth, probability, "CORP reliability", function(truth, probability, main) {
    table <- .corp_table(truth, probability, controls)
    .corp_draw(table, utils::modifyList(list(main = main), list(...)))
    table
  })
}

#' @export
corp_decomposition_plot <- function(truth, probability, ...) {
  probability <- .validate_corp_input(truth, probability)
  if (is.factor(truth)) {
    classes <- levels(truth)
    rows <- lapply(classes, function(class) .corp_decomposition(truth == class, probability[, class]))
    table <- data.frame(class = factor(classes, levels = classes), do.call(rbind, rows))
    height <- as.matrix(table[c("mcb", "dsc", "unc")])
    # The class legend takes rows of up to five classes in a strip above the
    # tallest bar.
    columns <- min(length(classes), 5L)
    defaults <- list(beside = TRUE, legend.text = classes,
                     col = grDevices::hcl.colors(length(classes), "Dark 3"),
                     args.legend = list(x = "top", ncol = columns, bty = "n"))
    if (max(height) > 0) {
      defaults$ylim <- c(0, (1 + .12 * ceiling(length(classes) / columns)) * max(height))
    }
  } else {
    table <- .corp_decomposition(truth, probability)
    height <- unlist(table[c("mcb", "dsc", "unc")])
    defaults <- list()
  }
  # Groups are the components; multiclass bars within a group are the classes.
  options <- utils::modifyList(c(defaults, list(
    names.arg = c("MCB", "DSC", "UNC"),
    ylab = "Brier score component",
    main = "CORP Brier score decomposition"
  )), list(...))
  options$height <- unname(height)
  do.call(graphics::barplot, options)
  invisible(table)
}

# Truth and probability under the scoring contract; multiclass returns the
# normalized class matrix.
.validate_corp_input <- function(truth, probability) {
  if (is.factor(truth)) return(.validate_multiclass_input(truth, probability))
  .validate_binary_input(truth, probability)
  probability
}

# One table per panel: binary draws one panel, multiclass one per class
# against the rest in its own grid, each table led by `class`.
.corp_panels <- function(truth, probability, title, panel) {
  if (!is.factor(truth)) return(invisible(panel(truth, probability, title)))
  classes <- levels(truth)
  old <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old))
  rows <- ceiling(sqrt(length(classes)))
  graphics::par(mfrow = c(rows, ceiling(length(classes) / rows)))
  tables <- lapply(classes, function(class) {
    table <- panel(truth == class, probability[, class], paste0("CORP: ", class))
    data.frame(class = factor(rep(class, nrow(table)), levels = classes), table)
  })
  invisible(do.call(rbind, tables))
}

# The CORP estimate: the PAV fit of the events on the probabilities, one row
# per unique probability in increasing order. stats::isoreg orders tied
# probabilities by decreasing event, a run that PAV pools into one block, so
# tied probabilities share one estimate.
.corp_pav <- function(truth, probability) {
  fit <- stats::isoreg(probability, as.numeric(truth))
  sorted <- if (fit$isOrd) probability else probability[fit$ord]
  first <- !duplicated(sorted)
  data.frame(probability = sorted[first], estimate = fit$yf[first],
             count = tabulate(cumsum(first)))
}

.corp_table <- function(truth, probability, controls) {
  table <- .corp_pav(truth, probability)
  n <- nrow(table)
  data.frame(table, band_lower = rep(NA_real_, n), band_upper = rep(NA_real_, n),
             valid_replicates = rep(NA_integer_, n), lapply(controls, rep, n))
}

.corp_draw <- function(table, graphical) {
  options <- utils::modifyList(list(
    type = "s",
    xlim = c(0, 1),
    ylim = c(0, 1),
    xaxs = "i",
    yaxs = "i",
    xlab = "Predicted probability",
    ylab = "Conditional event probability"
  ), graphical)
  options$x <- table$probability
  options$y <- table$estimate
  do.call(graphics::plot, options)
  graphics::abline(a = 0, b = 1, lty = 2)
}

# The CORP decomposition of the binary Brier score into miscalibration (MCB),
# discrimination (DSC) and uncertainty (UNC), against the PAV estimate on the
# same pairs and the constant event rate.
.corp_decomposition <- function(truth, probability) {
  truth <- as.numeric(truth)
  pav <- .corp_pav(truth, probability)
  estimate <- pav$estimate[match(probability, pav$probability)]
  brier <- mean((truth - probability)^2)
  pooled <- mean((truth - estimate)^2)
  unc <- mean((truth - mean(truth))^2)
  data.frame(brier = brier, mcb = brier - pooled, dsc = unc - pooled, unc = unc)
}
