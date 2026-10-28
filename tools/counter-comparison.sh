#!/bin/sh
# Counter-comparisons of vennabers with other Venn-Abers software
# (inst/PARITY.md, "Counter-comparisons"; tools/RELEASE.md). Not binding and
# outside the package build and tests. Run from the repository root:
#   tools/counter-comparison.sh <out> [<library> ...]
# The libraries are optional and are put before R's site library, for example
# one holding the package built from this checkout:
#   R CMD INSTALL -l <library> .
# Needs R, network access to PyPI and either uv or python3.12. Python runs only
# in a temporary virtual environment from tools/counter-comparison-requirements.txt,
# removed together with the large intermediate files (about 15 MB) on exit.
# <out> receives the summaries, the cause checks and the environments; the
# comparison with MAPIE's core patched to the main reference's upper tail
# (suffix -mapie-patched) diagnoses the cause of MAPIE's differences. fast-ivap
# (ptocca/VennABERS) writes its own files with the suffix -fast-ivap.
set -eu
if [ "$#" -lt 1 ]; then
  echo "Usage: tools/counter-comparison.sh <out> [<library> ...]" >&2
  exit 2
fi
tools=$(cd "$(dirname "$0")" && pwd)
out=$1
shift
mkdir -p "$out"
out=$(cd "$out" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/vennabers-counter-comparison.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM

if command -v uv >/dev/null 2>&1; then
  uv venv -q -p 3.12 "$work/venv"
  VIRTUAL_ENV="$work/venv" uv pip install -q -r "$tools/counter-comparison-requirements.txt"
  VIRTUAL_ENV="$work/venv" uv pip freeze > "$out/python-freeze.txt"
else
  python3.12 -m venv "$work/venv"
  "$work/venv/bin/python" -m pip install -q -r "$tools/counter-comparison-requirements.txt"
  "$work/venv/bin/python" -m pip freeze > "$out/python-freeze.txt"
fi

Rscript --vanilla "$tools/counter-comparison-inputs.R" "$work/data" "$@"
cp "$work/data/vennabers-environment.txt" "$out/"
"$work/venv/bin/python" -I "$tools/counter-comparison-mapie-ce.py" "$work/data" "$out"
"$work/venv/bin/python" -I "$tools/counter-comparison-mapie-ce.py" "$work/data" "$out" --mapie-patched
"$work/venv/bin/python" -I "$tools/counter-comparison-fast-ivap.py" "$work/data" "$out"
echo "Results in $out"
