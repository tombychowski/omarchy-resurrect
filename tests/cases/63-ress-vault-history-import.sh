# Ress history translation validates each source commit in isolation and builds
# new Montage commits only after the complete requested set is acceptable.

source_root="$SANDBOX/ress-history"
cp -a "$REPO_DIR/tests/fixtures/ress-v1/vault/." "$source_root/"
: >"$source_root/plugins/plugins.tsv"
git -C "$source_root" init -q -b main
git -C "$source_root" add -A
git -C "$source_root" commit -q -m "supported one"
first=$(git -C "$source_root" rev-parse HEAD)

jq '.schemaVersion=2 | .ressVersion="9.0.0"' "$source_root/ress.json" \
  >"$source_root/ress.json.next"
mv "$source_root/ress.json.next" "$source_root/ress.json"
git -C "$source_root" add -A
git -C "$source_root" commit -q -m "unsupported middle"
bad=$(git -C "$source_root" rev-parse HEAD)

jq '.schemaVersion=1 | .ressVersion="1.2.0" | .createdAt="2026-02-01T00:00:00Z"' \
  "$source_root/ress.json" >"$source_root/ress.json.next"
mv "$source_root/ress.json.next" "$source_root/ress.json"
printf 'bat\n' >>"$source_root/packages/native.txt"
git -C "$source_root" add -A
git -C "$source_root" commit -q -m "supported three"
third=$(git -C "$source_root" rev-parse HEAD)
git -C "$source_root" remote add origin https://example.invalid/ress-history.git
source_config=$(sha256sum "$source_root/.git/config")
source_status=$(git -C "$source_root" status --porcelain=v1 --untracked-files=all)

destination="$SANDBOX/montage-history"
mntg --dry-run port ress import vault "$source_root" --destination "$destination" \
  --history --json
assert_exit 3 "unsupported middle revision requires a subset decision"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "unsupported-history-revision" \
  "default history plan names the incompatible revision boundary"
assert_equals "$(jq -r '.selectedRevisions|length' <<<"$OUT")" "3" \
  "default plan reports every chronological source revision"
assert_equals "$(jq -r '[.selectedRevisions[]|select(.compatible|not)][0].sourceCommit' <<<"$OUT")" \
  "$bad" "bad middle revision is identified exactly"
assert_no_file "$destination/montage.json" "failed complete-history plan publishes nothing"

mntg --yes port ress import vault "$source_root" --destination "$destination" \
  --history --json
assert_exit 3 "live complete-history import also stops before publication"
assert_no_file "$destination/montage.json" "bad middle revision leaves no partial repository"

mntg --dry-run port ress import vault "$source_root" --destination "$destination" \
  --history --compatible-only --accept-loss unsupported-history-revisions --json
assert_ok "explicit compatible-subset preview succeeds"
assert_equals "$(jq -r '.selectedRevisions|map(.sourceCommit)|join(",")' <<<"$OUT")" \
  "$first,$third" "preview selects only the explicitly accepted compatible subset"
assert_equals "$(jq -r '.losses[]|select(.code=="unsupported-history-revisions")|.omittedSourceCommits[0]' <<<"$OUT")" \
  "$bad" "preview itemizes the omitted source revision"
assert_no_file "$destination/montage.json" "compatible-subset preview is non-mutating"

mntg --yes port ress import vault "$source_root" --destination "$destination" \
  --history --compatible-only --accept-loss unsupported-history-revisions --json
assert_ok "confirmed compatible-subset history translation succeeds"
assert_equals "$(jq -r '.operation' <<<"$OUT")" "import-vault-history" \
  "history import has a distinct operation identity"
assert_equals "$(jq -r '.translations|length' <<<"$OUT")" "2" \
  "only compatible revisions become Montage commits"
assert_equals "$(jq -r '.translations|map(.sourceCommit)|join(",")' <<<"$OUT")" \
  "$first,$third" "translation map preserves source revision evidence"
assert_equals "$(git -C "$destination" rev-list --count HEAD)" "2" \
  "translated history contains two fresh linear commits"
first_native=$(jq -r '.translations[0].destinationCommit' <<<"$OUT")
third_native=$(jq -r '.translations[1].destinationCommit' <<<"$OUT")
[[ $first_native != "$first" && $third_native != "$third" ]] && _pass ||
  _fail "translated commits never claim original Ress hashes"
git -C "$destination" cat-file -e "$bad^{commit}" 2>/dev/null
STATUS=$?; OUT=""
assert_fails "unsupported Ress commit is not imported as a native object"
assert_equals "$(git -C "$destination" remote | wc -l)" "0" \
  "translated history inherits no Ress remote"
assert_equals "$(git -C "$source_root" status --porcelain=v1 --untracked-files=all)" "$source_status" \
  "history translation leaves source working tree unchanged"
assert_equals "$(sha256sum "$source_root/.git/config")" "$source_config" \
  "history translation leaves source remotes unchanged"
