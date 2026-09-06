# v0.2 acceptance evidence

Both complete gates passed on 2026-09-06 for `vennabers` 0.2.0. Each run
built `vennabers_0.2.0.tar.gz`, checked that source artifact with
`R CMD check --no-manual`, installed it into a fresh temporary library, and
verified the loaded namespace path and package version before running the
README and standalone example. Both processes exited with status 0.

| Evidence | R 4.1.3 | R 4.6.1 (latest stable) |
| --- | --- | --- |
| R release date | 2022-03-10 | 2026-06-24 |
| R platform | `aarch64-apple-darwin20` | `aarch64-apple-darwin25.4.0` |
| Source build and installation | Passed | Passed |
| Artifact check | `Status: OK` (0 errors, warnings, notes) | `Status: OK` (0 errors, warnings, notes) |
| All four package test files and help examples | Passed | Passed |
| README R snippets | 2 passed | 2 passed |
| Canonical three-fold GLM script | Passed | Passed |
| IVAP fit/predict seconds, three runs | 0.414, 0.415, 0.412 | 0.425, 0.411, 0.410 |
| IVAP median, limit 10 seconds | 0.414 | 0.411 |
| Final gate message | `Acceptance gate passed.` | `Acceptance gate passed.` |

The shared reference machine was an Apple M5 Pro, 15 logical CPUs, running
macOS 26.6.2, Darwin 25.6.0, arm64. Each performance run fitted 100,000
calibration observations and predicted 100,000 probabilities. There is no
Cross Venn-Abers timing requirement.

R 4.6.1 was the installed Homebrew runtime, confirmed as latest stable against
[CRAN](https://cran.r-project.org/banner.shtml) on the run date. R 4.1.3 used
the official [CRAN arm64 installer](https://cran.r-project.org/bin/macosx/big-sur-arm64/base/R-4.1.3-arm64.pkg),
extracted into a temporary directory. Only runtime location paths and dynamic
library load paths were relocated, with local ad-hoc signatures; R's numerical
implementation was unchanged. Installer SHA-256:
`d973134c1417afeb8c54a8bd0b53ddbc47719e0e30fd9c2122a71d13a57106c4`.

The final gates ran with macOS sandbox networking denied to each process and
its children. Runtime preparation and optional reference regeneration occurred
before these runs; neither is a package installation or acceptance dependency.
Commands from the repository root (the first variable names the extracted
R 4.1.3 runtime used for this evidence):

```sh
R413_HOME=/private/tmp/vennabers-r413/expanded/R-fw.pkg/Payload/R.framework/Versions/4.1-arm64/Resources
RHOME="$R413_HOME" /usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' \
  "$R413_HOME/bin/Rscript" --vanilla tools/acceptance.R

/usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' \
  /opt/homebrew/opt/r/bin/Rscript --vanilla tools/acceptance.R
```

On either normally installed supported R version, the portable command remains
`Rscript tools/acceptance.R`. No saved build, library or plot files are needed
for reruns; the gate cleans its temporary outputs.

The gate retains `venn-abers.R`, `randomized-parity.R`, `cross-venn-abers.R`,
and `cross-parity.R`: the 33 deterministic IVAP rows, 100 randomized IVAP
cases, five deterministic and 100 randomized cross cases, stability checks,
validation, alignment, consumers and printing. No package implementation or
test assertions changed in this ticket, and no tolerance was relaxed.

The first R 4.1.3 run caught decimal parsing of the immediate predecessor of
0.5 as exactly 0.5. The `near_knots` probabilities now use hexadecimal float
serialization; every reference value was independently checked against its
previous decimal value and is unchanged. The optional generator, fixture
hashes and provenance document were updated together. The existing adjacent
value assertion catches regression. A focused installed-package R 4.1.3
cross-parity run measured maximum absolute errors of `2.220446e-16` for fold
endpoints and `1.221245e-15` for combined probabilities, below `1e-10`.

R 4.1 does not install a top-level README, so the gate extracts it from the
checked source artifact. The canonical script checks 300 test rows, the exact
one-double-column schema, finite probabilities in `[0, 1]`, both scores and
plot consumption, with a temporary PDF closed and removed. No exact GLM
coefficients or scores, or improvement after calibration, are required.

Validated gate SHA-256:
`7b6e084491d8ae8f680c08808f84441d2669ff4b8107c9460592ba1ba8505f37`.
Validated canonical script SHA-256:
`8fbe4c6e61c7e1e18821ad310827d5862f3b0ed950c9b15c426fe15b8b2155ac`.

The existing `4.1.3` / `release` CI matrix and its disabled workflow are
unchanged. This is local dual-version acceptance, not a CI run, CRAN-mode or
PDF-manual check, CRAN submission guarantee, or published release.
