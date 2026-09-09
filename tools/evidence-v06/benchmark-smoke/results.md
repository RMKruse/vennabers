# Local benchmark smoke results

**macOS ARM smoke only; controlled Linux performance clearance remains open.**

48 cases, 72 case/release medians, 288 raw rows: 72 warmups and 216 measurements.

All 72 independent fresh-process restorations passed; 16 encoded cases also
checked decoded predictions and training schemas. Full input data/plans, raw
measurements, per-process logs, medians and comparisons are retained here.
Zero conversion/outer values in inapplicable cases mean not applicable;
applicable tiny operations may round to zero at timer resolution.

## New capability baselines

Seconds. Per-process peak RSS and gzip/version-3 model RDS bytes are in
[medians.csv](medians.csv), with raw values in [runs.csv](runs.csv).

| Case | Fit/calibrate | Predict | Outer | Schema | Encode | Decode |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| workflow_binary_encoded_cross | 0.089 | 0.009 | 0.328 | 0.000 | 0.000 | 0.000 |
| workflow_binary_encoded_inductive | 0.044 | 0.003 | 0.158 | 0.000 | 0.000 | 0.000 |
| workflow_binary_encoded_ordered | 0.042 | 0.003 | 0.158 | 0.000 | 0.000 | 0.000 |
| workflow_binary_frozen | 0.018 | 0.005 | 0.000 | 0.000 | 0.000 | 0.000 |
| workflow_binary_frozen_encoded | 0.019 | 0.005 | 0.000 | 0.000 | 0.001 | 0.000 |
| workflow_binary_ordered | 0.040 | 0.003 | 0.162 | 0.000 | 0.000 | 0.000 |
| workflow_ovo_encoded_cross | 0.157 | 0.012 | 0.467 | 0.000 | 0.000 | 0.000 |
| workflow_ovo_encoded_inductive | 0.054 | 0.004 | 0.178 | 0.000 | 0.000 | 0.000 |
| workflow_ovo_encoded_ordered | 0.053 | 0.004 | 0.180 | 0.000 | 0.001 | 0.000 |
| workflow_ovo_frozen | 0.027 | 0.005 | 0.000 | 0.000 | 0.000 | 0.000 |
| workflow_ovo_frozen_encoded | 0.028 | 0.005 | 0.000 | 0.000 | 0.000 | 0.000 |
| workflow_ovo_ordered | 0.054 | 0.003 | 0.192 | 0.000 | 0.000 | 0.000 |
| workflow_ovr_encoded_cross | 0.158 | 0.011 | 0.481 | 0.000 | 0.000 | 0.000 |
| workflow_ovr_encoded_inductive | 0.054 | 0.004 | 0.185 | 0.000 | 0.000 | 0.000 |
| workflow_ovr_encoded_ordered | 0.054 | 0.004 | 0.183 | 0.000 | 0.000 | 0.000 |
| workflow_ovr_frozen | 0.035 | 0.005 | 0.000 | 0.000 | 0.000 | 0.000 |
| workflow_ovr_frozen_encoded | 0.036 | 0.005 | 0.000 | 0.000 | 0.000 | 0.000 |
| workflow_ovr_ordered | 0.054 | 0.003 | 0.193 | 0.000 | 0.000 | 0.000 |
| workflow_regression_encoded_cross | 0.084 | 0.029 | 0.386 | 0.000 | 0.000 | 0.000 |
| workflow_regression_encoded_inductive | 0.037 | 0.003 | 0.146 | 0.000 | 0.000 | 0.000 |
| workflow_regression_encoded_ordered | 0.038 | 0.003 | 0.154 | 0.000 | 0.000 | 0.000 |
| workflow_regression_frozen | 0.023 | 0.005 | 0.000 | 0.000 | 0.000 | 0.000 |
| workflow_regression_frozen_encoded | 0.020 | 0.004 | 0.000 | 0.000 | 0.000 | 0.000 |
| workflow_regression_ordered | 0.037 | 0.002 | 0.143 | 0.000 | 0.000 | 0.000 |

## Cumulative comparison observations

Ratios are current/v0.5, using the exact same newly saved input per pair.
These local smoke observations do not establish controlled Linux behavior.
Every ratio above 1 and positive memory/size difference remains visible for
investigation before release; no performance waiver or speed claim is made.
A missing ratio means the denominator is zero or the metric is inapplicable.

| Case | Fit ratio | Predict ratio | Outer ratio | RDS change, bytes | Peak RSS change, MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| 10_cross_ovo | 1.000 | 0.976 | — | +0 | +18.281 |
| 10_cross_ovr | 1.005 | 1.000 | — | +0 | -0.203 |
| 10_inductive_ovo | 0.984 | 1.000 | — | +0 | -0.109 |
| 10_inductive_ovr | 1.017 | 1.000 | — | +0 | +0.562 |
| 3_cross_ovo | 1.000 | 1.000 | — | +0 | +1.078 |
| 3_cross_ovo_brier_p2 | 1.000 | 1.000 | — | +0 | +0.312 |
| 3_cross_ovr | 0.992 | 1.000 | — | +0 | -0.484 |
| 3_inductive_ovo | 0.988 | 1.000 | — | +0 | +0.953 |
| 3_inductive_ovr | 1.000 | — | — | +0 | +0.062 |
| binary_cross | 1.000 | 1.000 | — | +0 | -0.062 |
| binary_cross_brier_p2 | 1.000 | 1.000 | — | +0 | +0.062 |
| binary_inductive | 1.007 | 1.000 | — | +0 | +0.000 |
| regression_cross_epsilon01 | 0.980 | 1.047 | — | +0 | +0.422 |
| regression_cross_m1 | 0.981 | 0.978 | — | +0 | +0.109 |
| regression_inductive_epsilon01 | 0.979 | — | — | +0 | -0.141 |
| regression_inductive_m1 | 1.000 | — | — | +0 | +0.219 |
| workflow_binary_cross | 1.023 | 1.000 | 0.971 | +149 | +0.516 |
| workflow_binary_inductive | 1.000 | 1.000 | 0.974 | +166 | -0.141 |
| workflow_ovo_cross | 1.000 | 0.923 | 0.989 | +179 | -1.000 |
| workflow_ovo_inductive | 1.019 | 0.750 | 1.072 | +169 | -0.109 |
| workflow_ovr_cross | 0.981 | 1.000 | 1.002 | +168 | -0.938 |
| workflow_ovr_inductive | 1.000 | 0.750 | 0.963 | +176 | -1.828 |
| workflow_regression_cross | 1.063 | 1.100 | 1.050 | +204 | +1.000 |
| workflow_regression_inductive | 1.026 | 1.000 | 1.060 | +156 | +0.703 |

These workloads retain the historical generator and RNG draw order. The
saved data, plan memberships, options and model/recipe configuration match the
prior macOS workload after excluding rsample fingerprint metadata. Some
multiclass input values differ in low-order bits from the historical Linux
bundle, and its machine/runtime differs, so its old timings are not used as
the denominator. Both artifacts were remeasured locally on the same inputs.

Generated model/prediction/outer/decoded RDS files remain in
`/Users/entropy/Git/venn-abers/.scratch/v06/final-benchmark/`.
[generated-rds.csv](generated-rds.csv) records their SHA-256 hashes and bytes;
saved inputs plus the pinned artifacts and generator reproduce them.
