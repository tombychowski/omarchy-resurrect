source "$TESTS_DIR/lib/loadout.sh"

seed_machine
machine_install native fd
machine_install foreign brave-bin
machine_publish repo fd
machine_publish aur brave-bin

seed_plugin acme.good
seed_plugin acme.secret "https://TOKEN@github.com/example/acme.secret"
mkdir -p "$HOME/.config/omarchy/plugins/acme.local"
printf '{"schemaVersion":1,"id":"acme.local"}\n' >"$HOME/.config/omarchy/plugins/acme.local/manifest.json"
mkdir -p "$HOME/.config/omarchy/plugins/no-manifest"
seed_plugin acme.unsafe file:///tmp/local-plugin

seed_webapp Draw https://draw.example/
mkdir -p "$HOME/.local/share/applications"
cat >"$HOME/.local/share/applications/Flagged.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Flagged
Exec=omarchy-launch-webapp https://flagged.example/ --profile-directory=Work
Icon=flagged
Type=Application
DESKTOP

machine_builtin_theme nord day
mkdir -p "$HOME/.config/omarchy/themes/local-theme"
printf 'background = "#111111"\n' >"$HOME/.config/omarchy/themes/local-theme/theme.conf"
mkdir -p "$HOME/.config/omarchy/themes/pinned-theme"
printf 'background = "#222222"\n' >"$HOME/.config/omarchy/themes/pinned-theme/theme.conf"
git -C "$HOME/.config/omarchy/themes/pinned-theme" init -q -b main
git -C "$HOME/.config/omarchy/themes/pinned-theme" add -A
git -C "$HOME/.config/omarchy/themes/pinned-theme" commit -q -m seed
git -C "$HOME/.config/omarchy/themes/pinned-theme" remote add origin https://github.com/example/pinned-theme
mkdir -p "$HOME/.local/state/omarchy/current"
printf 'nord\n' >"$HOME/.local/state/omarchy/current/theme.name"

# Every authored Share surface is library-backed, including the catalog's
# current-item comparison.
LIBRARY="$SANDBOX/loadout-library"
mntg repository init "$LIBRARY" --id compose-library --json
assert_ok "native share repository initializes"
mntg repository configure compose "$LIBRARY" --json
assert_ok "native share repository is configured"

mntg share catalog --json
assert_fails "catalog requires an explicit repository item"
mntg share --custom --select package:fd
assert_fails "authored share refuses missing library selection"
mntg share --out "$SANDBOX/legacy-profile" --name "Legacy"
assert_fails "retired standalone output syntax is unknown"
assert_no_file "$SANDBOX/legacy-profile/profile.json" \
  "refused standalone authoring writes no profile"

mntg share catalog --repository compose --loadout primary --json
assert_ok "share catalog is available"
jq -e '.schemaVersion==1 and .repositoryId=="compose-library" and
  .loadoutId=="primary" and .currentItem.state=="absent" and
  .presets.state=="valid"' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog has versioned independent source states" "$OUT"
jq -e 'any(.resources[]; .id=="package:fd" and .shareable and .channels==["native"])' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog includes explicit native packages" "$OUT"
jq -e 'any(.resources[]; .id=="package:brave-bin" and .shareable and .channels==["aur"])' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog includes explicit foreign packages" "$OUT"
jq -e 'any(.resources[]; .id=="plugin:acme.good" and .shareable)' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog includes pinned plugins" "$OUT"
jq -e 'any(.resources[]; .id=="plugin:acme.local" and (.shareable|not) and .reasonCode=="missing-remote")' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog explains local-only plugins" "$OUT"
jq -e 'any(.resources[]; .kind=="plugin" and .name=="no-manifest" and (.shareable|not) and .reasonCode=="missing-manifest")' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog explains plugins without manifests" "$OUT"
jq -e 'any(.resources[]; .id=="plugin:acme.unsafe" and (.shareable|not) and .reasonCode=="unsafe-remote")' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog explains unsafe plugin remotes" "$OUT"
jq -e 'any(.resources[]; .id=="webapp:Flagged" and (.shareable|not) and .reasonCode=="unsupported-launcher")' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog explains unsupported web apps" "$OUT"
jq -e 'any(.resources[]; .id=="theme-install:nord" and .shareable and .active)' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog includes the active bundled theme" "$OUT"
jq -e 'any(.resources[]; .id=="theme-install:pinned-theme" and .shareable) and
       any(.resources[]; .id=="theme-install:local-theme" and (.shareable|not) and .reasonCode=="local-only")' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog distinguishes pinned and local-only custom themes" "$OUT"
jq -e '.resources == (.resources|sort_by(.kind,.name,.id)) and .limits.themes==1 and
       .counts.package>=2 and .counts.plugin>=4 and .counts.theme>=4' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog ordering, counts and capability limit are stable" "$OUT"
assert_no_output "TOKEN@" "catalog strips remote credentials"
assert_no_output "cleanupPolicy" "catalog does not expose cleanup authority"
assert_no_output '"definition"' "catalog does not expose resource definitions"
assert_no_output '"command"' "catalog does not expose commands"
assert_no_output '"claimants"' "catalog does not expose ownership evidence"
DOC_FINGERPRINT=$(sed -n 's/.*"fingerprint": "\([0-9a-f]*\)".*/\1/p' \
  "$REPO_DIR/docs/contracts/cli-protocol.md" | head -1)
[[ $DOC_FINGERPRINT =~ ^[0-9a-f]{64}$ ]] && _pass ||
  _fail "documented catalog fingerprint is a valid protocol example" "$DOC_FINGERPRINT"

# Native sharing always names one repository and one stable item. Updating it
# preserves siblings and produces one commit after complete staged validation.
write_package_loadout "$SANDBOX/sibling-source" "Sibling" sibling-package
mkdir -p "$LIBRARY/loadouts/sibling"
cp "$SANDBOX/sibling-source/profile.json" "$LIBRARY/loadouts/sibling/profile.json"
git -C "$LIBRARY" add -A
git -C "$LIBRARY" commit -q -m sibling
SIBLING_BEFORE=$(sha256sum "$LIBRARY/loadouts/sibling/profile.json")
LIBRARY_COMMITS=$(git -C "$LIBRARY" rev-list --count HEAD)

mntg share --repository compose --loadout primary --name "Repository Everything" \
  --description "native library item"
assert_ok "whole-machine share writes one explicit repository item"
assert_file "$LIBRARY/loadouts/primary/profile.json" "native share publishes the portable leaf"
assert_equals "$(jq -r '.name' "$LIBRARY/loadouts/primary/profile.json")" \
  "Repository Everything" "native share keeps display metadata"
assert_equals "$(sha256sum "$LIBRARY/loadouts/sibling/profile.json")" "$SIBLING_BEFORE" \
  "native share preserves sibling loadouts"
assert_equals "$(git -C "$LIBRARY" rev-list --count HEAD)" "$((LIBRARY_COMMITS + 1))" \
  "native share records exactly one content-changing commit"

mntg share --custom --repository compose --loadout primary --name "Repository subset" \
  --select package:fd --select webapp:Draw --select theme-install:nord
assert_ok "selective share updates the explicit repository item"
jq -e '.packages.native==["fd"] and [.webapps[].name]==["Draw"] and
  .theme.name=="nord"' "$LIBRARY/loadouts/primary/profile.json" >/dev/null && _pass ||
  _fail "repository subset contains exactly the selection" "$(cat "$LIBRARY/loadouts/primary/profile.json")"

LIBRARY_HEAD=$(git -C "$LIBRARY" rev-parse HEAD)
PRIMARY_BEFORE=$(sha256sum "$LIBRARY/loadouts/primary/profile.json")
mntg share --custom --repository compose --loadout primary --select package:no-such
assert_fails "repository share refuses a stale or unknown selection"
mntg share --custom --repository compose --loadout primary
assert_fails "repository share refuses an empty selection"
mntg share --custom --repository compose --loadout primary \
  --select theme-install:nord --select theme-install:day
assert_fails "repository share refuses multiple schema-v1 themes"
assert_equals "$(git -C "$LIBRARY" rev-parse HEAD)" "$LIBRARY_HEAD" \
  "refused repository selections preserve history"
assert_equals "$(sha256sum "$LIBRARY/loadouts/primary/profile.json")" "$PRIMARY_BEFORE" \
  "refused repository selections preserve the selected item"
assert_equals "$(sha256sum "$LIBRARY/loadouts/sibling/profile.json")" "$SIBLING_BEFORE" \
  "refused repository selections preserve siblings"

PROFILE="$LIBRARY/loadouts/primary"
mntg share --repository compose --loadout primary --name "Everything" --description "all resources"
assert_ok "whole-machine share updates the selected library item"
assert_equals "$(jq -r '.name' "$PROFILE/profile.json")" "Everything" "library metadata is preserved"
assert_equals "$(jq -r '[.packages.native[],.packages.aur[]]|sort|join(",")' "$PROFILE/profile.json")" \
  "bash,brave-bin,fd,git,rsync" "all preset includes every explicit package"
assert_equals "$(jq -r '[.plugins[].id]|sort|join(",")' "$PROFILE/profile.json")" \
  "acme.good,acme.secret" "all-resource share includes only safely pinned plugins"
assert_equals "$(jq -r '.theme.name' "$PROFILE/profile.json")" "nord" "all-resource share keeps the active theme"

mntg share catalog --json --repository compose --loadout primary
assert_ok "explicit all-resources start can be derived from the catalog"
ALL_ARGS=()
while IFS= read -r id; do ALL_ARGS+=(--select "$id"); done \
  < <(jq -r '.resources[]|select(.shareable and (.kind!="theme" or .active))|.id' <<<"$OUT")
mntg share --custom --repository compose --loadout primary --name "Explicit all" "${ALL_ARGS[@]}"
assert_ok "explicit all-resources selection publishes immediately"
assert_equals "$(jq -r '[.theme.name]|map(select(length>0))|length' "$PROFILE/profile.json")" "1" \
  "all-resources start retains only the active schema-v1 theme"

mntg share --custom --repository compose --loadout primary --name "Pinned resources" \
  --select package:brave-bin --select plugin:acme.secret --select webapp:Draw \
  --select theme-install:pinned-theme
assert_ok "all representable resource kinds round-trip through custom publication"
jq -e '.packages.aur==["brave-bin"] and .plugins[0].id=="acme.secret" and
       .webapps[0].name=="Draw" and .theme.name=="pinned-theme" and
       (.theme.commit|test("^[0-9a-f]{40}$"))' "$PROFILE/profile.json" >/dev/null && _pass ||
  _fail "AUR, pinned plugin, web app and pinned theme definitions render exactly" "$(cat "$PROFILE/profile.json")"

mntg share --custom --repository compose --loadout primary --name "Small" --description "chosen" \
  --select package:fd --select webapp:Draw --select theme-install:nord
assert_ok "custom subset publishes"
assert_equals "$(jq -r '.packages.native|join(",")' "$PROFILE/profile.json")" "fd" "only selected package is published"
assert_equals "$(jq -r '.webapps|map(.name)|join(",")' "$PROFILE/profile.json")" "Draw" "only selected web app is published"
assert_equals "$(jq -r '.plugins|length' "$PROFILE/profile.json")" "0" "unselected plugins are omitted"
assert_equals "$(jq -r '.name+"|"+.description' "$PROFILE/profile.json")" "Small|chosen" "custom metadata is published"

BEFORE=$(sha256sum "$PROFILE/profile.json" | awk '{print $1}')
mntg share --custom --repository compose --loadout primary --select package:no-such
assert_fails "unknown selected resource is refused"
assert_equals "$(sha256sum "$PROFILE/profile.json" | awk '{print $1}')" "$BEFORE" "refusal preserves profile"
mntg share --custom --repository compose --loadout primary --select package:fd --select package:fd
assert_fails "duplicate selection is refused"
mntg share --custom --repository compose --loadout primary
assert_fails "empty custom selection is refused"
mntg share --custom --repository compose --loadout primary --select package:fd \
  --definition '{"name":"invented"}'
assert_fails "selective publication accepts identities, never panel-supplied definitions"
mntg share --custom --repository compose --loadout primary --select theme-install:nord --select theme-install:day
assert_fails "schema-v1 custom publication refuses multiple themes"
mntg share --custom --repository compose --loadout primary --name $'unsafe\nname' --select package:fd
assert_fails "control characters in metadata are refused"

machine_install native stale-after-catalog
mntg share catalog --json --repository compose --loadout primary
assert_ok "stale-selection fixture appears in the catalog"
jq -e 'any(.resources[]; .id=="package:stale-after-catalog" and .shareable)' <<<"$OUT" >/dev/null && _pass ||
  _fail "catalog includes stale-selection fixture" "$OUT"
grep -vxF stale-after-catalog "$FAKE_STATE/native.txt" >"$FAKE_STATE/native.next"
mv "$FAKE_STATE/native.next" "$FAKE_STATE/native.txt"
mntg share --custom --repository compose --loadout primary --select package:stale-after-catalog
assert_fails "publication reinspects and refuses a selection removed after catalog"

# A previously published entry that disappears remains explicit until the exact
# catalog fingerprint is acknowledged.
mntg share --custom --repository compose --loadout primary --name "Plugin" --select plugin:acme.good
assert_ok "plugin-only current item"
printf '// changed\n' >>"$HOME/.config/omarchy/plugins/acme.good/S.qml"
git -C "$HOME/.config/omarchy/plugins/acme.good" add S.qml
git -C "$HOME/.config/omarchy/plugins/acme.good" commit -q -m changed
mntg share catalog --json --repository compose --loadout primary
assert_ok "catalog compares the current definition with the published pin"
OLD_FINGERPRINT=$(jq -r '.currentItem.unavailable[]|select(.id=="plugin:acme.good" and .reasonCode=="definition-mismatch")|.fingerprint' <<<"$OUT")
assert_equals "${#OLD_FINGERPRINT}" "64" "changed current definition is an unavailable prior entry"
git -C "$PROFILE" remote add origin git@github.com:test/compose-loadout.git
mntg share --custom --repository compose --loadout primary --name "Plugin updated" --select plugin:acme.good \
  --acknowledge-unavailable plugin:acme.good "$OLD_FINGERPRINT"
assert_ok "the current shareable definition can explicitly replace an old pin"
rm -rf "$HOME/.config/omarchy/plugins/acme.good"
mntg share catalog --json --repository compose --loadout primary
assert_ok "catalog survives a missing current resource"
FINGERPRINT=$(jq -r '.currentItem.unavailable[]|select(.id=="plugin:acme.good")|.fingerprint' <<<"$OUT")
assert_equals "${#FINGERPRINT}" "64" "unavailable current entry has a fingerprint"
PROFILE_BEFORE=$(sha256sum "$PROFILE/profile.json" | awk '{print $1}')
README_BEFORE=$(sha256sum "$PROFILE/README.md" | awk '{print $1}')
HEAD_BEFORE=$(git -C "$PROFILE" rev-parse HEAD)
INDEX_BEFORE=$(git -C "$PROFILE" diff --cached --name-only)
REMOTE_BEFORE=$(git -C "$PROFILE" remote get-url origin)
MONTAGE_CONFIG="$XDG_CONFIG_HOME/montage/config"
CONFIG_BEFORE=$(sha256sum "$MONTAGE_CONFIG" | awk '{print $1}')
mntg share --custom --repository compose --loadout primary --name "Package" --select package:fd
assert_fails "unavailable current resource needs acknowledgement"
assert_output "plugin:acme.good" "refusal names the unavailable resource"
assert_equals "$(sha256sum "$PROFILE/profile.json" | awk '{print $1}')" "$PROFILE_BEFORE" "refusal preserves profile.json"
assert_equals "$(sha256sum "$PROFILE/README.md" | awk '{print $1}')" "$README_BEFORE" "refusal preserves README"
assert_equals "$(git -C "$PROFILE" rev-parse HEAD)" "$HEAD_BEFORE" "refusal preserves Git history"
assert_equals "$(git -C "$PROFILE" diff --cached --name-only)" "$INDEX_BEFORE" "refusal preserves Git index"
assert_equals "$(git -C "$PROFILE" remote get-url origin)" "$REMOTE_BEFORE" "refusal preserves Git remote"
assert_equals "$(sha256sum "$MONTAGE_CONFIG" | awk '{print $1}')" "$CONFIG_BEFORE" "refusal preserves profile link config"
mntg share --custom --repository compose --loadout primary --name "Package" --select package:fd \
  --acknowledge-unavailable plugin:acme.good wrong
assert_fails "stale acknowledgement is refused"
mntg share --custom --repository compose --loadout primary --name "Package" --select package:fd \
  --acknowledge-unavailable plugin:acme.good "$FINGERPRINT"
assert_ok "exact unavailable withdrawal can be acknowledged"
assert_equals "$(jq -r '.packages.native|join(",")' "$PROFILE/profile.json")" "fd" "acknowledged profile is written"

# Invalid current-item state is never treated as an empty selection, and a
# profile symlink cannot make catalog discovery read arbitrary outside content.
GOOD_PROFILE="$SANDBOX/good-profile.json"
cp "$PROFILE/profile.json" "$GOOD_PROFILE"
printf '{bad json\n' >"$PROFILE/profile.json"
mntg share catalog --json --repository compose --loadout primary
assert_ok "malformed current profile is optional unavailable catalog state"
jq -e '.currentItem.state=="unavailable" and .currentItem.reasonCode=="invalid-profile"' <<<"$OUT" >/dev/null && _pass ||
  _fail "malformed current profile is not a valid empty item" "$OUT"
MALFORMED_HASH=$(sha256sum "$PROFILE/profile.json" | awk '{print $1}')
mntg share --custom --repository compose --loadout primary --select package:fd
assert_fails "selective publication refuses to replace malformed current state"
assert_equals "$(sha256sum "$PROFILE/profile.json" | awk '{print $1}')" "$MALFORMED_HASH" "malformed profile refusal writes nothing"
cp "$GOOD_PROFILE" "$PROFILE/profile.json"

jq '.plugins=[{id:"credentialed",url:"https://TOKEN@github.com/example/credentialed",commit:"0123456789abcdef0123456789abcdef01234567"}]' \
  "$GOOD_PROFILE" >"$PROFILE/profile.json"
mntg share catalog --json --repository compose --loadout primary
assert_ok "credential-bearing current profile is unavailable"
jq -e '.currentItem.state=="unavailable"' <<<"$OUT" >/dev/null && _pass ||
  _fail "credential-bearing profile is rejected" "$OUT"
assert_no_output "TOKEN@" "invalid current profile does not leak URL credentials"
cp "$GOOD_PROFILE" "$PROFILE/profile.json"

OUTSIDE="$SANDBOX/outside-profile.json"
printf 'outside-profile-secret\n' >"$OUTSIDE"
rm "$PROFILE/profile.json"
ln -s "$OUTSIDE" "$PROFILE/profile.json"
mntg share catalog --json --repository compose --loadout primary
assert_ok "symlinked current profile becomes unavailable"
jq -e '.currentItem.state=="unavailable"' <<<"$OUT" >/dev/null && _pass ||
  _fail "symlinked current profile is refused" "$OUT"
assert_no_output "outside-profile-secret" "catalog does not read through a profile symlink"
rm "$PROFILE/profile.json"
cp "$GOOD_PROFILE" "$PROFILE/profile.json"

# Every item in one library contends on its stable repository lock identity.
LOCK_FILE="$XDG_STATE_HOME/montage/repository-locks/compose-library.lock"
mkdir -p "$(dirname "$LOCK_FILE")"
exec 8>"$LOCK_FILE"
flock -n 8
mntg share --custom --repository compose --loadout primary --select package:fd
assert_fails "concurrent publications to one library are refused"
flock -u 8

# Applied profiles seed only currently satisfied compatible resources.
mntg apply --yes "$PROFILE"
assert_ok "custom profile remains schema-v1 apply compatible"
mntg share catalog --json --repository compose --loadout primary
assert_ok "catalog includes applied presets"
jq -e 'any(.presets.loadouts[]; .name=="Package" and (.resourceIds|index("package:fd")))' <<<"$OUT" >/dev/null && _pass ||
  _fail "healthy applied resource is eligible for a preset" "$OUT"
assert_equals "$(jq -r '.resources[]|select(.id=="package:fd")|.cleanupPolicy' "$(registry_path)")" "retain" \
  "protected pre-existing resource remains eligible without granting cleanup authority"

# Two compatible claims stay eligible independently. A later live definition
# change degrades both presets, and an incompatible claim remains a warning.
PLUGIN_URL=https://github.com/example/acme.secret
PLUGIN_SHA=$(git -C "$HOME/.config/omarchy/plugins/acme.secret" rev-parse HEAD)
for spec in "preset-plugin-a:Plugin A" "preset-plugin-b:Plugin B"; do
  dir=${spec%%:*}; title=${spec#*:}; mkdir -p "$SANDBOX/$dir"
  jq -n --arg title "$title" --arg url "$PLUGIN_URL" --arg sha "$PLUGIN_SHA" '
    {schemaVersion:1,kind:"omarchy-loadout",name:$title,author:"A",description:"",
     createdAt:"2026-01-01T00:00:00Z",omarchy:"4",packages:{native:[],aur:[]},
     plugins:[{id:"acme.secret",url:$url,commit:$sha}],webapps:[],theme:{name:"",url:"",commit:""}}' \
    >"$SANDBOX/$dir/profile.json"
  mntg apply --yes "$SANDBOX/$dir"
  assert_ok "$title applied for preset composition"
done
mntg share catalog --json --repository compose --loadout primary
assert_ok "compatible multi-claim presets are cataloged"
jq -e '[.presets.loadouts[]|select((.name=="Plugin A" or .name=="Plugin B") and
       (.resourceIds|index("plugin:acme.secret")))]|length==2' <<<"$OUT" >/dev/null && _pass ||
  _fail "each compatible claimant exposes the healthy plugin identity" "$OUT"

printf '// local definition changed\n' >>"$HOME/.config/omarchy/plugins/acme.secret/S.qml"
git -C "$HOME/.config/omarchy/plugins/acme.secret" add S.qml
git -C "$HOME/.config/omarchy/plugins/acme.secret" commit -q -m changed
mntg share catalog --json --repository compose --loadout primary
assert_ok "modified preset resources are inspected live"
jq -e '[.presets.loadouts[]|select(.name=="Plugin A" or .name=="Plugin B") |
       .warnings[]|select(.id=="plugin:acme.secret" and .state=="modified")]|length==2' <<<"$OUT" >/dev/null && _pass ||
  _fail "modified shared plugin is warned and not auto-selected" "$OUT"

CONFLICT="$SANDBOX/preset-conflict"; mkdir -p "$CONFLICT"
jq --arg name "Plugin Conflict" --arg url "https://github.com/example/other-plugin" \
   --arg sha "0123456789abcdef0123456789abcdef01234567" \
   '.name=$name|.plugins[0].url=$url|.plugins[0].commit=$sha' \
   "$SANDBOX/preset-plugin-a/profile.json" >"$CONFLICT/profile.json"
mntg apply --yes "$CONFLICT"
assert_fails "incompatible applied plugin remains conflicting"
mntg share catalog --json --repository compose --loadout primary
assert_ok "conflicting preset remains inspectable"
jq -e 'any(.presets.loadouts[]; .name=="Plugin Conflict" and
       any(.warnings[]; .id=="plugin:acme.secret" and .state=="conflicting"))' <<<"$OUT" >/dev/null && _pass ||
  _fail "conflicting applied resource is excluded with a warning" "$OUT"

THEME_PRESET="$SANDBOX/preset-theme"; mkdir -p "$THEME_PRESET"
jq -n '{schemaVersion:1,kind:"omarchy-loadout",name:"Theme preset",author:"A",description:"",
  createdAt:"2026-01-01T00:00:00Z",omarchy:"4",packages:{native:[],aur:[]},plugins:[],webapps:[],
  theme:{name:"nord",url:"",commit:""}}' >"$THEME_PRESET/profile.json"
mntg apply --yes "$THEME_PRESET"
assert_ok "bundled theme preset applies"
mntg share catalog --json --repository compose --loadout primary
assert_ok "theme preset is cataloged"
jq -e 'any(.presets.loadouts[]; .name=="Theme preset" and
       (.resourceIds|index("theme-install:nord")))' <<<"$OUT" >/dev/null && _pass ||
  _fail "healthy bundled theme is an eligible preset identity" "$OUT"

machine_publish repo ghost
MISSING_PRESET="$SANDBOX/preset-missing"
write_package_loadout "$MISSING_PRESET" "Missing preset" ghost
mntg apply --yes "$MISSING_PRESET"
assert_ok "missing-state fixture initially applies"
grep -vxF ghost "$FAKE_STATE/native.txt" >"$FAKE_STATE/native.next"
mv "$FAKE_STATE/native.next" "$FAKE_STATE/native.txt"
mntg share catalog --json --repository compose --loadout primary
assert_ok "missing preset resource is cataloged as a warning"
jq -e 'any(.presets.loadouts[]; .name=="Missing preset" and
       any(.warnings[]; .id=="package:ghost" and .state=="missing") and
       (.resourceIds|index("package:ghost")|not))' <<<"$OUT" >/dev/null && _pass ||
  _fail "missing applied resource is not auto-selected" "$OUT"

# A composed union is still an ordinary schema-v1 profile and can be consumed
# through the existing apply preview path.
mntg share --custom --repository compose --loadout primary --name "Preset union" \
  --select package:fd --select plugin:acme.secret --select theme-install:nord
assert_ok "manual and preset-derived identities compose into one publication"
UNION_COPY="$SANDBOX/union-copy"; mkdir -p "$UNION_COPY"
cp "$PROFILE/profile.json" "$UNION_COPY/profile.json"
mntg apply --dry-run "$UNION_COPY"
assert_ok "composed union remains compatible with schema-v1 apply preview"
assert_output "Preset union" "apply preview identifies the composed item"

# Optional registry failure does not erase independently valid machine state.
printf 'not json\n' >"$(registry_path)"
mntg share catalog --json --repository compose --loadout primary
assert_ok "malformed registry does not erase catalog"
jq -e '.presets.state=="unavailable" and (.resources|length)>0 and .currentItem.state=="valid"' <<<"$OUT" >/dev/null && _pass ||
  _fail "only applied presets become unavailable" "$OUT"

# Porcelain refusal is protocol-only on stdout and still names the resource.
STDOUT="$SANDBOX/stdout"; STDERR="$SANDBOX/stderr"
"$MNTG" --porcelain share --custom --repository compose --loadout primary \
  --select package:no-such >"$STDOUT" 2>"$STDERR"
STATUS=$?
(( STATUS != 0 )) && _pass || _fail "porcelain refusal exits non-zero"
grep -Eq '^(BEGIN|STEP|PROGRESS|LOG|DONE)\|' "$STDOUT" && _pass || _fail "porcelain refusal emits protocol"
grep -qvE '^(BEGIN|STEP|PROGRESS|LOG|DONE)\|' "$STDOUT" && _fail "porcelain stdout contains prose" "$(cat "$STDOUT")" || _pass
grep -q 'package:no-such' "$STDOUT" && _pass || _fail "porcelain refusal names selected identity" "$(cat "$STDOUT")"
