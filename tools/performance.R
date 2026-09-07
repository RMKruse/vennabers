# Run separately after installing the built artifact: Rscript tools/performance.R
# Release comparisons and peak-memory measurement belong to overall acceptance.
library(vennabers)

performance_environment <- paste(
  R.version.string, "on", R.version$platform, "under",
  paste(Sys.info()[c("sysname", "release", "machine")], collapse = " ")
)

set.seed(20260906)
truth <- sample(c(FALSE, TRUE), 100000L, replace = TRUE)
probability <- runif(100000L)
new_probability <- runif(100000L)

elapsed <- replicate(3L, system.time({
  calibrator <- venn_abers(truth, probability)
  prediction <- predict(calibrator, new_probability)
  stopifnot(nrow(prediction) == 100000L, all(is.finite(as.matrix(prediction))))
})[["elapsed"]])
median_elapsed <- median(elapsed)

cat("Performance environment:", performance_environment, "\n")
cat("Fit/predict observations: 100000 / 100000\n")
cat("Elapsed seconds:", paste(format(elapsed, digits = 4), collapse = ", "), "\n")
cat("Median seconds:", format(median_elapsed, digits = 4), "\n")
