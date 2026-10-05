source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha beta gamma
P="$SANDBOX/update"; write_package_loadout "$P" Update alpha beta
apply_yes "$P"; ID=$(first_loadout_id); REGISTRY=$(registry_path)

write_package_loadout "$P" Update alpha gamma
ress apply --yes "$P"
assert_fails "ordinary apply never replaces changed known-source content"
assert_output "use: ress loadout update $ID"
grep -qxF beta "$FAKE_STATE/native.txt" && _pass || _fail "refused apply leaves old resource installed"

BEFORE=$(sha256sum "$REGISTRY" | awk '{print $1}')
ress loadout update --dry-run "$ID"
assert_ok "update dry run previews claim changes"
assert_output "RETAIN    package:alpha"
assert_output "ADD       package:gamma"
assert_output "WITHDRAW  package:beta"
assert_equals "$(sha256sum "$REGISTRY" | awk '{print $1}')" "$BEFORE" "update dry run changes no state"

ress loadout update --yes "$ID"
assert_ok "confirmed update reconciles withdrawn and added claims"
grep -qxF gamma "$FAKE_STATE/native.txt" && _pass || _fail "added package is installed"
if grep -qxF beta "$FAKE_STATE/native.txt"; then _fail "withdrawn owned package is removed"; else _pass; fi
assert_equals "$(jq -r --arg id "$ID" '.loadouts[]|select(.id==$id)|.profile.packages.native|join(",")' "$REGISTRY")" \
  "alpha,gamma" "stored normalized snapshot is updated"

# A withdrawn resource that changed externally remains unresolved until the
# user makes the same keep/remove decision offered by full loadout removal.
rm -f "$REGISTRY"; rm -rf "$HOME/.config/omarchy/plugins"; : >"$CALLS"
PP="$SANDBOX/update-plugin"; mkdir -p "$PP"
SHA=$(seed_remote plugin update-plugin acme.update)
jq -n --arg url "$(remote_url update-plugin)" --arg sha "$SHA" '
 {schemaVersion:1,kind:"omarchy-loadout",name:"Update Plugin",author:"A",description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4",
 packages:{native:[],aur:[]},plugins:[{id:"acme.update",url:$url,commit:$sha}],webapps:[],theme:{name:"",url:"",commit:""}}' >"$PP/profile.json"
apply_yes "$PP"; PID=$(first_loadout_id); REGISTRY=$(registry_path)
printf '\nchanged\n' >>"$HOME/.config/omarchy/plugins/acme.update/manifest.json"
jq '.plugins=[]' "$PP/profile.json" >"$SANDBOX/updated-plugin.json" && mv "$SANDBOX/updated-plugin.json" "$PP/profile.json"

ress loadout update --yes "$PID"
assert_fails "modified withdrawn claim leaves update pending"
assert_output "withdrawn resources could not be resolved"
assert_equals "$(jq '[.claims[]|select(.loadoutId=="'"$PID"'")]|length' "$REGISTRY")" "1" \
  "unresolved withdrawn claim remains tracked"

ress loadout update --yes "$PID" --keep-modified
assert_ok "explicit keep resolves a modified update withdrawal"
assert_dir "$HOME/.config/omarchy/plugins/acme.update" "kept withdrawn plugin becomes unmanaged"
assert_equals "$(jq '[.claims[]|select(.loadoutId=="'"$PID"'")]|length' "$REGISTRY")" "0" \
  "resolved withdrawal removes the claim"
