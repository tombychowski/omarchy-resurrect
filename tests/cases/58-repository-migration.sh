# Schema-1 configured repositories migrate once under lock. Valid loadout
# entries survive; vault configuration is retired without touching vault paths.

PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/montage/core.sh"
source "$REPO_DIR/lib/montage/safety.sh"
source "$REPO_DIR/lib/montage/repository/common.sh"
source "$REPO_DIR/lib/montage/repository/registry.sh"
OUT=""

make_loadout_repository() {
  local path="$1" id="$2"
  mkdir -p "$path"
  repository_envelope_json "$id" "2026-10-06T20:00:00Z" >"$path/montage.json"
}

select_registry_case() {
  local name="$1"
  CONFIG_DIR="$SANDBOX/config-$name"
  MONTAGE_REPOSITORY_REGISTRY="$CONFIG_DIR/repositories.json"
  MONTAGE_REPOSITORY_REGISTRY_BACKUP="$MONTAGE_REPOSITORY_REGISTRY.pre-schema2"
  REPOSITORY_REGISTRY=""
  REPOSITORY_REGISTRY_MIGRATION=null
  REPOSITORY_REGISTRY_ERROR_ENTRY=""
  REPOSITORY_CONFIG_LOCK_FD=""
  mkdir -p "$CONFIG_DIR"
}

legacy_registry() {
  local revision="$1" entries="$2"
  jq -nc --argjson revision "$revision" --argjson entries "$entries" \
    '{schemaVersion:1,revision:$revision,repositories:$entries}'
}

loadout_entry() {
  local name="$1" path="$2" id="$3" remote="${4:-}"
  jq -nc --arg name "$name" --arg path "$path" --arg id "$id" --arg remote "$remote" \
    '{name:$name,path:$path,type:"loadouts",id:$id,remote:$remote}'
}

vault_entry() {
  local name="$1" path="$2" id="$3"
  jq -nc --arg name "$name" --arg path "$path" --arg id "$id" \
    '{name:$name,path:$path,type:"vault",id:$id,remote:""}'
}

library_a="$SANDBOX/library-a"
library_b="$SANDBOX/library-b"
make_loadout_repository "$library_a" library-a1
make_loadout_repository "$library_b" library-b2

# Mixed input retains exact loadout configuration, deterministically retires
# vault names, increments once, and preserves an exact private rollback copy.
select_registry_case mixed
sentinel="$SANDBOX/do-not-open-vault"
mkdir -p "$sentinel"
printf 'user-owned bytes\n' >"$sentinel/payload"
sentinel_before=$(stat -c '%a|%Y|%s' "$sentinel/payload")
sentinel_digest=$(sha256sum "$sentinel/payload")
chmod 000 "$sentinel"
entry_b=$(loadout_entry zebra "$library_b" library-b2 ssh://example.invalid/zebra.git)
entry_v2=$(vault_entry retired-z "$sentinel" vault-z9)
entry_a=$(loadout_entry alpha "$library_a" library-a1 https://example.invalid/alpha.git)
entry_v1=$(vault_entry retired-a /path/that/does/not/exist vault-a1)
entries=$(jq -nc --argjson b "$entry_b" --argjson v2 "$entry_v2" \
  --argjson a "$entry_a" --argjson v1 "$entry_v1" '[$b,$v2,$a,$v1]')
legacy_registry 7 "$entries" >"$MONTAGE_REPOSITORY_REGISTRY"
legacy_digest=$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY" | cut -d' ' -f1)
repository_registry_load; STATUS=$?
assert_ok "a valid mixed schema-1 registry migrates"
assert_equals "$(jq -r '.schemaVersion' <<<"$REPOSITORY_REGISTRY")" "2" \
  "migration installs schema 2"
assert_equals "$(jq -r '.revision' <<<"$REPOSITORY_REGISTRY")" "8" \
  "migration increments the revision exactly once"
assert_equals "$(jq -r '[.repositories[].name] | join(",")' <<<"$REPOSITORY_REGISTRY")" \
  "alpha,zebra" "retained loadouts are deterministically ordered"
assert_equals "$(jq -Sc '.repositories[0]' <<<"$REPOSITORY_REGISTRY")" "$(jq -Sc . <<<"$entry_a")" \
  "retained loadout fields are exact"
assert_equals "$(jq -c '.retiredVaults' <<<"$REPOSITORY_REGISTRY_MIGRATION")" \
  '["retired-a","retired-z"]' "retired vault names are reported in order"
assert_equals "$(jq -r '.priorSchema,.newSchema' <<<"$REPOSITORY_REGISTRY_MIGRATION" | paste -sd /)" \
  "1/2" "the migration result identifies both schemas"
assert_file "$MONTAGE_REPOSITORY_REGISTRY_BACKUP" "a rollback copy is retained beside the registry"
assert_equals "$(stat -c '%a' "$MONTAGE_REPOSITORY_REGISTRY_BACKUP")" "600" \
  "the rollback copy is mode 0600"
assert_equals "$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY_BACKUP" | cut -d' ' -f1)" "$legacy_digest" \
  "the rollback copy contains the exact legacy bytes"
chmod 700 "$sentinel"
assert_equals "$(sha256sum "$sentinel/payload")" "$sentinel_digest" \
  "retiring a vault does not rewrite its contents"
assert_equals "$(stat -c '%a|%Y|%s' "$sentinel/payload")" "$sentinel_before" \
  "retiring a vault preserves observed content metadata"
assert_equals "$(<"$CALLS")" "" "migration invokes no repository or network command"

installed_digest=$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY")
rollback_digest=$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY_BACKUP")
REPOSITORY_REGISTRY=""; REPOSITORY_REGISTRY_MIGRATION=null
repository_registry_load; STATUS=$?
assert_ok "rerunning migration against schema 2 is a successful no-op"
assert_equals "$(jq -r '.performed' <<<"$REPOSITORY_REGISTRY_MIGRATION")" "false" \
  "the retry reports a no-op"
assert_equals "$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY")" "$installed_digest" \
  "the no-op does not rewrite the active document"
assert_equals "$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY_BACKUP")" "$rollback_digest" \
  "the no-op does not overwrite the rollback copy"

# Every supported legacy population migrates, including no vaults, no
# loadouts, and no entries.
for population in loadout-only vault-only empty; do
  select_registry_case "$population"
  case "$population" in
    loadout-only) entries=$(jq -nc --argjson item "$(loadout_entry only "$library_a" library-a1)" '[$item]') ;;
    vault-only) entries=$(jq -nc --argjson item "$(vault_entry retired /never/open vault-r1)" '[$item]') ;;
    empty) entries='[]' ;;
  esac
  legacy_registry 3 "$entries" >"$MONTAGE_REPOSITORY_REGISTRY"
  repository_registry_load; STATUS=$?
  assert_ok "$population schema-1 registry migrates"
  assert_equals "$(jq -r '.revision' <<<"$REPOSITORY_REGISTRY")" "4" \
    "$population migration increments once"
done

# Invalid retained entries block the whole migration, preserve schema 1, name
# the offender, and create no rollback artifact because validation was not
# complete.
assert_invalid_migration() {
  local case_name="$1" expected_name="$2" entries="$3"
  select_registry_case "$case_name"
  legacy_registry 5 "$entries" >"$MONTAGE_REPOSITORY_REGISTRY"
  before=$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY")
  OUT=$(repository_registry_load 2>&1); STATUS=$?
  assert_fails "$case_name migration is refused"
  [[ -z $expected_name ]] || assert_output "$expected_name" "$case_name names the offending entry"
  assert_equals "$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY")" "$before" \
    "$case_name leaves the active registry unchanged"
  assert_no_file "$MONTAGE_REPOSITORY_REGISTRY_BACKUP" \
    "$case_name does not publish a rollback artifact before validation"
}

missing=$(loadout_entry missing "$SANDBOX/missing-library" missing-a1)
assert_invalid_migration missing-path missing "[$missing]"

mismatch=$(loadout_entry mismatch "$library_a" wrong-a1)
assert_invalid_migration id-mismatch mismatch "[$mismatch]"

bad_envelope="$SANDBOX/bad-envelope"
mkdir -p "$bad_envelope"
printf '{"schemaVersion":1,"kind":"montage-repository","repositoryType":"vault","id":"bad-envelope","createdAt":"2026-10-06T20:00:00Z","machineId":"machine-a1"}\n' \
  >"$bad_envelope/montage.json"
envelope=$(loadout_entry bad-envelope "$bad_envelope" bad-envelope)
assert_invalid_migration envelope-mismatch bad-envelope "[$envelope]"

credential=$(loadout_entry credential "$library_a" library-a1 \
  https://user:secret@example.invalid/library.git)
assert_invalid_migration credential-bearing "" "[$credential]"

duplicate_a=$(loadout_entry duplicate "$library_a" library-a1)
duplicate_b=$(loadout_entry duplicate "$library_b" library-b2)
assert_invalid_migration duplicate-name "" "[$duplicate_a,$duplicate_b]"

select_registry_case malformed
printf '{"schemaVersion":1,"revision":0,"repositories":"not-an-array"}\n' \
  >"$MONTAGE_REPOSITORY_REGISTRY"
before=$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY")
repository_registry_load; STATUS=$?
assert_fails "malformed schema-1 input is refused"
assert_equals "$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY")" "$before" \
  "malformed input remains unchanged"
assert_no_file "$MONTAGE_REPOSITORY_REGISTRY_BACKUP" "malformed input creates no rollback artifact"

# An interruption after the exact copy but before replacement is retryable.
select_registry_case interrupted
entries=$(jq -nc --argjson item "$(loadout_entry retry "$library_a" library-a1)" '[$item]')
legacy_registry 10 "$entries" >"$MONTAGE_REPOSITORY_REGISTRY"
before=$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY")
MONTAGE_TEST_INTERRUPT_REPOSITORY_MIGRATION_BEFORE_REPLACE=1
repository_registry_load; STATUS=$?
unset MONTAGE_TEST_INTERRUPT_REPOSITORY_MIGRATION_BEFORE_REPLACE
assert_exit 75 "an interrupted migration reports its interruption"
assert_equals "$(sha256sum "$MONTAGE_REPOSITORY_REGISTRY")" "$before" \
  "interruption leaves schema 1 installed"
assert_file "$MONTAGE_REPOSITORY_REGISTRY_BACKUP" "interruption leaves the rollback copy"
REPOSITORY_REGISTRY=""; REPOSITORY_REGISTRY_MIGRATION=null
repository_registry_load; STATUS=$?
assert_ok "an interrupted migration retries successfully"
assert_equals "$(jq -r '.revision' <<<"$REPOSITORY_REGISTRY")" "11" \
  "retry still increments exactly once"

# Concurrent first readers serialize. Exactly one replacement occurs.
select_registry_case concurrent
entries=$(jq -nc --argjson item "$(loadout_entry concurrent "$library_a" library-a1)" '[$item]')
legacy_registry 20 "$entries" >"$MONTAGE_REPOSITORY_REGISTRY"
(REPOSITORY_REGISTRY=""; REPOSITORY_REGISTRY_MIGRATION=null; repository_registry_load) & first=$!
(REPOSITORY_REGISTRY=""; REPOSITORY_REGISTRY_MIGRATION=null; repository_registry_load) & second=$!
wait "$first"; first_status=$?
wait "$second"; second_status=$?
STATUS=$first_status; assert_ok "the first concurrent migration attempt succeeds"
STATUS=$second_status; assert_ok "the second concurrent migration attempt succeeds"
repository_registry_load; STATUS=$?
assert_ok "the concurrently migrated registry validates"
assert_equals "$(jq -r '.revision' <<<"$REPOSITORY_REGISTRY")" "21" \
  "concurrent migration replaces and increments only once"

# A post-migration vault edit is invalid active state, never another migration.
jq '.repositories[0].type="vault"' "$MONTAGE_REPOSITORY_REGISTRY" \
  >"$CONFIG_DIR/hand-edited.json"
mv "$CONFIG_DIR/hand-edited.json" "$MONTAGE_REPOSITORY_REGISTRY"
REPOSITORY_REGISTRY=""; REPOSITORY_REGISTRY_MIGRATION=null
repository_registry_load; STATUS=$?
assert_fails "a schema-2 vault edit is rejected instead of migrated"

# First-read migration facts stay inside each supported result channel.
prepare_cli_registry() {
  local root="$1"
  export XDG_CONFIG_HOME="$root"
  mkdir -p "$XDG_CONFIG_HOME/montage"
  entries=$(jq -nc --argjson keep "$(loadout_entry cli "$library_a" library-a1)" \
    --argjson retire "$(vault_entry old-vault /not/opened vault-old)" '[$keep,$retire]')
  legacy_registry 30 "$entries" >"$XDG_CONFIG_HOME/montage/repositories.json"
}

prepare_cli_registry "$SANDBOX/cli-json"
mntg repository list --json
assert_ok "JSON repository list performs first-read migration"
jq -e '.kind=="montage-repository-list" and .migration.performed==true and
  .migration.priorSchema==1 and .migration.newSchema==2 and
  .migration.retiredVaults==["old-vault"]' <<<"$OUT" >/dev/null; STATUS=$?
assert_ok "JSON carries one structured migration result"

prepare_cli_registry "$SANDBOX/cli-human"
mntg repository list
assert_ok "human repository list performs first-read migration"
assert_output "Migrated repository registry from schema 1 to 2" \
  "human output carries a concise migration notice"
assert_output "old-vault" "human output names retired vault entries"

prepare_cli_registry "$SANDBOX/cli-porcelain"
mntg --porcelain status
assert_ok "porcelain status performs first-read migration"
assert_output "MIGRATION|1|true|1|2|old-vault|" \
  "porcelain output carries the versioned migration record"
assert_no_output "Migrated repository registry" "porcelain has no human migration text"
