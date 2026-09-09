old <- "tools/evidence-v05/benchmark-smoke"
new <- ".scratch/v06/final-benchmark"
plan <- read.csv(file.path(old, "plan.csv"))
without_fingerprint <- function(x) { attr(x, "fingerprint") <- NULL; x }
for (id in plan$case) {
  a <- readRDS(file.path(old, paste0(id, "-input.rds")))
  b <- readRDS(file.path(new, paste0(id, "-input.rds")))
  for (field in setdiff(names(a), "base")) {
    x <- a[[field]]; y <- b[[field]]
    if (field == "inner") { x <- lapply(x, without_fingerprint); y <- lapply(y, without_fingerprint) }
    else if (field %in% c("outer", "split")) { x <- without_fingerprint(x); y <- without_fingerprint(y) }
    stopifnot(identical(x, y))
  }
  if (isTRUE(a$integration)) {
    stopifnot(identical(workflows::extract_spec_parsnip(a$base), workflows::extract_spec_parsnip(b$base)))
    x <- workflows::extract_recipe(a$base, estimated = FALSE)
    y <- workflows::extract_recipe(b$base, estimated = FALSE)
    stopifnot(identical(x$var_info, y$var_info), identical(x$steps, y$steps), identical(x$template, y$template))
  }
  cat(id, "historical data, plan memberships, options and model/recipe configuration unchanged (rsample fingerprints excluded)\n")
}
