# Ress export creates disposable compatibility copies and never converts native
# Montage repositories in place.

library="$SANDBOX/library"
mntg repository init loadouts "$library" --id export-library >/dev/null
mkdir -p "$library/loadouts/workstation"
jq '.plugins += [{"id":"tombychowski.montage","url":"https://github.com/tombychowski/montage","commit":"2222222222222222222222222222222222222222"}]' \
  "$REPO_DIR/tests/fixtures/ress-v1/loadout/profile.json" \
  >"$library/loadouts/workstation/profile.json"
git -C "$library" add -A
git -C "$library" commit -q -m loadout
git -C "$library" remote add origin https://example.invalid/montage-library.git
library_head=$(git -C "$library" rev-parse HEAD)
library_status=$(git -C "$library" status --porcelain=v1 --untracked-files=all)
library_config=$(sha256sum "$library/.git/config")
loadout_export="$SANDBOX/ress-loadout-copy"

mntg --dry-run port ress export loadout "$library" --loadout workstation \
  --destination "$loadout_export" --accept-loss montage-repository-metadata \
  --montage-plugin omit --json
assert_ok "selected loadout export has a dry-run preview"
assert_equals "$(jq -r '.selectedRevisions[0].commit' <<<"$OUT")" "$library_head" \
  "preview binds the exact Montage commit"
assert_no_file "$loadout_export/profile.json" "loadout preview creates no copy"

mntg --yes port ress export loadout "$library" --loadout workstation \
  --destination "$loadout_export" --accept-loss montage-repository-metadata \
  --montage-plugin omit --json
assert_ok "selected loadout exports to a separate Ress v1 directory"
assert_equals "$(jq -r '.published' <<<"$OUT")" "true" \
  "loadout export reports publication"
assert_file "$loadout_export/profile.json" "disposable Ress loadout contains profile.json"
assert_file_lacks "$loadout_export/profile.json" "tombychowski.montage" \
  "explicit Montage self-plugin omission is honored"
mntg port ress inspect "$loadout_export" --json
assert_ok "exported loadout is accepted by the frozen Ress v1 boundary"
assert_equals "$(jq -r '.artifactType' <<<"$OUT")" "loadout" \
  "exported loadout has the intended compatibility type"
assert_equals "$(git -C "$library" rev-parse HEAD)" "$library_head" \
  "loadout export does not change native history"
assert_equals "$(git -C "$library" status --porcelain=v1 --untracked-files=all)" "$library_status" \
  "loadout export does not change native working state"
assert_equals "$(sha256sum "$library/.git/config")" "$library_config" \
  "loadout export does not change native remotes"

printf 'sentinel\n' >"$loadout_export/sentinel"
sentinel_before=$(sha256sum "$loadout_export/sentinel")
mntg --yes port ress export loadout "$library" --loadout workstation \
  --destination "$loadout_export" --accept-loss montage-repository-metadata \
  --montage-plugin omit --json
assert_fails "non-empty Ress loadout destination is never overwritten implicitly"
assert_equals "$(sha256sum "$loadout_export/sentinel")" "$sentinel_before" \
  "refused overwrite preserves destination content"

vault=$(make_vault "$SANDBOX/native-vault")
mkdir -p "$vault/home/.config/example"
printf 'old\n' >"$vault/home/.config/example/settings.montage-bak"
printf 'tombychowski.montage\thttps://github.com/tombychowski/montage\tenabled\t2222222222222222222222222222222222222222\n' \
  >"$vault/plugins/plugins.tsv"
seal_vault "$vault" export-box
git -C "$vault" remote add origin https://example.invalid/montage-vault.git
vault_head=$(git -C "$vault" rev-parse HEAD)
vault_status=$(git -C "$vault" status --porcelain=v1 --untracked-files=all)
vault_config=$(sha256sum "$vault/.git/config")
vault_export="$SANDBOX/ress-vault-copy"

mntg --yes --vault "$vault" port ress export backup --backup "$vault_head" \
  --destination "$vault_export" --accept-loss montage-vault-identity \
  --montage-plugin map-ress --json
assert_ok "selected backup exports to a separate Ress v1 directory"
assert_equals "$(jq -r '.selectedRevisions[0].commit' <<<"$OUT")" "$vault_head" \
  "vault export binds the selected immutable backup"
assert_file "$vault_export/ress.json" "disposable Ress vault contains canonical manifest"
assert_no_file "$vault_export/montage.json" "disposable copy contains no native envelope"
assert_no_file "$vault_export/backup.json" "disposable copy contains no native backup manifest"
assert_file "$vault_export/home/.config/example/settings.ress-bak" \
  "Montage replacement suffix is translated for Ress"
assert_file_contains "$vault_export/plugins/plugins.tsv" "tsouth89.resurrect" \
  "explicit Montage-to-Ress self-plugin mapping is honored"
assert_file_lacks "$vault_export/plugins/plugins.tsv" "tombychowski.montage" \
  "mapping never silently retains both plugin identities"
mntg port ress inspect "$vault_export" --json
assert_ok "exported vault is accepted by the frozen Ress v1 boundary"
assert_equals "$(jq -r '.artifactType' <<<"$OUT")" "vault" \
  "exported backup has the intended compatibility type"
assert_equals "$(git -C "$vault" rev-parse HEAD)" "$vault_head" \
  "backup export does not change native history"
assert_equals "$(git -C "$vault" status --porcelain=v1 --untracked-files=all)" "$vault_status" \
  "backup export does not change native working state"
assert_equals "$(sha256sum "$vault/.git/config")" "$vault_config" \
  "backup export does not change native remotes"
