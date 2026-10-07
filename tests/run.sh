#!/bin/bash
#
# mntg test runner.
#
#   tests/run.sh              run every case
#   tests/run.sh restore      run cases whose name matches "restore"
#   tests/run.sh -v           keep going but print each case's output on failure
#   tests/run.sh --jobs 4     run isolated cases concurrently; report in order
#
# Every case runs in its own sandbox: a throwaway $HOME, a fake package
# database, and a PATH where tests/bin shadows pacman, yay, sudo, systemctl and
# the omarchy CLI. Nothing outside the sandbox is read or written.

set -uo pipefail

TESTS_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(dirname "$TESTS_DIR")

filter=""
verbose=0
jobs=1
while (( $# > 0 )); do
  case "$1" in
    -v|--verbose) verbose=1 ;;
    --jobs)
      jobs="${2:-}"; shift
      ;;
    --jobs=*) jobs="${1#*=}" ;;
    *) filter="$1" ;;
  esac
  shift
done
[[ $jobs =~ ^[1-9][0-9]*$ ]] || {
  printf 'tests/run.sh: --jobs requires a positive integer\n' >&2
  exit 2
}

# Syntax first: a parse error makes every case fail in the same confusing way.
# Keep this inventory filesystem-based so newly extracted modules are checked
# before they have been committed.
production_files=("$REPO_DIR/bin/mntg")
if [[ -d $REPO_DIR/lib/montage ]]; then
  while IFS= read -r file; do production_files+=("$file"); done < <(
    find "$REPO_DIR/lib/montage" -type f -name '*.sh' -print | sort
  )
fi
for file in "${production_files[@]}"; do
  if ! bash -n "$file"; then
    printf '\e[31m%s does not parse.\e[0m\n' "${file#"$REPO_DIR/"}" >&2
    exit 1
  fi
done

case_files=()
for case_file in "$TESTS_DIR"/cases/*.sh; do
  [[ -f $case_file ]] || continue
  name=$(basename "$case_file" .sh)
  [[ -n $filter && $name != *"$filter"* ]] && continue
  case_files+=("$case_file")
done

results_dir=$(mktemp -d "${TMPDIR:-/tmp}/mntg-results.XXXXXX")
trap 'rm -rf "$results_dir"' EXIT

run_case() {
  local case_file="$1" result_file="$2" case_started case_ended case_ms
  case_started=$(date +%s%N)
  bash -c '
    source "$1/lib/harness.sh"
    harness_setup
    trap harness_teardown EXIT
    source "$2"
    printf "\nTALLY %s %s\n" "$CASE_FAILURES" "$CASE_ASSERTIONS"
  ' _ "$TESTS_DIR" "$case_file" >"$result_file" 2>&1
  case_ended=$(date +%s%N)
  case_ms=$(( (case_ended - case_started) / 1000000 ))
  printf 'DURATION %s\n' "$case_ms" >>"$result_file"
}

# Launch bounded batches. Each case owns a throwaway HOME and fake-machine
# state, so concurrency changes only elapsed feedback time. Results are parsed
# afterward in filesystem order to keep output deterministic.
started=$SECONDS
for (( offset=0; offset<${#case_files[@]}; offset+=jobs )); do
  pids=()
  for (( slot=0; slot<jobs && offset+slot<${#case_files[@]}; slot++ )); do
    run_case "${case_files[offset+slot]}" "$results_dir/$((offset + slot)).out" &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do wait "$pid" || true; done
done

total=0; failed=0; assertions=0

for (( index=0; index<${#case_files[@]}; index++ )); do
  case_file="${case_files[index]}"
  name=$(basename "$case_file" .sh)
  total=$((total + 1))

  result=$(<"$results_dir/$index.out")
  # The tally is matched anywhere on the line: a case's last line of output may
  # not end in a newline, and losing the tally reads as "the case died".
  tally=$(printf '%s\n' "$result" | grep -o 'TALLY [0-9]\+ [0-9]\+' | tail -1)
  duration_ms=$(printf '%s\n' "$result" | sed -n 's/^DURATION \([0-9][0-9]*\)$/\1/p' | tail -1)
  duration_ms=${duration_ms:-0}
  body=$(printf '%s\n' "$result" |
    sed -e 's/TALLY [0-9]\+ [0-9]\+$//' -e '/^DURATION [0-9][0-9]*$/d')
  case_failures=$(awk '{print $2}' <<<"$tally"); case_failures=${case_failures:-1}
  case_assertions=$(awk '{print $3}' <<<"$tally"); case_assertions=${case_assertions:-0}
  assertions=$((assertions + case_assertions))

  if [[ -z $tally ]]; then
    printf '\e[31m  ✗\e[0m %-38s case died (%d.%03ds)\n' "$name" "$((duration_ms / 1000))" "$((duration_ms % 1000))"
    printf '%s\n' "$body" | sed 's/^/      /'
    failed=$((failed + 1))
  elif (( case_failures > 0 )); then
    printf '\e[31m  ✗\e[0m %-38s %d/%d assertions failed (%d.%03ds)\n' \
      "$name" "$case_failures" "$case_assertions" "$((duration_ms / 1000))" "$((duration_ms % 1000))"
    printf '%s\n' "$body"
    failed=$((failed + 1))
  else
    printf '\e[32m  ✓\e[0m %-38s %d assertions (%d.%03ds)\n' \
      "$name" "$case_assertions" "$((duration_ms / 1000))" "$((duration_ms % 1000))"
    (( verbose )) && [[ -n $body ]] && printf '%s\n' "$body" | sed 's/^/      /'
  fi
done

printf '\n'
if (( failed > 0 )); then
  printf '\e[31m%d of %d cases failed\e[0m (%d assertions, %ds)\n' "$failed" "$total" "$assertions" "$((SECONDS - started))"
  exit 1
fi
printf '\e[32m%d cases passed\e[0m (%d assertions, %ds)\n' "$total" "$assertions" "$((SECONDS - started))"
