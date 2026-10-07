# GitHub visibility is advisory evidence: known public vault storage requires
# confirmation, while unavailable evidence stays explicitly unknown.

make_visibility_vault() {
  local name="$1" path
  path=$(make_vault "$SANDBOX/$name")
  seal_vault "$path" "$name"
  printf '%s' "$path"
}

PUBLIC=$(make_visibility_vault public-vault)
printf 'public\n' >"$FAKE_STATE/gh-visibility"
mntg repository configure public-vault "$PUBLIC" vault \
  --remote https://github.com/example/public-vault
assert_fails "known-public vault configuration requires confirmation"
assert_output "this GitHub repository is public"
mntg repository show public-vault
assert_fails "declined public configuration is not persisted"

mntg --yes repository configure public-vault "$PUBLIC" vault \
  --remote https://github.com/example/public-vault --json
assert_ok "explicitly confirmed public vault configuration"
assert_equals "$(jq -r '.visibility' <<<"$OUT")" "public" \
  "JSON reports known-public visibility"
assert_output "personal backup metadata" "JSON carries the public-vault warning"

PRIVATE=$(make_visibility_vault private-vault)
printf 'private\n' >"$FAKE_STATE/gh-visibility"
mntg repository configure private-vault "$PRIVATE" vault \
  --remote https://github.com/example/private-vault --json
assert_ok "known-private vault configuration needs no public warning confirmation"
assert_equals "$(jq -r '.visibility' <<<"$OUT")" "private" \
  "known-private evidence is reported"
assert_equals "$(jq -r '.warning' <<<"$OUT")" "null" \
  "private result carries no public warning"

UNAVAILABLE=$(make_visibility_vault unavailable-vault)
printf 'unavailable\n' >"$FAKE_STATE/gh-visibility"
mntg repository configure unavailable-vault "$UNAVAILABLE" vault \
  --remote https://github.com/example/unavailable-vault --json
assert_ok "unavailable visibility does not pretend the remote is public or private"
assert_equals "$(jq -r '.visibility' <<<"$OUT")" "unknown" \
  "unavailable visibility stays unknown"

UNAUTH=$(make_visibility_vault unauthenticated-vault)
printf 'unauthenticated\n' >"$FAKE_STATE/gh-visibility"
mntg repository configure unauthenticated-vault "$UNAUTH" vault \
  --remote https://github.com/example/unauthenticated-vault --json
assert_ok "unauthenticated visibility inspection remains usable"
assert_equals "$(jq -r '.visibility' <<<"$OUT")" "unknown" \
  "unauthenticated visibility stays unknown"

LOADOUT="$SANDBOX/public-loadouts"
mntg repository init loadouts "$LOADOUT" --id public-loadouts >/dev/null
printf 'public\n' >"$FAKE_STATE/gh-visibility"
mntg repository configure public-loadouts "$LOADOUT" loadouts \
  --remote https://github.com/example/public-loadouts --json
assert_ok "public loadout repositories do not receive the private-vault gate"
assert_equals "$(jq -r '.visibility' <<<"$OUT")" "unknown" \
  "loadout configuration does not claim a vault visibility result"
