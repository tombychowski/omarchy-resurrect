#!/bin/bash
set -euo pipefail

ROOT=${1:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
ALLOW="$ROOT/tests/static-entrypoints.txt"
MAP="$ROOT/tests/module-dependencies.tsv"
failures=0

fail() { printf 'structure: %s\n' "$*" >&2; failures=$((failures + 1)); }

mapfile -t modules < <(find "$ROOT/lib/ress" -type f -name '*.sh' -printf '%P\n' | sed 's#^#lib/ress/#' | sort)
for module in "${modules[@]}"; do
  grep -qF "$module"$'\t' "$MAP" || fail "module missing from dependency map: $module"
done

mapfile -t definitions < <(rg -No '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$ROOT/bin/ress" "$ROOT/lib/ress" |
  sed -E 's/.*:([a-zA-Z_][a-zA-Z0-9_]*)\(\)/\1/' | sort)
while IFS= read -r duplicate; do
  [[ -n $duplicate ]] && fail "duplicate function definition: $duplicate"
done < <(printf '%s\n' "${definitions[@]}" | uniq -d)

for function in "${definitions[@]}"; do
  grep -qxF "$function" "$ALLOW" 2>/dev/null && continue
  uses=$(rg -w -- "$function" "$ROOT/bin/ress" "$ROOT/lib/ress" | wc -l)
  (( uses > 1 )) || fail "unreachable function: $function"
done

rg -n '\b(restore_[a-zA-Z0-9_]*|RESTORE_STATE|VAULT)\b' "$ROOT/lib/ress/loadout" >/dev/null 2>&1 &&
  fail "loadout module has a reverse dependency on private vault restore state"
rg -n '\b(registry_[a-zA-Z0-9_]*|loadout_[a-zA-Z0-9_]*|profile_[a-zA-Z0-9_]*|REGISTRY|VAULT)\b' \
  "$ROOT/lib/ress/machine" >/dev/null 2>&1 &&
  fail "machine module has a reverse dependency on vault/loadout ownership"
rg -n '\b(APPLY_WORK|PROFILE_WORK|DRYRUN_VAULT)\b' "$ROOT/lib/ress/core.sh" >/dev/null 2>&1 &&
  fail "core cleanup names a domain-specific workspace"

(( failures == 0 )) || exit 1
printf 'structure: %d modules and %d function definitions checked\n' "${#modules[@]}" "${#definitions[@]}"
