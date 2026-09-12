# v0.7 local acceptance and benchmark report

Ticket: `.scratch/v0.7-tickets/issues/07-release-abnahme.md`. Date: 2026-09-13.
Implementation base: `dd24293` on branch `v0.7`.
Status: **local checks complete and passed; overall release approval still blocked on external gates**.
This report does not apply earlier local-only release waivers.

## Candidate and predecessor

The candidate is built with `git archive` from committed source `dd242930a2641417729a99c050d3193d77664567`,
then `R CMD build`, and retained as
[evidence-v07/candidate/vennabers_0.7.0.tar.gz](evidence-v07/candidate/vennabers_0.7.0.tar.gz).
SHA-256: `18a9d5043f5560550757ce8b8a78c855fd39117230761cf2a6ca324220eb66c5`.
All final installs, package checks/tests, help/README/installed examples and
benchmark measurements use this exact archive. The report/evidence are
excluded from the package; evidence-only commits do not extend its tested payload.
Changed package contents require a new candidate and matching evidence.

The immutable predecessor is the actually tested v0.6 archive from source
`8db2ae6a9d465106cbfe135863446b5198da8b76`, retained at
[evidence-v06/candidate/vennabers_0.6.0.tar.gz](evidence-v06/candidate/vennabers_0.6.0.tar.gz),
SHA-256 `6c1953d9c319f3272e9b088be965984f99c7320c5567a7d3ecae62f4108e35db`.
The [v0.6 report](acceptance-v06.md) documents three passed local ARM package
profiles and a 48-case smoke run, but its mandatory platform matrix, controlled
Linux performance evidence and final overall approval are still open. That
approval remains an **external prerequisite for v0.7**, not a conclusion inferred
from the version number or later branch commits. All historical evidence is retained.

## Execution limits and release matrix

A read-only GitHub query confirms [Actions disabled](evidence-v07/tooling/actions-disabled.json)
and [workflow disabled manually](evidence-v07/tooling/workflows-disabled.json).
The existing workflow configuration is unchanged. No issue/milestone creation,
push, upload, trigger, tagging, publishing, remote configuration or reactivation
is performed. The local ticket remains the task source; no tracker setup is needed.
Remote execution or a changed approval criterion requires a separate explicit decision.

The [CRAN R source index](https://cran.r-project.org/src/base/R-4/) was checked on
2026-09-09: current R minor 4.6 (4.6.1), previous 4.5 (4.5.3).
`DESCRIPTION` retains R >= 4.5.0, the previous minor series.
Only macOS ARM/R 4.6.1 with prepared libraries is available for this execution;
no already-authorized reachable Linux/Windows/Intel Mac/previous-R runner is identified.

| Platform/profile | R | Mandatory evidence | Status |
| --- | --- | --- | --- |
| Linux x86_64 | 4.6.1 | Artifact check, tests, installed examples | Not run; open |
| Linux x86_64 | 4.5.3 | Artifact check, tests, installed examples | Not run; open |
| Windows x86_64 | 4.6.1 | Artifact check, tests, installed examples | Not run; open |
| Windows x86_64 | 4.5.3 | Artifact check, tests, installed examples | Not run; open |
| macOS Intel | 4.6.1 | Artifact check, tests, installed examples | Not run; open |
| macOS Intel | 4.5.3 | Artifact check, tests, installed examples | Not run; open |
| macOS ARM | 4.6.1 | Artifact check, tests, installed examples | Local results below |
| macOS ARM | 4.5.3 | Artifact check, tests, installed examples | Not run; open |
| Additional Linux core | 4.6.1 | No integration packages | Local ARM probe below (not the mandated Linux host); Linux itself not run |
| Additional Linux minimum | 4.5.3 | Direct minima and compatible transitive set | Local ARM probe below with pinned versions (not the mandated Linux host); Linux itself not run |
| Additional Linux early warning | R-devel | Check, tests, examples and finding triage | Not run; additional early warning |
| Controlled Linux benchmark | Common compatible R/package set | Serial same-host v0.7/v0.6 measurements and regression investigation | Not run; open |

The local gate runs `R CMD check --as-cran --no-manual`, with exact flags recorded
in each profile. PDF manual, online incoming and clock probes are disabled.
The reused local sandbox denies external connections and Python execution while
permitting localhost R workers. Repository-check warnings caused by these limits
are recorded separately from the final check status. Product code, packaged tests and installed examples do not install runtimes or
dependencies. Acceptance setup deliberately installs the identified artifact;
optional-dependency probes also build a temporary old-version stub. There is no configured static
typechecker; R parsing, byte compilation and the package code/usage checks apply.

## Local package results

All three profiles pass against the candidate archive on macOS ARM/R 4.6.1
(`/opt/homebrew/Cellar/r/4.6.1`): **0 ERROR, 0 WARNING and 0 NOTE** in each
`R CMD check --as-cran --no-manual` status, `Acceptance gate passed.`, and no
process-level offline/repository warnings recorded in these runs.

- **current**: all 45 test files, 17 README R blocks and 21 installed
  standalone examples pass. Log:
  [local-current/acceptance.log](evidence-v07/local-current/acceptance.log),
  [00check.log](evidence-v07/local-current/00check.log).
- **minimum**: verified against the exact pinned
  [minimum-dependencies.csv](evidence-v07/tooling/minimum-dependencies.csv)
  manifest (97 direct/transitive package versions); same 45 test files, 17
  README blocks and 21 installed examples pass. Log:
  [local-minimum/acceptance.log](evidence-v07/local-minimum/acceptance.log),
  [00check.log](evidence-v07/local-minimum/00check.log).
- **core**: an R library holding only base+recommended packages (no Suggests
  except `nnet`/`mgcv`); README/installed-example checks that require optional
  packages are skipped by design and replaced by a manual API smoke check
  (`venn_abers`/`venn_abers_regression` predict), which passes. The 45 package
  test files still run (integration-dependent assertions inside them use
  `skip_if_not_installed`). Log:
  [local-core/acceptance.log](evidence-v07/local-core/acceptance.log),
  [00check.log](evidence-v07/local-core/00check.log).

The reused [minimum dependency manifest](minimum-dependencies.csv) pins 97 exact
direct/test and transitive package versions and edges. The minimum gate verifies
the entire installed set; this demonstrates one compatible set on this R/runtime,
not compatibility of arbitrary transitive combinations. The current profile records
its actual packages; the core profile isolates base/recommended packages with no
integration dependencies. Exact platform/R/library details accompany each run.

## Twenty-path acceptance map

Each row names the existing product tests rerun from the candidate, not historical
passes transferred to a new archive. `print-costs.R` adds a public print check for all 20 paths.
`matched-last-fit.R` closes the eight legacy matched paths’ missing last_fit
coverage: complete collected identities, independently reconstructed metrics,
collected predictions versus an independent direct fit, automatic/explicit local
plan replay, native/decoded truth, learned normalization and held-out target isolation. Fixed settings alone belong to v0.7; automatic local parameter
selection and the tuning parts of the full contract belong to v0.8.

| Path | Direct numerical/roles/options and outer fit_resamples/last_fit tests | Schema/native/decoded and fresh-process evidence |
| --- | --- | --- |
| binary / Inductive / matched | [calibrated-workflow.R](../tests/calibrated-workflow.R), [outer-resampling.R](../tests/outer-resampling.R), [matched-last-fit.R](../tests/matched-last-fit.R) | [schema-resampling.R](../tests/schema-resampling.R), [schema-processes.R](../tests/schema-processes.R) |
| binary / Inductive / full | [full-model-workflow.R](../tests/full-model-workflow.R) | [schema-resampling.R](../tests/schema-resampling.R), [schema-processes.R](../tests/schema-processes.R) |
| binary / Cross / matched | [cross-workflow.R](../tests/cross-workflow.R), [outer-resampling.R](../tests/outer-resampling.R), [matched-last-fit.R](../tests/matched-last-fit.R) | [schema-resampling.R](../tests/schema-resampling.R), [schema-processes.R](../tests/schema-processes.R) |
| binary / Cross / full | [full-model-workflow.R](../tests/full-model-workflow.R) | [schema-resampling.R](../tests/schema-resampling.R), [schema-processes.R](../tests/schema-processes.R) |
| shared OvO / Inductive / matched | [multiclass-workflow.R](../tests/multiclass-workflow.R), [matched-last-fit.R](../tests/matched-last-fit.R) | [schema-multiclass-resampling.R](../tests/schema-multiclass-resampling.R), [integration-processes.R](../tests/integration-processes.R) |
| shared OvO / Inductive / full | [full-multiclass-workflow.R](../tests/full-multiclass-workflow.R) | [full-multiclass-workflow.R example](../inst/examples/full-multiclass-workflow.R), [full-multiclass-processes.R](../tests/full-multiclass-processes.R) |
| shared OvO / Cross / matched | [cross-multiclass-workflow.R](../tests/cross-multiclass-workflow.R), [matched-last-fit.R](../tests/matched-last-fit.R) | [schema-multiclass-resampling.R](../tests/schema-multiclass-resampling.R), [integration-processes.R](../tests/integration-processes.R) |
| shared OvO / Cross / full | [full-multiclass-workflow.R](../tests/full-multiclass-workflow.R) | [full-multiclass-workflow.R example](../inst/examples/full-multiclass-workflow.R), [full-multiclass-processes.R](../tests/full-multiclass-processes.R) |
| shared OvR / Inductive / matched | [multiclass-workflow.R](../tests/multiclass-workflow.R), [matched-last-fit.R](../tests/matched-last-fit.R) | [schema-multiclass-resampling.R](../tests/schema-multiclass-resampling.R), [integration-processes.R](../tests/integration-processes.R) |
| shared OvR / Inductive / full | [full-multiclass-workflow.R](../tests/full-multiclass-workflow.R) | [full-multiclass-workflow.R example](../inst/examples/full-multiclass-workflow.R), [full-multiclass-processes.R](../tests/full-multiclass-processes.R) |
| shared OvR / Cross / matched | [cross-multiclass-workflow.R](../tests/cross-multiclass-workflow.R), [matched-last-fit.R](../tests/matched-last-fit.R) | [schema-multiclass-resampling.R](../tests/schema-multiclass-resampling.R), [integration-processes.R](../tests/integration-processes.R) |
| shared OvR / Cross / full | [full-multiclass-workflow.R](../tests/full-multiclass-workflow.R) | [full-multiclass-workflow.R example](../inst/examples/full-multiclass-workflow.R), [full-multiclass-processes.R](../tests/full-multiclass-processes.R) |
| pairwise OvO / Inductive / matched | [pairwise-workflow.R](../tests/pairwise-workflow.R) | [pairwise-workflow.R](../tests/pairwise-workflow.R), [pairwise-processes.R](../tests/pairwise-processes.R) |
| pairwise OvO / Inductive / full | [full-pairwise-workflow.R](../tests/full-pairwise-workflow.R) | [full-pairwise-workflow.R](../tests/full-pairwise-workflow.R), [pairwise-processes.R](../tests/pairwise-processes.R) |
| pairwise OvO / Cross / matched | [pairwise-cross-workflow.R](../tests/pairwise-cross-workflow.R) | [pairwise-cross-workflow.R](../tests/pairwise-cross-workflow.R), [pairwise-processes.R](../tests/pairwise-processes.R) |
| pairwise OvO / Cross / full | [full-pairwise-workflow.R](../tests/full-pairwise-workflow.R) | [full-pairwise-workflow.R](../tests/full-pairwise-workflow.R), [pairwise-processes.R](../tests/pairwise-processes.R) |
| regression / Inductive / matched | [regression-workflow.R](../tests/regression-workflow.R), [matched-last-fit.R](../tests/matched-last-fit.R) | [schema-multiclass-resampling.R](../tests/schema-multiclass-resampling.R), [integration-processes.R](../tests/integration-processes.R) |
| regression / Inductive / full | [full-regression-workflow.R](../tests/full-regression-workflow.R) | [full-regression-workflow.R example](../inst/examples/full-regression-workflow.R), [full-regression-processes.R](../tests/full-regression-processes.R) |
| regression / Cross / matched | [regression-workflow.R](../tests/regression-workflow.R), [matched-last-fit.R](../tests/matched-last-fit.R) | [schema-multiclass-resampling.R](../tests/schema-multiclass-resampling.R), [integration-processes.R](../tests/integration-processes.R) |
| regression / Cross / full | [full-regression-workflow.R](../tests/full-regression-workflow.R) | [full-regression-workflow.R example](../inst/examples/full-regression-workflow.R), [full-regression-processes.R](../tests/full-regression-processes.R) |

The tests reconstruct held-out calibrators independently, validate training and
calibration roles through observed inputs and learned preprocessing, compare
matched/full stored calibration values and RNG order, and reject invalid or
misbound model/pair plans before learning. They cover lost/duplicated outer rows,
repeat/configuration/metric identities, assessment-target isolation, model-source
and calibrator tampering, failed full fits with no fallback, and state retention.
Loss log/Brier, rounding, class order/event orientation, empty/single/batch outputs,
moderation choices and domain errors remain in the cumulative suite. The
[installed evaluation checker](../inst/examples/calibrated-resampling.R) verifies
complete predictions and metrics rather than accepting successful folds alone.

Classification tolerance remains **1e-10 absolute**. Full regression tests fix
`abs(actual - expected) <= 1e-10 * s + 1e-10 * abs(expected)` before comparison,
with scale `s` changed with outcome units (including 1e-12 and 1e120 cases).
Native/decoded fresh-process snapshots require identity and trap unexpected
model/preprocessing/calibration learning. Existing frozen model/postprocessor
snapshots remain part of the suite.

Python component fixtures are separate evidence: binary full-transfer fixtures
pin upstream commit `0e7b4bc575ce230134576ba1c76688d46bf99ac7` and its module/generator
hashes in [full-model-environment.json](../inst/extdata/full-model-environment.json).
Shared multiclass R model training is an independent R extension; binary pair
components do not imply complete Python training parity. The documented
[regression reference limitations](../inst/extdata/cross-regression-reference.md)
and [Python research defects](python-parity-research.md) remain distinct from
passed R requirements. Existing Python fixtures are consumed without starting Python;
old probes do not replace this candidate's R acceptance.

## User-facing compatibility and costs

Help, NEWS and README identify matched/full and shared/pairwise, retained model
sources, unchanged held-out calibration values and actual fit/predict costs.
For one shared path, Inductive costs 1 matched or 2 full fits; Cross costs K or
K+1. Pair training sums the corresponding cost over all pairs (unequal explicit
Cross folds remain supported). Full prediction retains one model per pair/shared
path; matched prediction retains each source workflow. Print counts discarded
source fits too and reports stored calibration rows; pair rows count membership
in each pair. Empty predictions avoid model calls.

Manual and frozen APIs retain their behavior. New postprocessor training belongs
to v0.9; existing frozen learned postprocessing is preserved. Full transfer has
no automatic calibration/coverage guarantee or promise of better quality.
No automatic Python runtime/package installation or general serialization promise
is added. The measured RDS identities apply to these concrete artifacts and environments.

## Benchmark protocol and interpretation

The existing runner retains all 48 v0.6 cases and their RNG draw order. Eight
shared full paths and eight pair paths add 16 cases: **64 total**, with 48 common
cases remeasured against v0.6 and 16 new baselines. The underlying training matrix
has 20 three-class/base paths plus four ten-class pair paths. All trainable workflow paths
use 2,000 development rows, ten numerical predictors, 500 new rows, 20% Inductive
calibration, five Cross folds and three outer folds. The eight frozen workflow cases retain all 2,000 rows for calibration,
independent 1,000-row earlier training, and no calibration split or outer evaluation.
The historical 100,000-row binary and other 10,000-row manual cases remain unchanged.

GLMs model binary/pair probabilities, `nnet::multinom` shared multiclass
probabilities and LM regression. Recipes learn normalization within every local
model fit. Workflow settings are log loss/no rounding or m=1; historical manual options
retain Brier/rounding and epsilon=0.1. Historical outcome/data
seed 20260910 and shared plan seeds 3501/3502/3503 with fit seed 3504 remain;
ten-class pair outcomes use independent seed 20260912. Pair plans reset seed
3501 per local pair; outer plans use 3502. Every actual input, complete base
workflow, local pair subset and bound split/fold assignment is saved, including
outer analysis-local pair plans. Generator source is copied into the bundle.
The [historical-input audit](evidence-v07/tooling/historical-inputs.log) verifies
all 48 earlier inputs/configurations, excluding only rsample fingerprints.

Both releases run serially under the same R and compatible dependency set.
OMP/OpenBLAS/MKL/VECLIB/BLIS pools use one thread and outer resampling has
`allow_par=FALSE`. v0.7 uses a **fresh R process for each** warmup (iteration 0)
and three measurements (1–3), with an independent fresh restore after each.
This protocol differs from old bundles' one-process-per-case measurements;
old timings are retained but are not used as denominators for this comparison.

Fit and Predict are separately timed; complete three-fold outer evaluation has
its own total window. Public construction/input/output validation stays timed;
data and split setup, installation, output auditing and serialization are outside.
Existing schema/encode/decode costs remain separate. Actual GLM/multinom/LM calls
are counted through `trace()` with the same instrumentation for both artifacts;
this small counting overhead is included. Retained model counts come from the
fitted state. Frozen original training stays outside calibration timing/counts.
Zero outer/fit-model counts for manual/frozen cases mean inapplicable, not free work.

Raw values, medians excluding warmup, peak process RSS and gzip/version-3 RDS
bytes are retained. Peak RSS covers the whole individual process (including R,
loaded packages, validation and serialization), not just the fitting window.
Stored model/prediction outputs from the final measurement are retained locally;
each preceding iteration also receives its own restore check before overwrite.
The verifier reconciles identities, all 64 cases, 112 case/release pairs, 448 raw
rows, options, pair/fold/data bindings, actual counts and independently recomputed
summaries/ratios. Corruption probes must reject missing cases, altered plans,
model sources and coherently falsified fit/model counts.

Large measurements are outside package checks. Linux x86_64 release mode refuses
this host. Full-workload `--smoke` explicitly yields **no Linux performance
clearance**. `--prepare-only` creates replayable inputs and installations for
focused runner checks; it performs no measurements and cannot pass the bundle
validator. Local timing changes do not establish accepted performance regressions
or grant waivers. Controlled Linux investigation remains mandatory.

## Local benchmark results and evidence retention

The `--smoke` suite completed on this macOS ARM host against the candidate and
the retained v0.6 predecessor archive: **64 cases, 112 case/release pairs, 448
raw rows**. [Bundle checks](evidence-v07/tooling/benchmark-verifier.log) and
[corruption/mutation probes](evidence-v07/tooling/benchmark-mutations.log) both
pass (`tools/test-performance.R --v07` and `tools/test-performance-verifier.R`).

[comparison.csv](evidence-v07/benchmark-smoke/comparison.csv) reports 48 cases
as `requires regression review` (remeasured against v0.6 with semantically
matched inputs) and 16 as `new capability baseline` (v0.7 full/pair paths with
no v0.6 predecessor). Across all ratio columns for the 48 common cases, exactly
one exceeds the 1.5x flag threshold: `binary_cross` `predict_seconds_ratio =
2.0` (0.002s current vs 0.001s previous). This is sub-millisecond measurement
noise from a single fresh-process sample, not a reproducible slowdown; no other
fit/predict/outer/schema/encode/decode/rds/memory ratio for any of the 48
common cases crosses the threshold in either direction. No performance
regression is found in this local smoke run.

Source artifacts, generator, saved input RDS, environment/flags, check logs,
individual test/example results and file hashes are retained under
`tools/evidence-v07`. Large generated model/prediction/outer/decoded RDS
(320 files) remain in `.scratch/v07/benchmark` (not committed); their SHA-256
hashes and byte sizes are recorded in
[generated-rds.csv](evidence-v07/benchmark-smoke/generated-rds.csv) instead of
duplicating them in Git. The top-level
[SHA256SUMS](evidence-v07/SHA256SUMS) manifest covers the entire retained
`tools/evidence-v07` bundle (1,373 files; verify with `shasum -a 256 -c
tools/evidence-v07/SHA256SUMS` from the repository root).

This remains a macOS ARM smoke run, explicitly **not** the mandatory controlled
Linux x86_64 reference-machine measurement; it is retained as local evidence of
correctness (fresh restores, identity checks, reconciled counts) and directional
timing, not as release-grade performance clearance.

## Reproduction

Use a prepared dependency library; no package downloads are part of these commands:

```sh
ACCEPTANCE_ARTIFACT=tools/evidence-v07/candidate/vennabers_0.7.0.tar.gz \
  ACCEPTANCE_OUTPUT_DIR=/empty/output/current Rscript --vanilla tools/acceptance.R
# ACCEPTANCE_PROFILE=minimum checks the pinned dependency manifest;
# core requires an R library without any integration packages.
Rscript --vanilla tools/performance.R \
  tools/evidence-v07/candidate/vennabers_0.7.0.tar.gz \
  tools/evidence-v06/candidate/vennabers_0.6.0.tar.gz /empty/output/benchmark
Rscript --vanilla tools/test-performance.R /empty/output/benchmark --v07
Rscript --vanilla tools/test-performance-verifier.R /empty/output/benchmark
# Add --smoke on macOS; that never satisfies the Linux reference-machine gate.
```

## Standards

Independent review of the implementation: **0 findings** for the pre-execution
implementation. Cost reporting reuses stored state, tracing measures real
engines without replacements, and the runner adds no dependencies or
speculative abstraction. The 20-path public print check passes. The focused
matched last_fit test was also reviewed with no Standards findings.

A second review, after full execution and evidence packaging, checked the
final diff (`tools/acceptance.R`, `tools/performance.R`,
`tools/test-performance.R`, `tools/test-performance-verifier.R`,
`tests/matched-last-fit.R`) against this repo's smell baseline (no
`CODING_STANDARDS.md`/`CONTRIBUTING.md` is documented here, so only the
baseline judgement-call smells apply). It found one **possible Duplicated
Code** in `tools/performance.R`: the `formula`/`selector` base-environment
recipe construction was copied verbatim into the new ten-class pair-case
block instead of reused. This was corrected by factoring it into a shared
`base_env_recipe()` helper, used by both the original and pair-case call
sites. The refactor was verified behavior-preserving: a full `--smoke` rerun
against the same archives produced byte-identical `plan.csv` and generated
`-input.rds` files (same MD5s), and identical `fit_count`/`retained_models`/
`outer_fit_count`/status classification for every case in `comparison.csv`;
only wall-clock timing/memory noise differed, as expected between runs (see
[performance-refactor-check.log](evidence-v07/tooling/performance-refactor-check.log)).
No other findings. Total: Standards 0 hard violations, 1 judgement-call smell
(fixed).

## Spec

Independent review of the implementation: **0 findings**. The 64-case cumulative
matrix, 48 common comparisons, 16 new baselines, saved pair plans, fresh-process
restores and actual-count reconciliation match the ticket. An evidence-map review found missing matched last_fit checks and one collector
comparison gap; both were corrected and reviewed in the final source. Incorrect
full-schema citations and overbroad frozen benchmark wording were also corrected.

A final review, after full local execution and evidence packaging, checked the
report's claims against the actually committed evidence files (hashes, commit
SHAs, test/README/example counts, benchmark case counts, `SHA256SUMS`). It found
one issue: the report cited a `tools/evidence-v07/tooling/historical-inputs.log`
audit that did not exist in the diff. This was corrected by writing and running
the actual v0.7 historical-input audit
([historical-inputs.R](evidence-v07/tooling/historical-inputs.R),
[historical-inputs.log](evidence-v07/tooling/historical-inputs.log)), comparing
all 48 cases common with v0.6 (data, plan memberships, options and untrained
model/recipe configuration, excluding only rsample fingerprints) — all 48
verify unchanged. Every other claim in the report (candidate/predecessor
hashes, 45/17/21 test/README/example counts, all three `00check.log` results,
64/48/16 benchmark case split, the single flagged noise-level ratio, and the
open-gates disclosures) was independently verified against the committed
evidence and found accurate. Total remaining: Standards 0; Spec 0 implementation
findings.

## Outstanding overall release gates

Local package profiles (current/minimum/core) and the local benchmark smoke run
are complete and passed with no unexplained deterioration. The following
mandatory release gates remain genuinely open and unexecuted on this host: the
v0.6 overall approval, all non-macOS-ARM platform/R rows (Linux x86_64 current
and previous R, Windows x86_64, macOS Intel, macOS ARM/4.5.3), the mandated
Linux core/minimum runs (only local ARM substitutes ran here), the controlled
Linux x86_64 performance reference measurement, R-devel early-warning evidence,
unrestricted online CRAN probes and the PDF manual check. Missing mandatory
evidence blocks the overall v0.7 release; this local implementation/report does
not silently waive it or authorize remote work.
