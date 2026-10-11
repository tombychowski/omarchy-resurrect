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

mntg port ress inspect "$source_root" --json
assert_ok "contained Ress v1 loadout counterpart inspects successfully"
jq -e '.kind=="montage-ress-loadout-migration" and .format=="ress-v1" and
  .sourceSchemaVersion==1 and .compatible and .ready and
  .publication=={planned:false,published:false,commit:null}' <<<"$OUT" >/dev/null && _pass ||
  _fail "valid Ress source has the focused inspection contract" "$OUT"

# Hostile version and topology fixtures are refused at inspection, before a
# destination repository or applied-loadout state is consulted.
future_root="$SANDBOX/ress-loadout-future"
cp -a "$REPO_DIR/tests/fixtures/ress-v1/loadout/." "$future_root/"
jq '.schemaVersion = 2' "$future_root/profile.json" >"$future_root/profile.future.json"
mv "$future_root/profile.future.json" "$future_root/profile.json"
mntg port ress inspect "$future_root" --json
assert_fails "unsupported future Ress loadout schema is refused"

symlink_root="$SANDBOX/ress-loadout-symlink"
mkdir -p "$symlink_root"
ln -s "$source_root/profile.json" "$symlink_root/profile.json"
mntg port ress inspect "$symlink_root" --json
assert_fails "symlinked Ress profile control is refused"

credential_root="$SANDBOX/ress-loadout-credential"
cp -a "$REPO_DIR/tests/fixtures/ress-v1/loadout/." "$credential_root/"
jq '.webapps = [{name:"Private",url:"https://user:secret@example.com/private",icon:"private"}]' \
  "$credential_root/profile.json" >"$credential_root/profile.credential.json"
mv "$credential_root/profile.credential.json" "$credential_root/profile.json"
mntg port ress inspect "$credential_root" --json
assert_fails "credential-bearing Ress loadout is refused"
assert_no_output "secret" "Ress refusal does not expose credential material"

library="$SANDBOX/montage-library"
mntg repository init "$library" --id imported-library >/dev/null
mkdir -p "$library/loadouts/sibling"
cp "$source_root/profile.json" "$library/loadouts/sibling/profile.json"
git -C "$library" add -A
git -C "$library" commit -q -m sibling
git -C "$library" remote add origin https://example.invalid/montage-library.git
mntg repository configure imported "$library" >/dev/null
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
assert_equals "$(jq -r '.publication.published' <<<"$OUT")" "false" \
  "preview does not claim publication"
assert_equals "$(jq -r '.publication.planned' <<<"$OUT")" "true" \
  "preview reports the exact planned publication"
assert_no_file "$library/loadouts/workstation/profile.json" \
  "preview creates no loadout item"
assert_equals "$(git -C "$library" rev-parse HEAD)" "$head_before" \
  "preview creates no Montage commit"

mntg --yes port ress import loadout "$source_root" \
  --repository imported --loadout workstation --json
assert_ok "confirmed Ress loadout import succeeds"
assert_equals "$(jq -r '.publication.published' <<<"$OUT")" "true" \
  "import reports successful publication"
assert_equals "$(jq -r '.destination.repositoryId' <<<"$OUT")" "imported-library" \
  "import binds the native repository identity"
assert_equals "$(jq -r '.destination.loadoutId' <<<"$OUT")" "workstation" \
  "import reports the new stable item id"
assert_file "$library/loadouts/workstation/profile.json" \
  "portable profile is published as a native library leaf"
jq -S . "$source_root/profile.json" >"$SANDBOX/source.semantic"
jq -S . "$library/loadouts/workstation/profile.json" >"$SANDBOX/imported.semantic"
cmp -s "$SANDBOX/source.semantic" "$SANDBOX/imported.semantic" && _pass ||
  _fail "compatible portable profile data is preserved semantically"
assert_equals "$(git -C "$library" rev-list --count "$head_before..HEAD")" "1" \
  "import creates exactly one content-changing Montage commit"
assert_equals "$(git -C "$library" status --porcelain=v1 --untracked-files=all)" "" \
  "published destination repository is clean"
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

escaped="$SANDBOX/escaped-library"
mntg repository init "$escaped" --id escaped-library >/dev/null
rmdir "$escaped/loadouts"
ln -s "$source_root" "$escaped/loadouts"
git -C "$escaped" add -A
git -C "$escaped" commit -q -m redirect
mntg repository configure escaped "$escaped" >/dev/null
for mode in --dry-run --yes; do
  mntg "$mode" port ress import loadout "$source_root" --repository escaped --loadout escaped --json
  assert_fails "Ress $mode refuses a symlinked destination parent"
  assert_no_file "$source_root/escaped" "refusal preserves the Ress source"
done

# A regular library nested in the source also changes the source tree on import.
nested="$source_root/nested-library"
mntg repository init "$nested" --id nested-library >/dev/null
mntg repository configure nested "$nested" >/dev/null
for mode in --dry-run --yes; do
  mntg "$mode" port ress import loadout "$source_root" --repository nested --loadout nested --json
  assert_fails "Ress $mode refuses source/library overlap"
  assert_no_file "$nested/loadouts/nested" "overlap refusal publishes no item"
done
