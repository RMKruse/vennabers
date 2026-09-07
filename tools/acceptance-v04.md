# v0.4 regression candidate: acceptance and benchmarks

Status on 2026-09-07: **approved for release by the maintainer** under the
updated criterion: "if all tests locally pass, v0.4 is approved."
All local package tests, examples, artifact checks and benchmark tooling checks
passed for the saved candidate. This decision supersedes the original v0.4
requirement to block approval on the full platform matrix, Linux R-devel and
controlled Linux benchmarks. Those unexecuted checks remain documented below
and are not claimed as passes. Tagging, publishing and CRAN submission remain
outside this ticket.

Scope: `.scratch/v0.4-tickets/issues/03-release-abnahme.md`, the
[regression contract](https://github.com/RMKruse/venn-abers/issues/5#issuecomment-5561777290)
and [pinned roadmap](https://github.com/RMKruse/venn-abers/blob/73bcd7cceba1d9c3da665945f3d76c79c9370a61/RELEASE-ROADMAP.md),
sections 3 and 5. Implementation starts at
`cbd2729b6b13719049779d74cd05fea559e3585a`; IVAR and CVAR are already present
there. The initial acceptance ticket changed release metadata and verification
tooling. The refreshed candidate includes the subsequent regression endpoint
and fold-mean fixes, stricter benchmark metadata checks, and corrected
README/NEWS approval wording from source commit
`a4c6acd50b64ae5b1fd550985b7ba9d731d5f684`. Classification tolerances are unchanged.

## Predecessor: approved; stable comparison reference retained

Maintainer confirmation on 2026-09-07 supersedes the earlier local status:
**v0.3 is approved and has been run on Linux and Windows machines.**
Predecessor release approval is therefore no longer a v0.4 blocker. This
confirmation concerns v0.3; the v0.4 candidate results below remain separate.

The complete classification source used for comparison is
`801f467eeafe5539255e0aa09ac9b8cfae598d07`, the last commit before IVAR.
Its DESCRIPTION is 0.3.0. It includes binary Inductive/Cross, Log/Brier,
rounding, classes, fold diagnostics, Inductive/Cross OvO/OvR, scores and plots,
including the later active-subproblem probability fix. It is an immutable
comparison reference. The maintainer's confirmation did not identify the exact
archive used on the other machines, so those runs are not attributed to this
locally rebuilt archive.

The historical [v0.3 acceptance report](acceptance-v03.md) left approval open
before the maintainer's confirmation above.
Its historical archive SHA-256 is
`c72d953b049de7087372eb065c2198f88855094ca0120a31da3660c62788b825` and its
payload predates later classification fixes. It is not substituted for the
newer reference. The recorded archive identities remain unchanged; approval is
recorded from the maintainer's explicit confirmation, not inferred from a
version string or a closed planning issue.

The reference was exported with `git archive 801f467` and built with the same
local R 4.6.1 used for v0.4. Its saved source artifact is
`evidence-v04/vennabers_0.3.0.tar.gz`, SHA-256
`ef870867c303b43324f838dbb94e77d65377a833da5ec28cfd546f782308ca4f`.
The build log is retained; the benchmark installs this archive in its own library.
Future approved predecessor changes require a fresh compatible comparison.

## Candidate identity and capability map

The saved candidate is [vennabers_0.4.0.tar.gz](evidence-v04/vennabers_0.4.0.tar.gz),
SHA-256 `44846f1e2a6cd5ec1672264516122e5d26e65a2a18f69ec1d5fb7078514ddb69`,
MD5 `b799a986bf4c685ca5e28470d527ffd0`.
Both local acceptance runs and the benchmark used this exact archive.
[SHA256SUMS](evidence-v04/SHA256SUMS) identifies both archives, saved inputs,
runner/verifier source and evidence. These reports and `tools/evidence-v04/`
are excluded from the package so adding results cannot change its payload.

Refreshed on 2026-09-07 from `a4c6acd`. This archive supersedes the earlier
candidate SHA-256
`6521d7c38695774813057a4dc55695fca9bce5d904b2e8b7921270c78e102cd2`;
the earlier archive and evidence remain in Git history. The
[payload check](evidence-v04/payload-match.log) verifies every archived file
against that checkout, excluding only build-normalized DESCRIPTION, and confirms
the two acceptance runs used byte-identical archives. The refreshed
[build log](evidence-v04/source-build.log) is retained alongside the check logs.

All paths below are inside the source/installed artifact. The local gate ran
all 13 package test files, help examples, nine README R fences and seven
installed standalone scripts. Examples load the isolated installed namespace.

| Capability | Executable evidence | Contract retained |
| --- | --- | --- |
| IVAR m/epsilon and asymmetric moderation | `tests/inductive-regression.R`, `tests/regression-parity.R` | Explicit/default m, epsilon rounding/domain, requested/effective parameters, replacement without dropping rows |
| IVAR endpoints and weighted merger | Same two files | Independent isotonic checks, Formula 6, constant/coincident bounds, nonconstant zero weights, tiny positive weights, ties, exterior scores, strict finite inputs |
| CVAR fold-local moderation and diagnostics | `tests/cross-regression.R`, `tests/cross-regression-parity.R` | Matched named columns, unequal fold sizes, per-fold errors, complete calibrators and effective parameters |
| CVAR aggregation | Same two files | Separate equal-weight means of complete points/lower/upper; reconstruction distinguishes pooling, size weighting and a second merger; stable cancellation/overflow handling |
| Regressor schema, persistence and evaluation | Four regression test files; `inst/examples/inductive-regression.R`, `inst/examples/cross-regression.R`; both regression help topics | Double columns `prediction/lower/upper`, zero/one rows, positional identity, fresh-process RDS restoration, separate training/calibration/assessment, RMSE/MAE |
| Binary IVAP/Cross and default Log | `venn-abers.R`, `randomized-parity.R`, `cross-venn-abers.R`, `cross-parity.R` under `tests/`; README/help and installed GLM example | Original intervals, stable Cross Log aggregation, matched folds, scoring/plots |
| Classification options | `tests/binary-options.R`, `tests/binary-options-parity.R`; installed `binary-options.R` | Log/Brier, native calibration-only rounding, event/tie rule and fold details |
| Inductive/Cross multiclass OvO/OvR | `tests/inductive-multiclass.R`, `tests/inductive-ovr.R`, `tests/cross-multiclass.R`; three installed multiclass examples | Class identity, coupling/normalization, options, binary diagnostics, scores and plots |

Reference: Python venn-abers 1.5.4, commit
`0e7b4bc575ce230134576ba1c76688d46bf99ac7`; numerical module SHA-256
`ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5`.
[IVAR provenance](../inst/extdata/regression-reference.md) documents 116 cases,
1,099 valid direct rows and 337 retained defective direct rows.
[CVAR provenance](../inst/extdata/cross-regression-reference.md) documents 80
cases, 220 folds, 1,540 fold predictions and 560 aggregate predictions, with
1,243 valid direct component rows and 297 defective rows. Every row is compared
with the valid reference components and independently specified merger/aggregate.

Regression comparisons use `abs(actual-expected) <= 1e-10*s + 1e-10*abs(expected)`.
The unit scale is fixed before generation: ordinary `s=1`, small `s=1e-12`,
large `s=1e120`, shifted `s=1` with additive shift `1e5`. Shape, types, finiteness,
row/fold identity and ordering are separate checks. Classification remains
absolute `1e-10` without relative allowance. No tolerance was changed here.
Python's defective lower scan is replaced in reference comparisons by the
reflected valid upper component; zero-weight NaNs are replaced by the agreed
finite midpoint. CVAR is the manual R contract with independent complete-fold
averaging, not a claim of a corresponding public manual Python wrapper.

## Support, migration and check limitations

DESCRIPTION, NEWS, README and public help describe manual moderated IVAR/CVAR.
The [CRAN R source index](https://cran.r-project.org/src/base/R-4/) checked on
2026-09-07 lists 4.6.1 and 4.5.3 as the current/previous minor patches.
R >= 4.5.0 remains the release floor; recheck it for each release.
There is no new v0.3-to-v0.4 floor increase or classification API migration.
Regression uses separate `venn_abers_regression()` and
`cross_venn_abers_regression()` entry points; numeric 0/1 targets there are
regression. Bounds are conditional-expectation estimates, not coverage intervals;
Cross bounds carry no additional statistical guarantee.

The manual core uses only base/standard R packages, without tidymodels. Normal
tests and installed examples run after environment setup without Python or
network access. Optional Python fixture generation remains separate.

The gate uses `R CMD check --as-cran --no-manual`: PDF manual generation and
online incoming/repository/clock probes are excluded. It records the exact
command and `_R_CHECK_*` environment in `check-settings.txt`. No NOTE is
allowlisted; every current local check has zero NOTEs. Any later NOTE requires
individual investigation and justification. A configured workflow is not a pass.

## Actual platform results

The workflow builds one archive, records SHA-256 and downloads that same archive
to every matrix job. Results for an older hash cannot qualify this candidate.
No workflow was dispatched or branch pushed by this implementation task.

| Originally planned combination | Result for the saved v0.4 candidate |
| --- | --- |
| Linux x86_64 / R 4.6.1 | Not run; not required for this approval |
| Linux x86_64 / R 4.5.3 | Not run; not required for this approval |
| Windows x86_64 / R 4.6.1 | Not run; not required for this approval |
| Windows x86_64 / R 4.5.3 | Not run; not required for this approval |
| macOS Intel / R 4.6.1 | Not run; not required for this approval |
| macOS Intel / R 4.5.3 | Not run; not required for this approval |
| macOS ARM / R 4.6.1 | Local pass twice; hosted macOS 15 image not run |
| macOS ARM / R 4.5.3 | Not run; not required for this approval |
| Additional Linux R-devel | Not run; not required for this approval |

Local environment: R 4.6.1, `aarch64-apple-darwin25.4.0`, macOS 26.6.2
(25G83), Darwin 25.6.0, Apple M5 Pro, 15 logical CPUs, 24 GiB RAM.
OpenBLAS 0.3.34; R LAPACK 3.12.1. The complete installed package set, R/session,
OS and runner variables are in [local-environment.txt](evidence-v04/local-environment.txt).
This is a local workstation, not a hosted CI runner. No separate typechecker
is configured: R parsing and `R CMD check` static code-problem checks passed.
Workflow actionlint 1.7.12 passed.

The build/install/check and same-artifact recheck both passed with network and
Python process execution denied for the gate and its children. Injected failing
installed examples and package tests each correctly exited 1. Logs are retained
under `evidence-v04/`. An unchanged candidate needs no rebuild for other platforms.

## Benchmark protocol and actual smoke results

The existing 12 classification inputs are unchanged, including the 100,000 /
100,000 binary IVAP RNG draw order. Their saved R objects compare identically
with the historical v0.3 benchmark inputs. The refresh additionally verified
all 16 input RDS files are byte-identical to the prior v0.4 bundle; see
[input comparison](evidence-v04/historical-inputs.log). Every classification
case is run against both artifacts: binary Cross, Inductive/Cross OvO/OvR with 3/10 classes,
plus binary Cross and 3-class Cross OvO using Brier and precision 2.

Four new regression cases append seed 20260909 after the classification draws.
They use 10,000 finite targets/model predictions and 1,000 new rows. CVAR uses
five named interleaved folds, 2,000 rows each. The saved input RDS records actual
values, positional calibration/new row IDs, fold membership and named new
prediction columns, method and explicit `list(m=1)` or `list(epsilon=0.1)`.
Inputs represent supplied synthetic scores, not a claim of trained-model
provenance. Effective m is 1 in the m cases; epsilon gives m=500 for IVAR and
m=100 in each CVAR fold. Every fold is checked against
`1 <= m <= floor((k-1)/2)` before measurement; public validation remains timed.

The runner installs outside measurement and runs each release/case in a fresh
R process, serially, with one warmup and three measurements. Fit and Predict
have separate `system.time` windows. Generation, RDS I/O and restoration checks
are outside these windows. Fits, restored objects and predictions are removed
between iterations. Controllable OMP/OpenBLAS/MKL/VECLIB/BLIS pools use one thread.
RDS uses gzip and version 3 throughout. Same-process and separate fresh-process
restoration must reproduce identical predictions. Process peak RSS includes the
entire case process, warmup, R/runtime, validation and serialization; it is not
isolated model memory or a per-iteration peak. Linux uses `/usr/bin/time -v`.

The full-size macOS `--smoke` run passed all 16 current + 12 previous cases,
112 warmup/measurement rows, 28 medians and 16 comparison rows. All 28 fresh
restorations passed. Saved plan, inputs, raw runs, medians, comparison, environment
and process logs are in [benchmark-smoke](evidence-v04/benchmark-smoke/).
The bundle verifier recomputes summaries and checks v0.4 coverage, options,
fold domain, row identities and input hashes. Its mutation tests reject missing
regression cases, invalid moderation/folds/columns/row IDs and corrupt summaries.

| New case (smoke only) | Fit median, s | Predict median, s | Peak process bytes | Model RDS bytes |
| --- | ---: | ---: | ---: | ---: |
| IVAR m=1 | 0.050 | 0.001 | 94,076,928 | 117,834 |
| IVAR epsilon=0.1 | 0.047 | 0 | 91,996,160 | 100,327 |
| CVAR m=1 | 0.053 | 0.046 | 91,521,024 | 156,527 |
| CVAR epsilon=0.1 | 0.050 | 0.047 | 91,684,864 | 129,559 |

Zero indicates timer resolution, not a zero-cost prediction. Regression has no
predecessor values or invented ratios. The classification comparisons retain
all actual values and are marked `requires regression review`. For example,
binary IVAP fit was 0.418 versus 0.416 s and peak RSS 116,228,096 versus
113,016,832 bytes; these are unresolved smoke observations, not clearance.
The smoke ran after the local gates on macOS, outside the controlled Linux
protocol, so neither improvements nor increases establish performance clearance.
The non-Linux release-mode guard correctly rejected this host before creating output.

**No controlled Linux measurement or performance clearance is claimed.** The
original benchmark protocol calls for a documented Linux x86_64 machine to
rerun all 28 case/release combinations with
the same R/dependency set, CPU/RAM/OS and one-thread settings, without concurrent
work and investigation of every deterioration. These measurements are no longer
prerequisites for v0.4 approval under the maintainer's updated criterion. There is no
new fixed time threshold or Python speed promise. Benchmarks remain outside
CRAN checks. An incompatible machine/runtime/input format requires remeasurement
of both releases; its ratios cannot be mixed with this smoke or older reports.

## Reproduction

Use a prepared R environment and the matching checkout; commands below require
neither Python nor network. Keep outputs separate and initially empty.

```sh
# Validate the saved evidence identities from the repository root.
shasum -a 256 -c tools/evidence-v04/SHA256SUMS

# Reuse the saved archive on EVERY required platform, without rebuilding.
ACCEPTANCE_ARTIFACT=tools/evidence-v04/vennabers_0.4.0.tar.gz \
  ACCEPTANCE_OUTPUT_DIR=.scratch/v04-platform Rscript --vanilla tools/acceptance.R
Rscript --vanilla tools/test-acceptance.R

# On a controlled Linux x86_64 reference machine (no --smoke):
Rscript --vanilla tools/performance.R tools/evidence-v04/vennabers_0.4.0.tar.gz \
  tools/evidence-v04/vennabers_0.3.0.tar.gz benchmark-output
Rscript --vanilla tools/test-performance.R benchmark-output --v04
Rscript --vanilla tools/test-performance-verifier.R benchmark-output
sha256sum benchmark-output/*.tar.gz benchmark-output/*-input.rds \
  benchmark-output/performance.R > benchmark-output/SHA256SUMS

# Replay an actual stored input without regenerating it; a fresh library:
mkdir -p .scratch/v04-replay-library
R CMD INSTALL --library=.scratch/v04-replay-library tools/evidence-v04/vennabers_0.4.0.tar.gz
Rscript --vanilla tools/performance.R --case \
  tools/evidence-v04/benchmark-smoke/regression_cross_epsilon01-input.rds \
  .scratch/v04-replay-library .scratch/v04-replay 0.4.0
Rscript --vanilla tools/performance.R --restore \
  tools/evidence-v04/benchmark-smoke/regression_cross_epsilon01-input.rds \
  .scratch/v04-replay-library .scratch/v04-replay 0.4.0
```

The last commands reproduce Fit/Predict and RDS identity for a saved case; wrap
the case command in `/usr/bin/time -v` on Linux to record its process peak.
Full-run regenerated input hashes must match the stored inputs before treating
the measurements as comparable. Model/prediction RDS and isolated libraries are
recreated by the runner; the original local copies remain in
`.scratch/v04-refresh-benchmark/`.

For the denied-network local checks, the wrapper was:

```sh
/usr/bin/sandbox-exec \
  -p '(version 1)(allow default)(deny network*)(deny process-exec (regex #".*/python[^/]*$"))' \
  /opt/homebrew/opt/r/bin/Rscript --vanilla tools/acceptance.R
```

The maintainer's local-test approval criterion is satisfied for the saved
candidate. Changes to package code, metadata, tests, examples or bundled tools
require a new candidate hash and appropriate local verification. This refresh
replaces the older archive and reruns its acceptance and benchmark tooling
checks; the evidence directory and this report are excluded from the package.

## Historical Standards review

Independent review against `cbd2729b6b13719049779d74cd05fea559e3585a`:
no findings. No documented-standard violations or actionable maintainability
smells. The changes reuse the existing runner/verifier, add no dependencies or
unnecessary abstractions, and retain runnable mutation checks. The reviewer
independently reran the saved bundle and mutation verifiers successfully.

## Historical Spec review

Independent review against the same base: no actionable implementation defects
or scope creep. At review time, three acceptance gaps were recorded: v0.3 release approval,
seven mandatory platform combinations plus Linux R-devel, and controlled Linux
benchmark/comparison clearance. The report explicitly preserves these gaps;
the saved bundle passes v0.4 validation. The four regression cases, twelve
classification comparisons, separate timing windows, fresh-process restoration
and unchanged classification tolerances match the ticket.

Review totals: Standards 0 findings; Spec 0 actionable implementation findings,
3 external acceptance gaps at review time. The maintainer subsequently confirmed
v0.3 approval and accepted passing local tests as sufficient for v0.4 approval.
The remaining platform and Linux benchmark gaps are therefore not release
blockers under the updated criterion. These reviews describe the original
acceptance work, before the subsequent numerical fixes and evidence refresh.
The refreshed candidate includes the corrected NEWS/README approval wording.
