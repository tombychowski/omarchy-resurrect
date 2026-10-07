source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_shell_running
P="$SANDBOX/resources"; mkdir -p "$P"
PLUGIN_SHA=$(seed_remote plugin resource-plugin acme.resource)
THEME_SHA=$(seed_remote theme resource-theme)
jq -n --arg purl "$(remote_url resource-plugin)" --arg psha "$PLUGIN_SHA" \
      --arg turl "$(remote_url resource-theme)" --arg tsha "$THEME_SHA" '
  {schemaVersion:1,kind:"omarchy-loadout",name:"Resources",author:"A",description:"",
   createdAt:"2026-01-01T00:00:00Z",omarchy:"4",packages:{native:[],aur:[]},
   plugins:[{id:"acme.resource",url:$purl,commit:$psha}],
   webapps:[{name:"Draw",url:"https://draw.example",icon:"draw"}],
   theme:{name:"resource-theme",url:$turl,commit:$tsha}}' >"$P/profile.json"

mntg apply --yes "$P"
assert_ok "all integration resource kinds apply"
assert_equals "$(jq '[.resources[].kind]|unique|length' "$(registry_path)")" "4" \
  "plugin, web app, installed theme, and active theme have distinct identities"

P2="$SANDBOX/resources-conflict"; mkdir -p "$P2"
OTHER_SHA=$(seed_remote plugin other-plugin acme.resource)
jq --arg url "$(remote_url other-plugin)" --arg sha "$OTHER_SHA" --arg name "Conflict" \
  '.name=$name | .plugins[0].url=$url | .plugins[0].commit=$sha | .webapps=[] | .theme={name:"",url:"",commit:""}' \
  "$P/profile.json" >"$P2/profile.json"
mntg apply --dry-run "$P2"
assert_ok "conflicting definition is previewable"
assert_output "CONFLICT  plugin:acme.resource"
mntg apply --yes "$P2"
assert_fails "confirmed incompatible claim remains conflicting"
CONFLICT_ID=$(jq -r '.loadouts[]|select(.name=="Conflict")|.id' "$(registry_path)")
mntg loadout check "$CONFLICT_ID" --json
assert_fails "live checking includes stored claim conflicts"
assert_output '"claimStatus": "conflicting"'
assert_output '"healthState": "conflicting"'
assert_output '"healthy": false'

P3="$SANDBOX/webapp-conflict"; mkdir -p "$P3"
jq '.name="Web Conflict" | .plugins=[] | .theme={name:"",url:"",commit:""} |
  .webapps[0].url="https://different.example"' "$P/profile.json" >"$P3/profile.json"
mntg apply --dry-run "$P3"
assert_ok "web app definition conflict is previewable"
assert_output "CONFLICT  webapp:Draw"

printf 'local change\n' >>"$HOME/.config/omarchy/plugins/acme.resource/manifest.json"
ID=$(first_loadout_id)
mntg loadout check "$ID" --json
assert_fails "changed pinned plugin makes the loadout unhealthy"
assert_output '"currentState": "modified"'

# Native/AUR channel overlap is one name-based package resource. A later claim
# through the other channel is shared, but the channel disagreement is visible.
machine_publish repo dual
P4="$SANDBOX/channel-native"; P5="$SANDBOX/channel-aur"; mkdir -p "$P4" "$P5"
write_package_loadout "$P4" Channel-Native dual
jq '.name="Channel-AUR" | .packages.native=[] | .packages.aur=["dual"]' "$P4/profile.json" >"$P5/profile.json"
apply_yes "$P4"
mntg apply --dry-run "$P5"
assert_ok "native and AUR claims share package identity"
assert_output "package channel differs from an existing claim"
mntg apply --yes "$P5"
assert_ok "channel disagreement does not reinstall a present package"
assert_equals "$(jq '[.resources[]|select(.id=="package:dual")]|length' "$(registry_path)")" "1" \
  "native and AUR overlap has one canonical resource"
