# Run from the repository root: Rscript --vanilla tools/build-docs.R
# Build from the source package so internal root Markdown is not published.
root <- normalizePath(".")
staging <- tempfile("vennabers-docs-")
dir.create(staging)
archive <- pkgbuild::build(root, dest_path = staging, vignettes = FALSE,
                          manual = FALSE)
utils::untar(archive, exdir = staging)
package <- read.dcf(file.path(root, "DESCRIPTION"))[1, "Package"]
source <- file.path(staging, package)
stopifnot(file.copy(file.path(root, c("_pkgdown.yml", "pkgdown")), source,
                    recursive = TRUE))
destination <- file.path(root, "_site")
pkgdown::build_site(source, override = list(destination = destination),
                   preview = FALSE)
stopifnot(
  file.exists(file.path(destination, "index.html")),
  file.exists(file.path(destination, "reference", "vennabers-package.html")),
  !any(file.exists(file.path(destination,
    c("AGENTS.html", "CONTEXT.html", "RELEASE-ROADMAP.html"))))
)
