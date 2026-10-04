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
with no skips on this archive. All 41 installed files are accounted for across
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
