# Checks the building blocks of the CORP coverage study on small inputs.
# Rscript --vanilla tools/test-corp-coverage-study.R [<library> ...]
# The libraries are optional and hold vennabers with corp_plot().
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
source(file.path(dirname(normalizePath(script)), "corp-coverage-study.R"))
load_vennabers(commandArgs(trailingOnly = TRUE))
grDevices::pdf(NULL)

# Inner points exclude the outer 5 % of the forecast distribution on each
# side, for both designs the open interval (0.05, 0.95).
stopifnot(identical(inner(c(0, .05, .0501, .5, .9499, .95, 1)), c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE)))

# Both designs draw forecasts in (0, 1); the discrete one only its ten values.
set.seed(1)
continuous <- forecasts$continuous(500)
discrete <- forecasts$discrete(500)
stopifnot(length(continuous) == 500L, all(continuous > 0 & continuous < 1),
          length(discrete) == 500L, setequal(discrete, (1:10 - .5) / 10))

# A point is covered when its target lies in the closed band; missing limits
# count as not covered. The consistency band targets the CORP estimate, the
# confidence band the true conditional event probability.
table <- data.frame(probability = c(.2, .4, .6, .8), estimate = c(.1, .5, .6, .9),
                    band_lower = c(.1, .3, NA, .5), band_upper = c(.3, .45, .7, .7))
stopifnot(identical(covered(table, "consistency", identity), c(TRUE, FALSE, FALSE, FALSE)),
          identical(covered(table, "confidence", identity), c(TRUE, TRUE, FALSE, FALSE)),
          identical(covered(table, "confidence", function(x) x^2), c(FALSE, FALSE, FALSE, TRUE)))

# The hard criterion: within three Monte-Carlo standard errors of the level.
stopifnot(abs(tolerance(.9, 1000) - 3 * sqrt(.9 * .1 / 1000)) < 1e-15,
          passes(.9 + .0284, .9, 1000), passes(.9 - .0284, .9, 1000),
          !passes(.9 + .0286, .9, 1000), !passes(.9 - .0286, .9, 1000), !passes(NA_real_, .9, 1000))

# One run returns covered and inner points per tenth of [0, 1]; the discrete
# design has no inner points in the outer tenths.
run <- coverage_run(60, "discrete", "consistency", data_seed = 3L, band_seed = 4L, replicates = 199L, level = .9)
stopifnot(identical(names(run), c("covered", "points", "undefined")), length(run$points) == 10L,
          run$points[c(1L, 10L)] == 0L, all(run$covered <= run$points), sum(run$points) > 0L)

# The study is reproducible from its master seed whatever the number of cores.
small <- constellations(n = 50, designs = c("continuous", "discrete"))
one <- coverage_study(small, runs = 4L, master_seed = 16L, replicates = 199L, level = .9, cores = 1L)
two <- coverage_study(small, runs = 4L, master_seed = 16L, replicates = 199L, level = .9, cores = 2L)
other <- coverage_study(small, runs = 4L, master_seed = 17L, replicates = 199L, level = .9, cores = 2L)
stopifnot(identical(one, two), !identical(one$coverage, other$coverage), nrow(one) == 4L,
          all(c("band", "n", "design", "cep", "coverage", "pass") %in% names(one)),
          identical(is.na(one$pass), one$band == "confidence"))

# Effort reports elapsed time and the peak R heap of one call.
cost <- effort(200, "continuous", "consistency", replicates = 199L)
# Both heap sizes are in MB, not cells: a small call stays well below 1 GB.
stopifnot(cost$seconds >= 0, cost$unique == 200L, cost$baseline_mb > 0,
          cost$peak_mb >= cost$baseline_mb, cost$peak_mb < 1024)

cat("All CORP coverage study checks passed.\n")
