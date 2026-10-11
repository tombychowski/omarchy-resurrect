# Ress migration reads exactly one contained regular profile. Hostile JSON,
# credentials, private-key fields, executable authority, and symlink topology
# are non-waivable refusals; unrelated sidecar state is ignored, never adopted.

source "$TESTS_DIR/lib/loadout.sh"

fixture="$REPO_DIR/tests/fixtures/ress-v1/loadout/profile.json"
valid="$SANDBOX/valid-source"
mkdir -p "$valid/state" "$valid/locks"
cp "$fixture" "$valid/profile.json"
printf 'foreign applied state\n' >"$valid/state/loadouts.json"
printf 'foreign lock\n' >"$valid/locks/migration.lock"
valid_before=$(find "$valid" -type f -print0 | sort -z | xargs -0 sha256sum)

mntg port ress inspect "$valid" --json
assert_ok "contained regular Ress profile inspects"
jq -e '.compatible and .ready and
  .warnings==[{code:"non-profile-content-ignored"}] and
  .source.profile==$profile' --arg profile "$valid/profile.json" <<<"$OUT" >/dev/null && _pass ||
  _fail "inspection warns that non-profile state is ignored" "$OUT"
assert_equals "$(find "$valid" -type f -print0 | sort -z | xargs -0 sha256sum)" \
  "$valid_before" "inspection leaves the complete source tree unchanged"

mntg port ress inspect "$valid/profile.json" --json
assert_ok "the contained profile file is accepted directly"
assert_equals "$(jq -r '.source.root' <<<"$OUT")" "$valid" \
  "direct-file inspection retains the containing source identity"

source_link="$SANDBOX/source-link"
ln -s "$valid" "$source_link"
mntg port ress inspect "$source_link" --json
assert_fails "symlinked source root is refused"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "unsafe-or-missing-source" \
  "symlink-root refusal is explicit"

profile_link="$SANDBOX/profile-link"
mkdir -p "$profile_link"
ln -s "$valid/profile.json" "$profile_link/profile.json"
mntg port ress inspect "$profile_link" --json
assert_fails "symlinked profile control is refused"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "unsafe-profile-control"

other_name="$SANDBOX/not-profile.json"
cp "$fixture" "$other_name"
mntg port ress inspect "$other_name" --json
assert_fails "arbitrary JSON file names are not inferred as Ress profiles"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "outside-loadout-boundary"

malformed="$SANDBOX/malformed"
mkdir -p "$malformed"
printf '{bad json\n' >"$malformed/profile.json"
mntg port ress inspect "$malformed" --json
assert_fails "malformed profile JSON is refused"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "malformed-or-unsafe-profile"

marker="$SANDBOX/executable-authority-ran"
for field in commands privateKey cleanupPolicy; do
  hostile="$SANDBOX/hostile-$field"
  mkdir -p "$hostile"
  jq --arg field "$field" --arg value "touch $marker" '. + {($field):$value}' \
    "$fixture" >"$hostile/profile.json"
  mntg port ress inspect "$hostile" --json
  assert_fails "unsupported authority field $field is refused"
  assert_equals "$(jq -r '.reason' <<<"$OUT")" "malformed-or-unsafe-profile" \
    "$field is not represented as waivable loss"
  assert_no_file "$marker" "$field content is never executed"
done

for kind in plugin webapp; do
  credential="$SANDBOX/credential-$kind"
  mkdir -p "$credential"
  if [[ $kind == plugin ]]; then
    jq '.plugins[0].url="https://user:TOPSECRET@example.com/plugin"' \
      "$fixture" >"$credential/profile.json"
  else
    jq '.webapps[0].url="https://user:TOPSECRET@example.com/app"' \
      "$fixture" >"$credential/profile.json"
  fi
  mntg port ress inspect "$credential" --json
  assert_fails "credential-bearing Ress $kind URL is refused"
  assert_equals "$(jq -r '.reason' <<<"$OUT")" "malformed-or-unsafe-profile"
  assert_no_output "TOPSECRET" "$kind credential is not echoed"
done

# A dry-run import of the valid source reports only one profile publication;
# sidecar state never becomes a destination file or local applied authority.
library="$SANDBOX/library"
mntg repository init "$library" --id inspection-library >/dev/null
mntg repository configure inspection "$library" >/dev/null
mntg --dry-run port ress import loadout "$valid" \
  --repository inspection --loadout imported --json
assert_ok "valid sidecar-bearing source has a non-mutating import preview"
jq -e '.publication.planned and (.warnings|map(.code)|index("non-profile-content-ignored"))' \
  <<<"$OUT" >/dev/null && _pass || _fail "preview preserves ignored-state warning" "$OUT"
assert_no_file "$library/loadouts/imported/profile.json" "preview publishes no profile"
assert_no_file "$library/loadouts/imported/state/loadouts.json" "foreign state is never staged"
assert_no_file "$(registry_path)" "migration creates no applied-loadout authority"
