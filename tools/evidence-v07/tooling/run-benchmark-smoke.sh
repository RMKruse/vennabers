#!/bin/sh
set -e
cd /Users/entropy/Git/venn-abers
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 BLIS_NUM_THREADS=1
export R_LIBS="$PWD/.scratch/frozen-library:$PWD/.scratch/issue-35/current-dependencies:/tmp/venn-tidymodels-lib:/opt/homebrew/lib/R/4.6/site-library"
/opt/homebrew/Cellar/r/4.6.1/bin/Rscript --vanilla tools/performance.R \
  .scratch/v07/final2-candidate/vennabers_0.7.0.tar.gz \
  tools/evidence-v06/candidate/vennabers_0.6.0.tar.gz \
  .scratch/v07/benchmark --smoke
