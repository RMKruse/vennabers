# Run from the repository root:
#   Rscript --vanilla tools/minimum-dependencies.R REPOSITORY OUTPUT_DIR
# Installs the declared minimum version of every versioned Suggests entry
# except testthat, the documented transitive pins below, and the remaining
# Suggests from REPOSITORY. A dated snapshot repository supplies the other
# transitive dependencies. Requires pak; writes the pins to OUTPUT_DIR.
suggested_packages <- function(description) {
  field <- read.dcf(description, fields = "Suggests")[1, "Suggests"]
  entries <- trimws(strsplit(field, ",")[[1]])
  entries <- entries[nzchar(entries)]
  package <- trimws(sub("[(].*", "", entries))
  constraint <- ifelse(grepl("[(]", entries), gsub("^[^(]*[(]|[)].*$", "", entries), NA_character_)
  versioned <- !is.na(constraint)
  if (!all(grepl("^>=\\s*[0-9][0-9.-]*$", constraint[versioned]))) {
    stop("Only '>=' Suggests constraints can be pinned: ",
      paste(entries[versioned], collapse = ", "))
  }
  data.frame(package = package, minimum = sub("^>=\\s*", "", constraint))
}

# Transitive packages whose current snapshot version rejects a declared
# minimum: furrr 0.4.0 (imported by rsample and probably) needs future >= 1.70.0,
# so future 1.67.0 runs with furrr 0.3.1.
transitive_pins <- data.frame(package = "furrr", minimum = "0.3.1")

# testthat runs the checks; it is no integration package and stays unpinned.
pinned_minimums <- function(suggests, transitive = transitive_pins[0, ]) {
  rbind(suggests[!is.na(suggests$minimum) & suggests$package != "testthat", , drop = FALSE],
    transitive)
}

minimum_refs <- function(suggests, transitive = transitive_pins[0, ]) {
  pinned <- suggests$package %in% pinned_minimums(suggests)$package
  c(ifelse(pinned, paste0(suggests$package, "@", suggests$minimum), suggests$package),
    paste0(transitive$package, "@", transitive$minimum))
}

version_mismatches <- function(pins, installed) {
  pins$installed <- unname(installed[pins$package])
  same <- mapply(function(installed, minimum) {
    !is.na(installed) && package_version(installed) == package_version(minimum)
  }, pins$installed, pins$minimum)
  pins[!same, , drop = FALSE]
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) {
    stop("Usage: Rscript --vanilla tools/minimum-dependencies.R REPOSITORY OUTPUT_DIR")
  }
  options(repos = c(CRAN = args[1]))
  suggests <- suggested_packages("DESCRIPTION")
  pak::pkg_install(c(minimum_refs(suggests, transitive_pins), "rcmdcheck"), upgrade = FALSE, ask = FALSE)
  pins <- pinned_minimums(suggests, transitive_pins)
  installed <- vapply(pins$package, function(package) {
    as.character(utils::packageVersion(package))
  }, character(1))
  mismatches <- version_mismatches(pins, installed)
  pins$installed <- unname(installed)
  dir.create(args[2], recursive = TRUE, showWarnings = FALSE)
  write.csv(pins, file.path(args[2], "minimum-dependencies.csv"), row.names = FALSE)
  print(pins, row.names = FALSE)
  if (nrow(mismatches)) stop("Installed versions differ from the declared minimums.")
  cat("Declared minimum versions installed.\n")
}
