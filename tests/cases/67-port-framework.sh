# Ress is one focused migration boundary, not a generic adapter framework.

fixture="$REPO_DIR/tests/fixtures/ress-v1/loadout"

assert_file "$REPO_DIR/lib/montage/port/ress.sh" \
  "focused Ress validation and migration has one implementation owner"
assert_file "$REPO_DIR/lib/montage/port/commands.sh" \
  "focused Ress public parsing has one command owner"
for removed in common.sh adapter.sh inspect.sh import.sh export.sh \
  adapters/ress_v1/format.sh adapters/ress_v1/translate.sh; do
  assert_no_file "$REPO_DIR/lib/montage/port/$removed" \
    "retired port framework file is absent: $removed"
done

assert_file_contains "$REPO_DIR/bin/mntg" "lib/montage/port/ress.sh" \
  "entrypoint sources the focused Ress migration owner"
for retired in port/common.sh port/adapter.sh port/inspect.sh port/import.sh \
  port/export.sh port/adapters/ress_v1; do
  assert_file_lacks "$REPO_DIR/bin/mntg" "$retired" \
    "entrypoint no longer sources $retired"
done

if rg -n '\b(port_adapter_|port_export_|port_import_vault|port_history_|translate_vault|translate_backup)\b' \
    "$REPO_DIR/bin/mntg" "$REPO_DIR/lib/montage" >/dev/null; then
  _fail "retired generic, export, vault, or history port symbol remains reachable"
else
  _pass
fi
if rg -n '\b(vault|backup|history|export)\b' "$REPO_DIR/lib/montage/port" >/dev/null; then
  _fail "focused Ress source retains a retired artifact or direction"
else
  _pass
fi

: >"$CALLS"
for invocation in \
  "port ress plan $fixture --destination $SANDBOX/plan" \
  "port ress export loadout $fixture --destination $SANDBOX/export" \
  "port ress import vault $fixture --destination $SANDBOX/vault" \
  "port ress import loadout $fixture --repository missing --loadout item --history"; do
  read -r -a args <<<"$invocation"
  mntg "${args[@]}"
  assert_fails "retired invocation is unknown or unsupported: $invocation"
done
assert_not_called "git clone" "retired invocations perform no fetch"
assert_no_file "$SANDBOX/plan" "retired plan creates no destination"
assert_no_file "$SANDBOX/export" "retired export creates no destination"
assert_no_file "$SANDBOX/vault" "retired vault import creates no destination"

mntg port ress inspect "$fixture" --json
assert_ok "retained focused inspection remains reachable"
assert_equals "$(jq -r '.kind' <<<"$OUT")" "montage-ress-loadout-migration" \
  "retained inspection uses the focused result kind"
