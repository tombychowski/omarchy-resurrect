#!/bin/bash
set -euo pipefail

ROOT=${1:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
ALLOW="$ROOT/tests/static-entrypoints.txt"
MAP="$ROOT/tests/module-dependencies.tsv"
failures=0

fail() { printf 'structure: %s\n' "$*" >&2; failures=$((failures + 1)); }

mapfile -t modules < <(find "$ROOT/lib/montage" -type f -name '*.sh' -printf '%P\n' | sed 's#^#lib/montage/#' | sort)
for module in "${modules[@]}"; do
  grep -qF "$module"$'\t' "$MAP" || fail "module missing from dependency map: $module"
done

mapfile -t definitions < <(rg -No '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$ROOT/bin/mntg" "$ROOT/lib/montage" |
  sed -E 's/.*:([a-zA-Z_][a-zA-Z0-9_]*)\(\)/\1/' | sort)
while IFS= read -r duplicate; do
  [[ -n $duplicate ]] && fail "duplicate function definition: $duplicate"
done < <(printf '%s\n' "${definitions[@]}" | uniq -d)

for function in "${definitions[@]}"; do
  grep -qxF "$function" "$ALLOW" 2>/dev/null && continue
  uses=$(rg -w -- "$function" "$ROOT/bin/mntg" "$ROOT/lib/montage" | wc -l)
  (( uses > 1 )) || fail "unreachable function: $function"
done

rg -n '\b(restore_[a-zA-Z0-9_]*|RESTORE_STATE|VAULT)\b' "$ROOT/lib/montage/loadout" >/dev/null 2>&1 &&
  fail "loadout module has a reverse dependency on private vault restore state"
rg -n '\b(registry_[a-zA-Z0-9_]*|loadout_[a-zA-Z0-9_]*|profile_[a-zA-Z0-9_]*|REGISTRY|VAULT)\b' \
  "$ROOT/lib/montage/machine" >/dev/null 2>&1 &&
  fail "machine module has a reverse dependency on vault/loadout ownership"
rg -n '\b(APPLY_WORK|PROFILE_WORK|DRYRUN_VAULT)\b' "$ROOT/lib/montage/core.sh" >/dev/null 2>&1 &&
  fail "core cleanup names a domain-specific workspace"
rg -n '\b(port_adapter_|port_export_|port_import_vault|port_history_|translate_vault|translate_backup)\b' \
  "$ROOT/bin/mntg" "$ROOT/lib/montage" >/dev/null 2>&1 &&
  fail "retired generic, export, vault, or history port behavior remains reachable"
rg -n '\bress_migration_[a-zA-Z0-9_]*\b' \
  "$ROOT/lib/montage/repository" "$ROOT/lib/montage/machine" \
  "$ROOT/lib/montage/vault" "$ROOT/lib/montage/loadout" >/dev/null 2>&1 &&
  fail "native domain module depends on the focused Ress migration boundary"
rg -ni '\b(vault|backup|restore|secret|scheduler|retention|freshness)\b' \
  "$ROOT/lib/montage/commands.sh" >/dev/null 2>&1 &&
  fail "loadout-only application commands depend on retired vault concepts"

(( failures == 0 )) || exit 1
printf 'structure: %d modules and %d function definitions checked\n' "${#modules[@]}" "${#definitions[@]}"
