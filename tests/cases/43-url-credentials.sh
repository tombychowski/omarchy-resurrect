source "$TESTS_DIR/lib/loadout.sh"

SECRET=TOPSECRET
remote="https://$SECRET@github.com/example/vault"
safe_remote="https://github.com/example/vault"

seed_machine
machine_shell_running

PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/ress/core.sh"
source "$REPO_DIR/lib/ress/safety.sh"
assert_equals "$(strip_credentials "https://user:$SECRET@example.com:8443/a?q=1#frag")" \
  "https://example.com:8443/a?q=1#frag" "credential stripping preserves port, path, query, and fragment"
url_has_credentials "https://username@example.com/repo"; STATUS=$?
assert_ok "username-only URL user information is detected"
url_has_credentials "https://example.com/repo?owner=user@example.com"; STATUS=$?
assert_fails "an at-sign outside authority is not treated as credentials"
assert_equals "$(strip_credentials "git@example.com:owner/repo")" \
  "git@example.com:owner/repo" "scp-style SSH identity is unchanged"

ress init --remote "$remote"
assert_ok "init accepts a credential-bearing transport URL"
assert_no_output "$SECRET" "init output never displays URL credentials"
assert_file_lacks "$XDG_CONFIG_HOME/ress/config" "$SECRET" "init stores no URL credentials"
assert_file_contains "$XDG_CONFIG_HOME/ress/config" "REMOTE=$safe_remote" "init stores repository identity"

ress status --json
assert_ok "status remains available"
assert_no_output "$SECRET" "status JSON contains no URL credentials"
assert_equals "$(jq -r '.remote' <<<"$OUT")" "$safe_remote" "status reports credential-free remote"

ress set REMOTE="https://user:$SECRET@example.com:8443/path?q=one#frag"
assert_ok "set accepts a credential-bearing remote"
assert_no_output "$SECRET" "set output contains no credential"
assert_file_contains "$XDG_CONFIG_HOME/ress/config" "REMOTE=https://example.com:8443/path?q=one#frag" \
  "set preserves non-credential URL components"
ress set PROFILE_URL="https://name:$SECRET@example.com/profile.json" >/dev/null
assert_file_contains "$XDG_CONFIG_HOME/ress/config" "PROFILE_URL=https://example.com/profile.json" \
  "profile URL is sanitized before persistence"

# Captured Git-backed resources retain repository identity but never user info.
seed_plugin secret.plugin "https://user:$SECRET@github.com/example/secret.plugin"
theme="$HOME/.config/omarchy/themes/secret-theme"
mkdir -p "$theme"
printf 'background = "#101010"\n' >"$theme/theme.conf"
git -C "$theme" init -q -b main
git -C "$theme" add -A
git -C "$theme" commit -q -m seed
git -C "$theme" remote add origin "https://user:$SECRET@github.com/example/secret-theme"

seed_webapp Private "https://user:$SECRET@example.com/private"
ress set REMOTE="" PROFILE_URL="" >/dev/null
ress backup -m credentials
assert_ok "backup sanitizes captured URL-bearing resources"
assert_no_output "$SECRET" "backup output never displays credential material"
assert_file_lacks "$XDG_DATA_HOME/ress/vault/plugins/plugins.tsv" "$SECRET" "plugin inventory has no credential"
assert_file_contains "$XDG_DATA_HOME/ress/vault/plugins/plugins.tsv" \
  "https://github.com/example/secret.plugin" "plugin repository identity is retained"
assert_file_lacks "$XDG_DATA_HOME/ress/vault/omarchy/themes.tsv" "$SECRET" "theme inventory has no credential"
assert_no_file "$XDG_DATA_HOME/ress/vault/webapps/apps/Private.desktop" \
  "credential-bearing web app is omitted from plaintext capture"
assert_output "Private" "capture names the omitted launcher safely"

ress share catalog --json
assert_ok "share catalog remains available with a credential-bearing launcher"
assert_no_output "$SECRET" "share catalog contains no credential material"
jq -e 'any(.resources[]; .id=="webapp:Private" and (.shareable|not) and .reasonCode=="credential-url")' \
  <<<"$OUT" >/dev/null && _pass || _fail "catalog explicitly refuses credential-bearing web app" "$OUT"

profile_out="$SANDBOX/profile-out"
ress share --out "$profile_out"
assert_ok "initial profile export succeeds"
git -C "$profile_out" remote add origin "https://user:$SECRET@github.com/example/profile"
ress share --out "$profile_out"
assert_ok "profile export sanitizes its repository origin"
assert_no_output "$SECRET" "generated share instruction contains no credential"
assert_file_lacks "$XDG_CONFIG_HOME/ress/config" "$SECRET" "configured share URL contains no credential"
assert_equals "$(git -C "$profile_out" remote get-url origin)" "https://github.com/example/profile" \
  "profile repository origin is rewritten credential-free"

# Incoming web-app credentials refuse the profile before lock or mutation.
incoming="$SANDBOX/incoming"
mkdir -p "$incoming"
jq -n --arg url "https://user:$SECRET@example.com/private" \
  '{schemaVersion:1,kind:"omarchy-loadout",name:"Unsafe",author:"Test Author",
    description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4.0.0",
    packages:{native:[],aur:[]},plugins:[],
    webapps:[{name:"Private",url:$url,icon:"private"}],
    theme:{name:"",url:"",commit:""}}' >"$incoming/profile.json"
: >"$CALLS"
ress apply --yes "$incoming"
assert_fails "credential-bearing incoming web app is refused"
assert_output "credential-bearing web app URL" "refusal explains the safe reason"
assert_no_output "$SECRET" "profile refusal never echoes credential material"
assert_no_file "$(registry_path)" "refused profile creates no registry"
assert_no_file "$XDG_STATE_HOME/ress/running" "refused profile creates no visible operation marker"
assert_not_called "webapp install" "refused profile performs no web-app mutation"

# A credential may authenticate the immediate clone, but the adopted vault and
# config retain only repository identity.
source_vault=$(make_vault "$SANDBOX/source-vault")
seal_vault "$source_vault" source
rm -rf "$FAKE_STATE/remotes/vault"
mkdir -p "$FAKE_STATE/remotes"
cp -a "$source_vault" "$FAKE_STATE/remotes/vault"
rm -rf "$XDG_DATA_HOME/ress/vault"
ress set VAULT="$XDG_DATA_HOME/ress/vault" REMOTE="$safe_remote" >/dev/null
ress restore --from "$remote" --yes --no-aur --no-enable-units
assert_ok "restore may use credentials for the immediate clone"
assert_no_output "$SECRET" "restore output never displays transport credentials"
assert_file_lacks "$XDG_CONFIG_HOME/ress/config" "$SECRET" "restore adoption stores no credential"
assert_equals "$(git -C "$XDG_DATA_HOME/ress/vault" remote get-url origin)" "$safe_remote" \
  "cloned vault origin is rewritten credential-free"
