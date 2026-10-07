# A current Ress loadout is copied through the port boundary into one new
# stable Montage library item. Neither product's other state is adopted.

source_root="$SANDBOX/ress-loadout"
cp -a "$REPO_DIR/tests/fixtures/ress-v1/loadout/." "$source_root/"
git -C "$source_root" init -q -b main
git -C "$source_root" add -A
git -C "$source_root" commit -q -m source
git -C "$source_root" remote add origin https://example.invalid/ress-source.git
source_head=$(git -C "$source_root" rev-parse HEAD)
source_config=$(sha256sum "$source_root/.git/config")
source_status=$(git -C "$source_root" status --porcelain=v1 --untracked-files=all)

library="$SANDBOX/montage-library"
mntg repository init loadouts "$library" --id imported-library >/dev/null
mkdir -p "$library/loadouts/sibling"
cp "$source_root/profile.json" "$library/loadouts/sibling/profile.json"
git -C "$library" add -A
git -C "$library" commit -q -m sibling
git -C "$library" remote add origin https://example.invalid/montage-library.git
mntg repository configure imported "$library" loadouts >/dev/null
sibling_before=$(sha256sum "$library/loadouts/sibling/profile.json")
remote_before=$(sha256sum "$library/.git/config")
head_before=$(git -C "$library" rev-parse HEAD)

mkdir -p "$XDG_STATE_HOME/montage"
printf 'private-applied-state\n' >"$XDG_STATE_HOME/montage/loadouts.json"
registry_before=$(sha256sum "$XDG_STATE_HOME/montage/loadouts.json")

mntg --dry-run port ress import loadout "$source_root" \
  --repository imported --loadout workstation --json
assert_ok "Ress loadout import has a non-mutating JSON preview"
assert_equals "$(jq -r '.operation' <<<"$OUT")" "import-loadout" \
  "preview identifies the import operation"
assert_equals "$(jq -r '.published' <<<"$OUT")" "false" \
  "preview does not claim publication"
assert_no_file "$library/loadouts/workstation/profile.json" \
  "preview creates no loadout item"
assert_equals "$(git -C "$library" rev-parse HEAD)" "$head_before" \
  "preview creates no Montage commit"

mntg --yes port ress import loadout "$source_root" \
  --repository imported --loadout workstation --json
assert_ok "confirmed Ress loadout import succeeds"
assert_equals "$(jq -r '.published' <<<"$OUT")" "true" \
  "import reports successful publication"
assert_equals "$(jq -r '.repositoryId' <<<"$OUT")" "imported-library" \
  "import binds the native repository identity"
assert_equals "$(jq -r '.loadoutId' <<<"$OUT")" "workstation" \
  "import reports the new stable item id"
assert_file "$library/loadouts/workstation/profile.json" \
  "portable profile is published as a native library leaf"
cmp -s "$source_root/profile.json" "$library/loadouts/workstation/profile.json" && _pass ||
  _fail "compatible portable profile data is preserved"
assert_equals "$(git -C "$library" rev-list --count "$head_before..HEAD")" "1" \
  "import creates exactly one content-changing Montage commit"
assert_equals "$(sha256sum "$library/loadouts/sibling/profile.json")" "$sibling_before" \
  "sibling loadouts are preserved"
assert_equals "$(sha256sum "$library/.git/config")" "$remote_before" \
  "destination Git remotes are preserved"
assert_equals "$(git -C "$source_root" rev-parse HEAD)" "$source_head" \
  "source history is unchanged"
assert_equals "$(git -C "$source_root" status --porcelain=v1 --untracked-files=all)" "$source_status" \
  "source working tree is unchanged"
assert_equals "$(sha256sum "$source_root/.git/config")" "$source_config" \
  "source remotes are unchanged"
assert_equals "$(sha256sum "$XDG_STATE_HOME/montage/loadouts.json")" "$registry_before" \
  "import does not adopt or mutate applied-loadout state"

mntg --yes port ress import loadout "$source_root" \
  --repository imported --loadout workstation --json
assert_fails "import never replaces an existing stable item implicitly"
assert_equals "$(git -C "$library" rev-list --count "$head_before..HEAD")" "1" \
  "refused replacement creates no extra commit"
