plan <- read.csv("tools/evidence-v05/ci-final/benchmarks/plan.csv")
rows <- list()
for (id in plan$case[!grepl("^workflow_", plan$case)]) {
  a <- readRDS(file.path("tools/evidence-v05/ci-final/benchmarks", paste0(id, "-input.rds")))
  b <- readRDS(file.path(".scratch/v06/final-benchmark", paste0(id, "-input.rds")))
  for (field in c("probability", "prediction", "newdata")) {
    x <- unlist(a[[field]]); y <- unlist(b[[field]])
    if (!length(x)) next
    stopifnot(length(x) == length(y))
    rows[[length(rows)+1L]] <- data.frame(case=id, field=field, max_absolute_difference=max(abs(x-y)))
  }
}
write.csv(do.call(rbind, rows), ".scratch/v06/cross-platform-inputs.csv", row.names=FALSE)
