# Run from the repository root:
#   Rscript --vanilla tools/minimum-dependencies.R REPOSITORY OUTPUT_DIR
# Installs the declared minimum version of every versioned Suggests entry
# except testthat, and the remaining Suggests from REPOSITORY. A dated
# snapshot repository supplies a compatible, documented set of transitive
# dependencies. Requires pak; writes the pins to OUTPUT_DIR.
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

# testthat runs the checks; it is no integration package and stays unpinned.
pinned_minimums <- function(suggests) {
  suggests[!is.na(suggests$minimum) & suggests$package != "testthat", , drop = FALSE]
}

minimum_refs <- function(suggests) {
  pinned <- suggests$package %in% pinned_minimums(suggests)$package
  ifelse(pinned, paste0(suggests$package, "@", suggests$minimum), suggests$package)
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
  pak::pkg_install(c(minimum_refs(suggests), "rcmdcheck"), upgrade = FALSE, ask = FALSE)
  pins <- pinned_minimums(suggests)
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
