# The QML half. bin/ress is covered by everything else here; Panel.qml,
# Service.qml and Model.js are not, and a broken binding is a widget that
# vanishes from the bar with an error only the shell's log ever sees.

QMLLINT=/usr/lib/qt6/bin/qmllint
OMARCHY_SHELL=/usr/share/omarchy/shell

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
  for id in aur units backup restore auto share copy folder url preview apply loadout-update loadout-repair loadout-remove; do
    grep -q "\"$id\"" "$REPO_DIR/Panel.qml" ||
      _fail "Panel.qml has no row id \"$id\""
  done
  _pass
  grep -q '"loadouts"' "$REPO_DIR/Panel.qml" && _pass || _fail "Panel.qml exposes a Loadouts tab"
  grep -q 'loadout", "list", "--json", "--contents"' "$REPO_DIR/Service.qml" && _pass ||
    _fail "Service.qml reads applied loadouts through documented CLI JSON"
  grep -q 'loadout", "check", "--json"' "$REPO_DIR/Service.qml" && _pass ||
    _fail "Service.qml reads live loadout health through documented CLI JSON"
  grep -q 'modelData.healthState' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "Panel.qml progressively reveals live resource health"
  grep -q 'loadoutTerminalArgs("\|openLoadoutAction' "$REPO_DIR/Panel.qml" && _pass ||
    _fail "loadout mutations are routed through the service terminal boundary"
  if grep -q 'loadouts.json' "$REPO_DIR/Panel.qml" "$REPO_DIR/Service.qml"; then
    _fail "QML must not read the registry directly"
  else
    _pass
  fi
else
  echo "  (skipped: no qmllint or no Omarchy shell to resolve imports against)"
fi
