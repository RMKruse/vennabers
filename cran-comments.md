## Status of this file

Prepared on 2026-10-04 for the planned first CRAN submission of vennabers. Nothing
has been submitted. So far the package has been checked in only one local
environment, listed below. All other test environments are still open and must be
added before submission.

## Test environments

Run so far:

* Local macOS Tahoe 26.6.2 (arm64, Apple M5 Pro), R 4.6.1 (2026-06-24):
  `R CMD check --as-cran` on the built tarball, with network access and all
  Suggests installed. The latest check ran with `--no-tests` to save time; the
  tests then ran separately on the installed package (all passed). The previous
  candidate's check included the tests, which all passed in the check.
* The same machine with `_R_CHECK_DEPENDS_ONLY_=true`: Status OK. Tests that
  need the optional workflow packages skip.
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

On the previous candidate, the complete tests took 47 CPU minutes (58 minutes
elapsed) inside the local check, with other jobs running on the same machine.
The maintainer approved a short CRAN profile on 2026-10-04. The 65 long
process/worker and integration matrix files listed in `tests/cran-long-tests.txt`
remain in the source tarball but are excluded from the default CRAN run.
The 36 other files run there. `NOT_CRAN=true` enables the complete in-check
suite; `tools/verify.R` always runs every installed test file locally, with
bounded parallelism. The 1.0.0 candidate's measured check time and results will
be recorded after its check finishes; the results above refer to the preceding
metadata candidate.

## Downstream dependencies

None. This is a new package.
