# Inputs and vennabers outputs for the counter-comparisons with other
# Venn-Abers software (inst/PARITY.md, "Counter-comparisons"). Reads the
# stored classification fixtures and writes, as CSV with hexadecimal doubles:
# - binary-input-calibration.csv, binary-input-new.csv: 707 binary
#   calibration sets (every fold of the Cross fixtures and the 100 randomized
#   single sets) with their new scores;
# - multiclass-input-calibration.csv, multiclass-input-new.csv: the OvO/OvR
#   cases with a shared two-fold plan that alternates within each class;
#   fold A predicts the stored inputs, fold B their normalized squares;
# - vb-binary-inductive.csv, vb-binary-cross.csv, vb-multiclass.csv,
#   vb-multiclass-parts.csv: the vennabers results for precision NULL, 0, 2,
#   -1 and 4, both losses and class decisions;
# - edge-input-calibration.csv, edge-input-new.csv, vb-binary-edge.csv: 13
#   constructed binary calibration sets (ties, one label only, one score, a
#   single point, scores at 0 and 1) whose new scores are every calibration
#   score, the midpoints between them and points outside their range, with
#   the vennabers results for precision NULL;
# - vennabers-environment.txt.
# Run from anywhere; the libraries are optional and put before the site
# library, for example one holding the package built from this checkout:
#   Rscript --vanilla tools/counter-comparison-inputs.R <out> [<library> ...]
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("Usage: counter-comparison-inputs.R <out> [<library> ...]")
out <- args[[1L]]
libraries <- args[-1L]
if (length(libraries)) .libPaths(c(normalizePath(libraries, mustWork = TRUE), .libPaths()))
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
extdata <- file.path(dirname(dirname(normalizePath(script))), "tests", "testthat", "extdata")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
suppressPackageStartupMessages(library(vennabers))

fixture <- function(name) read.csv(file.path(extdata, name), comment.char = "#", stringsAsFactors = FALSE)
hex <- function(x) ifelse(is.na(x), "", sprintf("%a", x))
write_hex <- function(data, name) {
  numeric <- vapply(data, is.double, TRUE)
  data[numeric] <- lapply(data[numeric], hex)
  write.csv(data, file.path(out, name), row.names = FALSE, quote = FALSE)
}
precisions <- c("none", "0", "2", "-1", "4")
as_precision <- function(setting) if (setting == "none") NULL else as.numeric(setting)

# Binary Inductive: every (case, fold) of the Cross fixtures plus the 100
# randomized single calibration sets.
calibration <- fixture("cross-calibration.csv")
prediction <- fixture("cross-predictions.csv")
randomized_cal <- fixture("randomized-calibration.csv")
randomized_pred <- fixture("randomized-predictions.csv")
sets <- c(
  lapply(split(seq_len(nrow(calibration)), paste(calibration$case_id, calibration$fold, sep = "|")), function(i) {
    key <- paste(calibration$case_id[i[1]], calibration$fold[i[1]], sep = "|")
    j <- which(paste(prediction$case_id, prediction$fold, sep = "|") == key)
    list(key = key, truth = calibration$truth[i], score = calibration$probability[i], new = prediction$probability[j])
  }),
  lapply(split(seq_len(nrow(randomized_cal)), randomized_cal$case_id), function(i) {
    id <- randomized_cal$case_id[i[1]]
    list(key = paste0("randomized_", id, "|single"), truth = randomized_cal$truth[i],
         score = randomized_cal$probability[i], new = randomized_pred$probability[randomized_pred$case_id == id])
  })
)
binary_in_cal <- do.call(rbind, lapply(sets, function(s)
  data.frame(key = s$key, row = seq_along(s$truth), truth = s$truth, score = s$score)))
binary_in_new <- do.call(rbind, lapply(sets, function(s)
  data.frame(key = s$key, row = seq_along(s$new), score = s$new)))
write_hex(binary_in_cal, "binary-input-calibration.csv")
write_hex(binary_in_new, "binary-input-new.csv")
binary <- do.call(rbind, lapply(precisions, function(setting) do.call(rbind, lapply(sets, function(s) {
  fit <- venn_abers(s$truth, s$score, as_precision(setting))
  log <- predict(fit, s$new, loss = "log")
  brier <- predict(fit, s$new, loss = "brier")
  data.frame(precision = setting, key = s$key, row = seq_along(s$new), lower = log$lower, upper = log$upper,
             log = log$probability, brier = brier$probability,
             class_log = as.integer(predict(fit, s$new, loss = "log", type = "class")),
             class_brier = as.integer(predict(fit, s$new, loss = "brier", type = "class")))
}))))
write_hex(binary, "vb-binary-inductive.csv")

# Binary Cross over the stored fold partitions.
cross <- do.call(rbind, lapply(precisions, function(setting) do.call(rbind, lapply(unique(calibration$case_id), function(id) {
  cal <- calibration[calibration$case_id == id, ]
  pred <- prediction[prediction$case_id == id, ]
  folds <- unique(cal$fold)
  input <- sapply(folds, function(f) pred$probability[pred$fold == f])
  if (!is.matrix(input)) input <- matrix(input, nrow = 1, dimnames = list(NULL, folds))
  fit <- cross_venn_abers(cal$truth, cal$probability, cal$fold, as_precision(setting))
  log <- predict(fit, input, loss = "log")
  brier <- predict(fit, input, loss = "brier")
  data.frame(precision = setting, case_id = id, row = seq_len(nrow(input)), log = log$probability,
             brier = brier$probability,
             class_log = as.integer(predict(fit, input, loss = "log", type = "class")),
             class_brier = as.integer(predict(fit, input, loss = "brier", type = "class")))
}))))
write_hex(cross, "vb-binary-cross.csv")

# Binary edge sets, precision NULL only. Seeded draws give labels that follow
# the score; the rest is fixed by hand.
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
set.seed(20261028)
draw <- function(n, digits = NA, low = 0, high = 1) {
  score <- runif(n, low, high)
  if (!is.na(digits)) score <- round(score, digits)
  list(truth = rbinom(n, 1, score), score = score)
}
edge_sets <- list(
  ties_1_digit = draw(60, 1),
  ties_2_digits = draw(2000, 2),
  ties_3_digits = draw(500, 3),
  distinct = draw(40),
  narrow_range = draw(30, NA, 0.4, 0.6),
  label_0_only = list(truth = rep(0, 25), score = round(runif(25), 2)),
  label_1_only = list(truth = rep(1, 25), score = round(runif(25), 2)),
  single_0 = list(truth = 0, score = 0.3),
  single_1 = list(truth = 1, score = 0.7),
  one_score = list(truth = rep(0:1, 5), score = rep(0.5, 10)),
  two_scores = list(truth = c(0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1), score = rep(c(0.25, 0.75), each = 6)),
  bounds = list(truth = c(0, 1, 0, 1, 0, 1, 1, 0), score = c(0, 0, 0.2, 0.5, 0.5, 0.8, 1, 1)),
  reversed = list(truth = rep(1:0, each = 10), score = (1:20) / 21)
)
edge_new <- function(score) {
  s <- sort(unique(score))
  mid <- (s[-1] + s[-length(s)]) / 2
  sort(unique(c(0, 0.5, 1, s, mid, s[1] / 2, (s[length(s)] + 1) / 2)))
}
for (name in names(edge_sets)) edge_sets[[name]]$new <- edge_new(edge_sets[[name]]$score)
write_hex(do.call(rbind, lapply(names(edge_sets), function(name) with(edge_sets[[name]],
  data.frame(key = name, row = seq_along(truth), truth = as.double(truth), score = score)))),
  "edge-input-calibration.csv")
write_hex(do.call(rbind, lapply(names(edge_sets), function(name)
  data.frame(key = name, row = seq_along(edge_sets[[name]]$new), score = edge_sets[[name]]$new))),
  "edge-input-new.csv")
write_hex(do.call(rbind, lapply(names(edge_sets), function(name) with(edge_sets[[name]], {
  fit <- venn_abers(truth, score)
  log <- predict(fit, new, loss = "log")
  data.frame(key = name, row = seq_along(new), lower = log$lower, upper = log$upper, log = log$probability,
             brier = predict(fit, new, loss = "brier")$probability,
             class_log = as.integer(predict(fit, new, loss = "log", type = "class")),
             class_brier = as.integer(predict(fit, new, loss = "brier", type = "class")))
}))), "vb-binary-edge.csv")

# Manual multiclass OvO and OvR, Inductive and Cross. Matrices are padded to
# four columns so that every case fits one table.
mc_cal <- fixture("ovo-calibration.csv")
mc_new <- fixture("ovo-input.csv")
pad <- function(m) {
  full <- matrix(NA_real_, nrow(m), 4, dimnames = list(NULL, paste0("p", 1:4)))
  full[, seq_len(ncol(m))] <- m
  as.data.frame(full)
}
decode <- function(data, k) {
  m <- matrix(as.numeric(as.matrix(data[paste0("p", seq_len(k))])), nrow(data), k)
  colnames(m) <- paste0("c", seq_len(k))
  m
}
mc_inputs_cal <- list()
mc_inputs_new <- list()
mc_out <- list()
mc_parts <- list()
for (id in unique(mc_cal$case_id)) {
  cal <- mc_cal[mc_cal$case_id == id, ]
  k <- cal$classes[1]
  p <- decode(cal, k)
  xa <- decode(mc_new[mc_new$case_id == id, ], k)
  xb <- xa^2 / rowSums(xa^2)
  truth <- factor(paste0("c", cal$truth), levels = colnames(p))
  fold <- character(nrow(p))
  for (cl in levels(truth)) {
    rows <- which(truth == cl)
    stopifnot(length(rows) >= 2)
    fold[rows] <- rep_len(c("A", "B"), length(rows))
  }
  mc_inputs_cal[[id]] <- data.frame(case_id = id, classes = k, row = seq_len(nrow(p)), truth = cal$truth, fold = fold,
                                    pad(p))
  mc_inputs_new[[id]] <- rbind(
    data.frame(case_id = id, classes = k, fold = "A", row = seq_len(nrow(xa)), pad(xa)),
    data.frame(case_id = id, classes = k, fold = "B", row = seq_len(nrow(xb)), pad(xb)))
  for (method in c("ovo", "ovr")) for (setting in precisions) {
    fits <- list(inductive = venn_abers(truth, p, as_precision(setting), method = method),
                 cross = cross_venn_abers(truth, p, fold, as_precision(setting), method = method))
    news <- list(inductive = xa, cross = list(A = xa, B = xb))
    for (procedure in names(fits)) for (loss in c("log", "brier")) {
      details <- predict(fits[[procedure]], news[[procedure]], loss = loss, type = "details")
      probs <- details$prediction
      cls <- as.integer(predict(fits[[procedure]], news[[procedure]], loss = loss, type = "class"))
      tag <- paste(id, method, setting, procedure, loss, sep = "|")
      full <- matrix(NA_real_, nrow(probs), 4)
      full[, seq_len(k)] <- probs
      mc_out[[tag]] <- data.frame(case_id = id, method = method, precision = setting, procedure = procedure, loss = loss,
                                  row = seq_len(nrow(probs)), class = cls,
                                  p1 = full[, 1], p2 = full[, 2], p3 = full[, 3], p4 = full[, 4])
      parts <- details[[2L]]
      if (is.null(parts$fold)) parts$fold <- "single"
      if (is.null(parts$non_event)) parts$non_event <- NA_character_
      mc_parts[[tag]] <- data.frame(case_id = id, method = method, precision = setting, procedure = procedure, loss = loss,
                                    fold = parts$fold, row = parts$row,
                                    non_event = as.integer(sub("c", "", parts$non_event)),
                                    event = as.integer(sub("c", "", parts$event)),
                                    lower = parts$lower, upper = parts$upper, probability = parts$probability)
    }
  }
}
write_hex(do.call(rbind, mc_inputs_cal), "multiclass-input-calibration.csv")
write_hex(do.call(rbind, mc_inputs_new), "multiclass-input-new.csv")
write_hex(do.call(rbind, mc_out), "vb-multiclass.csv")
write_hex(do.call(rbind, mc_parts), "vb-multiclass-parts.csv")

writeLines(c(R.version.string, paste("vennabers", packageVersion("vennabers"), "from", find.package("vennabers")),
             paste("platform", R.version$platform)), file.path(out, "vennabers-environment.txt"))
cat(sprintf("%d binary calibration sets, %d edge sets, %d multiclass cases written to %s\n", length(sets),
            length(edge_sets), length(mc_inputs_cal), out))
