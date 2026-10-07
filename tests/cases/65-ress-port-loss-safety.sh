# Loss acceptance is itemized. It never stands in for containment, credential,
# consent, private-key, or cleanup-ownership safety.

library="$SANDBOX/library"
mntg repository init loadouts "$library" --id loss-library >/dev/null
mkdir -p "$library/loadouts/native"
jq '.plugins += [{"id":"tombychowski.montage","url":"https://github.com/tombychowski/montage","commit":"2222222222222222222222222222222222222222"}]' \
  "$REPO_DIR/tests/fixtures/ress-v1/loadout/profile.json" \
  >"$library/loadouts/native/profile.json"
git -C "$library" add -A
git -C "$library" commit -q -m native
head_before=$(git -C "$library" rev-parse HEAD)
destination="$SANDBOX/export"

mntg --yes port ress export loadout "$library" --loadout native \
  --destination "$destination" --montage-plugin omit --json
assert_exit 3 "general confirmation does not accept representational loss"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "loss-acceptance-required" \
  "missing loss acceptance is explicit"
assert_equals "$(jq -r '.losses[0].code' <<<"$OUT")" "montage-repository-metadata" \
  "loss is itemized"
assert_no_file "$destination/profile.json" "unaccepted loss publishes nothing"

mntg --yes port ress export loadout "$library" --loadout native \
  --destination "$destination" --accept-loss all --montage-plugin omit --json
assert_exit 3 "broad loss acceptance is not a wildcard"
assert_no_file "$destination/profile.json" "broad loss phrase bypasses no decision"

mntg --yes port ress export loadout "$library" --loadout native \
  --destination "$destination" --accept-loss montage-repository-metadata --json
assert_exit 3 "accepted metadata loss does not decide the Montage self-plugin"
assert_equals "$(jq -r '.kind' <<<"$OUT")" "montage-port-report" \
  "missing export decisions retain the stable report envelope"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "montage-self-plugin-decision-required" \
  "self-plugin decision is requested explicitly"
assert_no_file "$destination/profile.json" "missing self-plugin decision publishes nothing"
assert_equals "$(git -C "$library" rev-parse HEAD)" "$head_before" \
  "all refused exports preserve native history"

ress_self="$SANDBOX/ress-self"
mkdir "$ress_self"
jq '.plugins += [{"id":"tsouth89.resurrect","url":"https://github.com/btsouth/omarchy-resurrect","commit":"1111111111111111111111111111111111111111"}]' \
  "$REPO_DIR/tests/fixtures/ress-v1/loadout/profile.json" >"$ress_self/profile.json"
target="$SANDBOX/target"
mntg repository init loadouts "$target" --id target-library >/dev/null
mntg repository configure target "$target" loadouts >/dev/null
target_head=$(git -C "$target" rev-parse HEAD)
mntg --yes port ress import loadout "$ress_self" --repository target --loadout imported --json
assert_exit 3 "import does not silently reassign the Ress self-plugin"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "self-plugin-decision-required" \
  "import asks for an explicit Ress self-plugin decision"
assert_no_file "$target/loadouts/imported/profile.json" "undecided self-plugin import publishes nothing"

mntg --yes port ress import loadout "$ress_self" --repository target --loadout imported \
  --ress-plugin omit --json
assert_ok "explicit Ress self-plugin omission permits import"
assert_file_lacks "$target/loadouts/imported/profile.json" "tsouth89.resurrect" \
  "self-plugin omission does not map ownership to Montage"

credential="$SANDBOX/credential"
mkdir "$credential"
jq '.plugins[0].url="https://token@example.invalid/plugin"' \
  "$REPO_DIR/tests/fixtures/ress-v1/loadout/profile.json" >"$credential/profile.json"
mntg port ress plan "$credential" --destination "$SANDBOX/credential-target" --json
assert_fails "credential-bearing Ress input is a non-waivable refusal"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "malformed-or-unsafe" \
  "credential refusal is not represented as waivable loss"
assert_no_output "token@" "credential material is not echoed in the port report"

hostile="$SANDBOX/hostile"
cp -a "$REPO_DIR/tests/fixtures/ress-v1/vault" "$hostile"
ln -s "$SANDBOX/outside" "$hostile/home/escape"
mntg port ress plan "$hostile" --destination "$SANDBOX/hostile-target" --json
assert_fails "containment failure is non-waivable"
assert_equals "$(jq -r '.losses|length' <<<"$OUT")" "0" \
  "containment failure is never converted into a loss checkbox"
assert_no_file "$SANDBOX/hostile-target/montage.json" "hostile input publishes nothing"
