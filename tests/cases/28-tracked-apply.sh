source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha missing-package
machine_install native alpha
P="$SANDBOX/tracked"; write_package_loadout "$P" Tracked alpha

ress apply --dry-run "$P"
assert_ok "tracked apply dry run succeeds"
assert_output "PROTECT  package:alpha"
assert_no_file "$(registry_path)" "dry run records no desired state"

ress apply --yes "$P"
assert_ok "confirmed all-present loadout is tracked without reinstall"
assert_not_called "pacman -S" "pre-existing package is not reinstalled"
assert_equals "$(jq -r '.loadouts[0].state' "$(registry_path)")" "healthy" "no-op apply is healthy"
assert_equals "$(jq -r '.resources[0].cleanupPolicy' "$(registry_path)")" "retain" "pre-existing resource is protected"
ID=$(first_loadout_id)
ress loadout check "$ID" --json
assert_ok "protected resource is healthy under live checking"
assert_output '"healthState": "protected"'

ress apply --dry-run --porcelain "$P"
assert_ok "apply dry-run porcelain succeeds"
if grep -qEv '^(STEP|LOG|DONE)\|' <<<"$OUT"; then _fail "apply porcelain contains only protocol records" "$OUT"; else _pass; fi
ress loadout remove --dry-run --porcelain "$ID"
assert_ok "remove dry-run porcelain succeeds"
if grep -qEv '^(STEP|LOG|DONE)\|' <<<"$OUT"; then _fail "remove porcelain contains only protocol records" "$OUT"; else _pass; fi

P2="$SANDBOX/partial"; write_package_loadout "$P2" Partial missing-package
: >"$FAKE_STATE/repo-packages.txt"
ress apply --yes --porcelain "$P2"
assert_fails "failed install is a qualified outcome"
assert_output "DONE|partial|"
assert_no_output "DONE|ok|" "partial application never claims full success"
assert_equals "$(jq -r '.loadouts[]|select(.name=="Partial")|.state' "$(registry_path)")" "pending" \
  "partial loadout remains visible"
