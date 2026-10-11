# Self-plugin choices are exact, itemized decisions shared by inspection,
# preview, and live import. They never waive malformed input or authority.

source="$SANDBOX/self-plugins"
mkdir -p "$source"
jq '.plugins += [
  {id:"tsouth89.resurrect",url:"https://github.com/btsouth/omarchy-resurrect",commit:"1111111111111111111111111111111111111111"},
  {id:"tombychowski.montage",url:"https://github.com/tombychowski/omarchy-montage",commit:"2222222222222222222222222222222222222222"}
]' "$REPO_DIR/tests/fixtures/ress-v1/loadout/profile.json" >"$source/profile.json"

mntg port ress inspect "$source" --json
assert_ok "inspection reports undecided self-plugin entries without mutation"
jq -e '.compatible and (.ready|not) and .reason=="self-plugin-decision-required" and
  .decisions=={ressPlugin:"required",montagePlugin:"required"} and
  [.losses[].code]==["ress-self-plugin","montage-self-plugin"] and
  all(.losses[]; .waivable and (.accepted|not))' <<<"$OUT" >/dev/null && _pass ||
  _fail "inspection itemizes both exact self-plugin decisions" "$OUT"

library="$SANDBOX/library"
mntg repository init "$library" --id loss-library >/dev/null
mntg repository configure target "$library" >/dev/null
head_before=$(git -C "$library" rev-parse HEAD)

mntg --dry-run port ress import loadout "$source" \
  --repository target --loadout omitted --json
assert_exit 3 "dry-run import requires the same self-plugin decisions"
dry_missing="$OUT"
assert_no_file "$library/loadouts/omitted/profile.json" "undecided preview publishes nothing"

mntg --yes port ress import loadout "$source" \
  --repository target --loadout omitted --json
assert_exit 3 "general confirmation does not answer self-plugin decisions"
live_missing="$OUT"
assert_equals "$(jq -S '{warnings,losses,decisions,compatible,ready,reason}' <<<"$live_missing")" \
  "$(jq -S '{warnings,losses,decisions,compatible,ready,reason}' <<<"$dry_missing")" \
  "preview and live planning use identical decision data"
assert_equals "$(git -C "$library" rev-parse HEAD)" "$head_before" \
  "undecided live import preserves destination history"

mntg --yes port ress import loadout "$source" --repository target --loadout omitted \
  --ress-plugin omit --json
assert_exit 3 "deciding only one applicable self-plugin remains incomplete"
assert_equals "$(jq -r '.decisions.montagePlugin' <<<"$OUT")" "required" \
  "result identifies the remaining exact decision"

mntg --dry-run port ress import loadout "$source" --repository target --loadout omitted \
  --ress-plugin omit --montage-plugin omit --json
assert_ok "exact omission decisions produce a publishable preview"
omit_preview="$OUT"
jq -e '.ready and .publication.planned and (.publication.published|not) and
  .decisions=={ressPlugin:"omit",montagePlugin:"omit"} and
  all(.losses[]; .accepted)' <<<"$OUT" >/dev/null && _pass ||
  _fail "preview records accepted exact omission decisions" "$OUT"

mntg --yes port ress import loadout "$source" --repository target --loadout omitted \
  --ress-plugin omit --montage-plugin omit --json
assert_ok "exact self-plugin omission permits import"
assert_equals "$(jq -S '{warnings,losses,decisions,compatible,ready}' <<<"$OUT")" \
  "$(jq -S '{warnings,losses,decisions,compatible,ready}' <<<"$omit_preview")" \
  "published import retains preview decision data"
assert_file_lacks "$library/loadouts/omitted/profile.json" "tsouth89.resurrect" \
  "Ress plugin omission does not map ownership to Montage"
assert_file_lacks "$library/loadouts/omitted/profile.json" "tombychowski.montage" \
  "Montage self-plugin omission is honored independently"

mntg --yes port ress import loadout "$source" --repository target --loadout included \
  --ress-plugin include --montage-plugin include --json
assert_ok "exact include decisions preserve both explicit definitions"
assert_file_contains "$library/loadouts/included/profile.json" "tsouth89.resurrect"
assert_file_contains "$library/loadouts/included/profile.json" "tombychowski.montage"

credential="$SANDBOX/credential"
mkdir -p "$credential"
jq '.plugins[0].url="https://user:TOPSECRET@example.com/plugin"' \
  "$source/profile.json" >"$credential/profile.json"
mntg --yes port ress import loadout "$credential" --repository target --loadout unsafe \
  --ress-plugin include --montage-plugin include --json
assert_fails "credential-bearing input is non-waivable despite explicit decisions"
assert_equals "$(jq -r '.reason' <<<"$OUT")" "malformed-or-unsafe-profile"
assert_no_output "TOPSECRET" "non-waivable credential refusal does not echo material"
assert_no_file "$library/loadouts/unsafe/profile.json" "unsafe input publishes nothing"

mntg --yes port ress import loadout "$source" --repository target --loadout broad \
  --accept-loss all --json
assert_fails "retired broad loss acceptance is not a wildcard"
assert_output "usage: mntg port ress import loadout" \
  "unsupported decision syntax is rejected by the focused parser"
assert_no_file "$library/loadouts/broad/profile.json" "unsupported broad consent publishes nothing"
