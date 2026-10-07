# The local repository registry is serialized, identity-bound configuration.

PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/montage/core.sh"
source "$REPO_DIR/lib/montage/safety.sh"
source "$REPO_DIR/lib/montage/repository/common.sh"
source "$REPO_DIR/lib/montage/repository/registry.sh"
OUT=""

make_repository() {
  local path="$1" type="$2" id="$3" machine="${4:-}"
  mkdir -p "$path"
  repository_envelope_json "$type" "$id" "2026-10-06T20:00:00Z" "$machine" \
    >"$path/montage.json"
}

loadouts="$SANDBOX/loadouts"
vault_one="$SANDBOX/vault-one"
vault_two="$SANDBOX/vault-two"
make_repository "$loadouts" loadouts loadouts-a1
make_repository "$vault_one" vault vault-a1 machine-a1
make_repository "$vault_two" vault vault-b2 machine-b2

repository_registry_put personal "$loadouts" loadouts \
  'https://user:secret@github.com/example/loadouts.git'; STATUS=$?
assert_ok "a valid repository is configured"
assert_file "$XDG_CONFIG_HOME/montage/repositories.json" "the registry is persisted"
repository_registry_load; STATUS=$?
assert_ok "the persisted registry validates"
personal=$(repository_registry_get personal)
assert_equals "$(jq -r '.path' <<<"$personal")" "$(realpath "$loadouts")" \
  "the path is canonical and absolute"
assert_equals "$(jq -r '.id' <<<"$personal")" "loadouts-a1" \
  "the expected envelope identity is stored"
assert_equals "$(jq -r '.remote' <<<"$personal")" \
  "https://github.com/example/loadouts.git" "remote credentials are not persisted"

repository_registry_put relative relative/path loadouts; STATUS=$?
assert_fails "a relative repository path is refused"
repository_registry_put wrong "$loadouts" vault; STATUS=$?
assert_fails "a repository of the wrong kind is refused"

repository_registry_put primary "$vault_one" vault; STATUS=$?
assert_ok "a vault repository is configured"
before=$(sha256sum "$XDG_CONFIG_HOME/montage/repositories.json")
repository_registry_put primary "$vault_two" vault; STATUS=$?
assert_exit 2 "an alias cannot silently change repository identity"
assert_equals "$(sha256sum "$XDG_CONFIG_HOME/montage/repositories.json")" "$before" \
  "a stale-id refusal preserves the registry"
repository_registry_put primary "$vault_two" vault '' replace; STATUS=$?
assert_ok "explicit replacement accepts a new repository identity"
repository_registry_load
assert_equals "$(repository_registry_get primary | jq -r '.id')" "vault-b2" \
  "explicit replacement records the new expected identity"

# Separate writers contend on the same dedicated config lock. Every successful
# writer rereads under that lock, so neither entry is lost.
for item in alpha beta gamma delta; do
  repo="$SANDBOX/$item"
  make_repository "$repo" loadouts "repo-$item"
  (repository_registry_put "$item" "$repo" loadouts) &
done
wait
repository_registry_load; STATUS=$?
assert_ok "the registry remains valid after concurrent writes"
for item in alpha beta gamma delta; do
  repository_registry_get "$item" >/dev/null; STATUS=$?
  assert_ok "concurrent entry survives: $item"
done
assert_equals "$(jq -r '.repositories | length' <<<"$REPOSITORY_REGISTRY")" "6" \
  "concurrent writers preserve all existing and new entries"

malformed_before=$(sha256sum "$XDG_CONFIG_HOME/montage/repositories.json")
printf '{"schemaVersion":99}\n' >"$XDG_CONFIG_HOME/montage/repositories.json"
repository_registry_put rejected "$loadouts" loadouts; STATUS=$?
assert_fails "an invalid existing registry fails closed"
assert_equals "$(cat "$XDG_CONFIG_HOME/montage/repositories.json")" \
  '{"schemaVersion":99}' "invalid state is not guessed or overwritten"
