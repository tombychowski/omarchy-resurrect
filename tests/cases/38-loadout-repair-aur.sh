source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish aur brave-bin
machine_aur_rpc brave-bin
P="$SANDBOX/aur-repair"; mkdir -p "$P"
jq -n '{schemaVersion:1,kind:"omarchy-loadout",name:"AUR Repair",author:"A",description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4",
 packages:{native:[],aur:["brave-bin"]},plugins:[],webapps:[],theme:{name:"",url:"",commit:""}}' >"$P/profile.json"

mntg apply --yes --no-aur "$P"
assert_fails "declined AUR apply remains partial"
ID=$(first_loadout_id); : >"$CALLS"

mntg loadout repair --yes "$ID"
assert_fails "general yes does not authorize AUR repair"
assert_not_called "yay -S" "AUR build remains separately gated"
assert_equals "$(jq -r '.claims[0].status' "$(registry_path)")" "pending" "declined repair claim stays pending"

mntg loadout repair --yes --aur "$ID"
assert_ok "explicit AUR consent repairs the claim"
assert_called "yay -S --needed --noconfirm --answerclean None --answerdiff None -- brave-bin"
assert_equals "$(jq -r '.claims[0].status' "$(registry_path)")" "healthy" "successful AUR repair is recorded"
