# v0.5 native workflow candidate: acceptance and benchmarks

Issue: [#35](https://github.com/RMKruse/venn-abers/issues/35).
Implementation base: `8248ccc` on `v0.5`. Status: **acceptance incomplete**.
The maintainer's v0.4 approval is a completed predecessor decision, but its
local-only exception does not change the v0.5 acceptance contract. Publication,
tagging and CRAN submission are outside this work.

## Candidate and actual evidence

The candidate and completed local results are recorded below. Configured
jobs, historical predecessor checks and missing logs are never counted as passes.
The report and `tools/evidence-v05/` are excluded from the source archive, so
adding evidence does not alter its payload. All platform jobs download one
source archive, check its SHA-256 and record its installed version and MD5.
Reusing that archive is required: results for a different hash do not qualify.

## Capability evidence

The existing package tests and installed examples cover these paths; no core
formula, tolerance or training implementation changes in this ticket.

| Native paths (each Inductive and Cross) | Functional tests under `tests/` |
| --- | --- |
| Binary | `calibrated-workflow.R`, `cross-workflow.R` |
| Shared multiclass OvO and OvR | `multiclass-workflow.R`, `cross-multiclass-workflow.R` |
| Regression | `regression-workflow.R` |
| All paths: local/outer plans and persistence | `local-plans.R`, `outer-resampling.R`, `integration-processes.R`, plus path-specific files |

These exercise automatic and explicit local plans, complete `fit_resamples`,
manual-core comparisons, diagnostics, zero/one rows, invalid input, leakage,
retained fits, RDS restoration and fresh workers. The complete cumulative manual
reference suite remains installed in the source candidate. Classification uses
absolute tolerance 1e-10. Regression retains its fixed scale-aware absolute and
relative 1e-10 contract. No reference fixture or tolerance is regenerated here.
The installed `calibrated-workflow.R` and `calibrated-resampling.R` examples add
normal Fit/Predict and complete outer evaluation to all prior manual examples.

## Support and dependencies

[CRAN's R source index](https://cran.r-project.org/src/base/R-4/) checked on
2026-09-08 lists current R 4.6.1 and previous-minor R 4.5.3. The declared floor
remains R >= 4.5.0; recheck this rolling floor at release. No v0.4-to-v0.5 R
floor increase or manual API migration is needed.

| Mandatory check | R | Dependency profile | Actual result |
| --- | --- | --- | --- |
| Linux x86_64 / ubuntu-24.04 | 4.6.1 | Current published | Not run |
| Linux x86_64 / ubuntu-24.04 | 4.5.3 | Current published | Not run |
| Windows x86_64 / windows-2025 | 4.6.1 | Current published | Not run |
| Windows x86_64 / windows-2025 | 4.5.3 | Current published | Not run |
| macOS Intel / macos-15-intel | 4.6.1 | Current published | Not run |
| macOS Intel / macos-15-intel | 4.5.3 | Current published | Not run |
| macOS ARM / local macOS 26.6.2 | 4.6.1 | Current published | Pass; hosted macos-15 not run |
| macOS ARM / macos-15 | 4.5.3 | Current published | Not run |
| Additional Linux x86_64 core | 4.6.1 | No optional integration packages | Not run |
| Additional Linux x86_64 minimum | 4.5.3 | Pinned direct/transitive set | Not run |
| Additional Linux x86_64 early warning | R-devel | Current published | Not run; triage pending |

Each job records actual R patch/platform, OS and runner image, package versions,
check settings and artifact identity. The gate currently uses
`R CMD check --as-cran --no-manual`: PDF manual generation and online incoming,
repository and clock probes are excluded and explicitly recorded. Full CRAN
checks, including those omitted probes, remain missing release evidence.
Current/minimum profiles require all suggested packages and declared versions
before running: missing optional packages cannot silently produce green skipped
integration coverage. Minimum additionally checks the exact manifest versions.

The core profile rejects installed optional integration packages, then installs,
checks and exercises the same candidate. Its sole permitted NOTE is the expected
package-dependencies NOTE for unavailable Suggests; the exact check log and
individual justification are preserved. All other NOTEs, warnings and errors
fail the gate. Integration examples/tests are conditional only in this explicit
core profile, where the complete manual suite and manual examples still run.

| Direct optional package | Minimum |
| --- | --- |
| parsnip | 1.6.0 |
| workflows | 1.3.0 |
| hardhat | 1.4.3 |
| rsample | 1.3.2 |
| tune | 2.1.0 |
| yardstick | 1.4.0 |
| recipes | 1.4.0 |
| rlang | 1.2.0 |
| tibble | 3.3.1 |
| withr | 3.0.3 |
| generics | 0.1.4 |
| tidyselect (direct variable selection) | 1.2.1 |

All remain Suggests. There is no tidymodels metapackage or automatic package
installation. Existing `future` is used only to verify the optional worker path;
`tailor` exercises rejection of unsupported postprocessing. Neither introduces
an orchestration backend or a learned-postprocessing API. GLM/LM use `stats`;
shared multinomial uses recommended `nnet`. Workers need `vennabers` plus the
base engine namespaces (e.g. `pkgs = c("vennabers", "nnet")`).

`minimum-dependencies.csv` pins the 93 non-base/non-recommended packages in the
prepared dependency closure, including the exact direct baselines above and
existing test dependencies. It records dependency edges for installation order.
Recommended packages ship with the selected R distribution and their actual
versions are recorded separately. `install-minimum-dependencies.R` installs the
pinned CRAN sources in dependency order and verifies every installed version;
source URLs and MD5 values are logged during setup. This manifest is a candidate
compatible set; local validation does not establish compatibility with R 4.5.3
on Linux until that mandatory job actually passes. It does not claim every
possible dependency combination is supported.

## Benchmark protocol

`performance.R` preserves the historical 16 manual inputs and their RNG draw
order. All 16 now compare against the approved v0.4 archive from
`tools/evidence-v04/vennabers_0.4.0.tar.gz` (SHA-256
`44846f1e2a6cd5ec1672264516122e5d26e65a2a18f69ec1d5fb7078514ddb69`).
The eight new `workflow_*` paths have baseline measurements only, with no
invented predecessor ratios. The runner still supports historical v0.4/v0.3
bundle reproduction.

New inputs use seed 20260910, 2,000 development rows, ten numeric predictors,
and 500 new rows. Binary uses logistic GLM, both three-class paths share the
same multinomial data/configuration/partitions, and regression uses LM. All use
an untrained normalization recipe, learned separately within each permitted
model-training partition. Multinomial has fixed penalty 0 and maxit 200;
classification uses Log, no rounding, and regression m=1. Direct and inner
Inductive plans hold out 20%; Cross uses five folds. Outer evaluation has three
folds. Seeds 3501/3502/3503 prepare direct/outer/inner plans; 3504 controls fits.
Saved input RDS contains the actual data, outer and every local split, options,
untrained recipe/model configuration and seeds. It can be replayed unchanged.

One warmup and three measurements run serially in a fresh process per
case/release on the same Linux x86_64 machine and compatible R/package set.
OMP/OpenBLAS/MKL/VECLIB/BLIS pools use one thread. Fit and Predict have separate
elapsed timings. Integration also measures complete outer evaluation, including
all inner fits; construction and public validation stay timed. Manual
`outer_seconds = 0` denotes not applicable, not a measured zero-duration outer
fit. Data construction, dependency setup, package installation and RDS I/O are
outside timing windows. `allow_par = FALSE` enforces serial outer evaluation.

Raw runs, medians, model RDS bytes, per-case process peak RSS and fresh-process
restoration/prediction equality are saved. Linux uses `/usr/bin/time -v`; process
peak includes runtime, warmup, fits, outer evaluation and serialization and is
not an isolated model-memory claim. Fits/results are freed between iterations.
RDS is gzip/version 3. Hardware/RAM/OS, versions, pool options, generator source,
input/artifact hashes and logs accompany each bundle. Verifiers independently
recompute summaries and check coverage, schemas, disjoint actual plans, local
training domains and saved inputs. Mutation checks reject corrupt evidence.

Controlled Linux benchmark evidence and investigation of all deteriorations
remain required. Non-Linux `--smoke` validates tooling and restoration only;
it cannot establish performance clearance. Large benchmarks run separately from
package checks. Tests/examples require neither Python nor network after setup.

## Scope and reproduction

v0.6 adds frozen adoption, reversible names and ordered reference holdouts;
v0.7 pair training/full-model transfer; v0.8 tuning; v0.9 learned postprocessing.
The eight shared-model paths do not claim complete Python training parity.

```sh
# Setup only, in a prepared R 4.5.3/Linux environment:
Rscript --vanilla tools/install-minimum-dependencies.R /path/to/minimum-library

# Every platform reuses the saved candidate; output must be empty.
R_LIBS=/path/to/minimum-library ACCEPTANCE_PROFILE=minimum \
  ACCEPTANCE_ARTIFACT=tools/evidence-v05/vennabers_0.5.0.tar.gz \
  ACCEPTANCE_OUTPUT_DIR=.scratch/v05-minimum Rscript --vanilla tools/acceptance.R
# Use profile=current for the eight regular jobs; profile=core in a clean R
# installation without the optional integration packages.

# Controlled Linux x86_64; append --smoke only for non-release tooling checks.
Rscript --vanilla tools/performance.R tools/evidence-v05/vennabers_0.5.0.tar.gz \
  tools/evidence-v04/vennabers_0.4.0.tar.gz benchmark-output
Rscript --vanilla tools/test-performance.R benchmark-output --v05
Rscript --vanilla tools/test-performance-verifier.R benchmark-output
```

## Local execution record, 2026-09-08

The saved [candidate](evidence-v05/vennabers_0.5.0.tar.gz) has SHA-256
`53a2b544776f7978a51c2732df97f7372d18bdcfeab2f27b1b1b6f64b4e6ac26`.
The [payload check](evidence-v05/payload-match.log) confirms all 123 archived
files match the checkout byte-for-byte, with DESCRIPTION matching after build
whitespace normalization. The excluded workflow configuration additionally
sets dependency upgrades explicitly: `setup-r-dependencies` defaults to false.
`source-diff.patch` records implementation changes from `8248ccc`.

The final artifact is installed independently for all three local profiles.
Each profile uses R 4.6.1 on macOS 26.6.2 / ARM64, Apple M5 Pro, 15 logical CPUs,
24 GiB RAM, OpenBLAS 0.3.34 and LAPACK 3.12.1. The exact environment, libraries,
package versions, logs and check restrictions are retained per profile.
These are local runs; they are not hosted macOS-15 runner results or Linux
minimum/core results. The minimum profile uses the declared direct baselines
and all 93 exact non-recommended pins; recommended packages come from R 4.6.1.
The current profile also updates the seven newer recommended dependencies,
besides Rcpp, RcppArmadillo and rlang, and verifies the whole relevant CRAN
closure against the published index before starting its offline gate.

The gate's child processes deny outbound internet and Python execution. Local
loopback sockets remain allowed for fresh multisession workers. Environment
setup and the CRAN version lookup are outside that restriction. The sandbox
profile used is:

```text
(version 1)(allow default)(deny network-outbound)
(allow network-outbound (remote ip "localhost:*"))
(deny process-exec (regex #".*/python[^/]*$"))
```

The core profile reports unavailable Suggests as INFO on this R patch, not a
NOTE. Its integration blocks skip by design; all manual tests and examples run.
Current/minimum profiles require every dependency and run all 21 test files,
help examples, 12 README R fences and nine installed standalone example scripts.
Local static validation is R parsing plus R CMD check's usage/code-problem
checks; no separate typechecker is configured. Actionlint 1.7.12 passes.
The gate's injected missing/old dependencies, failing installed example and
failing package test all exit nonzero. Fresh missing/old parsnip probes verify
the installed candidate still loads and runs its manual core, while the native
constructor names the required package/version and explicit installation action.

### Remote execution blocker

GitHub API reports the acceptance workflow as `disabled_manually` (workflow ID
351671648); the exact response is [saved](evidence-v05/workflow-state.json).
Remote enablement and making this implementation available on the remote branch
are required before dispatching it with `benchmarks=true`. This runs the matrix,
additional minimum/core profiles and separate serial Linux benchmark on one
newly built CI candidate. Retain that candidate's own hash and evidence; do not
attribute local results to a newly built archive with a different hash.

The seven other platform/R combinations, additional Linux core/minimum jobs,
R-devel triage and controlled Linux performance comparisons remain missing.
No release approval, tagging, publication or CRAN submission is claimed.

## Standards review

Independent review against `8248ccc`: no documented-standard violations and no
actionable maintainability smells. The reviewer found one evidence-test defect:
a corrupted manual fixture could mask failures in subsequent integration
mutations. It is fixed by restoring the fixture and checking the valid bundle
before and after each mutation group. Final runnable verification is recorded
with the bundle. No additional package dependencies or product APIs were added.

## Spec review

Independent review against issue #35: no additional implementation gap or scope
creep found beyond pending external evidence. The same mutation-test defect was
found and independently confirmed fixed. Subsequent local verification also
fixed cold-process registration of rsample's `as.integer.rsplit` method in the
benchmark verifier and removed generator environments from saved recipe terms.
Those fixes preserve the benchmark configuration and all numerical tolerances.

Review totals: Standards 0 unresolved findings; Spec 0 unresolved implementation
findings, with the explicitly listed platform and controlled-benchmark evidence
still required for acceptance.

## Final smoke benchmark bundle

The final [bundle](evidence-v05/benchmark-smoke/) uses the same saved candidate
hash above and the approved v0.4 reference. It contains 24 cases, 40 case/release
pairs, 160 raw rows (40 warmups plus 120 measurements), 40 medians and 24
comparison rows. All 40 fresh-process restorations reproduce predictions
identically. All 16 historical manual input objects remain identical to v0.4.
The bundle verifier also still accepts the historical v0.4 evidence format.
The non-Linux release guard rejects this machine before creating output.

This macOS smoke used the pinned dependency environment and overlapped other
local verification. It validates execution and evidence tooling only; **none of
its timings or increases establish performance clearance**. Every manual
comparison remains marked `requires regression review`. Controlled serial Linux
remeasurement and investigation/justification of deteriorations remain open.

| Native case | Fit median, s | Predict median, s | Outer median, s | Process peak bytes | Model RDS bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| workflow_binary_cross | 0.089 | 0.011 | 0.327 | 405028864 | 9415695 |
| workflow_binary_inductive | 0.045 | 0.004 | 0.166 | 374374400 | 2259443 |
| workflow_ovo_cross | 0.159 | 0.013 | 0.480 | 397230080 | 7528990 |
| workflow_ovo_inductive | 0.054 | 0.004 | 0.191 | 372441088 | 1882048 |
| workflow_ovr_cross | 0.164 | 0.014 | 0.504 | 398983168 | 7543800 |
| workflow_ovr_inductive | 0.057 | 0.004 | 0.207 | 372326400 | 1885079 |
| workflow_regression_cross | 0.087 | 0.031 | 0.409 | 393297920 | 9229309 |
| workflow_regression_inductive | 0.040 | 0.003 | 0.158 | 367853568 | 2257148 |

All input RDS, options/plans, runs, medians, comparisons, generator source,
environment and case/restoration logs are retained in the committed bundle.
`generated-rds.csv` records SHA-256 and sizes of every generated model,
prediction and outer-evaluation RDS. Those generated RDS files and isolated
libraries remain in `.scratch/issue-35/evidence-benchmark/` and are recreated by
the runner rather than duplicated in Git. The source archives are retained once
in `evidence-v05/` and `evidence-v04/`. `SHA256SUMS` covers the committed evidence.

## Final local gate results

| Same candidate / R 4.6.1 / macOS ARM | Result | Evidence |
| --- | --- | --- |
| Current published direct and transitive dependencies | Pass: 0 errors, 0 warnings, 0 NOTEs | [check](evidence-v05/local-current/00check.log), [full gate](evidence-v05/local-current/acceptance.log) |
| Exact minimum direct / pinned transitive environment | Pass: 0 errors, 0 warnings, 0 NOTEs | [check](evidence-v05/local-minimum/00check.log), [full gate](evidence-v05/local-minimum/acceptance.log) |
| Manual core without optional integration packages | Pass: 0 errors, 0 warnings, 0 NOTEs; expected unavailable-Suggests INFO | [check](evidence-v05/local-core/00check.log), [full gate](evidence-v05/local-core/acceptance.log) |

The current-dependency audit is saved in
[published-current-versions.txt](evidence-v05/published-current-versions.txt).
This local ARM/current-R result supplies one platform/R combination. The local
minimum/core passes do not replace the two additional required Linux jobs.
The [bundle check](evidence-v05/bundle-check.log) and
[mutation checks](evidence-v05/verifier-regression.log) validate the saved smoke.

Verify committed evidence from its directory with `shasum -a 256 -c SHA256SUMS`.
