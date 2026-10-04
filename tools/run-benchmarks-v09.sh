#!/bin/sh
# Serial local Mac benchmark run, one fresh single-threaded process per case.
#   tools/run-benchmarks-v09.sh <candidate-lib> <v08-lib> <deps-lib> <temporary-out-dir>
# Shared capabilities: tools/benchmark-shared-v09.R (the v0.8 cases with seeded
# outer folds, plus IVAP 100k) on the v0.8 baseline and the candidate. New v0.9 postprocessing cases: tools/benchmark-v09.R on
# the candidate only (baselines). Run from the repository root.
set -eu
candidate=$1; v08=$2; deps=$3; out=$4
mkdir -p "$out"
export OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
run() { # label lib script args...
  label=$1; lib=$2; shift 2
  R_LIBS="$lib:$deps" /usr/bin/time -l Rscript "$@" > "$out/$label.log" 2> "$out/$label.time" || {
    echo "FAILED $label"; return 0; }
  echo "done $label"
}
for case in ivap-fixed binary-fixed binary-grid binary-bayes pairwise-fixed pairwise-grid pairwise-bayes \
    ovo-fixed ovr-fixed regression-fixed regression-grid regression-bayes; do
  family=${case%-*}; search=${case#*-}
  for artifact in v08 candidate; do
    lib=$candidate; [ "$artifact" = v08 ] && lib=$v08
    run "shared-$artifact-$case" "$lib" tools/benchmark-shared-v09.R "$family" "$search" \
      "$out/shared-$artifact-$case.rds"
  done
done
for family in binary pairwise ovo regression; do
  for strategy in holdout ensemble; do
    for mode in matched full; do
      run "v09-$family-$strategy-$mode" "$candidate" tools/benchmark-v09.R "$family" "$strategy" "$mode" \
        "$out/v09-$family-$strategy-$mode.rds"
    done
  done
done
run "v09-tuned-ensemble-full" "$candidate" tools/benchmark-v09.R tuned ensemble full "$out/v09-tuned-ensemble-full.rds"
