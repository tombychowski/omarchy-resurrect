source "$TESTS_DIR/lib/loadout.sh"

seed_machine
P="$SANDBOX/webapp-remove"; mkdir -p "$P"
jq -n '{schemaVersion:1,kind:"omarchy-loadout",name:"Web",author:"A",description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4",
 packages:{native:[],aur:[]},plugins:[],webapps:[{name:"Draw",url:"https://draw.example",icon:"draw"}],theme:{name:"",url:"",commit:""}}' >"$P/profile.json"
apply_yes "$P"; ID=$(first_loadout_id)
sed -i 's#https://draw.example#https://changed.example#' "$HOME/.local/share/applications/Draw.desktop"
mntg loadout remove --yes "$ID"
assert_exit 2 "changed launcher requires a decision"
assert_file "$HOME/.local/share/applications/Draw.desktop" "changed launcher is preserved"

mntg loadout remove --yes "$ID" --remove-modified
assert_ok "explicit changed-resource removal is supported"
assert_called "omarchy webapp remove Draw"
assert_no_file "$HOME/.local/share/applications/Draw.desktop"

apply_yes "$P"; ID=$(first_loadout_id)
printf 'Draw\n' >"$FAKE_STATE/fail-webapp-remove.txt"
mntg loadout remove --yes "$ID"
assert_fails "web-app cleanup failure remains resumable"
assert_file "$HOME/.local/share/applications/Draw.desktop" "failed delegated cleanup preserves the launcher"
: >"$FAKE_STATE/fail-webapp-remove.txt"
mntg loadout remove --yes "$ID"
assert_ok "web-app cleanup resumes after delegated failure clears"

# Omarchy may remove the launcher and then fail a best-effort cache refresh.
# mntg judges the observable postcondition instead of retaining a ghost claim.
apply_yes "$P"; ID=$(first_loadout_id)
printf 'Draw\n' >"$FAKE_STATE/fail-after-webapp-remove.txt"
mntg loadout remove --yes "$ID"
assert_ok "a delegated post-removal failure accepts the observed absent launcher"
assert_no_file "$HOME/.local/share/applications/Draw.desktop" "postcondition confirms launcher cleanup"
jq -e '.loadouts == [] and .resources == [] and .claims == [] and .operation == null' "$(registry_path)" >/dev/null && _pass ||
  _fail "postcondition-success removal clears registry relationships" "$(jq . "$(registry_path)")"
