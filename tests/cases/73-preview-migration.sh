source "$TESTS_DIR/lib/loadout.sh"
seed_machine
machine_publish repo alpha
library="$SANDBOX/preview-library"
mntg repository init "$library" --id preview-library
mntg repository configure preview "$library"
write_package_loadout "$library/loadouts/work" Preview alpha
git -C "$library" add -A
git -C "$library" commit -q -m profile
mntg apply --yes preview --loadout work
assert_ok "repository preview fixture applies"
id=$(first_loadout_id)
printf 'unrelated history\n' >"$library/README.md"
git -C "$library" add -A
git -C "$library" commit -q -m unrelated
before=$(sha256sum "$(registry_path)")
mntg loadout update "$id" --dry-run
assert_ok "unchanged-profile newer-commit preview succeeds"
assert_equals "$(sha256sum "$(registry_path)")" "$before" \
  "unchanged-content preview preserves authoritative provenance bytes"

# Preview must not reconcile an interrupted operation into persisted state.
jq --arg id "$id" '.operation={kind:"repair",target:$id,phase:"running",
 actions:[{resourceId:"package:alpha",state:"running"}]}' "$(registry_path)" >"$(registry_path).next"
mv "$(registry_path).next" "$(registry_path)"
before=$(sha256sum "$(registry_path)")
for action in update repair remove; do
  mntg loadout "$action" "$id" --dry-run
  assert_ok "$action preview with an interrupted operation succeeds"
  assert_equals "$(sha256sum "$(registry_path)")" "$before" \
    "$action preview does not persist recovery changes"
done
jq '.operation=null' "$(registry_path)" >"$(registry_path).next"
mv "$(registry_path).next" "$(registry_path)"

configured="$XDG_CONFIG_HOME/montage/repositories.json"
cp "$configured" "$SANDBOX/current-registry.json"
legacy() {
  rm -f "$configured.pre-schema2"
  jq '.schemaVersion=1 | .repositories += [{name:"retired",path:"/do-not-open",
    type:"vault",id:"retired",remote:""}]' "$SANDBOX/current-registry.json" >"$configured"
}
for consumer in catalog loadouts show rename ress; do
  legacy
  case "$consumer" in
    catalog) mntg share catalog --repository preview --loadout work --json ;;
    loadouts) mntg repository loadouts preview --json ;;
    show) mntg repository loadout show preview work --json ;;
    rename) mntg repository loadout rename preview work --name Preview --json ;;
    ress) mntg port ress import loadout "$REPO_DIR/tests/fixtures/ress-v1/loadout" \
      --repository preview --loadout imported --dry-run --json ;;
  esac
  assert_ok "$consumer first read succeeds"
  jq -se 'length==1 and .[0].migration.performed==true and
    .[0].migration.priorSchema==1 and .[0].migration.newSchema==2 and
    .[0].migration.retiredVaults==["retired"]' <<<"$OUT" >/dev/null && _pass ||
    _fail "$consumer exposes migration in its one JSON result" "$OUT"
done
for consumer in apply update share ress; do
  legacy
  case "$consumer" in
    apply) mntg apply preview --loadout work --dry-run --porcelain ;;
    update) mntg loadout update "$id" --dry-run --porcelain ;;
    share) mntg share --repository preview --loadout work --dry-run --porcelain ;;
    ress) mntg port ress import loadout "$REPO_DIR/tests/fixtures/ress-v1/loadout" \
      --repository preview --loadout imported --dry-run --porcelain ;;
  esac
  assert_ok "$consumer first read porcelain succeeds"
  assert_output 'MIGRATION|1|true|1|2|retired|' "$consumer reports performed migration"
  if grep -qEv '^(BEGIN|MIGRATION|RESS|RESS_LOSS|STEP|LOG|DONE)\|' <<<"$OUT"; then
    _fail "$consumer porcelain contains only records" "$OUT"
  else _pass; fi
done
mntg share catalog --repository preview --loadout work --json
assert_ok "post-migration catalog succeeds"
assert_equals "$(jq -r '.migration.performed' <<<"$OUT")" false "later reads report no new migration"
