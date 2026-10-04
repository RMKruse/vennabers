## Status of this file

Prepared on 2026-10-04 for the planned first CRAN submission of vennabers. Nothing
has been submitted. So far the package has been checked in only one local
environment, listed below. All other test environments are still open and must be
added before submission.

## Test environments

Run so far:

* Local macOS Tahoe 26.6.2 (arm64, Apple M5 Pro), R 4.6.1 (2026-06-24):
  `R CMD check --as-cran` on the built 1.0.0 tarball from candidate
  `0b35f3354d18ada96baf4d4f437e593da193d4e8`, with R's own online checks and all
  Suggests installed. The short CRAN profile passed all 3,948 expectations,
  without failures, warnings or skips; examples and PDF manual passed.
  Archive SHA-256: `e73335b8f1a822fa6abed64de77a4ee1aecf1383c6cd65862badfb69eef00183`.
  The complete suite passed separately from the same archive: 31,661 expectations
  in all 101 installed test files, with no failures, errors, warnings or skips.
  Four local test processes completed in 1,194.9 seconds; BLAS/OpenMP threads
  were limited to one. Product HTTP(S) was routed to a dead proxy in that run;
  R's own online checks were separate.
* The same 1.0.0 archive installed with only base/recommended packages and
  vennabers: manual core and all Rd examples passed, the optional workflow
  packages were unavailable and remained unloaded, and the workflow entry
  point returned its missing-package error. All 41 installed example files
  are covered by the complete suite, core checks, 16 fresh-process standalone
  tutorials and their helper tests. The 23 package-operation checks passed
  with no warning lines, including registration/load orders and the static
  scan for Python or product network calls (zero hits).
* The preceding metadata candidate on the same machine with
  `_R_CHECK_DEPENDS_ONLY_=true`: Status OK. Tests that
  need the optional workflow packages skip.
* The preceding metadata candidate on the same machine, with only R's
  base-priority packages and vennabers installed
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
bounded parallelism. On candidate `0b35f33`, the short-profile test process
used 79.9 user + 3.2 system CPU seconds and 83.5 elapsed seconds (the check log
rounds this to 83/84 seconds). This check included the tests; it did not use
`--no-tests`. The complete local suite remains a separate release gate.

## Downstream dependencies

None. This is a new package.
