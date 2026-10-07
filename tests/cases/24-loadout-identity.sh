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

mntg apply --yes "$P2"
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
mntg apply --dry-run "$P4"
assert_ok "credential-bearing represented URL can be sanitized for review"
assert_no_output "TOKEN@" "credentials are never printed"

# Native repository application resolves one exact commit and stores immutable
# repository/item provenance beside the validated snapshot.
machine_publish repo gamma delta epsilon
LIBRARY="$SANDBOX/app-library"
mntg repository init loadouts "$LIBRARY" --id app-library --json
assert_ok "repository apply fixture initializes"
mntg repository configure apps "$LIBRARY" loadouts --json
assert_ok "repository apply fixture is configured"
write_package_loadout "$SANDBOX/gamma-source" "Repository Gamma" gamma
write_package_loadout "$SANDBOX/beta-source" "Repository Beta" epsilon
mkdir -p "$LIBRARY/loadouts/gamma" "$LIBRARY/loadouts/beta"
cp "$SANDBOX/gamma-source/profile.json" "$LIBRARY/loadouts/gamma/profile.json"
cp "$SANDBOX/beta-source/profile.json" "$LIBRARY/loadouts/beta/profile.json"
git -C "$LIBRARY" add -A
git -C "$LIBRARY" commit -q -m profiles
GAMMA_COMMIT=$(git -C "$LIBRARY" rev-parse HEAD)

REGISTRY_BEFORE=$(sha256sum "$(registry_path)")
mntg apply --dry-run apps --loadout gamma
assert_ok "configured repository loadout dry run succeeds"
assert_equals "$(sha256sum "$(registry_path)")" "$REGISTRY_BEFORE" \
  "repository dry run records no desired state"
mntg apply --yes apps --loadout gamma
assert_ok "configured repository loadout applies"
GAMMA_LOCAL=$(jq -r '.loadouts[]|select(.repositoryId=="app-library" and .loadoutId=="gamma")|.id' "$(registry_path)")
[[ -n $GAMMA_LOCAL ]] && _pass || _fail "repository selection has a local applied identity"
jq -e --arg commit "$GAMMA_COMMIT" '
  .loadouts[] | select(.repositoryId=="app-library" and .loadoutId=="gamma") |
  .commit==$commit and .source=="'"$LIBRARY"'" and
  (.digest|test("^[0-9a-f]{64}$")) and .profile.name=="Repository Gamma"
' "$(registry_path)" >/dev/null && _pass ||
  _fail "applied state persists repository, item, commit, digest and snapshot" "$(cat "$(registry_path)")"

REGISTRY_STABLE=$(sha256sum "$(registry_path)")
jq '.packages.native=["delta"] | .name="Repository Gamma changed"' \
  "$LIBRARY/loadouts/gamma/profile.json" >"$LIBRARY/loadouts/gamma/next"
mv "$LIBRARY/loadouts/gamma/next" "$LIBRARY/loadouts/gamma/profile.json"
git -C "$LIBRARY" add -A
git -C "$LIBRARY" commit -q -m changed-gamma
CHANGED_COMMIT=$(git -C "$LIBRARY" rev-parse HEAD)
mntg apply --yes apps --loadout gamma
assert_fails "ordinary apply refuses silent repository profile replacement"
assert_output "changed since" "replacement refusal identifies immutable source drift"
assert_equals "$(sha256sum "$(registry_path)")" "$REGISTRY_STABLE" \
  "replacement refusal preserves the stored snapshot and claims"

mntg loadout update --yes "$GAMMA_LOCAL" apps
assert_ok "explicit update follows the stored repository and selector identity"
jq -e --arg commit "$CHANGED_COMMIT" --arg id "$GAMMA_LOCAL" '
  .loadouts[] | select(.id==$id) |
  .repositoryId=="app-library" and .loadoutId=="gamma" and .commit==$commit and
  .profile.name=="Repository Gamma changed" and .profile.packages.native==["delta"]
' "$(registry_path)" >/dev/null && _pass ||
  _fail "repository update advances commit and snapshot without changing identity" "$(cat "$(registry_path)")"
mntg loadout show "$GAMMA_LOCAL" --json --contents
assert_ok "repository provenance is queryable as JSON"
jq -e --arg commit "$CHANGED_COMMIT" '.loadout.repositoryId=="app-library" and
  .loadout.loadoutId=="gamma" and .loadout.commit==$commit and
  .loadout.profile.packages.native==["delta"]' <<<"$OUT" >/dev/null && _pass ||
  _fail "query returns immutable source identity and stored snapshot" "$OUT"
mntg loadout show "$GAMMA_LOCAL"
assert_ok "repository provenance is queryable for humans"
assert_output "repository: app-library" "human query names repository identity"
assert_output "loadout: gamma" "human query names stable loadout identity"
assert_output "commit: $CHANGED_COMMIT" "human query names resolved commit"

mntg apply --yes apps --loadout beta
assert_ok "a second stable selector from the same repository applies independently"
jq -e '[.loadouts[]|select(.repositoryId=="app-library")|.loadoutId]|sort==["beta","gamma"]' \
  "$(registry_path)" >/dev/null && _pass || _fail "repository selectors remain distinct" "$(cat "$(registry_path)")"

# The same contract applies after a remote clone: transport credentials are
# absent from state and the selected default-branch commit is pinned.
write_package_loadout "$SANDBOX/remote-source" "Remote item" delta
mkdir -p "$LIBRARY/loadouts/remote-item"
cp "$SANDBOX/remote-source/profile.json" "$LIBRARY/loadouts/remote-item/profile.json"
git -C "$LIBRARY" add -A
git -C "$LIBRARY" commit -q -m remote-item
REMOTE_COMMIT=$(git -C "$LIBRARY" rev-parse HEAD)
mkdir -p "$FAKE_STATE/remotes"
cp -a "$LIBRARY" "$FAKE_STATE/remotes/app-library-remote"
mntg apply --yes 'https://TOPSECRET@github.com/example/app-library-remote' --loadout remote-item
assert_ok "remote repository loadout applies at an exact commit"
assert_no_output "TOPSECRET" "repository transport credential is never printed"
jq -e --arg commit "$REMOTE_COMMIT" '
  .loadouts[] | select(.repositoryId=="app-library" and .loadoutId=="remote-item") |
  .commit==$commit and .source=="https://github.com/example/app-library-remote"
' "$(registry_path)" >/dev/null && _pass ||
  _fail "remote provenance stores sanitized source and exact commit" "$(cat "$(registry_path)")"

mntg apply --dry-run apps --loadout '../gamma'
assert_fails "hostile repository selector is refused before path access"
mntg apply --dry-run apps --loadout missing
assert_fails "missing stable selector is refused without choosing another loadout"
