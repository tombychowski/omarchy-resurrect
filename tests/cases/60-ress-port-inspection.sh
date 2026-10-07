# Ress port inspection and plans are versioned, explicit, and non-mutating.

FIXTURES="$REPO_DIR/tests/fixtures/ress-v1"
source_root="$SANDBOX/source-vault"
cp -a "$FIXTURES/vault" "$source_root"
source_before=$(find "$source_root" -type f -print0 | sort -z | xargs -0 sha256sum)
destination="$SANDBOX/native-vault"

mntg --dry-run port ress plan "$source_root" --destination "$destination" --json
assert_ok "current Ress vault import plan is available as JSON"
jq -e '.schemaVersion==1 and .kind=="montage-port-report" and
  .operation=="plan" and .artifactType=="vault" and .artifactVersion==1 and
  .source==$source and .destination==$destination and
  .selectedRevisions==[{selector:"current",compatible:true,reason:null}] and
  [.mutations[].code]==["create-vault-repository","create-montage-commit"]' \
  --arg source "$source_root" --arg destination "$destination" <<<"$OUT" >/dev/null &&
  _pass || _fail "plan reports exact source, destination, selection, and mutations" "$OUT"
assert_no_file "$destination" "dry-run does not create the destination"
assert_equals "$(find "$source_root" -type f -print0 | sort -z | xargs -0 sha256sum)" \
  "$source_before" "dry-run leaves every source file unchanged"

mntg port ress plan "$source_root" --destination "$destination"
assert_ok "current Ress vault plan has readable human output"
assert_output "ress-v1 vault" "human plan identifies the format and artifact type"
assert_output "selected revisions: 1" "human plan reports selected revisions"
assert_output "losses: 2" "human plan reports self-plugin decisions"
assert_output "planned mutations: 2" "human plan reports destination mutations"
assert_no_file "$destination" "planning remains non-mutating without the global dry-run flag"

nonempty="$SANDBOX/nonempty"
mkdir "$nonempty"
printf 'keep\n' >"$nonempty/sentinel"
mntg port ress plan "$source_root" --destination "$nonempty" --json
assert_fails "a non-empty destination is refused during planning"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "destination-not-empty" \
  "destination refusal is machine-readable"
assert_file "$nonempty/sentinel" "destination refusal preserves existing content"

future="$SANDBOX/future"
mkdir "$future"
cp "$FIXTURES/history/03-future.json" "$future/ress.json"
mntg port ress plan "$future" --destination "$destination" --json
assert_fails "a future Ress version cannot be planned"
assert_equals "$(jq -r '.artifactVersion' <<<"$OUT")" "2" \
  "future version is reported"
assert_equals "$(jq -r '.supportedArtifactVersion' <<<"$OUT")" "1" \
  "supported version is reported"

hostile="$SANDBOX/hostile"
cp -a "$FIXTURES/vault" "$hostile"
ln -s "$SANDBOX/outside" "$hostile/home/escape"
mntg port ress inspect "$hostile" --json
assert_fails "a symlinked Ress artifact is hostile input"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "malformed-or-unsafe" \
  "hostile artifact refusal is explicit"
assert_no_file "$SANDBOX/outside" "hostile inspection follows no escaping link"

source_link="$SANDBOX/source-link"
ln -s "$source_root" "$source_link"
mntg port ress inspect "$source_link" --json
assert_fails "a symlink source root is refused"
assert_no_file "$destination" "all refused inspections leave destination absent"
