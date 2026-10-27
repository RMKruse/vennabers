# Archive comparison for release fidelity (RELEASE-ROADMAP-1.x.md §3.2). Run
# from the repository root:
#   Rscript --vanilla tools/archive-comparison.R <previous> <candidate.tar.gz> <temporary-out-dir>
# <previous> is a CRAN version such as 1.0.0 (taken from the CRAN archive, or
# from src/contrib while it is the current release), a source tarball URL, or
# a local source tarball such as the durable 1.0.0 candidate. Both versions
# are installed into their own libraries under <temporary-out-dir>; the
# integration packages of the workflow cases come from the caller's libraries.
# Keep <temporary-out-dir> outside .scratch and remove it after summarizing.
#
# Fresh processes run tools/archive-comparison-cases.R, one per version. For
# each case they record every prediction, venn_abers_details() of workflows,
# print() output, warnings and the stored object fields. This process then
# compares the two records bitwise with identical(), writes comparison.csv
# and summary.md, prints the summary and exits with status 1 on any
# difference. Not part of R CMD check.

# Stored fields without what may differ between two releases or processes
# without a changed result: recorded package versions, parsnip's timing of
# each engine fit, functions and environments (model_adapter() callbacks,
# formula environments).
archive_fields <- function(x) {
  if (is.function(x)) return("<function>")
  if (is.environment(x) || typeof(x) %in% c("externalptr", "weakref")) return(paste0("<", typeof(x), ">"))
  drop <- is.list(x) & names(x) %in% c("versions", "elapsed")
  if (any(drop)) {
    # `[` would also drop the class and every other attribute.
    kept <- attributes(x)
    x <- x[!drop]
    kept$names <- names(x)
    attributes(x) <- kept
  }
  if (is.list(x)) x[] <- lapply(x, archive_fields)
  keep <- attributes(x)
  if (length(keep)) {
    keep <- keep[names(keep) != ".Environment"]
    attributes(x) <- if (length(keep)) lapply(keep, archive_fields)
  }
  x
}

archive_object_fields <- function(object) {
  if (inherits(object, "workflow")) object <- workflows::extract_fit_engine(object)
  archive_fields(unclass(object))
}

# All outputs of one case. Each output is evaluated on its own, so an error
# or a warning becomes part of the compared record instead of ending the run.
archive_outputs <- function(case, candidate = FALSE) {
  options <- if (candidate) case$new_options else list(fit = list(), predict = list())
  warnings <- character()
  run <- function(expr) withCallingHandlers(
    tryCatch(expr, error = function(e) structure(conditionMessage(e), class = "archive_error")),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  object <- run(do.call(case$fit, options$fit))
  if (inherits(object, "archive_error")) return(list(fit = object, warnings = warnings))
  outputs <- lapply(case$predict, function(args) {
    run(do.call(stats::predict, c(list(object, case$new), args, options$predict)))
  })
  names(outputs) <- paste0("predict.", names(case$predict))
  if (case$details) outputs$details <- run(venn_abers_details(object, case$new))
  c(outputs, list(print = run(utils::capture.output(print(object))),
                  fields = run(archive_object_fields(object)), warnings = warnings))
}

# Where two values first differ, as "path: previous vs candidate".
archive_first_difference <- function(a, b, path = "") {
  if (identical(a, b, num.eq = FALSE, single.NA = FALSE)) return(NA_character_)
  show <- function(x) {
    if (is.double(x)) return(sprintf("%.17g", x))
    paste(utils::head(format(x), 1L), collapse = " ")
  }
  if (!identical(class(a), class(b)) || !identical(length(a), length(b)) || typeof(a) != typeof(b)) {
    return(sprintf("%s: %s[%d] vs %s[%d]", if (nzchar(path)) path else "value",
                   paste(class(a), collapse = "/"), length(a), paste(class(b), collapse = "/"), length(b)))
  }
  if (is.list(a)) {
    labels <- if (is.null(names(a))) paste0("[[", seq_along(a), "]]") else paste0("$", names(a))
    for (i in seq_along(a)) {
      found <- archive_first_difference(a[[i]], b[[i]], paste0(path, labels[i]))
      if (!is.na(found)) return(found)
    }
  } else if (is.atomic(a)) {
    va <- as.vector(a)
    vb <- as.vector(b)
    for (i in seq_along(va)) {
      if (!identical(va[i], vb[i], num.eq = FALSE, single.NA = FALSE)) {
        return(sprintf("%s[%d]: %s vs %s", path, i, show(va[i]), show(vb[i])))
      }
    }
  }
  sprintf("%s: attributes differ", if (nzchar(path)) path else "value")
}

# One row per case and output; `identical` is bitwise (num.eq = FALSE).
archive_compare <- function(previous, candidate) {
  cases <- union(names(previous), names(candidate))
  rows <- lapply(cases, function(case) {
    a <- previous[[case]]
    b <- candidate[[case]]
    outputs <- union(names(a), names(b))
    difference <- vapply(outputs, function(output) archive_first_difference(a[[output]], b[[output]]), "")
    data.frame(case = case, output = outputs, identical = is.na(difference), difference = unname(difference))
  })
  do.call(rbind, rows)
}

archive_summary <- function(result, previous, candidate) {
  record <- function(x) c(sprintf("| %s | %s | `%s` |", x$role, x$vennabers, x$source))
  packages <- paste(sprintf("%s %s", names(candidate$packages), candidate$packages), collapse = ", ")
  differences <- result[!result$identical, ]
  c("# Archive comparison",
    "",
    sprintf("- Platform: %s (%s)", candidate$platform, candidate$os),
    sprintf("- R: %s", candidate$r),
    sprintf("- Integration packages: %s", packages),
    sprintf("- Result: %s (%d cases, %d outputs, %d different)",
            if (nrow(differences)) "DIFFERENT" else "identical",
            length(unique(result$case)), nrow(result), nrow(differences)),
    "",
    "| Role | vennabers | Source |",
    "| --- | --- | --- |",
    record(previous), record(candidate),
    if (nrow(differences)) c("", "| Case | Output | First difference (previous vs candidate) |", "| --- | --- | --- |",
      sprintf("| %s | %s | `%s` |", differences$case, differences$output, differences$difference)))
}

# A tarball path stays as it is; a URL or CRAN version is downloaded to `out`.
archive_source <- function(previous, out) {
  if (file.exists(previous)) return(normalizePath(previous))
  urls <- if (grepl("^https?://", previous)) previous else {
    file <- sprintf("vennabers_%s.tar.gz", previous)
    c(paste0("https://cran.r-project.org/src/contrib/Archive/vennabers/", file),
      paste0("https://cran.r-project.org/src/contrib/", file))
  }
  target <- file.path(out, basename(urls[[1L]]))
  for (url in urls) {
    ok <- tryCatch(utils::download.file(url, target, mode = "wb", quiet = TRUE) == 0L, error = function(e) FALSE,
                   warning = function(w) FALSE)
    if (ok) return(url)
  }
  stop("Cannot find ", previous, " at ", paste(urls, collapse = " or "), call. = FALSE)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
  if (length(args) == 4L && args[[1L]] == "run") {
    # Worker mode in a fresh process: one version, one library.
    role <- args[[2L]]
    lib <- args[[3L]]
    out <- args[[4L]]
    .libPaths(c(lib, .libPaths()))
    source(file.path(dirname(script), "archive-comparison-cases.R"))
    cases <- archive_cases()
    loaded <- normalizePath(dirname(find.package("vennabers")))
    if (!identical(loaded, normalizePath(lib))) stop("vennabers loaded from ", loaded, ", not ", lib, call. = FALSE)
    outputs <- lapply(cases, archive_outputs, candidate = role == "candidate")
    integration <- c("parsnip", "workflows", "hardhat", "rsample", "tibble", "generics")
    saveRDS(list(role = role, vennabers = format(utils::packageVersion("vennabers")),
                 r = R.version.string, platform = R.version$platform, os = utils::sessionInfo()$running,
                 packages = vapply(integration, function(p) format(utils::packageVersion(p)), ""),
                 outputs = outputs), file.path(out, paste0(role, ".rds")))
  } else {
    if (length(args) != 3L) {
      stop("Usage: Rscript --vanilla tools/archive-comparison.R <previous> <candidate.tar.gz> <temporary-out-dir>",
           call. = FALSE)
    }
    out <- args[[3L]]
    dir.create(out, showWarnings = FALSE, recursive = TRUE)
    out <- normalizePath(out)
    sources <- c(previous = archive_source(args[[1L]], out), candidate = normalizePath(args[[2L]]))
    tarballs <- c(previous = if (file.exists(sources[["previous"]])) sources[["previous"]] else
      file.path(out, basename(sources[["previous"]])), candidate = sources[["candidate"]])
    for (role in names(tarballs)) {
      lib <- file.path(out, paste0(role, "-lib"))
      log <- file.path(out, paste0(role, "-install.log"))
      dir.create(lib, showWarnings = FALSE)
      status <- system2(file.path(R.home("bin"), "R"),
        c("CMD", "INSTALL", "--no-docs", "--no-html", paste0("--library=", shQuote(lib)), shQuote(tarballs[[role]])),
        stdout = log, stderr = log)
      if (status != 0L) stop("Installing the ", role, " version failed; see ", log, call. = FALSE)
      log <- file.path(out, paste0(role, "-run.log"))
      status <- system2(file.path(R.home("bin"), "Rscript"),
        c("--vanilla", shQuote(script), "run", role, shQuote(lib), shQuote(out)), stdout = log, stderr = log)
      if (status != 0L) stop("The ", role, " run failed; see ", log, call. = FALSE)
    }
    records <- lapply(stats::setNames(names(tarballs), names(tarballs)), function(role) {
      record <- readRDS(file.path(out, paste0(role, ".rds")))
      record$source <- sources[[role]]
      record
    })
    result <- archive_compare(records$previous$outputs, records$candidate$outputs)
    utils::write.csv(result, file.path(out, "comparison.csv"), row.names = FALSE)
    summary <- archive_summary(result, records$previous, records$candidate)
    writeLines(summary, file.path(out, "summary.md"))
    writeLines(summary)
    if (!all(result$identical)) quit(status = 1L)
  }
}
