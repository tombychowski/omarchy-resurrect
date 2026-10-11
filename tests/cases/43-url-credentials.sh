source "$TESTS_DIR/lib/loadout.sh"

# URLs may be used for an immediate transport operation, but credentials are
# never part of a portable loadout, repository identity, persisted registry,
# generated instruction, or diagnostic output.

SECRET=TOPSECRET
remote="https://user:$SECRET@github.com/example/native-library.git"
safe_remote="https://github.com/example/native-library.git"

seed_machine
machine_shell_running

PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/montage/core.sh"
source "$REPO_DIR/lib/montage/safety.sh"

assert_equals "$(strip_credentials "https://user:$SECRET@example.com:8443/a?q=1#frag")" \
  "https://example.com:8443/a?q=1#frag" \
  "credential stripping preserves port, path, query, and fragment"
url_has_credentials "https://username@example.com/repo"; STATUS=$?
assert_ok "username-only URL user information is detected"
url_has_credentials "https://example.com/repo?owner=user@example.com"; STATUS=$?
assert_fails "an at-sign outside the authority is not treated as credentials"
assert_equals "$(strip_credentials "git@example.com:owner/repo")" \
  "git@example.com:owner/repo" "scp-style SSH identity is unchanged"
assert_equals "$(normalize_source 'ssh://git@example.com/owner/repo.git')" \
  "ssh://git@example.com/owner/repo.git" \
  "an explicit SSH transport reaches Git without an HTTPS prefix"

# A hostile live-machine web app is visible but never shareable, and neither
# its catalog entry nor the explanation leaks the credential.
library="$SANDBOX/native-library"
mntg repository init "$library" --id native-library --json
assert_ok "native loadout repository initializes"
mntg repository configure native "$library" --json
assert_ok "native loadout repository is configured for catalog inspection"
seed_webapp Private "https://user:$SECRET@example.com/private"
mntg share catalog --repository native --loadout workstation --json
assert_ok "share catalog remains available with a credential-bearing launcher"
assert_no_output "$SECRET" "share catalog contains no credential material"
jq -e 'any(.resources[]; .id=="webapp:Private" and (.shareable|not) and .reasonCode=="credential-url")' \
  <<<"$OUT" >/dev/null && _pass || _fail "catalog explicitly refuses credential-bearing web app" "$OUT"

# Repository configuration accepts a credential-bearing transport URL only
# after reducing it to credential-free identity. Generated loadout material
# and user instructions carry that canonical identity.
mntg repository configure native "$library" --remote "$remote" --json
assert_ok "credential-bearing configured loadout remote is sanitized"
assert_no_output "$SECRET" "repository configuration output contains no credential"
assert_equals "$(jq -r '.repository.remote' <<<"$OUT")" "$safe_remote" \
  "repository output exposes only credential-free identity"
assert_file_lacks "$XDG_CONFIG_HOME/montage/repositories.json" "$SECRET" \
  "repository registry stores no credential"

mntg share --repository native --loadout workstation --name Workstation
assert_ok "native repository share succeeds"
assert_output "mntg apply https://github.com/example/native-library --loadout workstation" \
  "generated instruction uses canonical URL and explicit stable selector"
assert_no_output "$SECRET" "native share instruction contains no credential"
assert_no_output "ress.sh" "native share instruction has no Ress short-link dependency"
assert_file_contains "$library/loadouts/workstation/README.md" \
  "mntg apply https://github.com/example/native-library --loadout workstation" \
  "generated repository documentation carries the explicit selector"
assert_file_lacks "$library/loadouts/workstation/README.md" "$SECRET" \
  "generated repository documentation contains no credential"

# Incoming credentials are rejected before any persistent state or machine
# mutation is created. The valid counterpart with the same public URL applies.
incoming="$SANDBOX/incoming"
mkdir -p "$incoming"
jq -n --arg url "https://user:$SECRET@example.com/private" \
  '{schemaVersion:1,kind:"omarchy-loadout",name:"Unsafe",author:"Test Author",
    description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4.0.0",
    packages:{native:[],aur:[]},plugins:[],
    webapps:[{name:"Private",url:$url,icon:"private"}],
    theme:{name:"",url:"",commit:""}}' >"$incoming/profile.json"
: >"$CALLS"
mntg apply --yes "$incoming"
assert_fails "credential-bearing incoming web app is refused"
assert_output "credential-bearing web app URL" "refusal explains the safe reason"
assert_no_output "$SECRET" "profile refusal never echoes credential material"
assert_no_file "$(registry_path)" "refused profile creates no registry"
assert_no_file "$XDG_STATE_HOME/montage/running" \
  "refused profile creates no visible operation marker"
assert_not_called "webapp install" "refused profile performs no web-app mutation"

jq '.webapps[0] |= (.name = "Public" | .url = "https://example.com/public" | .icon = "public")' \
  "$incoming/profile.json" >"$incoming/profile.safe.json"
mv "$incoming/profile.safe.json" "$incoming/profile.json"
mntg apply --yes "$incoming"
assert_ok "credential-free counterpart applies"
assert_file "$(registry_path)" "valid counterpart records applied-loadout state"
