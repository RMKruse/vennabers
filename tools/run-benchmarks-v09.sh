#!/bin/sh
# Serial local benchmark run, one fresh single-threaded process per case and library.
#   tools/run-benchmarks-v09.sh <candidate-lib> <previous-lib> <deps-lib> <temporary-out-dir> [shared|v09]
# Shared capabilities: tools/benchmark-shared-v09.R (the v0.8 cases with seeded
# outer folds, plus IVAP 100k). v0.9 postprocessing cases: tools/benchmark-v09.R.
# Both run on the previous release and the candidate; the fifth argument runs
# only one of them. BENCH_QUICK=1 sets BENCH_REPS=1 and skips the tuned cases.
# The process peak comes from /usr/bin/time (-l on macOS, -v GNU time on Linux).
# Exits with status 1 if a case failed. Run from the repository root.
set -eu
candidate=$1; previous=$2; deps=$3; out=$4; selected=${5:-}
case $selected in ""|shared|v09) ;; *) echo "Unknown part: $selected" >&2; exit 2 ;; esac
mkdir -p "$out"
export OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
quick=${BENCH_QUICK:-0}
[ "$quick" = 1 ] && export BENCH_REPS=1
time_flag=-v; [ "$(uname)" = Darwin ] && time_flag=-l
failed=0
run() { # label lib script args...
  label=$1; lib=$2; shift 2
  R_LIBS="$lib:$deps" /usr/bin/time $time_flag Rscript "$@" > "$out/$label.log" 2> "$out/$label.time" || {
    echo "FAILED $label"; failed=1; return 0; }
  echo "done $label"
}
both() { # part case script args... (each library gets its own RDS path)
  part=$1; case=$2; shift 2
  for artifact in previous candidate; do
    lib=$candidate; [ "$artifact" = previous ] && lib=$previous
    run "$part-$artifact-$case" "$lib" "$@" "$out/$part-$artifact-$case.rds"
  done
}
if [ "$selected" != v09 ]; then
  for case in ivap-fixed binary-fixed binary-grid binary-bayes pairwise-fixed pairwise-grid pairwise-bayes \
      ovo-fixed ovr-fixed regression-fixed regression-grid regression-bayes; do
    family=${case%-*}; search=${case#*-}
    [ "$quick" = 1 ] && [ "$search" != fixed ] && continue
    both shared "$case" tools/benchmark-shared-v09.R "$family" "$search"
  done
fi
if [ "$selected" != shared ]; then
  for family in binary pairwise ovo regression; do
    for strategy in holdout ensemble; do
      for mode in matched full; do
        both v09 "$family-$strategy-$mode" tools/benchmark-v09.R "$family" "$strategy" "$mode"
      done
    done
  done
  [ "$quick" = 1 ] || both v09 tuned-ensemble-full tools/benchmark-v09.R tuned ensemble full
fi
exit $failed
