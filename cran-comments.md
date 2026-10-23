## Test environments

* win-builder: R-release (4.6.1) and R-devel
* mac-builder: macOS arm64, R 4.6.1 patched
* R-hub: Linux, Windows, macOS x86_64 and arm64 (R-devel); Ubuntu R-release
  and R-next; gcc-asan, clang-asan, clang-ubsan, ATLAS, MKL and nosuggests
* GitHub Actions: Ubuntu 24.04, Windows Server 2025, macOS 15 x86_64 and
  arm64, each with R-release and R-oldrel-1; Ubuntu with R-devel; Ubuntu with
  the declared minimum versions of the suggested packages; Ubuntu without the
  suggested modelling packages
* Local: macOS 26 arm64, R 4.6.1

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  New submission

  Possibly misspelled words in DESCRIPTION:
    Abers, Brier, Dimitriadis, Fedorova, Gneiting, Manokhin, Petej, Vovk,
    multiclass

  This is a new submission. The flagged words are spelled correctly: "Venn-Abers"
  is the name of the method, Vovk, Petej, Fedorova, Manokhin, Dimitriadis and
  Gneiting are authors of the cited references, "Brier" refers to the Brier
  score, and "multiclass" is the standard term for classification with more
  than two classes.

This is the win-builder result. R-hub and mac-builder report no notes;
GitHub Actions and the local check report no errors or warnings.

## Notes for the reviewer

To keep the check time short, `tests/testthat.R` skips the long-running
process, worker and integration test files listed in
`tests/cran-long-tests.txt` unless `NOT_CRAN=true`. The complete suite runs in
the GitHub Actions matrix and locally before each release.

## Downstream dependencies

None. This is a new package.
