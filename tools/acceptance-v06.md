# v0.6 local acceptance and benchmark report

Ticket: `.scratch/v0.6-tickets/issues/07-release-abnahme.md`. Date: 2026-09-09.
Implementation base: `71eaa70d51ea2025a01847a78255d4686fd67521` on branch `v0.6`.
Status: **all three local package gates, benchmark smoke and evidence mutation checks passed**; **full platform and performance release
approval remains open**. No historical local-only waiver is applied to v0.6.

## Candidate identity

The candidate is built from committed source
`8db2ae6a9d465106cbfe135863446b5198da8b76` using `git archive` followed by
`R CMD build`. The source archive is
[evidence-v06/candidate/vennabers_0.6.0.tar.gz](evidence-v06/candidate/vennabers_0.6.0.tar.gz).
SHA-256: `6c1953d9c319f3272e9b088be965984f99c7320c5567a7d3ecae62f4108e35db`.
All final installation, package tests, help/README/standalone examples and
benchmark measurements use this archive. The report and evidence are excluded
from the package; subsequent evidence-only commits do not extend the tested
payload. A changed package payload needs a new archive and new evidence.

The immutable predecessor is the **actually tested** v0.5 artifact from commit
`e69a9b4`, retained at
[evidence-v05/ci-final/source-candidate/vennabers_0.5.0.tar.gz](evidence-v05/ci-final/source-candidate/vennabers_0.5.0.tar.gz),
SHA-256 `813e435f232b51cbaf36158bafc75ed3922e5905cd80dfee8ff69539d599effa`.
Later v0.5 commits are not covered by that artifact's historical acceptance.
The local comparison reuses this archive, not a rebuilt branch tip.

## Execution limits and platform matrix

GitHub Actions remains disabled by the user's recorded decision in
[the v0.5 report](acceptance-v05.md),
[repository setting](evidence-v05/ci-final/actions-disabled.json) and
[workflow state](evidence-v05/ci-final/workflows-disabled.json). These are historical
records. A fresh read-only GitHub API query on 2026-09-09 confirms
[repository Actions disabled](evidence-v06/tooling/actions-disabled.json) and
[the workflow disabled manually](evidence-v06/tooling/workflows-disabled.json).
This ticket makes no remote settings changes,
workflow edits, upload, issue/milestone creation, push, trigger, tag, publication
or CRAN submission. Re-enablement requires a separate explicit decision.
Deactivation is **not** a waiver of missing v0.6 release evidence.

CRAN's [R source index](https://cran.r-project.org/src/base/R-4/) was checked on
2026-09-09: current minor R 4.6 (4.6.1), previous minor R 4.5 (4.5.3).
`DESCRIPTION` retains R >= 4.5.0. Only macOS ARM/R 4.6.1 is available here;
no already-authorized reachable Linux/Windows/Intel Mac/R 4.5/R-devel runner was
identified. The documented mandatory matrix remains:

| Platform/profile | R | Required evidence | v0.6 result |
| --- | --- | --- | --- |
| Linux x86_64 | 4.6.1 | Current dependencies, artifact check/tests/examples | Not run; open |
| Linux x86_64 | 4.5.3 | Current dependencies, artifact check/tests/examples | Not run; open |
| Windows x86_64 | 4.6.1 | Current dependencies, artifact check/tests/examples | Not run; open |
| Windows x86_64 | 4.5.3 | Current dependencies, artifact check/tests/examples | Not run; open |
| macOS Intel | 4.6.1 | Current dependencies, artifact check/tests/examples | Not run; open |
| macOS Intel | 4.5.3 | Current dependencies, artifact check/tests/examples | Not run; open |
| macOS ARM | 4.6.1 | Current dependencies, artifact check/tests/examples | Local result below; all 17 Suggests match published CRAN versions |
| macOS ARM | 4.5.3 | Current dependencies, artifact check/tests/examples | Not run; open |
| Additional Linux core | 4.6.1 | No integration packages | Not run; open; local ARM probe does not replace it |
| Additional Linux minimum | 4.5.3 | Exact direct minima and compatible transitive set | Not run; open; local ARM probe does not replace it |
| Additional Linux early warning | R-devel | Artifact check/tests/examples and finding triage | Not run; no early-warning result |
| Controlled Linux benchmark | Compatible common R/package set | Same x86_64 host, serial v0.6/v0.5 comparison | Not run; performance clearance open |

The local gates use `R CMD check --as-cran --no-manual`. PDF manual generation,
online incoming/clock checks are disabled. Dependency repository lookups are
attempted but denied by the sandbox; their emitted warnings are listed below. Exact restrictions
and `_R_CHECK_*` settings are recorded per profile. The macOS sandbox denies
external network connections and Python execution, permitting localhost
connections for fresh R workers. Dependency setup precedes that sandbox.
This is a restricted local CRAN-mode check, not an unrestricted CRAN submission
check. No separate static typechecker is configured; R parsing and package
code/usage checks provide the applicable checks.

## Local results

The final current and exact-minimum dependency gates pass on macOS ARM/R 4.6.1: **0 ERROR,
0 WARNING and 0 NOTE findings in the final R CMD check status**, all 34 test files, 15 README R blocks and 16 installed
standalone examples. Exact outputs and environments are retained per profile.

| Local profile | R/runtime | Result | Finding disposition |
| --- | --- | --- | --- |
| Current dependencies | Homebrew R 4.6.1 ARM | [Pass](evidence-v06/local-current/00check.log) | No check ERROR/WARNING/NOTE findings |
| Exact 97-package minimum | Homebrew R 4.6.1 ARM | [Pass](evidence-v06/local-minimum/00check.log) | No check ERROR/WARNING/NOTE findings; previous-R/Linux still open |
| Core without integration packages | Homebrew R 4.6.1 ARM | [Pass](evidence-v06/local-core/00check.log) | No check ERROR/WARNING/NOTE findings; Linux core still open |

Separate [missing/old optional dependency probes](evidence-v06/tooling/final-optional-dependencies.log)
pass for both trainable and frozen constructors, with the manual core still usable.
The [sandbox probe](evidence-v06/tooling/sandbox-check.log) confirms external network
and Python denial; the expected denied-probe warnings are tooling evidence,
separate from the dependency-check warnings listed below. The core wrapper had a post-check shell
status-capture error, documented in [core-wrapper.txt](evidence-v06/tooling/core-wrapper.txt);
both package-gate and check success markers were verified afterward.

### Emitted offline repository warnings

A zero-WARNING final check status does not mean the process emitted no warnings.
Each current/minimum/core check emitted four `Warning: unable to access index`
messages during dependency checking. The core check emitted one additional
`Warning in url(...)`. No online repository validation is claimed.

| Attempted URL | Profiles | Disposition |
| --- | --- | --- |
| `https://CRAN.R-project.org/src/contrib/PACKAGES` | Current, minimum, core | Blocked by intentional external-network denial; local dependencies checked separately |
| `https://bioconductor.org/packages/3.23/bioc/src/contrib/PACKAGES` | Current, minimum, core | Blocked by intentional external-network denial; no Bioconductor dependency is installed or needed by these tests |
| `https://bioconductor.org/packages/3.23/data/annotation/src/contrib/PACKAGES` | Current, minimum, core | Same denied optional repository lookup |
| `https://bioconductor.org/packages/3.23/data/experiment/src/contrib/PACKAGES` | Current, minimum, core | Same denied optional repository lookup |
| `https://CRAN.R-project.org/web/packages/packages.rds` | Core only | DNS/network denied while inspecting intentionally absent Suggests; dependency stage ends INFO |

Thus current/minimum emitted four expected repository warnings each, and core
five, while all final check statuses were OK. These remain visible in each
`check.log` and `acceptance.log`; unrestricted online dependency checks are an
open gate. They are justified limitations of this local offline probe, not
silent suppression or a general warning allowance. The final core emitted no
NOTE requiring a dependency-NOTE exception. The initial contaminated core
preflight and its later wrapper status-capture error are separately recorded above.

## Capability evidence

All listed scripts are existing product tests/examples shipped in the candidate;
this acceptance ticket adds no replacement product implementation or fixtures.
Each full integration profile must satisfy all declared Suggests requirements
before running, so absent optional packages cannot silently turn it green.

| v0.6 capability | Tests under `tests/` | Installed examples under `examples/` |
| --- | --- | --- |
| Eight trainable encoded paths: binary/OvO/OvR/regression, each Inductive/Cross | `schema-workflow.R`, `schema-resampling.R`, `schema-multiclass-regression.R`, `schema-multiclass-resampling.R` | `encoded-binary.R`, `encoded-multiclass-regression.R`, `check-encoded-evaluation.R` |
| Four frozen paths without schema | `frozen-workflow.R`, `frozen-multiclass-regression.R` | `frozen-binary.R`, `frozen-multiclass-regression.R` |
| Four frozen paths retaining training schema | `frozen-schema.R` | `frozen-schema.R` |
| Complete already learned preprocessing/postprocessing, final-prediction parity and no refit | `frozen-workflow.R`, `frozen-multiclass-regression.R`, `frozen-schema.R` | All three frozen examples above |
| Native and decoded probabilities/classes/truth/outcome, identities and available diagnostics | `schema.R`, all schema integration/resampling tests, `frozen-schema.R` | Encoded and frozen-schema examples |
| Fresh RDS processes/workers, preserved models/schemas/classes/events/details, no hidden learning | `schema-processes.R`, `frozen-processes.R`, `frozen-multiclass-processes.R`, `frozen-schema.R`, `integration-processes.R` | Frozen-schema and encoded examples |
| Mixed/ordered holdouts, ordinary/stratified mixed/non-shuffled full Cross partitions and exact complements | `reference-splits.R`, `local-plans.R`, schema resampling tests | `reference-splits.R` |
| Invalid names/classes/bindings/empty inputs, impossible moderation, unfitted/unsupported frozen procedures and invalid forward-only plans | `schema.R`, schema/frozen workflow tests, `reference-splits.R` | Documented error contracts in installed help |
| Cumulative manual classification/regression fixtures, losses/rounding/bounds/folds/scores; eight native v0.5 paths and outer evaluation | All existing parity/core/native/resampling tests | All nine historical standalone examples retained |

Installed help covers `venn_abers_schema`, `venn_abers_encode`,
`venn_abers_decode`, `calibrate_workflow`, and explicit local split contracts.
README and NEWS document explicit encoding before training, retaining the actual
training schema for later frozen calibration, encoded native output, separate
decoding, and legacy full-predict limits. Original learned postprocessing is
part of v0.6. Pair/full-model paths (v0.7), tuning (v0.8), and newly learned
postprocessing (v0.9) remain outside scope.

## Dependencies

The direct minima in `DESCRIPTION` are unchanged. The 97-package
[minimum manifest](minimum-dependencies.csv) records exact direct/test and
transitive versions and dependency edges; the local minimum profile verifies
every installed version against it. `probably` 1.1.0 was installed separately
because the existing local library had 1.2.0. Setup archive identity and install
log are retained. The full local environment also records recommended packages,
R/BLAS/LAPACK and OS versions. All 17 installed Suggests match CRAN published versions on 2026-09-09;
[current version comparison](evidence-v06/tooling/current-published-versions.txt)
records the query. No claim is made about arbitrary transitive combinations.

The Homebrew R base/recommended library with empty user/site library paths
supplies the local core profile; it contains no
optional integration packages. Integration blocks explicitly skip only there,
while all manual capabilities remain tested. An initial framework-R core preflight correctly refused to run because its
base library includes optional packages (including withr). That failed setup is
retained and is not a passed package check. No system libraries were changed.
Separate missing/old-dependency
probes cover both trainable and frozen entry points and usable manual core.

## Benchmark protocol

`performance.R` keeps the original 16 manual and eight v0.5 workflow cases and
RNG draw order. All 24 are remeasured for both artifacts. The 24 new cases
(six per binary/OvO/OvR/regression family) are encoded mixed Inductive, encoded
Cross, unencoded ordered Inductive, encoded ordered Inductive, unencoded frozen,
and frozen with training schema. New abilities have baseline measurements only.

All workflow cases use 2,000 development/calibration rows, 500 new rows and ten
numeric predictors. Seed 20260910, outcome generation, GLM/shared multinomial/LM,
normalization recipes, Log/no rounding or m=1, five Cross folds, three outer folds,
plan seeds 3501/3502/3503 and fit seed 3504 match v0.5. OvO/OvR use identical
multinomial data and partitions. Encoding changes names and class codes on the
same values. Ordered plans use explicit `make_splits()` with the first
`n - ceiling(.2*n)` training rows and the remaining calibration rows, also within
each outer analysis domain. These are holdouts, not time-series validity claims.

For each frozen case, independent seed 20260911 generates 1,000 **separate earlier
training rows**. The actual training data, untrained workflow, and original
training schema are saved. Each measurement process fits that earlier procedure
once **before** warmup/timing. All 2,000 later rows calibrate the frozen predictor;
no part of them is used to retrain it. Model identity and calibration size are
checked. Frozen outer evaluation is not applicable. The benchmark baseline uses
learned recipe/model state; complete already learned postprocessing is exercised
by the package acceptance tests, not added as newly learned benchmark work.

One warmup and three measurements run serially for each case/release, in a fresh
R process per pair. OMP/OpenBLAS/MKL/VECLIB/BLIS pools use one thread;
`allow_par = FALSE` disables parallel outer resampling. Fit/calibration, Predict,
and complete outer evaluation are separate. Schema construction, encoding the
2,000+500 rows, and decoding native predictions have separate timing columns.
Frozen schema construction is timed independently against the saved training
schema, without changing that schema or relearning the model. Tiny operations
may round to zero at R's elapsed timer resolution. Zero outer/conversion times
for inapplicable cases mean not applicable, not measured free work.

Public construction/validation stays timed. Data/plan setup, installation,
original frozen training, output validation and RDS I/O stay outside these
windows. Every iteration records gzip/version-3 model RDS bytes. Per-case peak
RSS includes the complete process (runtime, original training if frozen, warmup,
measurements and serialization), not isolated calibrator memory. Fresh restore
processes compare native predictions identically and encoded cases additionally
compare decoded predictions and retained schemas. Saved inputs, generator,
artifact identities, thread settings, raw runs, medians and comparisons support
replay. Bundle validation independently recomputes medians/ratios, checks full
coverage and saved plans, replays original frozen training draws, and verifies
encoding/ordered membership. Corrupted evidence is checked by mutation probes.

Large benchmarks remain separate from package checks. Non-Linux `--smoke` keeps
the full workload and protocol but explicitly produces **no Linux performance
clearance**. A release-mode invocation rejects this host. Any slower timings in
the local comparison remain observations requiring controlled Linux investigation,
not accepted performance regressions or release waivers.

## Local smoke results and evidence retention

The completed smoke run has **48 cases, 72 case/release pairs, 288 raw rows**
(72 warmups and 216 measurements), 72 medians and 48 comparisons. All 72
independent fresh-process restorations pass; all 16 encoded variants also check
decoded predictions and retained schemas. The bundle validator passes.
[Mutation validation](evidence-v06/tooling/benchmark-mutations.log) also passes,
including corrupted frozen training, schema/encoding and ordered memberships.

[Measured baselines and every cumulative comparison](evidence-v06/benchmark-smoke/results.md)
show separate Fit/calibration, Predict, outer evaluation and schema conversion
costs. [Raw rows](evidence-v06/benchmark-smoke/runs.csv),
[medians](evidence-v06/benchmark-smoke/medians.csv) and
[comparisons](evidence-v06/benchmark-smoke/comparison.csv) retain memory, model
sizes and all observed deteriorations. These are macOS smoke observations;
controlled Linux remeasurement and investigation remain open before release.
No v0.6 performance regression waiver is inferred.

The historical input audit matches all 24 prior macOS workloads in data, plan
memberships, options and model/recipe configuration, excluding rsample fingerprint
metadata. The historical Linux bundle has some low-order numeric input differences
and a different machine/runtime; its old timings are not used as the denominator.
Both artifacts here use the same new saved input per case. The
[input audit](evidence-v06/tooling/historical-inputs.log) and
[cross-platform differences](evidence-v06/tooling/cross-platform-inputs.csv)
make that limitation explicit.

The evidence directory retains the exact source archive, payload audit, individual
check/test/example outputs, settings, package versions, benchmark inputs and
generator, per-case runs/peak-memory/session/restore logs, medians and comparisons.
Model/prediction/outer/decoded RDS outputs remain in
`/Users/entropy/Git/venn-abers/.scratch/v06/final-benchmark/`;
[generated-rds.csv](evidence-v06/benchmark-smoke/generated-rds.csv) records their
SHA-256 hashes and sizes without duplicating them in Git. Inputs plus the pinned
artifacts recreate them. Runtime libraries are not committed. The final manifest
covers all retained evidence; run `shasum -a 256 -c SHA256SUMS` from
`tools/evidence-v06` to verify it.

Development probes and superseded candidate checks are not attributed to the
final archive. The fixed candidate reran all three package profiles and all
benchmark cases; the report does not transfer prior results to a new hash.

## Reproduction

From the repo root with the desired prepared dependency library:

```sh
ACCEPTANCE_ARTIFACT=tools/evidence-v06/candidate/vennabers_0.6.0.tar.gz \
  ACCEPTANCE_OUTPUT_DIR=/empty/output/current Rscript --vanilla tools/acceptance.R
# Set ACCEPTANCE_PROFILE=minimum for the exact pinned set; core for a clean R library.

# Run serially on one authorized Linux x86_64 machine, after package checks finish.
Rscript --vanilla tools/performance.R \
  tools/evidence-v06/candidate/vennabers_0.6.0.tar.gz \
  tools/evidence-v05/ci-final/source-candidate/vennabers_0.5.0.tar.gz /empty/output/benchmark
Rscript --vanilla tools/test-performance.R /empty/output/benchmark --v06
Rscript --vanilla tools/test-performance-verifier.R /empty/output/benchmark
# --smoke is required on non-Linux machines; it never satisfies the Linux gate.
```

## Review and remaining release gates

Independent Standards and Spec reviews both found one predecessor compatibility
bug: v0.5 rejects even `schema = NULL`. Passing schema only on encoded paths fixes
it. The retained negative/positive probe uses the actual v0.5 archive. A focused
ordered encoded regression run also passes fresh-process restoration. No other
implementation findings were reported. Final evidence review identified the
repository-warning distinction documented above; artifact identity, local success
markers, workload/dependency claims and open gates otherwise matched the evidence.

Open: the unavailable matrix rows, Linux minimum/core and R-devel evidence,
controlled Linux comparison and review of deteriorations, unrestricted online
CRAN probes/PDF manual, and final v0.6 release approval. This ticket supplies a
local acceptance report and reproducible tools; it does not declare those gates
passed or authorize their remote execution.
