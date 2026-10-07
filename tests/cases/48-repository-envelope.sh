# Native repository envelopes are strict data: type, version, exact fields,
# and bounded ids are validated before a path or Git ref can be derived.

source "$REPO_DIR/lib/montage/repository/common.sh"
OUT=""

write_loadouts() {
  repository_envelope_json loadouts "$1" "2026-10-06T20:00:00Z" >"$2"
}

write_vault() {
  repository_envelope_json vault "$1" "2026-10-06T20:00:00Z" "$2" >"$3"
}

loadouts="$SANDBOX/loadouts.json"
vault="$SANDBOX/vault.json"
write_loadouts personal-loadouts-7d8f "$loadouts"
write_vault vault-4a63d1 omarchy-laptop-12af "$vault"

repository_envelope_validate_file "$loadouts" loadouts; STATUS=$?
assert_ok "a canonical loadout repository envelope is valid"
repository_envelope_validate_file "$vault" vault; STATUS=$?
assert_ok "a canonical vault repository envelope is valid"
repository_envelope_validate_file "$loadouts" vault; STATUS=$?
assert_fails "a valid envelope of the wrong repository kind is refused"

future="$SANDBOX/future.json"
jq '.schemaVersion = 2' "$loadouts" >"$future"
repository_envelope_validate_file "$future" loadouts; STATUS=$?
assert_fails "an unsupported future schema is refused"

hostile="$SANDBOX/hostile.json"
marker="$SANDBOX/schema-was-evaluated"
jq --arg schema '1 + system("touch '$marker'")' '.schemaVersion = $schema' \
  "$loadouts" >"$hostile"
repository_envelope_validate_file "$hostile" loadouts; STATUS=$?
assert_fails "a schema expression is refused as data"
assert_no_file "$marker" "a schema expression is never evaluated"

for bad in '../escape' 'has/slash' 'Uppercase' '-leading' 'trailing-' \
    'space value' ''; do
  jq --arg id "$bad" '.id = $id' "$loadouts" >"$hostile"
  repository_envelope_validate_file "$hostile" loadouts; STATUS=$?
  assert_fails "hostile repository id is refused: ${bad:-<empty>}"
done

too_long=$(printf 'a%.0s' {1..65})
jq --arg id "$too_long" '.id = $id' "$loadouts" >"$hostile"
repository_envelope_validate_file "$hostile" loadouts; STATUS=$?
assert_fails "a repository id longer than 64 characters is refused"

jq '.unexpected = true' "$loadouts" >"$hostile"
repository_envelope_validate_file "$hostile" loadouts; STATUS=$?
assert_fails "unknown envelope fields are refused"

jq 'del(.machineId)' "$vault" >"$hostile"
repository_envelope_validate_file "$hostile" vault; STATUS=$?
assert_fails "a vault without its machine lineage id is refused"

ln -s "$loadouts" "$SANDBOX/montage.json"
repository_envelope_validate_file "$SANDBOX/montage.json" loadouts; STATUS=$?
assert_fails "a symlinked repository envelope is refused"
