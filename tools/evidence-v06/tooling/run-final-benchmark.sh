#!/bin/sh
cd /Users/entropy/Git/venn-abers || exit 1
.scratch/v06/r-current .scratch/v06/final-source/tools/performance.R \
  .scratch/v06/final-candidate/vennabers_0.6.0.tar.gz \
  tools/evidence-v05/ci-final/source-candidate/vennabers_0.5.0.tar.gz \
  .scratch/v06/final-benchmark --smoke > .scratch/v06/final-benchmark.log 2>&1 || exit $?
.scratch/v06/r-current tools/test-performance.R .scratch/v06/final-benchmark --v06 \
  > .scratch/v06/benchmark-verifier.log 2>&1 || exit $?
.scratch/v06/r-current tools/test-performance-verifier.R .scratch/v06/final-benchmark \
  > .scratch/v06/benchmark-mutations.log 2>&1
