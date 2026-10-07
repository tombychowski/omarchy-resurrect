# Native Montage vaults have a repository envelope and one current snapshot.

seed_machine
mntg init >/dev/null
VAULT="$XDG_DATA_HOME/montage/vault"

repository_id=$(jq -r '.id' "$VAULT/montage.json")
machine_id=$(jq -r '.machineId' "$VAULT/montage.json")
if [[ $repository_id =~ ^vault-[a-f0-9]{12}$ ]]; then _pass
else _fail "initialization assigns a bounded stable repository identity"; fi
if [[ $machine_id =~ ^machine-[a-f0-9]{12}$ ]]; then _pass
else _fail "initialization assigns one bounded machine lineage"; fi
assert_no_file "$VAULT/backup.json" "an empty repository does not pretend to contain a backup"

mntg backup -m first
assert_ok "backup"
assert_file "$VAULT/montage.json" "vault envelope is written as montage.json"
assert_file "$VAULT/backup.json" "snapshot manifest is written as backup.json"
assert_no_file "$VAULT/mntg.json" "the provisional native manifest name is not written"
assert_no_file "$VAULT/ress.json" "a Ress manifest is not written by native backup"
assert_equals "$(jq -r '.kind' "$VAULT/backup.json")" "montage-backup" \
  "the snapshot declares the Montage backup kind"
assert_equals "$(jq -r '.montageVersion' "$VAULT/backup.json")" "$(mntg --version)" \
  "the backup records the version the CLI reports"
assert_equals "$(jq -r '.machineId' "$VAULT/backup.json")" "$machine_id" \
  "the backup is bound to the envelope machine lineage"

mntg backup -m second >/dev/null
assert_equals "$(jq -r '.id' "$VAULT/montage.json")" "$repository_id" \
  "later backups preserve repository identity"
assert_equals "$(jq -r '.machineId' "$VAULT/montage.json")" "$machine_id" \
  "later backups preserve machine lineage"

# A configured path cannot silently become another otherwise-valid repository.
mntg repository configure primary "$VAULT" vault >/dev/null
jq '.id = "vault-replacement"' "$VAULT/montage.json" >"$VAULT/envelope.new"
mv "$VAULT/envelope.new" "$VAULT/montage.json"
mntg repository validate primary --json
assert_fails "configured repository identity replacement is rejected"
assert_equals "$(jq -r '.repository.status' <<<"$OUT")" "identity-mismatch" \
  "identity mismatch is explicit"
jq --arg id "$repository_id" '.id = $id' "$VAULT/montage.json" >"$VAULT/envelope.new"
mv "$VAULT/envelope.new" "$VAULT/montage.json"

# Wrong kinds, malformed schemas and a crossed machine lineage fail before use.
WRONG=$(make_vault "$SANDBOX/wrong-kind")
seal_vault "$WRONG" wrong
jq 'del(.machineId) | .repositoryType = "loadouts"' "$WRONG/montage.json" >"$WRONG/x"
mv "$WRONG/x" "$WRONG/montage.json"
mntg --vault "$WRONG" restore --dry-run --only packages
assert_fails "a loadout repository is rejected as a vault"
assert_output "not a valid Montage backup"

MALFORMED=$(make_vault "$SANDBOX/malformed")
seal_vault "$MALFORMED" malformed
jq '.schemaVersion = "1"' "$MALFORMED/backup.json" >"$MALFORMED/x"
mv "$MALFORMED/x" "$MALFORMED/backup.json"
git -C "$MALFORMED" add backup.json
git -C "$MALFORMED" commit -q -m "string schema"
mntg --vault "$MALFORMED" restore --dry-run --only packages
assert_fails "a string backup schema is rejected"
assert_output "not a valid Montage backup"

jq '.schemaVersion = 99' "$MALFORMED/backup.json" >"$MALFORMED/x"
mv "$MALFORMED/x" "$MALFORMED/backup.json"
git -C "$MALFORMED" add backup.json
git -C "$MALFORMED" commit -q -m "future schema"
mntg --vault "$MALFORMED" restore --dry-run --only packages
assert_fails "a future backup schema is rejected"

LINEAGE=$(make_vault "$SANDBOX/lineage")
seal_vault "$LINEAGE" lineage
jq '.machineId = "machine-another"' "$LINEAGE/backup.json" >"$LINEAGE/x"
mv "$LINEAGE/x" "$LINEAGE/backup.json"
git -C "$LINEAGE" add backup.json
git -C "$LINEAGE" commit -q -m "crossed lineage"
mntg --vault "$LINEAGE" restore --dry-run --only packages
assert_fails "a backup from another machine lineage is rejected"

MIXED=$(make_vault "$SANDBOX/mixed")
seal_vault "$MIXED" mixed
mkdir -p "$MIXED/loadouts/example"
printf '{}\n' >"$MIXED/loadouts/example/profile.json"
git -C "$MIXED" add -A
git -C "$MIXED" commit -q -m "mixed content"
mntg --vault "$MIXED" restore --dry-run --only packages
assert_fails "loadout-library content is rejected inside a vault repository"
assert_output "not a valid Montage backup"

# Replacement files use only the Montage suffix and never recurse into backup.
printf 'replaced by the restore\n' >"$HOME/.bashrc"
mntg restore --yes --only config
assert_ok "restore config"
assert_file "$HOME/.bashrc.montage-bak" "a replaced file is kept under the Montage suffix"
assert_file_contains "$HOME/.bashrc.montage-bak" "replaced by the restore"
assert_file_contains "$HOME/.bashrc" "alias ll" "the vault's copy is in place"

printf 'stale\n' >"$HOME/.bashrc.ress-bak"
mntg backup -m third >/dev/null
assert_no_file "$VAULT/home/.bashrc.montage-bak" "the Montage suffix is excluded from capture"
assert_no_file "$VAULT/home/.bashrc.ress-bak" "a Ress suffix is not captured as native content"
