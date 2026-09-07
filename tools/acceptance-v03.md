# v0.3 source candidate and acceptance

**Status update, 2026-09-07:** The maintainer confirms that v0.3 is approved
and has been run on Linux and Windows machines. This supersedes the pending
approval status in the historical local report below. Exact remote run logs,
runtime versions and artifact hashes were not supplied with that confirmation;
the historical measurements and identities are preserved as recorded.

## Historical local report (before maintainer confirmation)

Status: **not approved for release**. This ticket prepares `vennabers_0.3.0.tar.gz`
and a repeatable acceptance path; a version number, configured matrix or local
smoke run is not a release approval. No tag, publishing or CRAN submission is
part of this work. Implementation starts at `019095e4c70eeed8e5c9bfe174d25961b865ba7f`.
The binding scope is [the release roadmap](../RELEASE-ROADMAP.md), sections 2–4.

## Capability evidence map

The final artifact check runs all nine existing package test files, help examples,
README R fences and five installed scripts. No new numerical fixture or relaxed
tolerance is introduced by this acceptance ticket. The execution record below
states which environment has actually run these checks.

| Capability | Executed checks in the artifact gate | Meaning of evidence |
| --- | --- | --- |
| Existing binary IVAP contract, endpoints, default Log, scores/plots | `venn-abers.R`, `randomized-parity.R`; README and help | 33 deterministic reference rows and 100 stored randomized cases; binary vector API retained |
| Existing binary Cross Log and matched folds | `cross-venn-abers.R`, `cross-parity.R`; installed `cross-venn-abers.R` GLM example | Five fixed and 100 random stored cases, identity/alignment, equal weighting, underflow, shape and consumers |
| Binary Log/Brier, fit precision, classes and fold diagnostics | `binary-options.R`, `binary-options-parity.R`; installed `binary-options.R` | Reference components plus independent Brier calculations, event wins at 0.5, reconstruction, validation and native rounding |
| Inductive OvO × Log/Brier × precision | `inductive-multiclass.R`; installed `inductive-ovo.R` | 33 fixed/seeded cases, 2/3/4 classes; manual Python Log parity, binary-component Brier parity plus independently calculated coupling |
| Inductive OvR × Log/Brier × precision | `inductive-ovr.R`; installed `inductive-ovr.R` | Same stored inputs/cases; Python Log component parity (3/4 classes also facade), Brier binary components plus normalization |
| Cross OvO/OvR × Log/Brier × precision | `cross-multiclass.R`; installed `cross-multiclass.R` | Manual R extension: public reference-checked binary IVAP components and independent fold merging/coupling; 2/3/4 classes, unequal folds, missing classes, empty-pair errors, reordered identities, zero/one rows |
| Multiclass classes, scores and classwise plots | `inductive-multiclass.R`, `inductive-ovr.R`, `cross-multiclass.R`; three multiclass installed examples and help | R API contracts and independent score/bin calculations; first stored class wins ties, even with two classes; Brier sums squared class errors |

Reference identity is Python `venn-abers` **1.5.4**, commit
`0e7b4bc575ce230134576ba1c76688d46bf99ac7`, numerical module SHA-256
`ea7816e8832eef3f0fa129d2bb80dffae4efcb785f37f083fc087136edb720a5`,
sdist SHA-256 `a6bf5383e618ce42d0ecb2335bba0d6b104ecbe979041f10019b57572364bc69`.
The `inst/extdata/*environment.json` manifests, input/output CSVs, class/pair/fold
identities and optional generators retain inputs and options, not just seeds.
See [binary provenance](../inst/extdata/binary-options-reference.md),
[Cross provenance](../inst/extdata/cross-reference.md), and
[OvO](../inst/extdata/ovo-environment.json)/[OvR](../inst/extdata/ovr-environment.json)
manifests. Absolute classification tolerance remains `1e-10`, with no relative
allowance; shape, identity and finiteness are checked independently.

Keep the following claims distinct:

- Numerical parity covers valid reference paths with identical inputs and options.
  Manual Python multiclass does not expose Brier selection; those R paths use
  reference binary components and independent combination formulas. Python has
  no matching public manual Cross-multiclass API.
- R extensions include that manual Cross API, class/fold diagnostics, strict input
  validation and R score/plot consumers. These are contract tests, not invented
  Python wrapper parity or a model-training claim.
- Defined reference defects include Cross product underflow, zero OvO pair mass
  handling and defective wrapper class selection. R uses stable log aggregation,
  neutral `(0.5,0.5)` zero pairs and documented final-probability tie rules. Defective
  results are not numerical oracles and do not justify wider tolerances.
- Native `round()` may differ from NumPy at floating-point boundaries (for example
  `.545` and `.575` at precision two in the recorded environments). Native-rounding
  contract tests are separate from comparable Python fixtures. New values stay
  unrounded; OvO pair normalization precedes fit rounding.
- v0.3 takes caller-supplied probabilities and fold assignments. It promises no
  automatic training/splitting, pair-model training, regression or tidymodels path.
  No universal coverage, accuracy, Brier or log-loss improvement is asserted.

## Artifact, support and migration

The candidate declares version 0.3.0, R >= 4.5.0 and no nonstandard dependencies.
René-M. Kruse (`rene.marcel.kruse@protonmail.com`) is the maintainer supplied by
the user; the existing author attribution is retained. NEWS and all eight public
help topics describe the implemented manual classification API.
[CRAN's archive](https://cran.r-project.org/src/base/R-4/) was rechecked on
2026-09-07: current R 4.6.1 and previous minor patch 4.5.3. The floor stays 4.5.0.

Migration from v0.2: R 4.1–4.4 users need a newer R or the earlier package. Existing
binary calls retain default Log, no rounding and their output schemas (three
IVAP double columns; one Cross probability column). Factor truth plus a named
class matrix selects multiclass; its two-class Brier sum and tie rule differ
intentionally from the binary-vector interface. The former checkout `examples/`
scripts now live at `inst/examples/` and ship in the installed package. Locate
installed scripts with `system.file("examples", package = "vennabers")`.

The CI source job builds once and writes SHA-256. All eight required jobs and
Linux R-devel download and verify the same archive, then use
`ACCEPTANCE_ARTIFACT`; each gate also records its portable MD5 identity. The gate
installs into a fresh library, verifies namespace path/version, checks the archive
and executes examples from the installation, not the checkout. It refuses an
archive whose Package/Version differs from the checkout metadata.

Checks use `R CMD check --as-cran --no-manual`. Online incoming/repository/clock
probes are disabled, while tests/help/examples stay enabled. PDF generation and
online CRAN submission checks are not claimed. No errors, warnings or NOTEs are
allowlisted: the gate requires `Status: OK`; a new NOTE requires investigation
and individual justification, never silent acceptance.

| Required environment | Exact final candidate result |
| --- | --- |
| Linux x86_64, R 4.6.1 | Pending hosted execution |
| Linux x86_64, R 4.5.3 | Pending hosted execution |
| Windows x86_64, R 4.6.1 | Pending hosted execution |
| Windows x86_64, R 4.5.3 | Pending hosted execution |
| macOS Intel, R 4.6.1 | Pending hosted execution |
| macOS Intel, R 4.5.3 | Pending hosted execution |
| macOS ARM, R 4.6.1 | Local macOS 26.6.2 run recorded below; macOS 15 CI image pending |
| macOS ARM, R 4.5.3 | Pending hosted execution |
| Linux x86_64 R-devel (additional early warning) | Final candidate pending; no current-candidate finding asserted |

The earlier [hosted run 34141791368](https://github.com/RMKruse/venn-abers/actions/runs/34141791368)
checked `37f3def`, before multiclass completion: six required jobs and Linux
R-devel succeeded, both Windows jobs failed during build. The log identifies
copying the open `.scratch/ci/build.log` as the failure. `acceptance.R` now captures
child logs in the system temporary directory and copies them after the child exits;
CI additionally checks a prebuilt archive. The failure regression check runs on
Windows as well as Linux. This is a diagnosed/fixed path, not a claimed Windows
retest. Old successful jobs do not count for the final candidate.

## Comparative benchmark protocol

`performance.R` implements the following 12 cases. Only the first two exist in
v0.2 and receive predecessor comparisons; the other ten are new baselines.

| Cases | Calibration / prediction rows | Classes / folds | Loss / precision |
| --- | --- | --- | --- |
| Original binary IVAP | 100,000 / 100,000 | 2 / 1 | Log / NULL |
| Binary Cross | 10,000 / 1,000 | 2 / 5 | Log / NULL |
| Inductive/Cross × OvO/OvR (four each) | 10,000 / 1,000 | 3 and 10 / 1 or 5 | Log / NULL |
| Additional binary Cross, three-class Cross OvO | 10,000 / 1,000 | 2 or 3 / 5 | Brier / 2 |

IVAP keeps seed 20260906 and exactly the old draw order: sample logical truth,
then uniform calibration and prediction vectors. The additional cases use seed
20260907, fixed row/fold/class identities, valid normalized positive class
matrices, five fold-named new-prediction inputs and class representation in every
fold. These are synthetic inputs for the manual calibration API; no upstream
model is trained. Actual arrays, truth and assignments are retained in per-case
RDS files, hashed in `plan.csv`, and shared unchanged between releases.

Preparation, input checks and package installation happen before timed workers.
Public API input/output validation remains inside timed fit/predict calls. Each
case/release gets a fresh R process; the driver executes them serially. Each
worker uses one warmup (iteration 0) then three measurements (1–3), separately
records fit and predict elapsed seconds, and releases temporary fits between runs.
Controllable BLAS/engine thread pools are set to one before workers start.

GNU `/usr/bin/time -v` records the whole case process high-water RSS. It includes
R startup, reading prepared inputs, warmup, all repeats, validation and RDS I/O;
it is neither isolated object memory nor a separate fit-only peak. The same case
peak is attached to its four timing rows. Model RDS sizes use `compress="gzip"`,
`version=3` in both releases. Predictions are checked after reload, including a
separate fresh-process restore outside timing/peak measurement. Saved predictions
are verification artifacts; only model files contribute the reported RDS size.

`runs.csv` includes individual values and warmups; `medians.csv` excludes warmup;
`comparison.csv` retains current/previous values and ratios only where supported
and the previous denominator is positive. Zero-resolution timings yield no ratio.
All comparable cases require regression review; no threshold automatically approves
them. Increased timing, RSS or model size must be investigated on that reference
machine before release. Historical M5/other-hardware numbers and the old ten-second
ceiling are not acceptance comparisons.

The output retains OS/CPU/RAM details on Linux, R/session and installed dependency
versions, thread settings, archive identities, generator source, exact inputs,
model/prediction RDS files, install/process/restore logs and summary CSVs. The
runner rejects release measurements on a non-Linux-x86_64 host; `--smoke` marks
those results explicitly as non-release validation. No Linux reference measurement
or regression clearance is claimed in this record yet.

## Reproduction commands

Run from the matching checkout with R and its standard packages installed. No
Python or network is used after environment preparation. Use empty output paths.

```sh
# Build/check locally and retain an immutable candidate and logs.
ACCEPTANCE_OUTPUT_DIR=.scratch/v03-final Rscript --vanilla tools/acceptance.R

# Recheck the EXACT archive; do not rebuild for each R/platform.
ACCEPTANCE_ARTIFACT=.scratch/v03-final/vennabers_0.3.0.tar.gz \
  ACCEPTANCE_OUTPUT_DIR=.scratch/v03-recheck Rscript --vanilla tools/acceptance.R

# Regression checks: injected installed-example/test failures must fail the gate.
Rscript --vanilla tools/test-acceptance.R

# Prepare predecessor source once, outside measurement (no tag is assumed).
mkdir -p .scratch/v03-predecessor
# Use an empty predecessor directory.
git archive b1037eb | tar -x -C .scratch/v03-predecessor
R CMD build .scratch/v03-predecessor

# On the Linux x86_64 reference machine, with the SAME two artifacts and R:
Rscript --vanilla tools/performance.R \
  .scratch/v03-final/vennabers_0.3.0.tar.gz vennabers_0.2.0.tar.gz benchmark-output
Rscript --vanilla tools/test-performance.R benchmark-output
sha256sum .scratch/v03-final/vennabers_0.3.0.tar.gz vennabers_0.2.0.tar.gz \
  tools/performance.R benchmark-output/*-input.rds > benchmark-output/SHA256SUMS
```

The predecessor is the last v0.2 DESCRIPTION source at `b1037ebe69e65f07f4123a6273a5805c41a09adc` (version 0.2.0),
rebuilt under the same runtime as the candidate; no comparison is made to an
unavailable predecessor multiclass/Brier/precision API. Retain the source archive,
all SHA-256 manifests, gate outputs and benchmark output together. CI uploads
per-platform evidence even on failure. This report and `tools/evidence-v03/` are
external evidence, excluded from the package so appending results cannot change
the candidate identity.

## Execution record and release blockers

On 2026-09-07, the final local gate and a separate `ACCEPTANCE_ARTIFACT` recheck
both exited 0 on R 4.6.1 (`aarch64-apple-darwin25.4.0`), macOS 26.6.2 / Darwin
25.6.0, Apple M5 Pro, 15 logical CPUs, 24 GiB RAM. Both used the identical archive
(MD5 records compared equal). Standard packages were R 4.6.1 and codetools 0.2-20;
the complete package set and machine data are retained in the environment log.

| Local verification | Result / retained evidence |
| --- | --- |
| Source build, isolated install, CRAN-mode check | Passed; [check log](evidence-v03/local-check.log), zero errors/warnings/NOTEs |
| Nine package test files and public help examples | Passed against the installed archive; [gate log](evidence-v03/local-acceptance.log) |
| Seven README R fences, five installed standalone examples | Passed in both runs; [same-artifact recheck](evidence-v03/artifact-recheck.log) |
| Offline/no-Python execution | Both complete gates and injected-failure checks ran with network and Python process execution denied, including children |
| Failure propagation | Installed-example and package-test injections each exited 1; [regression log](evidence-v03/gate-regression.log) |
| R parse checks and actionlint 1.7.12 | Passed; package `R CMD check` also passed static code-problem checks; no separate typechecker is configured |
| Benchmark CLI smoke using this archive plus rebuilt v0.2 | All 12 current + 2 predecessor cases, 56 warmup/measurement rows, 14 medians, 12 comparison rows; [bundle check](evidence-v03/benchmark-smoke-check.log) |
| Model restoration | All 14 case/release workers passed fresh-process prediction identity; [process logs](evidence-v03/benchmark-smoke/processes.log) |
| Platform guard | Non-Linux release measurement rejected before output creation; [guard log](evidence-v03/benchmark-platform-guard.log) |

The two artifact gates and regression checks used this wrapper (with their
respective environment variables and script arguments):

```sh
/usr/bin/sandbox-exec \
  -p '(version 1)(allow default)(deny network*)(deny process-exec (regex #".*/python[^/]*$"))' \
  /opt/homebrew/opt/r/bin/Rscript --vanilla tools/acceptance.R
```

Candidate: `.scratch/v03-final/vennabers_0.3.0.tar.gz`, SHA-256
`c72d953b049de7087372eb065c2198f88855094ca0120a31da3660c62788b825`.
The local package payload matches the implementation commit `27da771`; later
changes only append excluded evidence. Source archive, predecessor and runner
identities plus all prepared-input SHA-256 values are in
[SHA256SUMS](evidence-v03/SHA256SUMS). Logs and source package remain in
`.scratch/v03-final/`, with the second gate in `.scratch/v03-recheck/`.

The full-size smoke command was the documented benchmark command with
`--smoke`, using `.scratch/v03-benchmark-final-smoke` for output. It exercised
`/usr/bin/time -l` on macOS; the GNU Linux RSS collection path is still unexecuted
here. The smoke ran alongside other local checks and is **not** controlled
performance evidence or a regression clearance. Its [plan](evidence-v03/benchmark-smoke/plan.csv),
[individual results](evidence-v03/benchmark-smoke/runs.csv),
[medians](evidence-v03/benchmark-smoke/medians.csv),
[comparisons](evidence-v03/benchmark-smoke/comparison.csv) and environment/process
logs are retained to verify the runner, not to claim Linux performance. Exact
input/model/prediction RDS files remain in `.scratch/v03-benchmark-final-smoke/`.

Code review used two independent agents against starting commit `019095e`:
Standards — no findings. Spec — no fixable implementation defect or scope creep;
two outstanding evidence groups: final platform/R-devel results and controlled
Linux predecessor measurement/regression review. Neither finding is waived.
Outstanding mandatory evidence blocks release approval: the final eight-platform
matrix, current-candidate R-devel triage, Linux reference benchmarks and investigated
predecessor comparisons. Later code, fixture, example or metadata changes require
a new artifact and fresh evidence. No release approval is inferred from missing
capacity or from this ticket's commit.
