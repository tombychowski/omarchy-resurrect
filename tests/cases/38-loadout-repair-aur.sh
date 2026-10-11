source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_publish aur brave-bin
machine_aur_rpc brave-bin
P="$SANDBOX/aur-repair"; mkdir -p "$P"
jq -n '{schemaVersion:1,kind:"omarchy-loadout",name:"AUR Repair",author:"A",description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4",
 packages:{native:[],aur:["brave-bin"]},plugins:[],webapps:[],theme:{name:"",url:"",commit:""}}' >"$P/profile.json"

mntg --porcelain apply --yes --no-aur "$P"
assert_fails "declined AUR apply remains partial"
assert_output "DONE|partial|apply finished with unresolved resources" \
  "deferred apply is machine readable"
ID=$(first_loadout_id); : >"$CALLS"
assert_equals "$(jq -r '.claims[0].status' "$(registry_path)")" "deferred" \
  "declined apply is unresolved desired state"

mntg status --json
assert_ok "status reports deferred AUR work"
assert_equals "$(jq -r '.attention' <<<"$OUT")" "repair-needed" \
  "deferred AUR claim is not healthy"

mntg loadout repair --yes "$ID"
assert_fails "general yes does not authorize AUR repair"
assert_not_called "yay -S" "AUR build remains separately gated"
assert_equals "$(jq -r '.claims[0].status' "$(registry_path)")" "deferred" \
  "declined repair claim stays deferred"

mntg loadout repair --yes --review-aur "$ID"
assert_ok "explicit AUR review consent repairs the claim"
assert_called "yay -S --needed -- brave-bin" "review mode preserves yay review prompts"
assert_not_called "--answerdiff None" "review mode does not answer the PKGBUILD diff"
assert_equals "$(jq -r '.claims[0].status' "$(registry_path)")" "healthy" "successful AUR repair is recorded"

# A policy-denied package is removed before the build decision and remains a
# truthful deferred claim in the same machine-readable registry.
rm -f "$(registry_path)"
: >"$FAKE_STATE/foreign.txt"; : >"$CALLS"
machine_publish aur questionable
machine_aur_rpc questionable
jq '.name="AUR Deny" | .packages.aur=["brave-bin","questionable"]' "$P/profile.json" \
  >"$P/deny.json"
mv "$P/deny.json" "$P/profile.json"
mkdir -p "$XDG_CONFIG_HOME/montage"
printf 'questionable\n' >"$XDG_CONFIG_HOME/montage/aur-deny"
mntg --porcelain apply --yes --aur "$P"
assert_fails "denied AUR package leaves a partial loadout"
assert_called "yay -S --needed --noconfirm --answerclean None --answerdiff None -- brave-bin" \
  "allowed AUR package is built"
if grep '^yay ' "$CALLS" | grep -qF -- questionable; then
  _fail "denied package never reaches yay" "$(grep '^yay ' "$CALLS")"
else
  _pass
fi
assert_equals "$(jq -r '.claims[] | select(.resourceId=="package:questionable") | .status' "$(registry_path)")" \
  "deferred" "denied package remains deferred"
assert_equals "$(jq -r '.claims[] | select(.resourceId=="package:questionable") | .lastError' "$(registry_path)")" \
  "AUR package denied by policy" "denied outcome is machine readable"
