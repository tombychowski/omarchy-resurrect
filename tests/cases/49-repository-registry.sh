# The active configured-repository registry is schema 2, deterministic, and
# accepts only identity-bound loadout libraries.

PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/montage/core.sh"
source "$REPO_DIR/lib/montage/safety.sh"
source "$REPO_DIR/lib/montage/repository/common.sh"
source "$REPO_DIR/lib/montage/repository/registry.sh"
OUT=""

make_repository() {
  local path="$1" id="$2"
  mkdir -p "$path"
  repository_envelope_json "$id" "2026-10-06T20:00:00Z" >"$path/montage.json"
}

loadouts="$SANDBOX/loadouts"
alternate="$SANDBOX/alternate"
make_repository "$loadouts" loadouts-a1
make_repository "$alternate" loadouts-b2

repository_registry_put personal "$loadouts" \
  'https://user:secret@github.com/example/loadouts.git'; STATUS=$?
assert_ok "a valid loadout library is configured"
assert_file "$XDG_CONFIG_HOME/montage/repositories.json" "the registry is persisted"
assert_equals "$(jq -r '.schemaVersion' "$XDG_CONFIG_HOME/montage/repositories.json")" "2" \
  "new registries use schema 2"
assert_equals "$(stat -c '%a' "$XDG_CONFIG_HOME/montage/repositories.json")" "600" \
  "the registry is private"
repository_registry_load; STATUS=$?
assert_ok "the persisted registry validates"
personal=$(repository_registry_get personal)
assert_equals "$(jq -r '.path' <<<"$personal")" "$(realpath "$loadouts")" \
  "the path is canonical and absolute"
assert_equals "$(jq -r '.id' <<<"$personal")" "loadouts-a1" \
  "the expected envelope identity is stored"
assert_equals "$(jq -r '.type' <<<"$personal")" "loadouts" \
  "the repository kind is fixed"
assert_equals "$(jq -r '.remote' <<<"$personal")" \
  "https://github.com/example/loadouts.git" "remote credentials are not persisted"

repository_registry_put relative relative/path; STATUS=$?
assert_fails "a relative repository path is refused"
vault_path="$SANDBOX/vault-envelope"
mkdir -p "$vault_path"
printf '{"schemaVersion":1,"kind":"montage-repository","repositoryType":"vault","id":"vault-a1","createdAt":"2026-10-06T20:00:00Z","machineId":"machine-a1"}\n' \
  >"$vault_path/montage.json"
repository_registry_put wrong "$vault_path"; STATUS=$?
assert_fails "a vault envelope is refused"

before=$(sha256sum "$XDG_CONFIG_HOME/montage/repositories.json")
repository_registry_put personal "$alternate"; STATUS=$?
assert_exit 2 "an alias cannot silently change repository identity"
assert_equals "$(sha256sum "$XDG_CONFIG_HOME/montage/repositories.json")" "$before" \
  "a stale-id refusal preserves the registry"
repository_registry_put personal "$alternate" '' replace; STATUS=$?
assert_ok "explicit replacement accepts a new loadout-library identity"
repository_registry_load
assert_equals "$(repository_registry_get personal | jq -r '.id')" "loadouts-b2" \
  "explicit replacement records the new expected identity"

# Separate writers contend on the same dedicated config lock. Every successful
# writer rereads under that lock, so neither entry is lost.
for item in alpha beta gamma delta; do
  repo="$SANDBOX/$item"
  make_repository "$repo" "repo-$item"
  (repository_registry_put "$item" "$repo") &
done
wait
repository_registry_load; STATUS=$?
assert_ok "the registry remains valid after concurrent writes"
for item in alpha beta gamma delta; do
  repository_registry_get "$item" >/dev/null; STATUS=$?
  assert_ok "concurrent entry survives: $item"
done
assert_equals "$(jq -r '.repositories | length' <<<"$REPOSITORY_REGISTRY")" "5" \
  "concurrent writers preserve all existing and new entries"
assert_equals "$(jq -r '[.repositories[].name] == ([.repositories[].name] | sort)' \
  <<<"$REPOSITORY_REGISTRY")" "true" "entries serialize in deterministic name order"

registry="$XDG_CONFIG_HOME/montage/repositories.json"
valid=$(<"$registry")
jq '.unexpected=true' <<<"$valid" >"$registry"
repository_registry_load; STATUS=$?
assert_fails "extra top-level fields are rejected"
printf '%s\n' "$valid" >"$registry"
jq '.repositories[0].unexpected=true' <<<"$valid" >"$registry"
repository_registry_load; STATUS=$?
assert_fails "extra entry fields are rejected"
printf '%s\n' "$valid" >"$registry"
jq '.repositories[0].type="vault"' <<<"$valid" >"$registry"
repository_registry_load; STATUS=$?
assert_fails "a hand-edited schema-2 vault entry is rejected"

printf '{"schemaVersion":99}\n' >"$registry"
repository_registry_put rejected "$loadouts"; STATUS=$?
assert_fails "an invalid existing registry fails closed"
assert_equals "$(<"$registry")" '{"schemaVersion":99}' \
  "invalid state is not guessed or overwritten"
