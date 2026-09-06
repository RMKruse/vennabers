# Run from the package root after `R CMD INSTALL .`.
library(vennabers)

reference_machine <- paste(
  "Apple MacBook Pro (Mac17,9), Apple M5 Pro (15 cores), 24 GB RAM;",
  "macOS 26.6.2; R 4.6.1"
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

cat("Reference machine:", reference_machine, "\n")
cat("Fit/predict observations: 100000 / 100000\n")
cat("Elapsed seconds:", paste(format(elapsed, digits = 4), collapse = ", "), "\n")
cat("Median seconds:", format(median_elapsed, digits = 4), "\n")
stopifnot(median_elapsed <= 10)
