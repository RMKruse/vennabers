# v0.3 package CI and support evidence

Implemented on 2026-09-07 for the v0.3 development branch, starting at
`3be8ac61f9a9c71c399d4b3a03169b26c0232172`. Package version `0.2.0.9000`
distinguishes this work from released v0.2.0; it does not declare v0.3 complete.

## Required matrix

[CRAN's release archive](https://cran.r-project.org/src/base/R-4/) and
[macOS binaries](https://cran.r-project.org/bin/macosx/) were checked on
2026-09-07: current R is 4.6.1, previous minor series is 4.5 (patch 4.5.3).
The active `.github/workflows/acceptance.yaml` expands to eight required jobs:

| Runner label | Runner architecture | R architecture | Required patches |
| --- | --- | --- | --- |
| `ubuntu-24.04` | `X64` | `x86_64` | 4.6.1, 4.5.3 |
| `windows-2025` | `X64` | `x86_64` | 4.6.1, 4.5.3 |
| `macos-15-intel` | `X64` | `x86_64` | 4.6.1, 4.5.3 |
| `macos-15` | `ARM64` | `aarch64` | 4.6.1, 4.5.3 |

Runner labels follow [GitHub's hosted-runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
Both `RUNNER_ARCH` and `R.version$arch` are checked: emulated Intel R on an
ARM runner cannot masquerade as the Intel job. OS labels identify an image
series, not an immutable image; `ImageOS`, `ImageVersion`, `Sys.info()`, exact
R build, package versions and GitHub run/commit identifiers are retained per
job in `environment.txt`. Build/install/check logs and the source artifact
are uploaded with the check directory even when the gate fails. The setup
job log additionally records resolved action and runner-image revisions.

A ninth job uses Linux x86_64 R-devel. Only this job has `continue-on-error`;
its failure remains visible in Actions with the same evidence artifacts.
Review and record any devel findings at release acceptance; they do not
automatically block release. No R-devel result is asserted here.

The `DESCRIPTION` floor is R 4.5.0. Before final v0.3 acceptance, resolve the
then-current and previous minor series again, update both patch pins and the
floor if necessary, document any increase in NEWS, and obtain all eight clean
hosted results. Released versions retain their recorded minimum; there is
no additional permanent R 4.1 job. The v0.5 integration/minimum-dependency jobs
are outside this ticket.

## Gate and scope

From the checkout root, `Rscript --vanilla tools/acceptance.R` builds a source
tarball, installs it in a fresh library and checks the tarball with
`R CMD check --as-cran --no-manual --library=...`. R CMD check installs that
artifact and runs all discovered package tests and Rd examples against it.
The gate then verifies the loaded namespace path and package version before
running both README R fences from the tarball and every `.R`/`.r` script
recursively under `examples/`. It never sources the package's checkout `R/`.

Only base R and standard distribution packages are needed. Python is only
used by optional fixture regeneration; stored numerical fixtures are used
by normal tests. `NOT_CRAN=false` overrides setup-r's default. Online incoming
checks (`_R_CHECK_CRAN_INCOMING_`, `_R_CHECK_CRAN_INCOMING_REMOTE_`) and the
network-dependent clock probe (`_R_CHECK_SYSTEM_CLOCK_`) are disabled. No
package tests or executable examples are disabled. PDF manual generation is
excluded, so CI needs no TeX installation. This gate is not a CRAN submission
or a claim that online submission checks and manual checks passed.

The gate fails on nonzero child status, errors, warnings or NOTEs and requires
`Status: OK`. There is currently no NOTE allowlist. The initial CRAN-mode run
identified the nonstandard top-level `RELEASE-ROADMAP.md`; `.Rbuildignore`
now excludes this planning document. No remaining NOTEs need justification.

The large IVAP case remains separately runnable via
`Rscript tools/performance.R` after installing the source artifact. It retains
100,000 calibration and 100,000 prediction rows and three timings, without
the old 10-second threshold. The complete warmup, measurement, peak-memory
and prior-release comparison protocol remains part of overall release
acceptance in `RELEASE-ROADMAP.md`; this ticket does not claim those benchmarks.

## Representative local evidence

On 2026-09-07 the clean gate exited 0 on R 4.6.1
(`aarch64-apple-darwin25.4.0`), macOS 26.6.2 / Darwin 25.6.0, arm64.
All four package test files, Rd examples, two README R fences and the
three-fold GLM example passed. The check finished with `Status: OK` (zero
errors, warnings and NOTEs) and the gate printed `Acceptance gate passed.`
R's standard base packages, compiler and tools were version 4.6.1;
codetools was 0.2-20. No additional package dependency was introduced.

The clean run and the failure regression check used a macOS sandbox denying
all network access and Python process execution, including child processes:

```sh
ACCEPTANCE_OUTPUT_DIR=.scratch/ci-clean EXPECTED_R_ARCH=aarch64 \
  /usr/bin/sandbox-exec \
  -p '(version 1)(allow default)(deny network*)(deny process-exec (regex #".*/python[^/]*$"))' \
  /opt/homebrew/opt/r/bin/Rscript --vanilla tools/acceptance.R

/usr/bin/sandbox-exec \
  -p '(version 1)(allow default)(deny network*)(deny process-exec (regex #".*/python[^/]*$"))' \
  /opt/homebrew/opt/r/bin/Rscript --vanilla tools/test-acceptance.R
```

Choose a new empty output directory when repeating a retained run. Logs and
the artifact from this local run are in `.scratch/ci-clean/`; the console log
is `.scratch/ci-clean.log`. These local outputs are not committed.

`tools/test-acceptance.R` copies the checkout to temporary storage and injects
a failing example, then a failing package test, separately. Both child gates
exited 1, included the intentional failure marker, and omitted the success
message. Before implementation the newly added example was silently ignored
and the gate exited 0; this regression check failed as expected. CI runs the
same regression check inside the required Linux R 4.6.1 job. It cannot turn
the normal gate green: the clean gate is an earlier, separate required step.

R syntax checks and actionlint 1.7.12 passed. The matrix is configured and
validated, but no hosted GitHub Actions run was dispatched from this local
implementation session. This ARM local run is not evidence for macOS Intel,
Linux, Windows, R 4.5.3, or the macOS 15 runner image. Their results must be
collected from the workflow after push before claiming full matrix acceptance.
