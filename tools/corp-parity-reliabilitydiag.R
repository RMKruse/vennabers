# Numerical parity of the CORP estimate and uncertainty bands of corp_plot()
# with reliabilitydiag 0.2.1. reliabilitydiag is deliberately not in Suggests,
# so this runs outside the package tests. Run from the repository root:
#   Rscript --vanilla tools/corp-parity-reliabilitydiag.R [<library> ...]
# The libraries are optional and are put before the site library. Together
# they hold vennabers with corp_plot() and reliabilitydiag 0.2.1 with its
# imports, for example one throwaway library built with
#   install.packages(c("bde", "ggExtra", "vctrs"), lib = <library>)
#   install.packages(<reliabilitydiag_0.2.1.tar.gz from CRAN or its archive>,
#                    lib = <library>, repos = NULL, type = "source")
#   R CMD INSTALL -l <library> .
#
# For equal data and seed, corp_plot(seed = s) is compared with set.seed(s)
# followed by reliabilitydiag(region.method = "resampling") at position
# "diagonal" (consistency band) or "estimate" (confidence band). Estimate and
# both limits must agree within 1e-10 absolute at every unique probability;
# a difference stops the script with its case. Two deviations are by design:
# - A replicate that draws one unique probability makes the reference recycle
#   a scalar through its replicate matrix. The cases are sized so that such a
#   replicate has a chance below 1e-9 per call, which is checked.
# - With one outcome vennabers omits the confidence band with a warning, which
#   is checked instead of the reference band.
# monotone must be absent, otherwise the reference fits PAV with it instead of
# stats::isoreg.

libraries <- commandArgs(trailingOnly = TRUE)
if (length(libraries)) .libPaths(c(normalizePath(libraries, mustWork = TRUE), .libPaths()))
suppressPackageStartupMessages(library(vennabers))
for (package in c("reliabilitydiag", "dplyr", "tibble")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Missing package: ", package)
}
stopifnot("corp_plot" %in% getNamespaceExports("vennabers"),
          utils::packageVersion("reliabilitydiag") == "0.2.1")
if (requireNamespace("monotone", quietly = TRUE)) stop("monotone is installed; remove it from the libraries.")
versions <- vapply(c("vennabers", "reliabilitydiag", "dplyr", "tibble"),
                   function(p) as.character(utils::packageVersion(p)), "")
cat(R.version.string, "|", R.version$platform, "|", paste(RNGkind(), collapse = ", "), "\n")
cat(paste(names(versions), versions, collapse = ", "), "| monotone absent\n")
cat("vennabers from", find.package("vennabers"), "\n\n")
grDevices::pdf(NULL)

seeds <- c(1L, 42L, 2026L)
replicates <- 1000L
level <- .9
tolerance <- 1e-10
bands <- c("consistency", "confidence")

# Binary pairs with events drawn from a conditional event probability.
simulated <- function(probability, event_probability) {
  list(truth = stats::rbinom(length(probability), 1L, event_probability(probability)), probability = probability)
}
set.seed(15)
datasets <- list(
  continuous = simulated(stats::runif(400), function(x) x^1.5),
  "continuous, n = 30" = simulated(stats::rbeta(30, 2, 2), identity),
  "discrete, 0 and 1 included" = simulated(rep(seq(0, 1, by = .1), 20), identity),
  ties = simulated(round(stats::rbeta(300, 2, 3), 2), function(x) stats::plogis(4 * x - 1.5)),
  "inner 0/1 estimates" = simulated(rep(seq(.05, .95, by = .1), 15),
                                    function(x) ifelse(x < .3, 0, ifelse(x > .7, 1, x))),
  "one outcome, all 0" = list(truth = rep(0L, 120), probability = stats::runif(120, 0, .6)),
  "one outcome, all 1" = list(truth = rep(1L, 60), probability = round(stats::runif(60, .4, 1), 1))
)
inner_estimates <- with(datasets[["inner 0/1 estimates"]], corp_plot(truth, probability, band = "none"))
inner_estimates <- inner_estimates$estimate[!inner_estimates$probability %in% range(inner_estimates$probability)]
stopifnot(any(inner_estimates == 0), any(inner_estimates == 1))
# Three classes with dyadic probabilities: rows sum to one exactly, so the
# normalization in corp_plot() leaves them unchanged.
set.seed(16)
datasets[["multiclass, 3 classes"]] <- local({
  sixteenths <- t(replicate(240, {
    k <- sort(sample(0:16, 2L, replace = TRUE))
    c(k[1L], k[2L] - k[1L], 16L - k[2L]) / 16
  }))
  colnames(sixteenths) <- c("a", "b", "c")
  stopifnot(all(Reduce(`+`, as.data.frame(sixteenths)) == 1))
  list(truth = factor(apply(sixteenths, 1L, function(p) sample(colnames(sixteenths), 1L, prob = p + .05)),
                      levels = colnames(sixteenths)),
       probability = sixteenths)
})

# The binary panels of a case in the order corp_plot() draws them: the case
# itself, or each class against the rest in level order.
panels <- function(d) {
  if (!is.factor(d$truth)) return(list(c(d, label = "")))
  lapply(levels(d$truth), function(class) {
    list(truth = d$truth == class, probability = d$probability[, class], label = paste0(", class ", class))
  })
}

# Chance that one replicate draws a single unique probability.
single_value <- function(probability) {
  share <- tabulate(match(probability, unique(probability))) / length(probability)
  sum(share^length(probability))
}

# The reference band with its PAV estimate at the unique probabilities. The
# stream continues from the caller's state.
reference <- function(truth, probability, band) {
  position <- c(consistency = "diagonal", confidence = "estimate")[[band]]
  fit <- reliabilitydiag::reliabilitydiag(forecast = probability, y = as.numeric(truth), region.level = level,
                                          region.method = "resampling", region.position = position,
                                          n.boot = replicates)[[1L]]
  pav <- dplyr::distinct(fit$cases[c("x", "CEP_pav")])
  stopifnot(identical(pav$x, fit$regions$x))
  list(probability = fit$regions$x, estimate = pav$CEP_pav, count = fit$regions$n,
       lower = fit$regions$lower, upper = fit$regions$upper)
}

# corp_plot() tables per panel with the warnings that omitted a confidence
# band; any other warning fails.
vennabers_panels <- function(d, band, seed) {
  warnings <- character()
  table <- withCallingHandlers(
    corp_plot(d$truth, d$probability, band = band, level = level, replicates = replicates, seed = seed),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  stopifnot(all(grepl("^Confidence band omitted: `truth` has only one outcome", warnings)))
  list(tables = if (is.factor(d$truth)) unname(split(table, table$class)) else list(table), warnings = warnings)
}

# Compares one panel and returns its largest difference. A confidence band
# omitted for one outcome must be missing throughout.
compare <- function(case, table, expected, omitted) {
  if (!identical(table$probability, expected$probability) || !identical(table$count, expected$count)) {
    stop(case, ": unique probabilities or their counts differ from reliabilitydiag", call. = FALSE)
  }
  columns <- c(estimate = "estimate", lower = "band_lower", upper = "band_upper")
  if (omitted) {
    stopifnot(all(is.na(table$band_lower)), all(is.na(table$band_upper)))
    columns <- columns["estimate"]
  }
  differences <- vapply(names(columns), function(name) {
    ours <- table[[columns[[name]]]]
    if (!identical(is.na(ours), is.na(expected[[name]]))) {
      stop(case, ": ", name, " is missing at other probabilities than in reliabilitydiag", call. = FALSE)
    }
    max(0, abs(ours - expected[[name]]), na.rm = TRUE)
  }, 0)
  if (any(differences > tolerance)) {
    worst <- names(which.max(differences))
    stop(sprintf("%s: %s differs from reliabilitydiag by %.3g", case, worst, max(differences)), call. = FALSE)
  }
  max(differences)
}

# Each seed runs corp_plot() once and the reference panel by panel from the
# same seed, so multiclass checks one stream for all classes.
largest <- 0
for (case in names(datasets)) {
  d <- datasets[[case]]
  case_panels <- panels(d)
  for (p in case_panels) stopifnot(replicates * single_value(p$probability) < 1e-9)
  one_outcome <- vapply(case_panels, function(p) length(unique(p$truth)) == 1L, TRUE)
  values <- max(vapply(case_panels, function(p) length(unique(p$probability)), 1L))
  for (band in bands) {
    omitted <- band == "confidence" & one_outcome
    differences <- vapply(seeds, function(seed) {
      ours <- vennabers_panels(d, band, seed)
      stopifnot(length(ours$warnings) == sum(omitted))
      set.seed(seed)
      max(vapply(seq_along(case_panels), function(i) {
        p <- case_panels[[i]]
        compare(sprintf("%s%s, %s, seed %d", case, p$label, band, seed), ours$tables[[i]],
                reference(p$truth, p$probability, band), omitted[[i]])
      }, 0))
    }, 0)
    largest <- max(largest, differences)
    cat(sprintf("%-28s %-11s %4d unique  seeds %s  max |diff| %.3g%s\n", case, band, values,
                paste(seeds, collapse = "/"), max(differences), if (any(omitted)) "  (band omitted)" else ""))
  }
}

cat(sprintf("\n%d runs (%d cases x %d bands x %d seeds), replicates = %d, level = %g.\n",
            length(datasets) * length(bands) * length(seeds), length(datasets), length(bands), length(seeds),
            replicates, level))
cat(sprintf("Largest absolute difference: %.3g (tolerance %g).\n", largest, tolerance))
cat("All CORP parity checks passed.\n")
