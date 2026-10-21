# Contributing to vennabers

Report bugs and suggest changes in the
[issue tracker](https://github.com/RMKruse/vennabers/issues). For a bug, a
minimal reproducible example and the output of `sessionInfo()` help most.

## Running the tests

Install the packages listed under `Suggests` in `DESCRIPTION`, plus `rpart`.
Then run from the repository root:

```sh
Rscript --vanilla tools/verify.R
# Verify a specific built archive, using four local test processes:
Rscript --vanilla tools/verify.R 4 /absolute/path/vennabers_1.0.0.tar.gz
```

This installs the package and its tests in a temporary library and runs every
test file once across four processes, longest files first. Failures, errors,
warnings and skips all fail verification. Logs and results stay in the printed
temporary directory, and a successful run refreshes `tools/test-durations.csv`.
Use `R_LIBS` to point at an additional dependency library. A complete run takes
about 16 minutes with four processes.

CRAN checks use a short profile: `tests/cran-long-tests.txt` lists the process,
worker and integration matrix files excluded there. Set `NOT_CRAN=true` to run
the complete suite under `R CMD check`; `tools/verify.R` always runs every
test file.

## Building the documentation website

With `pkgdown` and the suggested packages installed:

```sh
Rscript --vanilla tools/build-docs.R
```

Open `_site/index.html`. The homepage source is `pkgdown/index.md`. The build
runs the reference examples and guide code against a temporary package
installation. Generated HTML is excluded from Git and the source package.

The `pkgdown` workflow runs the same script on every push to `main` and
publishes the result at <https://rmkruse.github.io/vennabers/>.

## Updating the README

`README.md` is generated. Edit `README.Rmd` and render it against a temporary
installation of the checkout:

```sh
Rscript --vanilla tools/build-readme.R
```

The script also writes the README figures to `man/figures/`. Commit both.

## Release candidates

```sh
Rscript --vanilla tools/build-candidate.R HEAD
```

builds the source archive, PDF manual, packaged-content hashes and
`candidate.dcf` from a committed checkout. [`tools/RELEASE.md`](../tools/RELEASE.md)
covers dependency setup, offline product tests, examples and benchmarks.
