# Small runnable check: Rscript --vanilla tools/test-migration-v09.R
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
root <- dirname(dirname(normalizePath(script)))
source(file.path(root, "tools", "migration-v09.R"))
details <- list(details = data.frame(row = 1:2, label = c("a", "b"), p = c(.2, .4)),
                postprocessing = list(Fold1 = list(coefficients = c(1, 2), input = "probability")))
same <- list(main = data.frame(.pred_a = c(.2, .4)), details = details)
shifted <- same
shifted$details$postprocessing$Fold1$coefficients <- c(1, 2 + 5e-8)
stopifnot(migration_max_diff(same, same) == 0,
  abs(migration_max_diff(same, shifted) - 5e-8) < 1e-15,
  is.na(migration_max_diff(same, list(main = data.frame(.pred_a = .2), details = details))))
accepted <- function(actual, tolerance = NULL) migration_compare(same, actual, "case", tolerance)$accepted
stopifnot(accepted(same), !accepted(shifted), accepted(shifted, 1e-7), !accepted(shifted, 1e-8))
shifted$details$postprocessing$Fold1$coefficients <- c(1, 3)
stopifnot(!accepted(shifted, 1e-7))
tuning <- list(elapsed_seconds = 1, native = 2, steps = list(a = 1),
  param_info = data.frame(id = "penalty", object = I(list(list(transform = function(x) x)))))
cleaned <- migration_tuning(tuning)
stopifnot(identical(names(cleaned), c("steps", "param_info")), is.null(cleaned$param_info$object[[1L]]$transform))
cat("Migration comparison checks passed.\n")
