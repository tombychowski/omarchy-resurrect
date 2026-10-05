source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha
P="$SANDBOX/check"; write_package_loadout "$P" Check alpha
apply_yes "$P"
ID=$(first_loadout_id)

printf 'alpha\t9.9-2\n' >"$FAKE_STATE/package-versions.tsv"
ress loadout check "$ID" --json
assert_ok "package version changes remain healthy under name-based claims"
assert_output '"currentState": "present"'

grep -vxF alpha "$FAKE_STATE/native.txt" >"$FAKE_STATE/native.next" && mv "$FAKE_STATE/native.next" "$FAKE_STATE/native.txt" || : >"$FAKE_STATE/native.txt"
: >"$CALLS"
ress loadout check "$ID" --json
assert_fails "external package removal is detected"
assert_output '"currentState": "missing"'
assert_output '"healthState": "missing"'
assert_output '"state": "drifted"'
assert_not_called "pacman -S" "check never repairs"

P2="$SANDBOX/unverifiable"; mkdir -p "$P2"
SHA=$(seed_remote plugin unverifiable-plugin acme.unverifiable)
jq -n --arg url "$(remote_url unverifiable-plugin)" --arg sha "$SHA" '
  {schemaVersion:1,kind:"omarchy-loadout",name:"Unverifiable",author:"A",description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4",
   packages:{native:[],aur:[]},plugins:[{id:"acme.unverifiable",url:$url,commit:$sha}],webapps:[],theme:{name:"",url:"",commit:""}}' \
  >"$P2/profile.json"
apply_yes "$P2"
PLUGIN_ID=$(jq -r '.loadouts[]|select(.name=="Unverifiable")|.id' "$(registry_path)")
mv "$HOME/.config/omarchy/plugins/acme.unverifiable" "$SANDBOX/unverifiable-plugin"
ln -s "$SANDBOX/unverifiable-plugin" "$HOME/.config/omarchy/plugins/acme.unverifiable"
ress loadout check "$PLUGIN_ID" --json
assert_fails "symlinked tracked resource is unverifiable"
assert_output '"currentState": "unverifiable"'
assert_output '"healthState": "unverifiable"'

ress status --json
assert_ok "backup status survives loadout state"
assert_output '"loadouts"'

printf '{bad json\n' >"$(registry_path)"
ress status --json
assert_ok "malformed optional registry does not erase backup status"
assert_output '"available": false'
