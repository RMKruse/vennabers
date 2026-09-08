# v0.5 acceptance and benchmark report

Issue: [#35](https://github.com/RMKruse/venn-abers/issues/35). Date: 2026-09-08.
Implementation base: `8248ccc`; tested package commit: `e69a9b4` on `v0.5`.
Status: **all eleven package gates and benchmarks passed; CI disabled at the user’s request**.
The final workflow is cancelled because Windows’ extra failure-propagation test
was interrupted. Its normal package gate had already passed.

## Candidate and check scope

[Final CI run 34219433855](https://github.com/RMKruse/venn-abers/actions/runs/34219433855)
builds one [source archive](evidence-v05/ci-final/source-candidate/vennabers_0.5.0.tar.gz).
Every platform, dependency-profile and benchmark job downloads that exact archive.
SHA-256: `813e435f232b51cbaf36158bafc75ed3922e5905cd80dfee8ff69539d599effa`.
MD5: `d370424fc5cb59105b51f800951779d6`.
The [payload check](evidence-v05/ci-final/payload-match.log) verifies 123 package
files byte-for-byte plus normalized DESCRIPTION fields against the tested commit.
This report and all evidence are excluded from the archive; subsequent evidence
commits do not alter the tested package payload.

All package gates use `R CMD check --as-cran --no-manual`, then run installed
standalone examples and the 12 executable README fences. PDF manual generation
and online CRAN incoming/repository/clock probes are excluded. Exact flags,
restrictions, R/OS/runner image, libraries and package versions are saved per job.
These results do not claim an unrestricted CRAN submission check. Tests and
examples need neither Python nor network after environment setup; initial local
runs additionally enforced outbound-network and Python-execution denial while
allowing loopback sockets for fresh workers.

The current/minimum profiles require every suggested package and declared
version before checking. Missing dependencies cannot silently skip integration
coverage. Minimum additionally verifies the exact 93-package manifest. The core
profile rejects installed optional integration dependencies; only its integration
blocks skip, while all manual tests and examples run. Its only permitted NOTE is
the expected unavailable-Suggests dependency NOTE, justified individually if
emitted; the completed Linux core check emitted INFO instead, with zero NOTEs.
All other NOTEs, warnings and errors fail the gate.

## Platform and dependency results

CRAN's [R source index](https://cran.r-project.org/src/base/R-4/) was checked on
2026-09-08: current R 4.6.1, previous minor R 4.5.3. The package floor remains
R >= 4.5.0. The eight regular jobs use current published dependencies; the two
additional Linux profiles do not replace any regular job. R-devel is separately
checked and triaged.

| Platform/profile | R | Dependencies | Actual package gate |
| --- | --- | --- | --- |
| Linux x86_64 | 4.6.1 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-4.6.1-ubuntu-24.04-x86_64/00check.log) |
| Windows x86_64 | 4.6.1 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-4.6.1-windows-2025-x86_64/00check.log) |
| macOS Intel | 4.6.1 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-4.6.1-macos-15-intel-x86_64/00check.log) |
| macOS ARM | 4.6.1 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-4.6.1-macos-15-aarch64/00check.log) |
| Linux x86_64 | 4.5.3 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-4.5.3-ubuntu-24.04-x86_64/00check.log) |
| Windows x86_64 | 4.5.3 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-4.5.3-windows-2025-x86_64/00check.log) |
| macOS Intel | 4.5.3 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-4.5.3-macos-15-intel-x86_64/00check.log) |
| macOS ARM | 4.5.3 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-4.5.3-macos-15-aarch64/00check.log) |
| Additional Linux core | 4.6.1 | No integration packages | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-core/00check.log) |
| Additional Linux minimum | 4.5.3 | Exact pinned set | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-minimum/00check.log) |
| Additional Linux early warning | R-devel r90504 | Current published | [Pass: 0 errors/warnings/NOTEs](evidence-v05/ci-final/acceptance-devel-ubuntu-24.04-x86_64/00check.log) |

R-devel is the 2026-09-07 r90504 snapshot; its additional gate passes with no
findings requiring an exception. Full environments are retained beside each
check log, and [job records](evidence-v05/ci-final/jobs.json) map every job to its
[full output](evidence-v05/ci-final/jobs/). All regular and minimum integration
jobs run all 21 package test files, 12 README R blocks and nine installed example
scripts. The core profile's integration skips are explicit, as described above.

The separate Linux missing/old-dependency and injected-failure checks pass.
Windows/R 4.5.3 also passes the missing/old optional-package probes. The user
requested deactivation of all GitHub CI while Windows/R 4.6.1 was running its
extra failure-propagation checks. That step was cancelled and its later optional
probe skipped; neither is counted as passed. Its normal package gate had passed.
GitHub Actions is now disabled repository-wide, the acceptance workflow is
`disabled_manually`, and no run remains active. The saved
[repository setting](evidence-v05/ci-final/actions-disabled.json) and
[workflow state](evidence-v05/ci-final/workflows-disabled.json) record this decision.
Future CI execution requires explicit re-enablement.


## Capability evidence

The existing package tests and installed examples cover these paths. The shared
multiclass normalizer now uses deterministic binary64 additions, as described
below; no reference fixture, numerical tolerance or training scope is changed.

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

## Optional dependencies

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
source URLs and MD5 values are logged during setup. The mandatory Linux/R 4.5.3 job validates this candidate
compatible set; its actual result is recorded in the matrix. It does not claim every
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

The controlled Linux results and investigation of deteriorations are recorded
below. Non-Linux `--smoke` validates tooling and restoration only;
it cannot establish performance clearance. Large benchmarks run separately from
package checks. Tests/examples require neither Python nor network after setup.

## Controlled Linux benchmark results

The final [Linux bundle](evidence-v05/ci-final/benchmarks/) passed the bundle and
mutation verifiers. It contains 24 cases, 40 case/release pairs, 160 raw rows
(40 warmups, 120 measurements), 40 medians and 24 comparisons. All 40 independent
restorations reproduce predictions identically. The historical manual generator and RNG draw order are retained; both
releases use the same saved inputs in this run. Both releases ran serially on the same Ubuntu 24.04.4 x86_64 runner:
Intel Xeon Platinum 8370C, two logical CPUs, 8,127,868 kB RAM, R 4.6.1,
OpenBLAS 0.3.26/LAPACK 3.12.0; all controllable pools were one thread. Exact
versions, runtime settings and source identities are in `environment.txt` and
the per-case session logs.

New integration baselines (seconds; peak RSS is the whole case process):

| Native case | Fit | Predict | Complete outer evaluation | Peak RSS, bytes | Model RDS, bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| workflow_binary_cross | 0.258 | 0.032 | 0.966 | 346726400 | 9415601 |
| workflow_binary_inductive | 0.112 | 0.009 | 0.469 | 327868416 | 2259441 |
| workflow_ovo_cross | 0.390 | 0.041 | 1.312 | 347389952 | 7529100 |
| workflow_ovo_inductive | 0.140 | 0.011 | 0.537 | 327712768 | 1882067 |
| workflow_ovr_cross | 0.416 | 0.040 | 1.338 | 351092736 | 7543865 |
| workflow_ovr_inductive | 0.144 | 0.011 | 0.540 | 327356416 | 1885097 |
| workflow_regression_cross | 0.237 | 0.087 | 1.144 | 347820032 | 9229556 |
| workflow_regression_inductive | 0.107 | 0.008 | 0.451 | 324988928 | 2257216 |

All manual comparisons remain visible below. Ratios are v0.5/v0.4; differences
are current minus predecessor. The raw CSV deliberately says `requires regression
review`; the following analysis is the human-readable review, not a rewritten
measurement or automatic acceptance threshold.

| Manual case | Fit ratio | Predict ratio | RDS change, bytes | Peak RSS change, MiB |
| --- | ---: | ---: | ---: | ---: |
| 10_cross_ovo | 0.997 | 0.991 | +42 | +0.445 |
| 10_cross_ovr | 0.998 | 1.000 | -29 | +2.070 |
| 10_inductive_ovo | 0.999 | 1.000 | -4 | +0.219 |
| 10_inductive_ovr | 1.013 | 1.000 | +27 | -0.766 |
| 3_cross_ovo | 0.982 | 1.000 | +11 | +0.477 |
| 3_cross_ovo_brier_p2 | 1.000 | 1.000 | +0 | +0.340 |
| 3_cross_ovr | 1.003 | 1.000 | -10 | +0.523 |
| 3_inductive_ovo | 1.009 | 1.000 | +6 | +0.125 |
| 3_inductive_ovr | 1.003 | 1.000 | -14 | +0.000 |
| binary_cross | 1.000 | 1.500 | +0 | +0.105 |
| binary_cross_brier_p2 | 1.000 | 1.000 | +0 | -0.004 |
| binary_inductive | 1.003 | 0.967 | +0 | -0.184 |
| regression_cross_epsilon01 | 1.008 | 1.008 | +0 | +0.121 |
| regression_cross_m1 | 1.000 | 1.008 | +0 | +0.137 |
| regression_inductive_epsilon01 | 1.008 | 1.000 | +0 | +0.230 |
| regression_inductive_m1 | 1.000 | 1.000 | +0 | -0.031 |

The observed increases were investigated as follows:

- `binary_cross` Predict is 3 ms versus 2 ms: the apparent 50% increase is one
  timer tick. Current raw values are 3/2/3 ms and predecessor values 2/2/2 ms.
  Its core source and saved model are unchanged. The earlier diagnostic Linux
  run measured 3 ms for both releases (retained in `ci-history/initial-benchmark`).
  This evidence does not establish a systematic 50% regression.
- The largest Fit increase is 14 ms (1.33%) for `10_inductive_ovr`; other Fit
  increases are 1–3 ms. Regression Predict increases are 1 ms (at most 0.8%).
  Several raw ranges overlap; three measurements cannot cleanly separate small
  runtime variation from normalization work. Source review finds the explicit
  multiclass column additions and the previously extracted shared regression
  moderation helper, with unchanged fitting algorithms. These observed small
  costs are retained and judged acceptable for this candidate's correctness fix;
  no speedup or universal absence of regressions is claimed.
- All 16 manual models have exactly unchanged uncompressed serialization lengths
  and R `object.size` ([size audit](evidence-v05/ci-final/benchmarks/manual-model-sizes.csv)).
  Binary, regression and rounded multiclass models are identical. Other
  multiclass calibrator scores differ at approximately machine precision after
  deterministic normalization, changing gzip size by -29 to +42 bytes; this is
  compression variation, not model growth. Detailed comparisons are retained.
- Peak-process changes range from -0.766 to +2.070 MiB, at most +2.23%.
  The largest is ten-class Cross OvR. Its retained model size is unchanged;
  explicit normalization creates temporary column vectors, and v0.5 also has a
  larger loaded namespace. These are plausible contributors, not isolated causal
  measurements: `/usr/bin/time` captures the entire four-iteration process and
  allocator/GC behavior. The measured bounded overhead is accepted here; these
  data do not establish model-memory growth or a memory-leak trend.

No material performance regression is identified for these recorded workloads.
The report retains every deterioration and its measurement limits; it does not
extrapolate beyond this machine or invent predecessor timings for native paths.


## Reproduction and retained evidence

```sh
# Minimum setup on Ubuntu (network permitted during setup only):
sudo apt-get install -y libuv1-dev
Rscript --vanilla tools/install-minimum-dependencies.R /path/to/minimum-library

# Reuse the exact archive; choose an empty output directory.
R_LIBS=/path/to/minimum-library ACCEPTANCE_PROFILE=minimum \
  ACCEPTANCE_ARTIFACT=tools/evidence-v05/ci-final/source-candidate/vennabers_0.5.0.tar.gz \
  ACCEPTANCE_OUTPUT_DIR=.scratch/v05-minimum Rscript --vanilla tools/acceptance.R
# Use current for the eight regular jobs; core in a clean R installation.

# Serial Linux x86_64 benchmark and verifiers:
Rscript --vanilla tools/performance.R \
  tools/evidence-v05/ci-final/source-candidate/vennabers_0.5.0.tar.gz \
  tools/evidence-v04/vennabers_0.4.0.tar.gz benchmark-output
Rscript --vanilla tools/test-performance.R benchmark-output --v05
Rscript --vanilla tools/test-performance-verifier.R benchmark-output
```

[Final evidence](evidence-v05/ci-final/) retains the source, individual check and
test/example outputs, environments, benchmark input RDS, runner source, raw rows,
medians, comparisons and logs. GitHub artifact IDs, digests and expiration dates
are saved in `ci-final/artifacts.json`. Full generated model/prediction/outer RDS
files are in that hosted benchmark artifact and the local `.scratch` download;
`generated-rds.csv` preserves their hashes/sizes in Git. Saved inputs and source
recreate them. Runtime libraries and duplicate generated RDS are not copied into
Git. Verify committed evidence from `tools/evidence-v05` with
`shasum -a 256 -c SHA256SUMS`.

## Historical evidence and fixes

The initial local macOS ARM/R 4.6.1 candidate had SHA-256
`53a2b544776f7978a51c2732df97f7372d18bdcfeab2f27b1b1b6f64b4e6ac26`.
Its current, pinned-minimum and clean-core gates all passed with zero errors,
warnings and NOTEs; those logs remain in `local-current`, `local-minimum` and
`local-core`. The 24-case local smoke remains in `benchmark-smoke`; it validates
tooling/restoration only and supplies no Linux performance clearance. The
corrected local gate and minimized numerical reproduction are retained in
`corrective-local`. None is attributed to the final archive's different hash.

The workflow was initially disabled (the [saved initial response](evidence-v05/workflow-state.json)
records that historical state). It was enabled and the implementation pushed to
`v0.5`; three explicit full runs include the separate Linux benchmark:

- [Initial run 34217697484](https://github.com/RMKruse/venn-abers/actions/runs/34217697484),
  commit `89cbf81`, source SHA-256
  `86ef0b75914b9a0af2f645301a517bc5c601ca82996155960444a6850b20f9dc`.
  This candidate is superseded and is not accepted.
- [Corrective run 34218981782](https://github.com/RMKruse/venn-abers/actions/runs/34218981782),
  commit `92fe351`, superseded after a related test-oracle failure and missing
  libuv source-build headers. Remaining jobs were cancelled after retaining
  the failure logs.
- [Final run 34219433855](https://github.com/RMKruse/venn-abers/actions/runs/34219433855),
  commit `e69a9b4`, cancelled at the user’s request after every normal package
  gate passed; the Windows extra verification remains incomplete. Source SHA-256
  `813e435f232b51cbaf36158bafc75ed3922e5905cd80dfee8ff69539d599effa`.
  Every job uses this one archive; results for earlier hashes do not qualify.

The first run exposed two reproducible failures. The minimum installer compared
R's normalized package-version string (`0.1.6`) to the raw declared version
(`0.1-6`), rejecting a correctly installed package. It now checks DESCRIPTION's
raw Version field and preserves setup logs even when installation fails.

The first run’s x86 package-test failures occur in the unchanged
`fixed_3_00/2/log` multiclass fixture. Extended-precision row sums on x86 produce
1 for `(1/6, 2/3, 1/6)`; ARM's binary64 additions produce
0.9999999999999999. After calibration-only rounding, the normalization difference
can move a prediction across a calibration knot, changing a probability by about
0.15 despite identical fitted calibrators. Explicit column-order binary64
additions in the shared validator preserve the existing reference behavior on
every platform. The fix covers fitting and Inductive/Cross prediction, including
native workflows. No tolerance, fixture or calibration rounding is loosened.
Affected x86 predictions can change; NEWS records this correction.

The existing near-normalization assertion also now uses explicit binary64
additions, keeping its 1e-10 tolerance; its old expected value still used x86
extended precision. The minimum job provisions `libuv1-dev` for pinned `fs`
source compilation.

The minimized reproduction fails before the change and passes afterward. The
corrected candidate also passes the complete local current-dependency gate,
including all package tests and installed examples. Both independent reviewers
found no further issues in the fixes. Hosted results remain authoritative for
the platform matrix and Linux benchmark below.

## Review, scope and remaining limitations

Independent Standards and Spec reviews found no unresolved implementation
findings. Review caught a verifier-test defect: a corrupted manual fixture could
mask later integration mutations. Restoring it and checking the valid bundle
before/after each mutation group fixed the evidence test. Follow-up review
confirmed the normalization/version/system-dependency fixes without tolerance
changes. R parsing, actionlint 1.7.12 and the package's usage/code checks pass;
no separate typechecker is configured. Final hosted validation is recorded above.

NEWS, README and workflow help describe all eight paths and migration. Optional
packages remain Suggests; manual API names, R floor and numerical tolerances are
unchanged. Affected x86 multiclass predictions can change due to the documented
normalization correction. No training API beyond the agreed v0.5 scope is added.
v0.6 retains frozen adoption, reversible names and ordered reference holdouts;
v0.7 pair training/full-model transfer; v0.8 tuning; v0.9 learned postprocessing.
No complete Python training parity is claimed.

The maintainer's historical v0.4 local-only approval does not approve v0.5.
PDF manual generation and online CRAN probes remain unexecuted as stated above;
benchmark conclusions apply to the recorded serial Linux machine and workloads.
No publication, tag or CRAN submission is part of this ticket or claimed here.
