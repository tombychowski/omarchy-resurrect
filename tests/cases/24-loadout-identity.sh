source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish repo alpha beta
P1="$SANDBOX/identity-a"; P2="$SANDBOX/identity-b"; P3="$SANDBOX/identity-c"
write_package_loadout "$P1" "Same Name" alpha
mkdir -p "$P2"
jq '{ignored:{publisher:"noise"}} + . | .packages.native |= reverse' "$P1/profile.json" >"$P2/profile.json"

apply_yes "$P1"
assert_ok "first normalized profile is applied"
ID1=$(first_loadout_id)
COUNT1=$(jq '.loadouts|length' "$(registry_path)")

ress apply --yes "$P2"
assert_ok "unknown fields and ordering are an exact reapply"
assert_output "already tracked as $ID1"
assert_equals "$(jq '.loadouts|length' "$(registry_path)")" "$COUNT1" "exact digest is not duplicated"

write_package_loadout "$P3" "Same Name" beta
apply_yes "$P3"
assert_ok "a distinct profile with the same display name is tracked separately"
ID2=$(jq -r '.loadouts[1].id' "$(registry_path)")
[[ $ID1 != "$ID2" && $ID1 == same-name-* && $ID2 == same-name-* ]] && _pass ||
  _fail "local ids are readable and collision-safe" "$ID1 / $ID2"

P4="$SANDBOX/identity-plugin"; mkdir -p "$P4"
SHA=$(seed_remote plugin identity-plugin acme.identity)
jq -n --arg sha "$SHA" '
  {schemaVersion:1,kind:"omarchy-loadout",name:"Credential Test",author:"A",description:"",
   createdAt:"2026-01-01T00:00:00Z",omarchy:"4",packages:{native:[],aur:[]},
   plugins:[{id:"acme.identity",url:"https://TOKEN@github.com/example/identity-plugin",commit:$sha}],
   webapps:[],theme:{name:"",url:"",commit:""}}' >"$P4/profile.json"
ress apply --dry-run "$P4"
assert_ok "credential-bearing represented URL can be sanitized for review"
assert_no_output "TOKEN@" "credentials are never printed"
