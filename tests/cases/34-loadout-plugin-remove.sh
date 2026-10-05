source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_shell_running
P="$SANDBOX/plugin-remove"; mkdir -p "$P"
SHA=$(seed_remote plugin removable-plugin acme.remove)
jq -n --arg url "$(remote_url removable-plugin)" --arg sha "$SHA" '
 {schemaVersion:1,kind:"omarchy-loadout",name:"Plugin",author:"A",description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4",
 packages:{native:[],aur:[]},plugins:[{id:"acme.remove",url:$url,commit:$sha}],webapps:[],theme:{name:"",url:"",commit:""}}' >"$P/profile.json"
apply_yes "$P"; ID=$(first_loadout_id)
printf '\nchanged\n' >>"$HOME/.config/omarchy/plugins/acme.remove/manifest.json"

ress loadout remove --yes "$ID"
assert_exit 2 "modified plugin requires a decision"
assert_output "DECISION-REQUIRED  plugin:acme.remove"
assert_dir "$HOME/.config/omarchy/plugins/acme.remove" "modified plugin is preserved"

ress loadout remove --yes "$ID" --keep-modified
assert_ok "explicit keep releases cleanup authority"
assert_dir "$HOME/.config/omarchy/plugins/acme.remove"

# A clean pinned plugin is delegated to Omarchy for unload/rescan semantics.
rm -rf "$HOME/.config/omarchy/plugins/acme.remove"; rm -f "$(registry_path)"; : >"$CALLS"
apply_yes "$P"; ID=$(first_loadout_id); : >"$CALLS"
mkdir -p "$HOME/.local/share/acme.remove-data"
printf 'keep me\n' >"$HOME/.local/share/acme.remove-data/settings"
ress loadout remove --yes "$ID"
assert_ok "clean pinned plugin is removable"
assert_called "omarchy plugin remove --yes acme.remove"
assert_no_file "$HOME/.config/omarchy/plugins/acme.remove" "Omarchy removed the plugin"
assert_file "$HOME/.local/share/acme.remove-data/settings" "plugin cleanup preserves unrelated application data"

apply_yes "$P"; ID=$(first_loadout_id)
printf 'acme.remove\n' >"$FAKE_STATE/fail-plugin-remove.txt"
ress loadout remove --yes "$ID"
assert_fails "plugin cleanup failure remains resumable"
assert_equals "$(jq -r '.loadouts[0].state' "$(registry_path)")" "removal-pending" \
  "failed plugin cleanup remains tracked"
: >"$FAKE_STATE/fail-plugin-remove.txt"
ress loadout remove --yes "$ID"
assert_ok "plugin cleanup resumes after delegated failure clears"

# An unresponsive live shell is not equivalent to no shell: cleanup fails
# closed rather than deleting code that may still be loaded.
apply_yes "$P"; ID=$(first_loadout_id); machine_shell_stopped; : >"$CALLS"
ln -s /usr/bin/sleep "$SANDBOX/quickshell"
"$SANDBOX/quickshell" 30 & shell_pid=$!
ress loadout remove --yes "$ID"
assert_fails "an unresponsive live shell leaves plugin cleanup pending"
assert_dir "$HOME/.config/omarchy/plugins/acme.remove" "live-shell ambiguity preserves the plugin"
kill "$shell_pid" 2>/dev/null || true
wait "$shell_pid" 2>/dev/null || true

# On a genuinely headless machine ress supplies no-live-shell semantics to the
# same supported Omarchy remover rather than deleting the plugin itself.
ress loadout remove --yes "$ID"
assert_ok "clean pinned plugin is removable when no Omarchy shell is running"
assert_called "omarchy plugin remove --yes acme.remove"
assert_no_file "$HOME/.config/omarchy/plugins/acme.remove" "headless cleanup still uses Omarchy removal"
