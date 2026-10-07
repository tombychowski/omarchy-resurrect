# One native repository contains independently identified portable loadouts.

source "$TESTS_DIR/lib/loadout.sh"

assert_one_json() {
  jq -se 'length == 1' <<<"$OUT" >/dev/null && _pass || _fail "$1" "$OUT"
}

repo="$SANDBOX/loadout-library"
mntg repository init loadouts "$repo" --id personal-library --json
assert_ok "loadout repository initialization succeeds"
assert_one_json "initialization emits one JSON result"
jq -e '.kind=="montage-loadout-repository-initialized" and
  .repository.id=="personal-library" and .repository.repositoryType=="loadouts"' \
  <<<"$OUT" >/dev/null && _pass || _fail "initialization reports native identity" "$OUT"
assert_dir "$repo/loadouts" "repository has the loadout collection"
assert_equals "$(git -C "$repo" rev-list --count HEAD)" "1" "initialization records one commit"

mntg repository configure personal "$repo" loadouts --json
assert_ok "initialized repository can be configured"

write_package_loadout "$SANDBOX/alpha-source" "Alpha display" alpha
write_package_loadout "$SANDBOX/beta-source" "Beta display" beta
mkdir -p "$repo/loadouts/alpha" "$repo/loadouts/beta"
cp "$SANDBOX/alpha-source/profile.json" "$repo/loadouts/alpha/profile.json"
cp "$SANDBOX/beta-source/profile.json" "$repo/loadouts/beta/profile.json"

# Invalid siblings remain visible as invalid records and never merge with valid
# identities. Symlinked directories and leaves are not followed.
mkdir -p "$repo/loadouts/bad..id" "$repo/loadouts/broken"
cp "$SANDBOX/alpha-source/profile.json" "$repo/loadouts/bad..id/profile.json"
printf '{"schemaVersion":99}\n' >"$repo/loadouts/broken/profile.json"
ln -s "$SANDBOX/alpha-source" "$repo/loadouts/linked"
git -C "$repo" add -A
git -C "$repo" commit -q -m fixtures

mntg repository loadouts personal --json
assert_ok "multi-loadout discovery succeeds"
assert_one_json "loadout catalog emits one JSON result"
jq -e '.repositoryCommit as $commit |
  .kind=="montage-loadout-catalog" and .repositoryId=="personal-library" and
  ($commit|test("^[0-9a-f]{40}$")) and
  [.items[].id]==["alpha","beta"] and (.invalid|length)==3 and
  all(.items[]; .repositoryId=="personal-library" and
    .repositoryCommit==$commit) and
  any(.invalid[]; .id=="bad..id" and .reason=="hostile-id") and
  any(.invalid[]; .id=="broken" and .reason=="invalid-profile") and
  any(.invalid[]; .id=="linked" and .reason=="unsafe-directory")' \
  <<<"$OUT" >/dev/null && _pass || _fail "catalog separates valid and invalid entries" "$OUT"

machine_publish repo alpha
mntg apply --dry-run "$repo/loadouts/alpha/profile.json"
assert_ok "a contained repository leaf is independently applicable"
assert_output "Alpha display" "direct leaf apply reads portable profile metadata"
mntg apply --dry-run "$repo/loadouts/alpha"
assert_ok "a contained standalone leaf directory remains supported"

mntg repository loadouts personal
assert_ok "human loadout discovery succeeds"
assert_output "alpha  Alpha display" "human catalog shows stable id and display name"
assert_output "Invalid entries:" "human catalog calls out invalid siblings"

alpha_path="$repo/loadouts/alpha/profile.json"
beta_before=$(sha256sum "$repo/loadouts/beta/profile.json")
alpha_created=$(jq -r '.createdAt' "$alpha_path")
commits_before=$(git -C "$repo" rev-list --count HEAD)
mntg repository loadout rename personal alpha --name "Renamed Alpha" \
  --description "Mutable display metadata" --json
assert_ok "loadout metadata rename succeeds"
assert_one_json "rename emits one JSON result"
jq -e '.kind=="montage-loadout-renamed" and .item.id=="alpha" and
  .item.name=="Renamed Alpha" and .item.description=="Mutable display metadata" and
  .item.relativePath=="loadouts/alpha/profile.json"' \
  <<<"$OUT" >/dev/null && _pass || _fail "rename reports stable identity and new metadata" "$OUT"
assert_file "$alpha_path" "rename preserves stable item path"
assert_equals "$(jq -r '.createdAt' "$alpha_path")" "$alpha_created" \
  "rename preserves creation identity metadata"
assert_equals "$(sha256sum "$repo/loadouts/beta/profile.json")" "$beta_before" \
  "rename preserves sibling loadout content"
assert_equals "$(git -C "$repo" rev-list --count HEAD)" "$((commits_before + 1))" \
  "rename creates one content-changing commit"

mntg repository loadout show personal alpha --json
assert_ok "renamed item remains discoverable by stable id"
assert_one_json "loadout show emits one JSON result"
jq -e '.item.id=="alpha" and .item.name=="Renamed Alpha"' <<<"$OUT" >/dev/null &&
  _pass || _fail "display rename does not change selection identity" "$OUT"

mntg repository loadout rename personal '../alpha' --name Nope --json
assert_fails "hostile item identity is refused"
assert_file "$alpha_path" "hostile identity refusal preserves the selected item"

existing="$SANDBOX/existing"
mkdir -p "$existing"
printf 'owned\n' >"$existing/value"
mntg repository init loadouts "$existing" --id another-library --json
assert_fails "initialization refuses an existing destination"
assert_file_contains "$existing/value" "owned" "initialization preserves existing content"
