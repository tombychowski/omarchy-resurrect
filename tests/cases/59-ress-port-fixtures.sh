# The public Ress boundary accepts one frozen v1 portable profile and rejects
# every broader artifact family or unsupported command before mutation.

FIXTURES="$REPO_DIR/tests/fixtures/ress-v1"
source_before=$(sha256sum "$FIXTURES/loadout/profile.json")

mntg port ress inspect "$FIXTURES/loadout" --json
assert_ok "frozen Ress v1 loadout is recognized"
jq -se 'length==1 and .[0].schemaVersion==1 and
  .[0].kind=="montage-ress-loadout-migration" and
  .[0].operation=="inspect" and .[0].format=="ress-v1" and
  .[0].sourceSchemaVersion==1 and .[0].supportedSourceSchemaVersion==1 and
  .[0].compatible and .[0].publication.published==false' <<<"$OUT" >/dev/null && _pass ||
  _fail "inspection emits one focused versioned result" "$OUT"
assert_equals "$(sha256sum "$FIXTURES/loadout/profile.json")" "$source_before" \
  "inspection leaves the source profile byte-identical"

mntg port ress inspect "$FIXTURES/loadout"
assert_ok "supported inspection has readable human output"
assert_output "Ress v1 loadout migration" "human output identifies the bounded operation"
assert_output "compatible: true" "human output reports compatibility"

mntg port ress-v1 inspect "$FIXTURES/loadout" --json
assert_fails "the retired generic format alias is unsupported"
assert_output "unsupported port format: ress-v1" \
  "unsupported format refusal identifies the requested id"
mntg port imaginary-v9 inspect "$FIXTURES/loadout" --json
assert_fails "an arbitrary format id is unsupported"
assert_output "unsupported port format: imaginary-v9"

for outside in vault-control legacy-control; do
  outside_path="$SANDBOX/$outside"
  mkdir -p "$outside_path"
  if [[ $outside == vault-control ]]; then
    printf '{"schemaVersion":1,"ressVersion":"1.2.0"}\n' >"$outside_path/ress.json"
  else
    printf '{"schemaVersion":1,"ressVersion":"1.0.0"}\n' >"$outside_path/resurrect.json"
  fi
  : >"$CALLS"
  mntg port ress inspect "$outside_path" --json
  assert_fails "Ress $outside is outside the loadout-only boundary"
  jq -e '.kind=="montage-ress-loadout-migration" and
    .compatible==false and .reason=="outside-loadout-boundary" and
    .destination==null and .publication=={planned:false,published:false,commit:null}' \
    <<<"$OUT" >/dev/null && _pass ||
    _fail "Ress $outside refusal is structured and proposes no publication" "$OUT"
  assert_not_called "git clone" "Ress $outside refusal performs no fetch"
done

history="$SANDBOX/history-control"
mkdir -p "$history"
printf '{"schemaVersion":1,"ressVersion":"1.2.0","createdAt":"2026-01-01T00:00:00Z"}\n' \
  >"$history/ress.json"
mntg port ress inspect "$history" --json
assert_fails "Ress backup/history control is outside the migration boundary"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "outside-loadout-boundary" \
  "history refusal names the loadout-only boundary"

future="$SANDBOX/future-loadout"
cp -a "$FIXTURES/loadout/." "$future/"
jq '.schemaVersion=2' "$future/profile.json" >"$future/next"
mv "$future/next" "$future/profile.json"
mntg port ress inspect "$future" --json
assert_fails "future Ress profile version is refused"
jq -e '.sourceSchemaVersion==2 and .supportedSourceSchemaVersion==1 and
  .reason=="unsupported-version" and .publication.published==false' \
  <<<"$OUT" >/dev/null && _pass ||
  _fail "future-version refusal reports both version boundaries" "$OUT"

: >"$CALLS"
mntg --yes port ress import loadout "$FIXTURES/loadout" --repository nowhere --json
assert_fails "missing stable loadout selection is refused by command parsing"
assert_output "usage: mntg port ress import loadout" \
  "incomplete destination selection reports focused syntax"
mntg --yes port ress import loadout "$FIXTURES/loadout" --loadout item --json
assert_fails "missing repository selection is refused by command parsing"
assert_not_called "git clone" "incomplete destination performs no source fetch"
assert_no_file "$XDG_STATE_HOME/montage/loadouts.json" \
  "inspection and refused migration create no applied-loadout state"

assert_file_contains "$FIXTURES/README.md" "Ress 1.2.0" \
  "the frozen compatibility baseline remains documented beside its fixtures"
