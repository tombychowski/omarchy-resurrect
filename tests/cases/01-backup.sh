# A backup captures each category into the vault and commits it.

seed_machine
machine_install foreign some-aur-tool
seed_plugin example.plugin
seed_webapp Excalidraw https://excalidraw.com

mntg init
assert_ok "mntg init"

VAULT="$XDG_DATA_HOME/montage/vault"
assert_dir "$VAULT/.git" "init creates a git vault"

# Deliberately broaden capture across Montage's own roots. The dynamic
# exclusions must prevent recursive vault capture and operational-state leaks
# while preserving unrelated content beside them.
printf '%s\n' '.local' '.config/montage' >>"$XDG_CONFIG_HOME/montage/include"
printf 'keep me\n' >"$HOME/.local/bin/user-tool"
printf 'old replacement\n' >"$HOME/.local/bin/user-tool.montage-bak"
ln -s "$MNTG" "$HOME/.local/bin/mntg"
mkdir -p "$HOME/.local/share"
mntg repository init loadouts "$HOME/.local/share/user-catalog" --id user-catalog >/dev/null
mntg repository configure user-catalog "$HOME/.local/share/user-catalog" loadouts >/dev/null
ln -s /etc "$HOME/.local/share/user-catalog/loadouts/escaping-link"

mntg backup -m "first"
assert_ok "mntg backup"

assert_file "$VAULT/packages/native.txt"
assert_file_contains "$VAULT/packages/foreign.txt" "some-aur-tool"
assert_file_contains "$VAULT/home/.bashrc" "alias ll"
assert_file "$VAULT/home/.config/hypr/hyprland.conf"
assert_file_contains "$VAULT/plugins/plugins.tsv" "example.plugin"
assert_file "$VAULT/webapps/apps/Excalidraw.desktop"
assert_file "$VAULT/omarchy/shell.json"
assert_file "$VAULT/home/.local/bin/user-tool" "unrelated broad-include content is captured"
assert_no_file "$VAULT/home/.local/bin/user-tool.montage-bak" \
  "Montage replacement files are excluded"
assert_no_file "$VAULT/home/.local/bin/mntg" "the Montage CLI link is excluded"
assert_no_file "$VAULT/home/.config/montage/config" "Montage configuration is excluded"
assert_no_file "$VAULT/home/.local/state/montage/loadouts.json" \
  "Montage operational state is excluded"
assert_no_file "$VAULT/home/.local/share/montage/vault/.git/HEAD" \
  "the configured vault cannot capture itself recursively"
assert_no_file "$VAULT/home/.local/share/user-catalog/montage.json" \
  "another configured Montage repository nested below a captured root is excluded"
assert_file_lacks "$VAULT/report/symlinks-skipped.txt" "user-catalog" \
  "reporting does not recurse into configured Montage repositories"

# The vault is a git repo with the backup committed.
assert_equals "$(git -C "$VAULT" rev-list --count HEAD)" "1" "one commit"
assert_equals "$(git -C "$VAULT" log -1 --pretty=%s)" "first" "commit subject"

mntg status
assert_ok "mntg status"
assert_output "backups    1"

mntg status --json
assert_ok "mntg status --json"
assert_equals "$(jq -r '.hasVault' <<<"$OUT")" "1" "status reports a vault"
assert_equals "$(jq -r '.manifest.machine.user' <<<"$OUT")" "$USER" "manifest records the user"
