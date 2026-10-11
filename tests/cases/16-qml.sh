# The panel is a strict consumer of the loadout-only CLI protocol.

QMLLINT=/usr/lib/qt6/bin/qmllint
OMARCHY_SHELL=/usr/share/omarchy/shell

assert_equals "$(jq -r '.id' "$REPO_DIR/manifest.json")" "tombychowski.montage" \
  "manifest publishes the Montage plugin id"
assert_equals "$(jq -r '.kinds | join(",")' "$REPO_DIR/manifest.json")" "bar-widget" \
  "manifest registers no headless scheduling service"
assert_equals "$(jq -r '.entryPoints | keys | join(",")' "$REPO_DIR/manifest.json")" "barWidget" \
  "manifest has only the panel entrypoint"
assert_equals "$(jq -r '.barWidget.schema | length' "$REPO_DIR/manifest.json")" "0" \
  "manifest has no backup-age settings"
assert_file_contains "$REPO_DIR/Panel.qml" 'moduleName: "tombychowski.montage"' \
  "panel uses the Montage module id"
assert_file_contains "$REPO_DIR/Service.qml" 'Qt.resolvedUrl("bin/mntg")' \
  "panel service invokes only the Montage CLI"

for surface in '"libraries"' '"compose"' '"applied"'; do
  assert_file_contains "$REPO_DIR/Panel.qml" "$surface" "panel exposes $surface surface"
done
for route in \
  '"status", "--json"' \
  '"repository", "list", "--json"' \
  '"repository", "loadouts", selectedRepositoryName, "--json"' \
  '"repository", "sync", repository, "--json"' \
  '"share", "catalog", "--repository", repo' \
  '"loadout", "list", "--json", "--contents"' \
  '"loadout", "check", "--json"' \
  '"port", "ress", "inspect"'; do
  assert_file_contains "$REPO_DIR/Service.qml" "$route" "service owns CLI route $route"
done
for parser in parseStatus parseRepositoryList parseLoadoutCatalog parseSyncResult \
  parseShareCatalog parseLoadoutList parseLoadoutCheck parseRessMigration; do
  assert_file_contains "$REPO_DIR/Service.qml" "Model.$parser" \
    "service validates $parser output"
done

if rg -n -i 'backup|restore|vault|retention|freshness|schedule|last-attempt|last-backup' \
    "$REPO_DIR/Panel.qml" "$REPO_DIR/Service.qml" "$REPO_DIR/Model.js" \
    "$REPO_DIR/manifest.json" >/dev/null; then
  _fail "active QML or manifest retains a removed product concept"
else
  _pass
fi
if rg -n 'FileView|montage\.json|profile\.json|loadouts\.json|/\.git|\["git"' \
    "$REPO_DIR/Panel.qml" "$REPO_DIR/Service.qml" >/dev/null; then
  _fail "QML reads files or Git instead of consuming mntg"
else
  _pass
fi
if rg -n 'sh -c|bash -c|shellCommand' "$REPO_DIR/Service.qml" >/dev/null; then
  _fail "service assembles a shell command"
else
  _pass
fi

for label in 'Loading libraries…' 'Review divergence in terminal' \
  'Compose from selected loadout' 'Applied loadout state is unavailable' \
  'Inspect Ress loadout' 'Import Ress loadout in terminal' \
  'AUR package policy'; do
  assert_file_contains "$REPO_DIR/Panel.qml" "$label" "panel exposes $label"
done
for state in healthy update-available repair-needed drifted repository-attention \
  unavailable-or-invalid operation-partial-or-failed operation-active; do
  assert_file_contains "$REPO_DIR/Model.js" "\"$state\"" "model recognizes $state"
done
for row in sync-preview sync-terminal library-apply-preview library-apply \
  library-compose library-save ress-preview ress-import share-all share-current \
  share-empty share-publish applied-update applied-repair applied-remove aur-policy; do
  assert_file_contains "$REPO_DIR/Panel.qml" "\"$row\"" "keyboard row $row exists"
done

assert_file_contains "$REPO_DIR/Service.qml" \
  '["omarchy-launch-terminal", cli, "repository", "sync", name]' \
  "synchronization decisions use an interactive terminal"
assert_file_contains "$REPO_DIR/Service.qml" \
  '["omarchy-launch-terminal", cli, "port", "ress", "import", "loadout"' \
  "Ress publication uses an interactive terminal"
assert_file_contains "$REPO_DIR/Service.qml" \
  'args = args.concat(["--select", selected[i]])' \
  "Share uses an argument array for resource ids"
assert_file_contains "$REPO_DIR/Service.qml" \
  '["--acknowledge-unavailable", acknowledged[j], acknowledgements[acknowledged[j]]]' \
  "Share preserves explicit withdrawal acknowledgements"
assert_file_contains "$REPO_DIR/Panel.qml" 'modelData.healthState' \
  "Applied Loadouts reveals per-resource health"
assert_file_contains "$REPO_DIR/Panel.qml" 'Model.attentionLabel(engine.attention)' \
  "bar and panel use the CLI attention classification"

NODE=""
while IFS= read -r candidate; do
  [[ -n $candidate ]] || continue
  if "$candidate" --version >/dev/null 2>&1; then NODE="$candidate"; break; fi
done < <(type -a -p node 2>/dev/null; printf '/usr/bin/node\n/bin/node\n')
if [[ -n $NODE ]]; then
  OUT=$("$NODE" "$REPO_DIR/tests/model-test.js" 2>&1); STATUS=$?
  assert_ok "Model.js unit tests"
  assert_output "all Model.js assertions passed"
else
  echo "  (skipped: no runnable node for Model.js tests)"
fi

if [[ -x $QMLLINT && -d $OMARCHY_SHELL ]]; then
  ROOT="$SANDBOX/qml-imports"
  mkdir -p "$ROOT"
  ln -sfn "$OMARCHY_SHELL" "$ROOT/qs"
  for file in Panel.qml Service.qml; do
    OUT=$("$QMLLINT" -I "$ROOT" -I /usr/lib/qt6/qml "$REPO_DIR/$file" 2>&1); STATUS=$?
    errors=$(printf '%s\n' "$OUT" | grep -c '^Error:' || true)
    assert_equals "$errors" "0" "$file has no qmllint errors"
    assert_no_output "was not found. Did you add all imports" "$file resolves imported types"
  done

  missing=""
  while IFS= read -r member; do
    grep -qE "(property [A-Za-z<>]+ $member\b|function $member\(|signal $member\b)" \
      "$REPO_DIR/Service.qml" || missing="$missing $member"
  done < <(rg -o 'engine\.[A-Za-z_][A-Za-z0-9_]*' "$REPO_DIR/Panel.qml" |
    sed 's/^engine\.//' | sort -u)
  assert_equals "$missing" "" "every engine member used by the panel exists"
else
  echo "  (skipped: no qmllint or Omarchy shell import tree)"
fi
