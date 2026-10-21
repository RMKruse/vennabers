# Run from the repository root: Rscript --vanilla tools/build-readme.R
# Render README.Rmd against a temporary installation of this checkout, so the
# output and figures in README.md and man/figures/ come from the current sources.
root <- normalizePath(".")
staging <- tempfile("vennabers-readme-")
library <- file.path(staging, "library")
dir.create(library, recursive = TRUE)
archive <- pkgbuild::build(root, dest_path = staging, vignettes = FALSE,
                          manual = FALSE)
utils::install.packages(archive, lib = library, repos = NULL, type = "source",
                        quiet = TRUE)
.libPaths(c(library, .libPaths()))
stopifnot(packageVersion("vennabers", lib.loc = library) ==
            read.dcf(file.path(root, "DESCRIPTION"))[1, "Version"])

unlink(Sys.glob(file.path(root, "man", "figures", "README-*")))
rmarkdown::render(file.path(root, "README.Rmd"),
                  output_format = rmarkdown::github_document(html_preview = FALSE),
                  envir = new.env(parent = globalenv()), quiet = TRUE)
stopifnot(
  file.exists(file.path(root, "README.md")),
  length(Sys.glob(file.path(root, "man", "figures", "README-*.png"))) > 0
)
