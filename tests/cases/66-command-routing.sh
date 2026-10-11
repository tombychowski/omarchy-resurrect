# The renamed CLI has one complete command tree and owns no ambiguous aliases.

mntg --help
assert_ok "Montage help is reachable"
for route in 'mntg share' 'mntg apply' 'mntg loadout' 'mntg resource' \
  'mntg repository' 'mntg repository sync' 'mntg status' 'mntg set AUR=' \
  'mntg doctor' 'mntg link' 'mntg port ress inspect' \
  'mntg port ress import loadout'; do
  assert_output "$route" "help documents $route"
done
for removed in 'mntg backup' 'mntg restore' 'mntg verify' 'mntg scan' \
  'mntg enable-units' 'mntg diff' 'mntg init' 'mntg secrets'; do
  assert_not_output "$removed" "help omits removed route $removed"
done

mntg status --json
assert_ok "status route"
assert_equals "$(jq -r 'type' <<<"$OUT")" "object" "status emits JSON"

library="$SANDBOX/routing-library"
mntg repository init "$library" --id routing-library --json
assert_ok "repository initialization route"
mntg repository configure routing "$library" --json
assert_ok "repository configuration route"
mntg repository list --json
assert_ok "repository list route"
mntg repository loadouts routing --json
assert_ok "repository content route"
mntg repository sync routing --json
assert_fails "sync route reports a missing remote through its own protocol"
assert_equals "$(jq -r '.kind' <<<"$OUT")" "montage-repository-sync" \
  "sync route emits its versioned result"

mntg share catalog --repository routing --loadout workstation --json
assert_ok "share catalog route"
mntg --dry-run apply "$REPO_DIR/tests/fixtures/ress-v1/loadout/profile.json"
assert_ok "standalone portable-loadout preview route"
mntg loadout list --json
assert_ok "applied-loadout route"
mntg port ress inspect "$REPO_DIR/tests/fixtures/ress-v1/loadout" --json
assert_ok "Ress port route"

for invalid in 'repository unknown' 'loadout unknown' 'resource unknown' \
  'port ress unknown'; do
  read -r -a words <<<"$invalid"
  mntg "${words[@]}"
  assert_fails "invalid route is refused: $invalid"
  assert_output "mntg:" "invalid route uses Montage error identity"
done

for removed in backup restore verify scan enable-units diff init secrets; do
  mntg "$removed"
  assert_fails "removed route is unknown: $removed"
  assert_output "unknown command: $removed" "removed route has no compatibility dispatch: $removed"
done

assert_no_file "$REPO_DIR/bin/ress" "Montage ships no ress command alias"
assert_no_file "$REPO_DIR/bin/montage" "Montage does not collide with ImageMagick montage"
