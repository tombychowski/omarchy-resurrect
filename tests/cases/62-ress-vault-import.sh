# Current Ress vault import creates one fresh, independent Montage vault.

source_root="$SANDBOX/ress-vault"
cp -a "$REPO_DIR/tests/fixtures/ress-v1/vault/." "$source_root/"
mkdir -p "$source_root/home/.config/ress" "$source_root/home/.local/state/ress" \
  "$source_root/home/.local/share/ress" "$source_root/locks"
printf 'ress-config\n' >"$source_root/home/.config/ress/config"
printf 'ress-registry\n' >"$source_root/home/.local/state/ress/loadouts.json"
printf 'ress-owned-data\n' >"$source_root/home/.local/share/ress/data"
printf 'lock\n' >"$source_root/locks/vault.lock"
printf 'progress\n' >"$source_root/restore.progress"
printf 'private-key\n' >"$source_root/secrets.key"
git -C "$source_root" init -q -b main
git -C "$source_root" add -A
git -C "$source_root" commit -q -m source
git -C "$source_root" remote add origin https://example.invalid/ress-vault.git
source_head=$(git -C "$source_root" rev-parse HEAD)
source_status=$(git -C "$source_root" status --porcelain=v1 --untracked-files=all)
source_config=$(sha256sum "$source_root/.git/config")
source_cipher=$(sha256sum "$source_root/secrets/secrets.tar.age" | cut -d' ' -f1)

destination="$SANDBOX/montage-vault"
mntg --dry-run port ress import vault "$source_root" --destination "$destination" \
  --ress-plugin omit --montage-plugin include --json
assert_ok "current Ress vault import has a dry-run plan"
assert_equals "$(jq -r '.operation' <<<"$OUT")" "import-vault" \
  "dry-run identifies vault import"
assert_equals "$(jq -r '.published' <<<"$OUT")" "false" \
  "dry-run does not claim publication"
assert_no_file "$destination/montage.json" "dry-run creates no native vault"

mntg --yes port ress import vault "$source_root" --destination "$destination" \
  --ress-plugin omit --montage-plugin include --json
assert_ok "confirmed current Ress vault import succeeds"
assert_equals "$(jq -r '.published' <<<"$OUT")" "true" \
  "vault import reports publication"
repository_id=$(jq -r '.repositoryId' <<<"$OUT")
machine_id=$(jq -r '.machineId' <<<"$OUT")
assert_equals "$(jq -r '.id' "$destination/montage.json")" "$repository_id" \
  "fresh envelope has the reported repository identity"
assert_equals "$(jq -r '.machineId' "$destination/backup.json")" "$machine_id" \
  "translated backup is bound to the new machine lineage"
assert_equals "$(jq -r '.kind' "$destination/backup.json")" "montage-backup" \
  "Ress manifest is translated to the native backup kind"
assert_no_file "$destination/ress.json" "canonical Ress manifest is not native state"
assert_no_file "$destination/resurrect.json" "legacy Ress manifest is not native state"
assert_file "$destination/home/.config/example/settings.montage-bak" \
  "Ress replacement suffix is translated"
assert_no_file "$destination/home/.config/example/settings.ress-bak" \
  "Ress replacement suffix is not retained"
assert_equals "$(sha256sum "$destination/secrets/secrets.tar.age" | cut -d' ' -f1)" "$source_cipher" \
  "representable encrypted ciphertext is copied byte-for-byte"
assert_no_file "$destination/home/.config/ress/config" "Ress configuration is excluded"
assert_no_file "$destination/home/.local/state/ress/loadouts.json" \
  "Ress ownership registry is excluded"
assert_no_file "$destination/home/.local/share/ress/data" "Ress product data is excluded"
assert_no_file "$destination/locks/vault.lock" "Ress locks are excluded"
assert_no_file "$destination/restore.progress" "Ress restore progress is excluded"
assert_no_file "$destination/secrets.key" "private encryption identity is excluded"
assert_file_lacks "$destination/plugins/plugins.tsv" "tsouth89.resurrect" \
  "explicit Ress self-plugin omission is honored"
assert_file_contains "$destination/plugins/plugins.tsv" "tombychowski.montage" \
  "explicit Montage plugin inclusion is honored without remapping"
assert_equals "$(git -C "$destination" rev-list --count HEAD)" "1" \
  "current snapshot import starts one fresh Montage history"
assert_equals "$(git -C "$destination" remote | wc -l)" "0" \
  "Ress remote is not inherited"
assert_equals "$(git -C "$source_root" rev-parse HEAD)" "$source_head" \
  "source commit remains unchanged"
assert_equals "$(git -C "$source_root" status --porcelain=v1 --untracked-files=all)" "$source_status" \
  "source working tree remains unchanged"
assert_equals "$(sha256sum "$source_root/.git/config")" "$source_config" \
  "source remote remains unchanged"
