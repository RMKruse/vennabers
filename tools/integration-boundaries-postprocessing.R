# Research only: verify source-workflow learning domains; no VA implementation.
lib <- Sys.getenv("VENN_RESEARCH_LIB")
if (nzchar(lib)) .libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages({
  library(workflows); library(parsnip); library(recipes)
  library(rsample); library(tailor)
})
args <- commandArgs(trailingOnly = TRUE)
if (length(args) && args[[1]] == "--read") {
  bundle <- readRDS(args[[2]])
  for (case in bundle) {
    before <- serialize(case$workflow, NULL)
    stopifnot(isTRUE(all.equal(predict(case$workflow, case$new_data,
                                      type = case$type), case$expected)),
              identical(before, serialize(case$workflow, NULL)))
  }
  cat("PASS fresh-process RDS and immutable prediction:", length(bundle), "workflows\n")
  quit(status = 0)
}
cat("R", as.character(getRversion()), R.version$platform, "\n")
for (p in c("workflows", "parsnip", "recipes", "rsample", "tailor", "probably", "nnet"))
  cat(p, as.character(packageVersion(p)), "\n")
error_text <- function(expr) tryCatch({force(expr); "NO ERROR"}, error = conditionMessage)
equal <- function(x, y) isTRUE(all.equal(x, y, tolerance = 1e-12))
set.seed(719)
d <- data.frame(id = 1:1200, x = rnorm(1200), z = rnorm(1200))
d$binary <- factor(ifelse(runif(1200) < plogis(.7*d$x-.3*d$z), "yes", "no"))
d$multiclass <- factor(sample(c("a", "b", "c"), 1200, replace=TRUE,
                              prob=c(.25,.35,.4)))
d$regression <- 2*d$x-d$z+rnorm(1200)
# Fixed independent outer assessment. IDs are audit metadata, never predictors.
outer_ids <- 1001:1200
bundle <- list()
for (mode in c("binary", "multiclass", "regression")) {
  dat <- data.frame(id=d$id, x=d$x, z=d$z, y=d[[mode]])
  local <- dat[-outer_ids, ]
  outer <- dat[outer_ids, ]
  model <- switch(mode, binary=logistic_reg() |> set_engine("glm"),
                  multiclass=multinom_reg() |> set_engine("nnet", trace=FALSE),
                  regression=linear_reg() |> set_engine("lm"))
  tlr <- if (mode == "regression") {
    tailor() |> adjust_numeric_calibration(method="linear", smooth=FALSE)
  } else {
    tailor() |> adjust_probability_calibration(method=if (mode == "binary") "logistic" else "multinomial", smooth=FALSE)
  }
  spec <- workflow() |>
    add_recipe(recipe(y ~ x + z, dat) |> step_normalize(all_numeric_predictors())) |>
    add_model(model) |> add_tailor(tlr)
  type <- if (mode == "regression") "numeric" else "prob"
  for (method in c("inductive", "cross")) {
    set.seed(800)
    va_splits <- if (method == "inductive") list(initial_split(local, prop=.75)) else
      vfold_cv(local, v=3)$splits
    for (i in seq_along(va_splits)) {
      va_split <- va_splits[[i]]
      set.seed(900+i)
      inner <- internal_calibration_split(va_split, split_args=list(prop=.75))
      base <- analysis(inner)
      post <- calibration(inner)
      va <- assessment(va_split)
      roles <- list(base$id, post$id, va$id, outer$id)
      stopifnot(all(vapply(combn(4, 2, simplify=FALSE), function(j)
        !length(intersect(roles[[j[1]]], roles[[j[2]]])), logical(1))),
        setequal(c(base$id, post$id), analysis(va_split)$id),
        setequal(c(base$id, post$id, va$id), local$id))
      if (i == 1L && method == "inductive") {
        missing <- error_text(fit(spec, data=base))
        no_assessment <- error_text(assessment(inner))
        stopifnot(missing != "NO ERROR", no_assessment != "NO ERROR")
        cat(mode, "missing data_calibration:", gsub("\n", " ", missing), "\n")
        cat(mode, "internal assessment error:", gsub("\n", " ", no_assessment), "\n")
      }
      if (mode == "multiclass" && method == "inductive") {
        invalid <- update_tailor(spec, tailor() |> adjust_probability_calibration(method="logistic", smooth=FALSE))
        msg <- error_text(fit(invalid, data=base, data_calibration=post))
        stopifnot(msg != "NO ERROR")
        cat("multiclass logistic method error:", gsub("\n", " ", msg), "\n")
      }
      if (mode == "binary" && method == "inductive") {
        # Public fitting does not verify observational disjointness for callers.
        unsafe <- fit(spec, data=base, data_calibration=base)
        stopifnot(nrow(predict(unsafe, outer, type=type)) == nrow(outer))
        cat("OBSERVED overlap accepted: caller must validate data roles\n")
      }
      fitted <- fit(spec, data=base, data_calibration=post)
      plain <- fit(remove_tailor(spec), data=base)
      if (mode == "binary" && method == "inductive") {
        raw_error <- error_text(predict(fitted, outer, type="raw", opts=list(type="response")))
        stopifnot(raw_error != "NO ERROR")
        cat("tailor raw predict error:", gsub("\n", " ", raw_error), "\n")
      }
      pp <- extract_tailor(fitted)
      # The learned recipe and raw model see base only, checked independently.
      means <- extract_recipe(fitted)$steps[[1]]$means
      stopifnot(equal(unname(means), unname(colMeans(base[c("x","z")]))),
                equal(coef(extract_fit_engine(fitted)),coef(extract_fit_engine(plain))))
      # Refit only postprocessing manually on held-out raw predictions.
      pp_data <- cbind(data.frame(y=post$y), predict(plain, post, type=type))
      if (mode == "regression") {
        independent <- fit(tlr, pp_data, outcome=y, estimate=.pred)
      } else {
        pp_data$.pred_class <- predict(plain, post, type="class")$.pred_class
        independent <- fit(tlr, pp_data, outcome=y, estimate=.pred_class,
                           probabilities=tidyselect::all_of(names(predict(plain, post, type="prob"))))
      }
      preds_va <- predict(fitted, va[c("x","z")], type=type)
      preds_outer <- predict(fitted, outer[c("x","z")], type=type)
      stopifnot(nrow(preds_va)==nrow(va), nrow(preds_outer)==nrow(outer),
                all(is.finite(as.matrix(preds_va))), all(is.finite(as.matrix(preds_outer))))
      raw <- predict(plain, outer, type=type)
      manual_input <- raw
      if (mode != "regression") manual_input$.pred_class <- predict(plain, outer, type="class")$.pred_class
      manual <- predict(independent, manual_input)[names(preds_outer)]
      stopifnot(equal(manual, preds_outer), !equal(raw, preds_outer))
      # Changes to postprocessor outcomes must leave base parameters fixed but
      # alter the final prediction: demonstrates actual learned postprocessing.
      changed_post <- post
      changed_post$y <- if (mode == "regression") post$y+7 else
        factor(rev(post$y), levels=levels(post$y))
      changed <- fit(spec, data=base, data_calibration=changed_post)
      stopifnot(equal(coef(extract_fit_engine(changed)),coef(extract_fit_engine(fitted))),
                !equal(predict(changed, outer, type=type), preds_outer))
      # VA/outer labels and extreme unused predictors cannot enter these fits.
      changed_dat <- dat
      forbidden <- c(va$id, outer$id)
      changed_dat$x[forbidden] <- 1e8
      changed_dat$y[forbidden] <- if (mode == "regression") -1e8 else levels(dat$y)[1]
      again <- fit(spec, data=changed_dat[base$id,], data_calibration=changed_dat[post$id,])
      stopifnot(equal(predict(again, outer, type=type), preds_outer))
      # Frozen reuse is a distinct operation: read-only prediction, no refitting.
      frozen_before <- serialize(fitted, NULL)
      invisible(predict(fitted, va, type=type))
      invisible(predict(fitted, outer, type=type))
      stopifnot(identical(frozen_before, serialize(fitted, NULL)))
      key <- paste(mode,method,i,sep="/")
      bundle[[key]] <- list(workflow=fitted,new_data=outer[c("x","z")],
                            type=type,expected=preds_outer)
      cat("PASS", key, "base/post/VA/outer:", paste(lengths(roles),collapse="/"),
          "max postprocessing change", max(abs(as.matrix(preds_outer)-as.matrix(raw))), "\n")
    }
  }
}
# Full-transfer source domain is intentionally different: the complete local
# fit domain may include former VA rows, but never outer assessment rows.
# This proof does not make the human policy choice of its postprocessing split.
rds <- tempfile(fileext=".rds")
saveRDS(bundle, rds)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value=TRUE)[1])
status <- system2(file.path(R.home("bin"),"Rscript"),
                  c("--vanilla",shQuote(normalizePath(script)),"--read",shQuote(rds)))
unlink(rds)
stopifnot(status == 0L)
cat("PASS all 12 source-workflow probes; no Venn-Abers algorithm implemented\n")
