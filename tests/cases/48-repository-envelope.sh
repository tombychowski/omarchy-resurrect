# Native loadout repository envelopes are strict data: fixed type, exact
# version and fields, and bounded ids are validated before paths or refs exist.

source "$REPO_DIR/lib/montage/repository/common.sh"
OUT=""

write_loadouts() {
  repository_envelope_json "$1" "2026-10-06T20:00:00Z" >"$2"
}

loadouts="$SANDBOX/loadouts.json"
write_loadouts personal-loadouts-7d8f "$loadouts"

repository_envelope_validate_file "$loadouts"; STATUS=$?
assert_ok "a canonical loadout repository envelope is valid"

future="$SANDBOX/future.json"
jq '.schemaVersion = 2' "$loadouts" >"$future"
repository_envelope_validate_file "$future"; STATUS=$?
assert_fails "an unsupported future schema is refused"

hostile="$SANDBOX/hostile.json"
marker="$SANDBOX/schema-was-evaluated"
jq --arg schema '1 + system("touch '$marker'")' '.schemaVersion = $schema' \
  "$loadouts" >"$hostile"
repository_envelope_validate_file "$hostile"; STATUS=$?
assert_fails "a schema expression is refused as data"
assert_no_file "$marker" "a schema expression is never evaluated"

for bad in '../escape' 'has/slash' 'Uppercase' '-leading' 'trailing-' \
    'space value' ''; do
  jq --arg id "$bad" '.id = $id' "$loadouts" >"$hostile"
  repository_envelope_validate_file "$hostile"; STATUS=$?
  assert_fails "hostile repository id is refused: ${bad:-<empty>}"
done

too_long=$(printf 'a%.0s' {1..65})
jq --arg id "$too_long" '.id = $id' "$loadouts" >"$hostile"
repository_envelope_validate_file "$hostile"; STATUS=$?
assert_fails "a repository id longer than 64 characters is refused"

jq '.unexpected = true' "$loadouts" >"$hostile"
repository_envelope_validate_file "$hostile"; STATUS=$?
assert_fails "unknown envelope fields are refused"

jq '.repositoryType = "vault" | .machineId = "machine-a1"' "$loadouts" >"$hostile"
repository_envelope_validate_file "$hostile"; STATUS=$?
assert_fails "a non-loadout repository type is refused"

vault_path="$SANDBOX/vault-repository"
mkdir -p "$vault_path/history"
cp "$hostile" "$vault_path/montage.json"
printf 'payload must remain opaque\n' >"$vault_path/backup.json"
payload_before=$(sha256sum "$vault_path/backup.json")
mntg repository validate "$vault_path" --json
assert_fails "normal repository validation rejects a vault envelope"
assert_equals "$(jq -r '.repository.status' <<<"$OUT")" "invalid-envelope" \
  "vault refusal occurs at the envelope boundary"
assert_equals "$(sha256sum "$vault_path/backup.json")" "$payload_before" \
  "vault payload is not changed during refusal"
assert_equals "$(<"$CALLS")" "" "vault refusal invokes no Git history inspection"

ln -s "$loadouts" "$SANDBOX/montage.json"
repository_envelope_validate_file "$SANDBOX/montage.json"; STATUS=$?
assert_fails "a symlinked repository envelope is refused"

# Re-checking the valid counterpart after every hostile mutation demonstrates
# that refusal is local to the input and does not poison later reads.
repository_envelope_validate_file "$loadouts"; STATUS=$?
assert_ok "canonical envelope remains valid after hostile fixtures"
