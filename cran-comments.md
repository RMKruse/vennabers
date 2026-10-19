## Status of this file

Prepared on 2026-10-04 and updated on 2026-10-19 for the planned first CRAN
submission of vennabers. Nothing has been submitted. So far the package has been checked in only one local
environment, listed below. All other test environments are still open and must be
added before submission.

## Test environments

Run so far:

* Local macOS Tahoe 26.6.2 (arm64, Apple M5 Pro), R 4.6.1 (2026-06-24):
  `R CMD check --as-cran` on the built 1.0.0 tarball from candidate
  `b32c2915d8c03585fbf1b0c4f6eb4315820ad0c1`, with R's own online checks and all
  Suggests installed. The short CRAN profile passed all 4,331 expectations,
  without failures, warnings or skips; examples, vignettes and PDF manual passed.
  Archive SHA-256: `0de85865ad6b8c28a787d6e33c5116c0a47399c252053057771ad774571b10de`.
  The complete suite passed separately from the same archive: 32,184 expectations
  in all 108 installed test files, with no failures, errors, warnings or skips.
  Four local test processes completed in 1,062.5 seconds; BLAS/OpenMP threads
  were limited to one. Product HTTP(S) was routed to a dead proxy in that run;
  R's own online checks were separate.
* The same 1.0.0 archive installed with only base/recommended packages and
  vennabers: manual core, the one-hot class example and all Rd examples
  passed, the optional workflow packages were unavailable and remained
  unloaded, and the workflow entry point returned its missing-package error.
  All 45 installed example files are covered by the complete suite, 8 core
  examples, 18 fresh-process standalone tutorials and 2 helpers. The 25
  package-operation checks passed with no warning lines, including
  registration/load orders and the static scan for Python or product network
  calls (zero hits).
* The earlier candidate `0b35f3354d18ada96baf4d4f437e593da193d4e8` (archive
  SHA-256 `e73335b8f1a822fa6abed64de77a4ee1aecf1383c6cd65862badfb69eef00183`)
  passed its local checks before the 1.0.0 additions; it is superseded.
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

  Found the following (possibly) invalid URLs:
    URL: https://github.com/RMKruse/venn-abers
    URL: https://github.com/RMKruse/venn-abers/issues
      Status: 404

  This is a new submission. The repository and issue tracker were not yet
  public when this local check ran. They must resolve before submission, and
  this NOTE must then be rechecked rather than explained.

* checking HTML version of manual ... NOTE
  Skipping checking HTML validation: 'tidy' doesn't look like recent enough
  HTML Tidy.

  This NOTE comes from the local machine: its HTML Tidy is the 2006 build that
  ships with macOS. The Rd files pass all other Rd checks, and the PDF manual
  builds.

## Check time

On the previous candidate, the complete tests took 47 CPU minutes (58 minutes
elapsed) inside the local check, with other jobs running on the same machine.
The maintainer approved a short CRAN profile on 2026-10-04. The long
process/worker and integration matrix files listed in `tests/cran-long-tests.txt`
remain in the source tarball but are excluded from the default CRAN run. `NOT_CRAN=true` enables the complete in-check
suite; `tools/verify.R` always runs every installed test file locally, with
bounded parallelism. The 68 long files listed there now include the
process files of the 1.0.0 additions; 40 files run in the short profile. On
candidate `b32c291`, the short-profile test process used 84.7 user + 3.0
system CPU seconds and 87.9 elapsed seconds (the check log rounds this to
88 seconds). This check included the tests; it did not use
`--no-tests`. The complete local suite remains a separate release gate.

## Downstream dependencies

None. This is a new package.
