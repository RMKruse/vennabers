## Status of this file

Prepared on 2026-10-04 for the planned first CRAN submission of vennabers. Nothing
has been submitted. So far the package has been checked in only one local
environment, listed below. All other test environments are still open and must be
added before submission.

## Test environments

Run so far:

* Local macOS Tahoe 26.6.2 (arm64, Apple M5 Pro), R 4.6.1 (2026-06-24):
  `R CMD check --as-cran` on the built tarball, with network access and all
  Suggests installed.
* The same machine, with only R's base-priority packages and vennabers installed
  (no Suggests and no recommended packages): the manual calibration examples and all
  Rd examples run. Workflow integration, tuning and Tailor postprocessing stop
  with an error that names the missing package.

Still open:

* Linux x86_64, Windows x86_64, macOS x86_64 and macOS arm64, each on the current
  (4.6) and previous (4.5) R minor series.
* R-devel (Linux, and win-builder).
* A Linux run with the declared minimum versions of the optional packages.
* A Linux run without the optional workflow packages.

## R CMD check results

Local macOS arm64, R 4.6.1: 0 errors | 0 warnings | 2 notes

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'René-M. Kruse <rene.marcel.kruse@protonmail.com>'
  New submission

  This is a new submission.

* checking HTML version of manual ... NOTE
  Skipping checking HTML validation: 'tidy' doesn't look like recent enough
  HTML Tidy.

  This NOTE comes from the local machine: its HTML Tidy is the 2006 build that
  ships with macOS. The Rd files pass all other Rd checks, and the PDF manual
  builds.

## Check time

The tests took 47 CPU minutes (58 minutes elapsed) in this local
`R CMD check`, with other jobs running on the same machine. The CRAN Repository
Policy asks for as little check time as possible and allows long-running tests
to be made optional. Which tests stay out of CRAN checks has not been decided
yet; this must be settled before submission.

## Downstream dependencies

None. This is a new package.
