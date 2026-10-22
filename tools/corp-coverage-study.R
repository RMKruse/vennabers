# Empirical pointwise coverage of the CORP uncertainty bands of corp_plot()
# and the run time and memory of one call. Run from the repository root:
#   Rscript --vanilla tools/corp-coverage-study.R [cores=<detected - 1>] [<library> ...]
# The libraries are optional and are put before the site library; they hold
# vennabers with corp_plot(). The results do not depend on the cores.
#
# Coverage: every constellation of band, n in {100, 1000} and forecast design
# runs 1000 Monte-Carlo runs at level 0.9 with 1000 replicates. The
# consistency band is checked under CEP(x) = x, where it should hold the CORP
# estimate; the confidence band under CEP(x) = x^2, where it should hold the
# true CEP. Continuous forecasts are uniform on (0, 1); discrete forecasts
# take ten values 0.05, 0.15, ..., 0.95 with equal chance, as a Venn-Abers
# calibrator yields few distinct values. A point is covered when its target
# lies in the closed band; missing limits count as not covered. Inner points
# leave out the outer 5 % of the forecast distribution on each side, the open
# interval (0.05, 0.95) for both designs. The coverage of a constellation is
# the mean over runs of the share of inner unique probabilities covered.
#
# Hard criterion, consistency band only: the coverage lies within
# 0.9 +/- 3 * sqrt(0.9 * 0.1 / 1000) in every constellation. The confidence
# band is reported without a threshold. A failure stops the script with a
# non-zero status after printing all tables.
#
# Effort: one call each at n in {1e3, 1e4, 1e5}, 1000 replicates, both
# designs and bands, with the elapsed time and the peak R heap from gc().
# This is a measurement, not a performance gate.
#
# Each run draws its data and its band from two seeds taken in a fixed order
# from the master seed, so a run is the same in any worker.

master_seed <- 16L
level <- .9
replicates <- 1000L
runs <- 1000L

# Forecast designs, each drawing n probabilities.
forecasts <- list(
  continuous = function(n) stats::runif(n),
  discrete = function(n) sample((1:10 - .5) / 10, n, replace = TRUE)
)

# The true CEP each band is checked under.
ceps <- list(consistency = identity, confidence = function(x) x^2)
cep_labels <- c(consistency = "x", confidence = "x^2")

load_vennabers <- function(libraries = character()) {
  if (length(libraries)) .libPaths(c(normalizePath(libraries, mustWork = TRUE), .libPaths()))
  suppressPackageStartupMessages(library(vennabers))
  stopifnot("corp_plot" %in% getNamespaceExports("vennabers"))
}

inner <- function(probability) probability > .05 & probability < .95

# Whether the band holds its target at each unique probability of a
# corp_plot() table.
covered <- function(table, band, cep) {
  target <- if (band == "consistency") table$estimate else cep(table$probability)
  !is.na(table$band_lower) & !is.na(table$band_upper) &
    table$band_lower <= target & target <= table$band_upper
}

tolerance <- function(level, runs) 3 * sqrt(level * (1 - level) / runs)

passes <- function(coverage, level, runs) !is.na(coverage) && abs(coverage - level) <= tolerance(level, runs)

constellations <- function(n = c(100, 1000), designs = names(forecasts)) {
  grid <- expand.grid(design = designs, n = n, band = names(ceps), stringsAsFactors = FALSE)
  data.frame(band = grid$band, n = grid$n, design = grid$design, cep = unname(cep_labels[grid$band]))
}

# Pairs of one design with events drawn from the CEP the band is checked
# under, from their own seed.
simulate <- function(n, design, band, seed) {
  set.seed(seed)
  probability <- forecasts[[design]](n)
  list(truth = stats::rbinom(n, 1L, ceps[[band]](probability)), probability = probability)
}

# One Monte-Carlo run: covered and inner unique probabilities per tenth of
# [0, 1], and the inner ones with undefined limits.
coverage_run <- function(n, design, band, data_seed, band_seed, replicates, level) {
  pairs <- simulate(n, design, band, data_seed)
  corp <- withCallingHandlers(
    corp_plot(pairs$truth, pairs$probability, band = band, level = level, replicates = replicates,
              seed = band_seed),
    warning = function(w) {
      if (grepl("^Confidence band omitted", conditionMessage(w))) invokeRestart("muffleWarning")
    })
  keep <- inner(corp$probability)
  tenth <- factor(pmin(floor(10 * corp$probability[keep]), 9) + 1, levels = 1:10)
  hit <- covered(corp, band, ceps[[band]])[keep]
  list(covered = as.integer(tapply(hit, tenth, sum, default = 0L)),
       points = as.integer(table(tenth)),
       undefined = sum(is.na(corp$band_lower[keep]) | is.na(corp$band_upper[keep])))
}

# Coverage per constellation, with the pooled coverage per tenth of [0, 1]
# as attribute "tenths" (NaN without inner points there).
coverage_study <- function(constellations, runs, master_seed, replicates, level, cores) {
  set.seed(master_seed)
  seeds <- array(sample.int(.Machine$integer.max, 2L * runs * nrow(constellations)),
                 c(runs, 2L, nrow(constellations)))
  rows <- lapply(seq_len(nrow(constellations)), function(k) {
    with(constellations[k, ], {
      results <- parallel::mclapply(seq_len(runs), function(r) {
        coverage_run(n, design, band, seeds[r, 1L, k], seeds[r, 2L, k], replicates, level)
      }, mc.cores = cores)
      failed <- vapply(results, inherits, TRUE, "try-error")
      if (any(failed)) stop(band, ", n = ", n, ", ", design, ": ", results[[which(failed)[1L]]], call. = FALSE)
      covered <- do.call(rbind, lapply(results, `[[`, "covered"))
      points <- do.call(rbind, lapply(results, `[[`, "points"))
      share <- rowSums(covered) / rowSums(points)
      coverage <- mean(share)
      list(row = data.frame(band, n, design, cep, runs, inner_points = mean(rowSums(points)), coverage,
                            mc_se = stats::sd(share) / sqrt(runs),
                            undefined = sum(vapply(results, `[[`, 0L, "undefined")) / sum(points),
                            pass = if (band == "consistency") passes(coverage, level, runs) else NA),
           tenths = colSums(covered) / colSums(points))
    })
  })
  tenths <- do.call(rbind, lapply(rows, `[[`, "tenths"))
  colnames(tenths) <- sprintf("%.1f-%.1f", 0:9 / 10, 1:10 / 10)
  structure(do.call(rbind, lapply(rows, `[[`, "row")), tenths = tenths)
}

# Elapsed time and peak R heap of one corp_plot() call with seed 1. peak_mb
# is the largest heap gc() saw during the call, baseline_mb the heap before
# it; matrix_mb is the size of the unique-by-replicate matrix of doubles.
effort <- function(n, design, band, replicates) {
  pairs <- simulate(n, design, band, 1L)
  baseline <- gc(reset = TRUE)
  seconds <- system.time(corp <- corp_plot(pairs$truth, pairs$probability, band = band,
                                           replicates = replicates, seed = 1L))[["elapsed"]]
  peak <- gc()
  # The MB column follows its cell count; gc() may add a limit column.
  mb <- function(memory, column) sum(memory[, match(column, colnames(memory)) + 1L])
  data.frame(n, design, band, unique = nrow(corp), seconds, baseline_mb = mb(baseline, "used"),
             peak_mb = mb(peak, "max used"), matrix_mb = 8 * nrow(corp) * replicates / 2^20)
}

print_markdown <- function(table, digits = 4L) {
  cells <- vapply(table, function(column) {
    if (is.double(column)) formatC(column, digits = digits, format = "fg") else as.character(column)
  }, character(nrow(table)))
  cells <- matrix(cells, nrow = nrow(table))
  lines <- c(paste("|", paste(names(table), collapse = " | "), "|"),
             paste0("|", paste(rep("---", ncol(table)), collapse = "|"), "|"),
             apply(cells, 1L, function(row) paste("|", paste(row, collapse = " | "), "|")))
  cat(lines, sep = "\n")
  cat("\n")
}

main <- function(args) {
  cores_arg <- grepl("^cores=", args)
  cores <- if (any(cores_arg)) as.integer(sub("^cores=", "", args[cores_arg][1L]))
           else max(1L, parallel::detectCores() - 1L)
  load_vennabers(args[!cores_arg])
  grDevices::pdf(NULL)
  cat(R.version.string, "|", R.version$platform, "|", paste(RNGkind(), collapse = ", "), "\n")
  cat("vennabers", as.character(utils::packageVersion("vennabers")), "from", find.package("vennabers"), "\n")
  cat(sprintf("master seed %d, level %g, replicates %d, runs %d, cores %d\n\n", master_seed, level,
              replicates, runs, cores))

  started <- Sys.time()
  study <- coverage_study(constellations(), runs, master_seed, replicates, level, cores)
  cat(sprintf("Coverage at inner points (criterion for consistency: %g +/- %.4f)\n\n", level,
              tolerance(level, runs)))
  print_markdown(study)
  cat("Pooled coverage per tenth of [0, 1] (inner points only)\n\n")
  print_markdown(data.frame(study[c("band", "n", "design")], attr(study, "tenths"), check.names = FALSE), 3L)
  cat(sprintf("Coverage study: %.1f min\n\n", as.numeric(difftime(Sys.time(), started, units = "mins"))))

  grid <- expand.grid(n = c(1e3, 1e4, 1e5), design = names(forecasts), band = names(ceps),
                      stringsAsFactors = FALSE)
  cost <- do.call(rbind, lapply(seq_len(nrow(grid)), function(k) {
    with(grid[k, ], effort(n, design, band, replicates))
  }))
  cat("Effort of one call, replicates =", replicates, "\n\n")
  print_markdown(cost)

  failed <- study$band == "consistency" & !study$pass
  if (any(failed)) {
    cat("FAILED: consistency band coverage outside the criterion for",
        paste0("n = ", study$n[failed], ", ", study$design[failed], collapse = "; "), "\n")
    quit(status = 1L)
  }
  cat("Consistency band coverage within the criterion in every constellation.\n")
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
