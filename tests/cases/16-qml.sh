# The QML half. bin/mntg is covered by everything else here; Panel.qml,
# Service.qml and Model.js are not, and a broken binding is a widget that
# vanishes from the bar with an error only the shell's log ever sees.

QMLLINT=/usr/lib/qt6/bin/qmllint
OMARCHY_SHELL=/usr/share/omarchy/shell

# Montage is an independent plugin and IPC target. These assertions run even
# when qmllint is unavailable, so coexistence identity does not depend on a
# particular desktop image.
assert_equals "$(jq -r '.id' "$REPO_DIR/manifest.json")" "tombychowski.montage" \
  "the manifest publishes the Montage plugin id"
assert_equals "$(jq -r '.name' "$REPO_DIR/manifest.json")" "montage" \
  "the manifest publishes the Montage package name"
assert_equals "$(jq -r '.barWidget.displayName' "$REPO_DIR/manifest.json")" "Montage" \
  "the bar widget is branded Montage"
assert_file_contains "$REPO_DIR/Panel.qml" 'moduleName: "tombychowski.montage"' \
  "the panel uses the Montage module id"
assert_file_contains "$REPO_DIR/Panel.qml" 'ipcTarget: "tombychowski.montage"' \
  "the panel uses the Montage IPC target"
assert_file_contains "$REPO_DIR/Service.qml" 'Qt.resolvedUrl("bin/mntg")' \
  "the service invokes only the Montage CLI"
if grep -Eq 'tsouth89\.resurrect|Qt\.resolvedUrl\("bin/ress"\)' \
    "$REPO_DIR/manifest.json" "$REPO_DIR/Panel.qml" "$REPO_DIR/Service.qml"; then
  _fail "Montage runtime identity overlaps the published Ress plugin"
else
  _pass
fi

# Every rich panel view is obtained from one documented mntg JSON command.
# Keep these checks outside qmllint availability so the consumer boundary is
# enforced in minimal CI images too.
for route in \
  '"repository", "list", "--json"' \
  '"repository", "loadouts", selectedRepositoryName, "--json"' \
  '"backup", "list", "--json"' \
  '"repository", "sync", name, "--json"' \
  '"share", "catalog", "--repository", repo' \
  '"loadout", "list", "--json", "--contents"' \
  '"loadout", "check", "--json"' \
  '"port", "ress", "plan"'; do
  grep -qF "$route" "$REPO_DIR/Service.qml" ||
    _fail "Service.qml is missing CLI consumer route: $route"
done
_pass

for parser in parseRepositoryList parseLoadoutCatalog parseBackupList parseSyncResult \
  parseShareCatalog parseLoadoutList parseLoadoutCheck parsePortReport; do
  grep -q "Model\.$parser" "$REPO_DIR/Service.qml" ||
    _fail "Service.qml does not validate $parser output"
done
_pass

if grep -Eq 'Qt\.resolvedUrl\("bin/(ress|montage)"\)|\["(git|ress|montage)"' \
    "$REPO_DIR/Panel.qml" "$REPO_DIR/Service.qml"; then
  _fail "QML invokes an old command path or invokes Git directly"
else
  _pass
fi
if grep -Eq 'montage\.json|profile\.json|backup\.json|ress\.json|resurrect\.json|loadouts\.json|/\.git([/" ]|$)' \
    "$REPO_DIR/Panel.qml" "$REPO_DIR/Service.qml"; then
  _fail "QML must not parse repository controls, leaves, history, or Git state directly"
else
  _pass
fi

for label in 'Loading repositories…' 'Repository is healthy.' 'Review divergence in terminal' \
  'Selected loadout' 'Restore this exact backup' 'Preview retention' 'Run retention in terminal' \
  'Preview Ress port' 'Publish port in terminal'; do
  grep -qF "$label" "$REPO_DIR/Panel.qml" || _fail "Panel.qml is missing documented label: $label"
  grep -qF "$label" "$REPO_DIR/docs/panel/status-language.md" ||
    _fail "panel language does not document QML label: $label"
done
_pass
for doc in principles status-language cli-integration keyboard-workflow settings; do
  [[ -f "$REPO_DIR/docs/panel/$doc.md" ]] || _fail "missing panel documentation: $doc.md"
done
_pass

# ---- 1. Model.js is plain JavaScript, so it gets real unit tests ---------

# The first `node` on PATH is not always a node. On a machine where it is a
# version-manager shim — mise, asdf, nvm — the shim can fail before node starts:
# mise refuses to read its global config untrusted, and it only asks that when
# the working directory is under $HOME, which is exactly where this suite runs.
# So the candidates are tried in the environment this case runs in, and the first
# one that actually answers is the one the tests use.
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
  echo "  (skipped: no node that runs — Model.js unit tests need one)"
fi

# ---- 2. the .qml files must at least parse and resolve ------------------

if [[ -x $QMLLINT && -d $OMARCHY_SHELL ]]; then
  # Quickshell maps the shell's config root to the `qs` module namespace, so
  # the import root is a directory containing a `qs` pointing at it.
  ROOT="$SANDBOX/qml-imports"
  mkdir -p "$ROOT"
  ln -sfn "$OMARCHY_SHELL" "$ROOT/qs"

  for f in Panel.qml Service.qml; do
    OUT=$("$QMLLINT" -I "$ROOT" -I /usr/lib/qt6/qml "$REPO_DIR/$f" 2>&1); STATUS=$?
    # Warnings here are pre-existing patterns: properties resolved at runtime on
    # a dynamically typed `bar`, and ids reached from a nested component. An
    # Error is a file that will not load.
    ERRORS=$(printf '%s\n' "$OUT" | grep -c '^Error:' || true)
    assert_equals "$ERRORS" "0" "$f has no qmllint errors"
    assert_no_output "was not found. Did you add all imports" \
      "$f resolves every type it uses"
  done

  # Every engine.<member> the panel binds to has to exist on Service.qml. The
  # panel reaches the engine through a dynamically typed property, so qmllint
  # cannot see this: a binding to a member that does not exist renders blank
  # and says nothing anywhere.
  MISSING=""
  for member in $(grep -oE 'engine\.[A-Za-z_][A-Za-z0-9_]*' "$REPO_DIR/Panel.qml" |
                  sed 's/^engine\.//' | sort -u); do
    grep -qE "(property [A-Za-z<>]+ $member\b|function $member\(|signal $member\b)" \
      "$REPO_DIR/Service.qml" || MISSING="$MISSING $member"
  done
  assert_equals "$MISSING" "" "every engine.<member> the panel binds to exists on the engine"
  # ...and the ids in the row list have to match the ones trigger() handles,
  # or a click does nothing.
  for id in aur units backup restore auto copy folder loadout-update loadout-repair loadout-remove \
    sync-preview repository-loadout-compose repository-loadout-preview repository-loadout-apply repository-backup-restore \
    share-start-all share-start-current share-start-empty share-name share-description share-search \
    share-export share-back; do
    grep -q "\"$id\"" "$REPO_DIR/Panel.qml" ||
      _fail "Panel.qml has no row id \"$id\""
  done
  _pass
  grep -q '"loadouts"' "$REPO_DIR/Panel.qml" && _pass || _fail "Panel.qml exposes a Loadouts tab"
  grep -q '"repositories"' "$REPO_DIR/Panel.qml" && _pass || _fail "Panel.qml exposes a Repositories tab"
  for state in empty invalid loading healthy stale divergent attention; do
    grep -q "\"$state\"" "$REPO_DIR/Panel.qml" "$REPO_DIR/Model.js" ||
      _fail "repository panel model does not expose $state state"
  done
  _pass
  grep -q 'rowId: "repository:"' "$REPO_DIR/Panel.qml" &&
    grep -q 'rowId: "repository-loadout:"' "$REPO_DIR/Panel.qml" &&
    grep -q 'rowId: "repository-backup:"' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "repository, loadout, and backup selections are not keyboard rows"
  grep -q 'restoreTerminalArgs(vaultPath, commit)' "$REPO_DIR/Service.qml" &&
    grep -q '"restore", "--backup", commit' "$REPO_DIR/Service.qml" &&
    grep -q 'title: "Restore this exact backup"' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "exact backup restore is not pinned to the selected full commit"
  grep -q 'repositoryConfigureTerminalArgs(name, path, type, remote, replace)' "$REPO_DIR/Service.qml" &&
    grep -q '"repository", "configure"' "$REPO_DIR/Service.qml" &&
    grep -q 'Model.stripCredentials(remote)' "$REPO_DIR/Service.qml" && _pass ||
    _fail "repository settings do not use the locked CLI configuration boundary with sanitized remotes"
  grep -q 'Model.isRessLocation(repositorySettingPath)' "$REPO_DIR/Panel.qml" &&
    grep -q 'Ress directory is a read-only migration source' "$REPO_DIR/Panel.qml" &&
    grep -q 'engine.previewPort(portSource, portDestination, false)' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "Ress locations are not explicitly isolated as one-time port sources"
  for helper in openRestore openRetention openSync openPortImport openLoadoutAction; do
    grep -q "function $helper" "$REPO_DIR/Service.qml" ||
      _fail "risky action is missing interactive terminal helper: $helper"
  done
  grep -q '\["omarchy-launch-terminal", cli' "$REPO_DIR/Service.qml" && _pass ||
    _fail "risky repository actions are not launched in an interactive terminal"
  grep -q 'previewRetention' "$REPO_DIR/Service.qml" &&
    grep -q '"--dry-run"' "$REPO_DIR/Service.qml" &&
    grep -q 'previewPort' "$REPO_DIR/Service.qml" &&
    grep -q 'previewSync' "$REPO_DIR/Service.qml" && _pass ||
    _fail "retention, port, and sync previews are not separated from terminal publication"
  grep -q '"restore", "--backup", commit' "$REPO_DIR/Service.qml" &&
    grep -q '"backup", "retain", "--keep"' "$REPO_DIR/Service.qml" &&
    grep -q '"port", "ress", "import"' "$REPO_DIR/Service.qml" && _pass ||
    _fail "terminal commands do not retain exact restore, retention, and port identities"
  grep -q 'Model.consent(engine.aurMode' "$REPO_DIR/Panel.qml" &&
    grep -q 'openRepositoryApply' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "panel no longer preserves visible AUR consent around terminal apply"
  grep -q 'loadout", "list", "--json", "--contents"' "$REPO_DIR/Service.qml" && _pass ||
    _fail "Service.qml reads applied loadouts through documented CLI JSON"
  grep -q 'loadout", "check", "--json"' "$REPO_DIR/Service.qml" && _pass ||
    _fail "Service.qml reads live loadout health through documented CLI JSON"
  grep -q '"share", "catalog", "--repository", repo' "$REPO_DIR/Service.qml" && _pass ||
    _fail "Service.qml reads the Share catalog through documented CLI JSON"
  grep -q 'function refreshShareCatalog' "$REPO_DIR/Service.qml" &&
    grep -q 'if (name === "share" && opened) engine.refreshShareCatalog()' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "the catalog is requested only through the active Share workflow"
  grep -q 'function shareCustom(repositoryName, loadoutId, name, description, ids, acknowledgements)' "$REPO_DIR/Service.qml" &&
    grep -q 'args = args.concat(\["--select", selected\[i\]\])' "$REPO_DIR/Service.qml" &&
    grep -q '"--acknowledge-unavailable", resourceId' "$REPO_DIR/Service.qml" && _pass ||
    _fail "selective export uses argument-array ids and acknowledgement fingerprints"
  if grep -Eq 'sh -c|bash -c|shellCommand' "$REPO_DIR/Service.qml"; then
    _fail "Service.qml must not assemble Share arguments as a shell string"
  else
    _pass
  fi
  for choice in 'All shareable resources' 'Current export' 'Empty selection' 'OR AN APPLIED LOADOUT'; do
    grep -q "$choice" "$REPO_DIR/Panel.qml" || _fail "Share composer is missing explicit choice: $choice"
  done
  _pass
  grep -q 'shareName = current.name' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "Share composer uses the CLI catalog's metadata default"
  grep -q "Selecting one that is shareable exports this machine's current definition, not the applied snapshot" \
      "$REPO_DIR/Panel.qml" && _pass ||
    _fail "modified preset selection explains that the current definition is exported"
  grep -q 'filterShareResources(engine.shareCatalog, root.shareCategory, root.shareSearch, 200)' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "Share category detail is search-filtered and bounded"
  grep -q 'Keys.onEscapePressed: keyCatcher.forceActiveFocus()' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "Share text fields expose keyboard focus return"
  grep -q 'modelData.healthState' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "Panel.qml progressively reveals live resource health"
  grep -q 'loadoutTerminalArgs("\|openLoadoutAction' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "loadout mutations are routed through the service terminal boundary"
  if grep -Eq 'loadouts\.json|profile\.json|\.local/share/applications|\.config/omarchy/(plugins|themes)' \
      "$REPO_DIR/Panel.qml" "$REPO_DIR/Service.qml"; then
    _fail "QML must not read profile, registry, or machine resource files directly"
  else
    _pass
  fi
else
  echo "  (skipped: no qmllint or no Omarchy shell to resolve imports against)"
fi
