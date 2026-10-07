# Frozen Ress v1 fixtures define the bounded compatibility baseline. They are
# inspected only by the port adapter and never accepted by native readers.

FIXTURES="$REPO_DIR/tests/fixtures/ress-v1"

mntg port ress inspect "$FIXTURES/loadout" --json
assert_ok "frozen Ress v1 loadout is recognized"
jq -e '.schemaVersion==1 and .kind=="montage-port-report" and
  .artifactType=="loadout" and .artifactVersion==1 and .compatible' \
  <<<"$OUT" >/dev/null && _pass || _fail "loadout inspection is one versioned result" "$OUT"

mntg port ress inspect "$FIXTURES/vault" --json
assert_ok "frozen canonical Ress v1 vault is recognized"
assert_equals "$(jq -r '.sourceManifestName' <<<"$OUT")" "ress.json" \
  "canonical manifest spelling is identified"
jq -e '[.losses[].code]|sort==["montage-self-plugin","ress-self-plugin"]' \
  <<<"$OUT" >/dev/null && _pass || _fail "both self-plugin identities are explicit" "$OUT"
assert_file "$FIXTURES/vault/home/.config/example/settings.ress-bak" \
  "current Ress replacement suffix is frozen"

mntg port ress inspect "$FIXTURES/legacy-vault" --json
assert_ok "frozen legacy-manifest Ress v1 vault is recognized"
assert_equals "$(jq -r '.sourceManifestName' <<<"$OUT")" "resurrect.json" \
  "legacy manifest spelling is identified"
assert_equals "$(jq -r '.warnings[0].code' <<<"$OUT")" "legacy-manifest-name" \
  "legacy manifest translation is previewed"
assert_file "$FIXTURES/legacy-vault/home/.config/example/settings.resurrect-bak" \
  "legacy Ress replacement suffix is frozen"

for revision in 01-ress.json 02-ress.json; do
  revision_root="$SANDBOX/${revision%.json}"
  mkdir -p "$revision_root"
  cp "$FIXTURES/history/$revision" "$revision_root/ress.json"
  mntg port ress inspect "$revision_root/ress.json" --json
  assert_ok "supported historical control $revision is recognized"
  assert_equals "$(jq -r '.artifactType' <<<"$OUT")" "vault-manifest" \
    "historical control is classified without native vault interpretation"
  mntg port ress plan "$revision_root/ress.json" \
    --destination "$SANDBOX/${revision%.json}-target" --json
  assert_exit 2 "a standalone historical control cannot become an executable plan"
  assert_equals "$(jq -r '.reason' <<<"$OUT")" "incomplete-artifact" \
    "manifest-only planning reports its incomplete-artifact boundary"
done
future_root="$SANDBOX/future-history"
mkdir -p "$future_root"
cp "$FIXTURES/history/03-future.json" "$future_root/ress.json"
mntg port ress inspect "$future_root/ress.json" --json
assert_fails "future Ress history fixture is outside the frozen boundary"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "unsupported-version" \
  "future version refusal names the compatibility boundary"
assert_equals "$(jq -r '.supportedArtifactVersion' <<<"$OUT")" "1" \
  "supported Ress baseline is machine-readable"

assert_file_contains "$FIXTURES/README.md" "Ress 1.2.0" \
  "the compatibility baseline is documented beside its fixtures"
assert_file_lacks "$REPO_DIR/lib/montage/port/adapters/ress_v1/format.sh" "profile_document_valid" \
  "the port adapter does not delegate fixture validation to the native profile reader"
validator_body=$(sed -n '/^ress_v1_vault_validate_root()/,/^}/p' \
  "$REPO_DIR/lib/montage/port/adapters/ress_v1/format.sh")
[[ $validator_body != *"vault_repository_validate_root"* ]] && _pass ||
  _fail "Ress fixture validation does not delegate to the native vault reader" "$validator_body"
