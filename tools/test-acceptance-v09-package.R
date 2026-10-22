# Small runnable check: Rscript --vanilla tools/test-acceptance-v09-package.R
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
root <- dirname(dirname(normalizePath(script)))
source(file.path(root, "tools", "acceptance-v09-package.R"))
map <- read.csv(file.path(root, "tools", "acceptance-v09-example-coverage.csv"), stringsAsFactors = FALSE)
examples <- list.files(file.path(root, "inst", "examples"), "[.]R$", full.names = TRUE)
stopifnot(!anyDuplicated(map$example), all(map$example %in% basename(examples)),
  all(map$coverage %in% c("suite", "core", "helper", "standalone")))
suite <- map[map$coverage == "suite", ]
for (i in seq_len(nrow(suite))) {
  owner <- paste(readLines(file.path(root, suite$covered_by[i])), collapse = "\n")
  stopifnot(grepl(paste0('"', suite$example[i], '"'), owner, fixed = TRUE))
}
coverage <- example_coverage(examples, map)
stopifnot(identical(coverage$example, basename(examples)),
  identical(coverage$coverage, map$coverage[match(basename(examples), map$example)]),
  coverage$coverage[coverage$example == "full-postprocessing.R"] == "suite",
  coverage$coverage[coverage$example == "cross-venn-abers.R"] == "core",
  coverage$coverage[coverage$example == "assertions.R"] == "helper")
# Unmapped examples must still run, including when an installed candidate has
# a different example inventory from this checkout.
added <- example_coverage(c("new-example.R", "full-postprocessing.R"), map)
stopifnot(identical(added$coverage, c("standalone", "suite")), !anyNA(added))
stopifnot(nrow(example_coverage(character(), map)) == 0L)
cat("Acceptance example coverage checks passed.\n")
