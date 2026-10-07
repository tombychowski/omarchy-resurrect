source "$TESTS_DIR/lib/loadout.sh"

seed_machine
P0="$SANDBOX/package-only"
write_package_loadout "$P0" Package-Only bash
apply_yes "$P0"
assert_equals "$(jq -r '.baseline.activeTheme | type' "$(registry_path)")" "null" \
  "a package-only loadout does not consume the active-theme baseline"
machine_builtin_theme baseline
mkdir -p "$HOME/.local/state/omarchy/current"
ln -s "$OMARCHY_PATH/themes/baseline" "$HOME/.local/state/omarchy/current/theme"

theme_profile() {
  local dir="$1" title="$2" theme="$3" remote="$4" sha="$5"
  mkdir -p "$dir"
  jq -n --arg title "$title" --arg theme "$theme" --arg url "$remote" --arg sha "$sha" '
    {schemaVersion:1,kind:"omarchy-loadout",name:$title,author:"A",description:"",createdAt:"2026-01-01T00:00:00Z",omarchy:"4",
     packages:{native:[],aur:[]},plugins:[],webapps:[],theme:{name:$theme,url:$url,commit:$sha}}' >"$dir/profile.json"
}

SHA1=$(seed_remote theme theme-one); SHA2=$(seed_remote theme theme-two)
P1="$SANDBOX/theme-one"; P2="$SANDBOX/theme-two"
theme_profile "$P1" Theme-One theme-one "$(remote_url theme-one)" "$SHA1"
theme_profile "$P2" Theme-Two theme-two "$(remote_url theme-two)" "$SHA2"
apply_yes "$P1"; apply_yes "$P2"
REGISTRY=$(registry_path)
ID1=$(jq -r '.loadouts[]|select(.name=="Theme-One")|.id' "$REGISTRY")
ID2=$(jq -r '.loadouts[]|select(.name=="Theme-Two")|.id' "$REGISTRY")
assert_equals "$(jq -r '.baseline.activeTheme' "$REGISTRY")" "baseline" "theme symlink compatibility supplies the baseline"
assert_equals "$(<"$HOME/.local/state/omarchy/current/theme.name")" "theme-two" "last applied theme wins"
mntg loadout check --json
assert_ok "a superseded theme request does not make its loadout drifted"
assert_output '"healthy": true'
assert_equals "$(jq -r --arg id "$ID1" '.loadouts[] | select(.id == $id) | .resources[] | select(.kind == "theme-active") | .currentEvidence.effective' <<<"$OUT")" \
  "false" "lower-precedence theme request is healthy standby intent"

: >"$CALLS"; mntg loadout remove --yes "$ID2"
assert_ok "removing effective request falls back to remaining loadout"
assert_called "omarchy theme set theme-one"
assert_called "omarchy theme remove theme-two"

: >"$CALLS"; mntg loadout remove --yes "$ID1"
assert_ok "removing final request restores baseline"
assert_called "omarchy theme set baseline"
assert_called "omarchy theme remove theme-one"

# An external selection is preserved during unrelated managed-theme cleanup.
apply_yes "$P1"; ID1=$(first_loadout_id)
machine_builtin_theme external
printf 'external\n' >"$HOME/.local/state/omarchy/current/theme.name"; : >"$CALLS"
mntg loadout remove --yes "$ID1"
assert_ok "external active-theme override is preserved"
assert_not_called "omarchy theme set" "cleanup does not override an external selection"

# A theme discovered before tracking remains protected, and two compatible
# loadouts share its installed resource without granting cleanup authority.
rm -f "$REGISTRY"
printf 'baseline\n' >"$HOME/.local/state/omarchy/current/theme.name"
apply_yes "$P1"
rm -f "$REGISTRY"
P3="$SANDBOX/theme-one-shared"; theme_profile "$P3" Theme-One-Shared theme-one "$(remote_url theme-one)" "$SHA1"
apply_yes "$P1"; apply_yes "$P3"
ID1=$(jq -r '.loadouts[]|select(.name=="Theme-One")|.id' "$REGISTRY")
ID3=$(jq -r '.loadouts[]|select(.name=="Theme-One-Shared")|.id' "$REGISTRY")
assert_equals "$(jq -r '.resources[]|select(.id=="theme-install:theme-one")|.cleanupPolicy' "$REGISTRY")" "retain" \
  "pre-existing installed theme remains protected"
: >"$CALLS"; mntg loadout remove --yes "$ID1"
assert_ok "removing one shared theme claimant releases only its claims"
assert_not_called "omarchy theme remove theme-one" "shared installed theme remains"
mntg loadout remove --yes "$ID3"
assert_ok "final pre-existing theme claimant is released without cleanup"
assert_dir "$HOME/.config/omarchy/themes/theme-one" "pre-existing theme files remain"

# Changed owned theme content requires an explicit decision.
rm -f "$REGISTRY"; rm -rf "$HOME/.config/omarchy/themes/theme-one"
printf 'baseline\n' >"$HOME/.local/state/omarchy/current/theme.name"
apply_yes "$P1"; ID1=$(first_loadout_id)
printf 'local change\n' >>"$HOME/.config/omarchy/themes/theme-one/theme.conf"
mntg loadout remove --yes "$ID1"
assert_exit 2 "changed installed theme requires a decision"
assert_dir "$HOME/.config/omarchy/themes/theme-one" "changed theme is preserved"
mntg loadout remove --yes "$ID1" --keep-modified
assert_ok "keeping a changed theme relinquishes cleanup authority"

# Already-missing theme content is released without reinstalling or deleting it.
rm -f "$REGISTRY"; rm -rf "$HOME/.config/omarchy/themes/theme-one"
printf 'baseline\n' >"$HOME/.local/state/omarchy/current/theme.name"
apply_yes "$P1"; ID1=$(first_loadout_id)
rm -rf "$HOME/.config/omarchy/themes/theme-one"
printf 'baseline\n' >"$HOME/.local/state/omarchy/current/theme.name"; : >"$CALLS"
mntg loadout remove --yes "$ID1"
assert_ok "already-missing theme cleanup completes"
assert_not_called "omarchy theme remove theme-one" "already-missing theme is not removed twice"

# Delegated cleanup failure stays pending and resumes after the cause clears.
rm -f "$REGISTRY"
apply_yes "$P1"; ID1=$(first_loadout_id)
printf 'theme-one\n' >"$FAKE_STATE/fail-theme-remove.txt"
mntg loadout remove --yes "$ID1"
assert_fails "theme cleanup failure remains resumable"
assert_equals "$(jq -r '.loadouts[0].state' "$REGISTRY")" "removal-pending" "failed theme cleanup remains tracked"
: >"$FAKE_STATE/fail-theme-remove.txt"
mntg loadout remove --yes "$ID1"
assert_ok "theme cleanup resumes after delegated failure clears"

# If the recorded fallback is unavailable, removal preserves the active theme
# and remains pending instead of leaving the desktop without a usable theme.
rm -f "$REGISTRY"
machine_builtin_theme baseline
printf 'baseline\n' >"$HOME/.local/state/omarchy/current/theme.name"
apply_yes "$P1"; ID1=$(first_loadout_id)
rm -rf "$OMARCHY_PATH/themes/baseline"; : >"$CALLS"
mntg loadout remove --yes "$ID1"
assert_fails "unavailable theme fallback leaves removal pending"
assert_equals "$(<"$HOME/.local/state/omarchy/current/theme.name")" "theme-one" "active theme is preserved when fallback cannot load"
assert_dir "$HOME/.config/omarchy/themes/theme-one" "active theme files are not deleted without a fallback"
