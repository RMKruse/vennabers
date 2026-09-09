#!/bin/sh
cd /Users/entropy/Git/venn-abers || exit 1
export ACCEPTANCE_ARTIFACT="$PWD/.scratch/v06/final-candidate/vennabers_0.6.0.tar.gz"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 BLIS_NUM_THREADS=1
for profile in current minimum core; do
  export ACCEPTANCE_PROFILE="$profile" ACCEPTANCE_OUTPUT_DIR="$PWD/.scratch/v06/final-$profile"
  if [ "$profile" = current ]; then
    runtime="$PWD/.scratch/v06/r-current"
  elif [ "$profile" = minimum ]; then
    export R_LIBS="$PWD/.scratch/v06/minimum-library:/tmp/venn-tidymodels-lib"
    runtime=/opt/homebrew/Cellar/r/4.6.1/bin/Rscript
  else
    export R_LIBS="$PWD/.scratch/v06/empty" R_LIBS_USER="$PWD/.scratch/v06/empty" R_LIBS_SITE="$PWD/.scratch/v06/empty"
    runtime=/opt/homebrew/Cellar/r/4.6.1/bin/Rscript
  fi
  /usr/bin/sandbox-exec -f .scratch/v06/offline.sb "$runtime" --vanilla tools/acceptance.R > ".scratch/v06/final-$profile.log" 2>&1
  status=$?
  printf '%s %s\n' "$profile" "$status" >> .scratch/v06/final-status.txt
  [ "$status" = 0 ] || exit "$status"
done
