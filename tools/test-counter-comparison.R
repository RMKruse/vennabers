# Small runnable check without Python:
#   Rscript --vanilla tools/test-counter-comparison.R [<library> ...]
# The libraries are passed on to counter-comparison-inputs.R.
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
tools <- dirname(normalizePath(script))
root <- dirname(tools)
libraries <- commandArgs(trailingOnly = TRUE)

# The inputs cover every stored classification fixture and round-trip exactly.
out <- tempfile("counter-comparison-")
on.exit(unlink(out, recursive = TRUE), add = TRUE)
status <- system2(file.path(R.home("bin"), "Rscript"),
  c("--vanilla", shQuote(file.path(tools, "counter-comparison-inputs.R")), shQuote(out), shQuote(libraries)))
stopifnot(status == 0L)
read <- function(name) read.csv(file.path(out, name), colClasses = "character")
unhex <- function(x) ifelse(x == "", NA_real_, as.numeric(x))
calibration <- read("binary-input-calibration.csv")
new <- read("binary-input-new.csv")
binary <- read("vb-binary-inductive.csv")
cross <- read("vb-binary-cross.csv")
multiclass <- read("multiclass-input-new.csv")
stopifnot(length(unique(calibration$key)) == 707L, nrow(new) == 17444L,
  nrow(binary) == 5L * 17444L, nrow(cross) == 5L * 2520L,
  length(unique(multiclass$case_id)) == 33L, nrow(multiclass) == 2L * 372L)
fixtures <- file.path(root, "tests", "testthat", "extdata")
randomized <- read.csv(file.path(fixtures, "randomized-calibration.csv"), comment.char = "#")
stored <- calibration[startsWith(calibration$key, "randomized_"), ]
stopifnot(identical(unhex(stored$score), randomized$probability[order(randomized$case_id, seq_len(nrow(randomized)))]))
stopifnot(all(grepl("^-?0x", binary$upper)), all(unhex(binary$lower) <= unhex(binary$upper)))

# The pins agree across the requirements, the Python script and PARITY.md.
requirements <- readLines(file.path(tools, "counter-comparison-requirements.txt"))
pin <- function(package) sub(".*==", "", grep(paste0("^", package, "=="), requirements, value = TRUE))
parity <- paste(readLines(file.path(root, "inst", "PARITY.md"), encoding = "UTF-8"), collapse = "\n")
python <- paste(readLines(file.path(tools, "counter-comparison-mapie-ce.py")), collapse = "\n")
reference_hash <- regmatches(parity, regexpr("numerical module SHA-256\n`[0-9a-f]{64}`", parity))
reference_hash <- gsub(".*`([0-9a-f]{64})`", "\\1", reference_hash)
stopifnot(identical(pin("venn-abers"), "1.5.4"),
  grepl(paste0("- **Version:** MAPIE ", pin("mapie"), ","), parity, fixed = TRUE),
  grepl(paste0("- **Version:** calibrated-explanations ", pin("calibrated-explanations"), ","), parity, fixed = TRUE),
  nchar(reference_hash) == 64L,
  grepl(paste0('REFERENCE_MODULE_SHA256 = "', reference_hash, '"'), python, fixed = TRUE))

cat("Counter-comparison checks passed.\n")
