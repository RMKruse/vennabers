# Build and verify a release candidate

Use R >= 4.5, Git, Pandoc (for the HTML vignettes) and a working LaTeX
installation (`R CMD Rd2pdf`). Install `knitr` and `rmarkdown` with the other
suggested packages below. The builder uses R's own
[SHA-256 support](https://stat.ethz.ch/CRAN/bin/windows/base/old/4.5.0/NEWS.R-4.5.0.html)
and has no additional R dependencies. Run from a fresh checkout of the
candidate commit. Disposable archives, installed libraries, logs and RDS
results belong outside `.scratch`; keep only the Markdown result summary there.

## One-time setup

Choose a new dependency library and install the packages from `Suggests`:

```r
deps <- "/absolute/path/to/deps"
dir.create(deps, recursive = TRUE)
d <- read.dcf("DESCRIPTION")
packages <- trimws(sub(" *[(].*", "", strsplit(d[1, "Suggests"], ",")[[1]]))
install.packages(packages, lib = deps, repos = "https://cloud.r-project.org", Ncpus = 1)
```

After setup, point `R_LIBS` at that library. Runtime verification does not
install packages, download reference fixtures or invoke Python. Committed
fixtures include their Python provenance; their generator is for fixture
maintenance only. Record R, OS, BLAS and dependency versions for each run.

## Candidate and local evidence

```sh
Rscript --vanilla tools/build-candidate.R HEAD /absolute/path/to/new-candidate-dir
```

The output contains a Git export in `checkout/`, the source tarball,
`vennabers-manual.pdf`, `candidate.dcf` (package version, full commit/tree,
source/PDF SHA-256, R and platform), `SHA256SUMS`, and `contents.csv` with hashes
of every packaged file. The build executes the vignettes and includes their
HTML and extracted R code. The builder compares every committed test, fixture,
installed example and vignette source with the unpacked archive and fails on
omission or changes. Local edits and untracked files cannot enter the export. A rebuild
may have different archive/PDF hashes because of packaging timestamps; retain
and share the specific hashed archive for all checks of the same candidate.

Install and check that archive, keeping output in a temporary directory:

```sh
R CMD INSTALL --install-tests --library=/absolute/path/to/new-lib /absolute/path/to/vennabers_1.0.0.tar.gz
Rscript --vanilla tools/test-build-candidate.R
Rscript --vanilla tools/test-verify.R
Rscript --vanilla tools/test-acceptance-v09-package.R
Rscript --vanilla tools/test-migration-v09.R
Rscript --vanilla tools/verify.R 4 /absolute/path/to/vennabers_1.0.0.tar.gz
Rscript --vanilla tools/acceptance-v09-package.R /absolute/path/to/new-lib /absolute/path/to/deps /absolute/path/to/vennabers_1.0.0.tar.gz /absolute/path/to/package-evidence
```

Create the installation library before `R CMD INSTALL`. The complete suite
uses four test processes by default, with BLAS/OpenMP limited to one thread;
individual worker tests use at most two workers. Use fewer test processes on
smaller hosts. To verify product HTTP(S) independence, set `http_proxy` and
`https_proxy` to `http://127.0.0.1:9`, `HTTP_PROXY` and `HTTPS_PROXY` likewise,
and `no_proxy`/`NO_PROXY` to empty for the complete-suite command. The package
acceptance tool already applies the lowercase dead proxy to its processes.
This is an HTTP(S) failure check, not a claim of a physically disabled network.

The package acceptance tool runs unmapped tutorials in fresh processes and
checks the core without integration packages and all Rd examples. Its
`acceptance-v09-example-coverage.csv` maps the larger installed examples to
their full-suite owners. Therefore run it only after the complete suite passes
with no skips on this archive. All 46 installed files are accounted for across
suite, core, helpers and standalone examples.

Run `R CMD check --as-cran /absolute/path/to/vennabers_1.0.0.tar.gz` from a
temporary working directory. Leave `NOT_CRAN` unset for the short CRAN profile:
`tests/cran-long-tests.txt` explicitly lists the longer process/worker and
integration matrix files excluded there, without removing them from the
tarball. `NOT_CRAN=true` enables the full in-check suite; `tools/verify.R`
always executes every installed test file, irrespective of the CRAN profile.
Allow R's incoming/index/time checks their own online access and report their
findings separately from product tests. Inspect each new NOTE and WARNING;
do not inherit an earlier environment's explanations.

## Reused acceptance and benchmark sources

All these sources are committed and excluded from the R source package by
`.Rbuildignore`; expensive benchmarks never become regular package tests.

| Source | Scope |
| --- | --- |
| `acceptance-v09-package.R` and coverage CSV | Installation, core-only operation, load orders, installed tutorials and static Python/network scan |
| `acceptance-v09-matrix.R` | 80 original Grid/Bayes cases and 40 targeted postprocessing cases; CLI and optional `MATRIX_ONLY` selection documented in its header |
| `migration-v09.R` | Migration from the fixed 0.9.0 commit, 22 representative saved-object/refit paths |
| `xgboost-early-stopping.R` | Real XGBoost early-stopping fits on every local fit; xgboost stays outside `Suggests`, so install it in a throwaway library and pass that after the candidate library |
| `corp-parity-reliabilitydiag.R` | CORP estimate and both resampling bands of `corp_plot()` against reliabilitydiag 0.2.1 (48 runs); reliabilitydiag stays outside `Suggests`, so pass a throwaway library holding it |
| `corp-coverage-study.R` and `test-corp-coverage-study.R` | Simulated pointwise coverage of the CORP bands (hard criterion for the consistency band only) and one-call run time and memory; a measurement, not a performance gate |
| `benchmark-v08.R` | Historical v0.8 measurement source |
| `benchmark-shared-v09.R` | Shared-capability comparison with seeded identical outer splits |
| `benchmark-v09.R` | Postprocessing cases, phase timings, heap peaks, RDS sizes and fit/retention counters |
| `run-benchmarks-v09.sh` / `summarize-benchmarks-v09.R` | Historical serial **macOS** runner (`/usr/bin/time -l`) and summary; preserve its v0.8/v0.9 protocol |

These are reusable inputs, not a claim that the later Linux benchmark matrix
is complete. Tickets 27–29 supply that matrix and Linux RSS measurement with
the same v0.9.0 baseline commit `8ef60f98804b6bb589cf3c871416f82411b5d5fd`.
Use a fresh single-threaded process per measured case, one warm-up and three
measurements; keep preparation/installation outside the measured phases.

## Candidate handoff and corrections

Tickets 20–29 must record the full candidate commit, version and archive hash
from `candidate.dcf`, their commands, environment, results and disposition of
findings. Use the same archive for platform and benchmark runs. Any later
product correction creates a new candidate identity: rebuild, list affected
behaviour/platform/performance evidence, and rerun it before release. Old green
runs cannot certify changed code. This local build does not complete any of
the later platform or Linux benchmark gates.

## Minor checkpoint (1.x)

Before each 1.x minor candidate, record in the release log
(`RELEASE-ROADMAP-1.x.md` §9.1):

1. New releases of the main reference and of every procedure reference: adopt
   each new capability as a new ticket (never in the current minor) or record
   that it is not adopted. Changed values keep the pin and become a D entry
   and a 2.0 candidate. Only this record blocks the release.
2. Rerun the counter-comparison scripts under `tools/` against current
   releases; otherwise note "last checked with version X".
3. Recheck preprint validity statements and update their labels in the help
   pages and `inst/PARITY.md` once they are peer reviewed.
4. From 1.2 on, review the weekly CI run against tidymodels `main` and file
   breaks of the fenced internals as tickets.

Also run the archive comparison against the previous CRAN release
(`RELEASE-ROADMAP-1.x.md` §3.2) on every CI platform; see below.

## Archive comparison (1.x)

Release fidelity: with the same scores, labels, options and fold assignments,
a 1.x candidate must reproduce the previous release bit for bit on the same
platform and R version. Run this for every 1.x minor and patch, after the
complete suite passes, from a checkout of the candidate:

```sh
Rscript --vanilla tools/test-archive-comparison.R
Rscript --vanilla tools/archive-comparison.R <previous> /absolute/path/to/vennabers_1.1.0.tar.gz /absolute/path/to/temporary-out-dir
```

`<previous>` is a CRAN version such as `1.0.0` (CRAN archive, or
`src/contrib` while it is the current release), a source tarball URL, or a
local source tarball. While 1.0.0 is not on CRAN, pass the durable candidate
`vennabers_1.0.0.tar.gz` of commit `71f1041`. The tool installs both versions
into their own libraries under the output directory; parsnip, workflows,
hardhat, rsample, tibble and generics come from the caller's libraries. It is
not part of `R CMD check`.

A fresh process per version runs the catalog in
`archive-comparison-cases.R`: every manual kernel (binary, OvO and OvR, each
Inductive and Cross, with and without `precision`; IVAR and CVAR with default,
`m` and `epsilon` moderation), predicted with both losses, as classes and with
details, and one workflow per target (binary, OvO, OvR, regression). Workflow
cases start at the handover of the scores: a `model_adapter()` returns fixed
score columns and explicit splits fix the folds, so engine fits and
dependencies stay outside the comparison. Each case records its predictions,
`venn_abers_details()` (workflows), `print()` output, warnings, errors and
stored object fields. Stored fields leave out recorded package versions,
parsnip's engine fit timings (`elapsed`), functions and environments; these
differ between releases or processes without a changed result.

The two records are compared with `identical(num.eq = FALSE, single.NA =
FALSE)`, so a single changed bit counts. The output directory holds
`comparison.csv` (one row per case and output, with the first difference) and
`summary.md` (platform, R version, both vennabers versions and sources,
integration package versions, and each difference with both values to 17
significant digits). The tool prints the summary and exits with status 1 on
any difference. Keep only the summary in the release log and remove the
directory afterwards.

On CI, start the `archive-comparison` workflow by hand on the candidate ref
(it must also exist on `main` to be offered). It runs the eight required
platform/R combinations and adds each summary to the job summary. Leave
`previous` at the CRAN version, or set `previous_ref` (for example the
`v1.0.0` tag) to build the previous release from Git while it is not on CRAN:

```sh
gh workflow run archive-comparison.yaml --ref v1.1.0 -f previous_ref=v1.0.0
```

The CI job builds both packages without vignettes or manual; only R code and
data enter the comparison.

**Extending the catalog.** An option omitted from a call takes its default in
both versions, so the existing cases already cover the default of every new
option. Each minor adds its new options' defaults as explicit calls: add a
case with a new name whose `new_options` lists them, as
`list(fit = list(option = default), predict = list(option = default))`. The
candidate passes them, the previous release (which lacks them) does not. If a
stored field records that an option was passed explicitly, compare the
outputs and justify the expected field difference in the release log. Never
edit an existing case; the only exception is a documented defect correction
under §3.2, which adjusts the affected case with its reason.
