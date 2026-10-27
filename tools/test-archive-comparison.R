# Small runnable check: Rscript --vanilla tools/test-archive-comparison.R
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
tools <- dirname(normalizePath(script))
source(file.path(tools, "archive-comparison.R"))

# Stored fields keep the data and drop versions, timings, functions and environments.
fit <- list(calibrator = list(knots = c(.1, .4), upper = c(.2, .5, 1)), versions = c(vennabers = "1.0.0"),
            model = list(elapsed = list(elapsed = 0.001), predict = function(x) x, formula = y ~ x))
fields <- archive_fields(fit)
stopifnot(identical(names(fields), c("calibrator", "model")),
  identical(fields$calibrator, fit$calibrator),
  identical(names(fields$model), c("predict", "formula")),
  identical(fields$model$predict, "<function>"),
  is.null(attr(fields$model$formula, ".Environment")),
  identical(archive_fields(local(y ~ x)), archive_fields(y ~ x)),
  identical(archive_fields(list(e = new.env())), list(e = "<environment>")),
  identical(archive_fields(structure(list(a = 1, versions = "1.0.0"), class = "venn_abers", n = 2L)),
            structure(list(a = 1), class = "venn_abers", n = 2L)))

# A one-ulp change in one stored value is reported with case, output and path.
record <- list(binary = list(predict.log = data.frame(probability = c(.25, 1 / 3)), fields = fields),
               ivar = list(predict.default = data.frame(prediction = 2), print = "<venn_abers_regression>"))
changed <- record
changed$binary$fields$calibrator$upper[2] <- .5 * (1 + .Machine$double.eps)
same <- archive_compare(record, record)
different <- archive_compare(record, changed)
stopifnot(identical(nrow(same), 4L), all(same$identical), all(is.na(same$difference)),
  identical(different$identical, c(TRUE, FALSE, TRUE, TRUE)),
  identical(different$case[!different$identical], "binary"),
  identical(different$output[!different$identical], "fields"),
  identical(different$difference[!different$identical],
            "$calibrator$upper[2]: 0.5 vs 0.50000000000000011"))

# Bitwise: signed zero differs, and missing outputs or cases are reported.
stopifnot(!is.na(archive_first_difference(0, -0)),
  identical(archive_first_difference(c(a = 1), list(a = 1)), "value: numeric[1] vs list[1]"),
  identical(archive_compare(record, record["binary"])$difference[3], "value: data.frame[1] vs NULL[0]"))

# Outputs record errors and warnings; new options reach the candidate only.
case <- list(fit = function(...) stats::lm(y ~ x, data.frame(x = 1:4, y = c(1, 3, 2, 4)), ...),
  new = data.frame(x = 5), details = FALSE, new_options = list(fit = list(), predict = list(interval = "none")),
  predict = list(plain = list(), level = list(level = .9), broken = list(newdata = "no")))
outputs <- archive_outputs(case)
stopifnot(identical(names(outputs), c("predict.plain", "predict.level", "predict.broken", "print", "fields", "warnings")),
  is.double(outputs$predict.plain), length(outputs$predict.plain) == 1L, inherits(outputs$predict.broken, "archive_error"),
  is.null(attr(outputs$fields$terms, ".Environment")), identical(outputs$warnings, character()))
warned <- archive_outputs(modifyList(case, list(fit = function(...) { warning("ties"); stats::lm(y ~ x, data.frame(x = 1:2, y = 1:2)) })))
stopifnot(identical(warned$warnings, "ties"))
explicit <- archive_outputs(modifyList(case, list(new_options = list(fit = list(), predict = list(interval = "wrong")))),
                            candidate = TRUE)
stopifnot(inherits(explicit$predict.plain, "archive_error"), !inherits(archive_outputs(case, candidate = TRUE)$predict.plain, "archive_error"))
failed <- archive_outputs(modifyList(case, list(fit = function(...) stop("no fit"))))
stopifnot(identical(names(failed), c("fit", "warnings")), identical(unclass(failed$fit), "no fit"))

# The summary names platform, R, both package versions and each difference.
info <- function(role) list(role = role, vennabers = "1.0.0", source = paste0(role, ".tar.gz"),
  r = R.version.string, platform = R.version$platform, os = "test OS", packages = c(parsnip = "1.6.0"))
summary <- archive_summary(different, info("previous"), info("candidate"))
stopifnot(any(grepl("Result: DIFFERENT (2 cases, 4 outputs, 1 different)", summary, fixed = TRUE)),
  any(grepl(R.version.string, summary, fixed = TRUE)), any(grepl("parsnip 1.6.0", summary, fixed = TRUE)),
  any(grepl("| previous | 1.0.0 | `previous.tar.gz` |", summary, fixed = TRUE)),
  any(grepl("| binary | fields | `$calibrator$upper[2]", summary, fixed = TRUE)))

# A local tarball is used where it is.
tarball <- tempfile(fileext = ".tar.gz")
invisible(file.create(tarball))
stopifnot(identical(archive_source(tarball, tempdir()), normalizePath(tarball)))
unlink(tarball)

# The catalog covers every manual kernel and one workflow per target.
if (all(vapply(c("vennabers", "workflows", "rsample"), requireNamespace, logical(1), quietly = TRUE))) {
  source(file.path(tools, "archive-comparison-cases.R"))
  cases <- archive_cases()
  stopifnot(!anyDuplicated(names(cases)),
    all(c("binary_inductive", "binary_cross", "ovo_inductive", "ovr_inductive", "ovo_cross", "ovr_cross",
          "ivar_m", "ivar_epsilon", "cvar_m", "cvar_epsilon", "workflow_binary", "workflow_ovo",
          "workflow_ovr", "workflow_regression") %in% names(cases)),
    all(vapply(cases, function(case) identical(names(case), c("fit", "new", "predict", "details", "new_options")) &&
      !is.null(names(case$predict)) && !anyDuplicated(names(case$predict)), logical(1))))
}
cat("Archive comparison checks passed.\n")
