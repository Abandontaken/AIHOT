#!/usr/bin/env bash
# Runs the fork-parent query through gh's gojq. The comma inside an array binds
# tighter than "|", so an unparenthesized ".fork|tostring" makes ".parent" index
# the boolean ".fork".
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
workflow="$root/.github/workflows/sync-upstream.yml"
query='[(.fork|tostring), (.parent.full_name // "")] | @tsv'
broken='[.fork|tostring, (.parent.full_name // "")] | @tsv'

grep -F -q -- "$query" "$workflow"
if grep -F -q -- "$broken" "$workflow"; then
  echo "workflow still has the unparenthesized parent query" >&2
  exit 1
fi

command -v gh >/dev/null

run_jq() {
  gh api "repos/$1" --jq "$2"
}

fork_out=$(run_jq Abandontaken/AIHOT "$query")
if [ "$fork_out" != $'true\tKKKKhazix/AIHOT' ]; then
  printf 'fork query returned %q\n' "$fork_out" >&2
  exit 1
fi

upstream_out=$(run_jq KKKKhazix/AIHOT "$query")
if [ "$upstream_out" != $'false\t' ]; then
  printf 'upstream query returned %q\n' "$upstream_out" >&2
  exit 1
fi

err=$(mktemp)
if run_jq Abandontaken/AIHOT "$broken" >/dev/null 2>"$err"; then
  echo "unparenthesized query succeeded under this gh" >&2
  rm -f "$err"
  exit 1
fi
if ! grep -F -q 'expected an object but got: boolean (true)' "$err"; then
  echo "unparenthesized query failed for a different reason:" >&2
  cat "$err" >&2
  rm -f "$err"
  exit 1
fi
rm -f "$err"

echo "gh --jq parent query ok"
