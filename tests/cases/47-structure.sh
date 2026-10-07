"$REPO_DIR/tests/check-structure.sh" "$REPO_DIR" >"$SANDBOX/structure.out" 2>&1
STATUS=$?; OUT=$(<"$SANDBOX/structure.out")
assert_ok "the checked-in ownership and entrypoint structure passes"
assert_output "modules" "the structural check reports its scope"
if rg -n '\.ress-bak|\.resurrect-bak|\.local/bin/ress|\.config/ress|\.local/(state|share)/ress' \
    "$REPO_DIR/bin" "$REPO_DIR/lib/montage" "$REPO_DIR/defaults" \
    --glob '!**/port/**' >/dev/null; then
  _fail "active Montage capture or restore code retains Ress-owned artifact paths"
else
  _pass
fi
assert_file_contains "$REPO_DIR/docs/index.md" "architecture/application-identity.md" \
  "the documentation index links the application identity contract"
assert_file_contains "$REPO_DIR/docs/index.md" "contracts/repository-format.md" \
  "the documentation index links the repository format contract"
assert_file_contains "$REPO_DIR/docs/architecture/cli-modules.md" "repository/transaction.sh" \
  "CLI architecture records repository module ownership"
assert_file_contains "$REPO_DIR/docs/architecture/cli-modules.md" "port/adapters/ress_v1/format.sh" \
  "CLI architecture records bounded port adapter ownership"
assert_file_contains "$REPO_DIR/docs/index.md" "architecture/port-adapters.md" \
  "the documentation index links the port adapter architecture"
assert_file_contains "$REPO_DIR/docs/architecture/port-adapters.md" "Adding another format" \
  "port architecture documents the future-format extension workflow"
assert_file_contains "$REPO_DIR/docs/contracts/repository-format.md" "repository list" \
  "repository contract records the CLI consumer boundary"
assert_file_contains "$REPO_DIR/docs/contracts/loadout-profile.md" \
  'loadouts/<stable-id>/profile.json' \
  "loadout contract records the stable portable-leaf layout"
assert_file_contains "$REPO_DIR/docs/contracts/loadout-profile.md" \
  "Library items versus applied state" \
  "loadout contract distinguishes authored library items from local applied state"
assert_file_contains "$REPO_DIR/docs/workflows/share-apply.md" \
  "mntg share --repository" \
  "share workflow uses the Montage command and an explicit repository"
assert_file_contains "$REPO_DIR/docs/workflows/share-apply.md" \
  "mntg apply https://github.com/example/personal-loadouts" \
  "apply workflow uses the Montage command and an explicit repository source"
assert_file_contains "$REPO_DIR/docs/contracts/vault-format.md" \
  'current snapshot is' \
  "vault contract distinguishes the current snapshot from Git history"
assert_file_contains "$REPO_DIR/docs/contracts/vault-format.md" \
  'repository id and exact backup commit' \
  "vault contract binds restore progress to repository and commit identity"
assert_file_contains "$REPO_DIR/docs/workflows/backup-restore.md" \
  'mntg restore --backup before-reinstall --dry-run' \
  "restore workflow previews an explicit backup selector"
assert_file_contains "$REPO_DIR/docs/workflows/backup-restore.md" \
  'local history now diverges' \
  "retention workflow explains published-remote divergence"
assert_file_contains "$REPO_DIR/docs/index.md" "workflows/repository-sync.md" \
  "the documentation index links repository synchronization guidance"
assert_file_contains "$REPO_DIR/docs/workflows/repository-sync.md" \
  "credential helper, an SSH agent" \
  "synchronization guidance assigns authentication to Git transport"
assert_file_contains "$REPO_DIR/docs/workflows/repository-sync.md" \
  "Loadout repositories are designed to be shareable and may be public" \
  "synchronization guidance distinguishes public loadouts from private vaults"
assert_file_contains "$REPO_DIR/docs/workflows/repository-sync.md" \
  "Divergence is always decision-required" \
  "synchronization guidance explains divergence resolution"
assert_file_contains "$REPO_DIR/docs/workflows/repository-sync.md" \
  "force-push" \
  "synchronization guidance records the no-force guarantee"
assert_file_contains "$REPO_DIR/docs/index.md" "workflows/ress-portability.md" \
  "the documentation index links the bounded Ress port workflow"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "The default is one current snapshot and fresh Montage history" \
  "port guidance makes current-snapshot import the default"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "History translation is slower" \
  "port guidance explains optional history cost"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "Loss and identity decisions" \
  "port guidance contains an itemized loss matrix"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "private keys are never ported" \
  "port guidance records the encryption identity boundary"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "Manual copy fallback" \
  "port guidance includes a separate-path manual fallback"
if rg -n '^\s*ress(?:\s|$)' \
    "$REPO_DIR/docs/contracts/loadout-profile.md" \
    "$REPO_DIR/docs/contracts/loadout-registry.md" \
    "$REPO_DIR/docs/contracts/vault-format.md" \
    "$REPO_DIR/docs/contracts/restore-safety.md" \
    "$REPO_DIR/docs/workflows/share-apply.md" \
    "$REPO_DIR/docs/workflows/backup-restore.md" >/dev/null; then
  _fail "current loadout or vault documentation contains a Ress command example"
else
  _pass
fi
assert_file_lacks "$REPO_DIR/docs/architecture/cli-modules.md" "bin/ress" \
  "CLI architecture names only the Montage entrypoint"
assert_file_lacks "$REPO_DIR/docs/architecture/cli-modules.md" "lib/ress" \
  "CLI architecture names only the Montage module tree"
for current_doc in \
  "$REPO_DIR/README.md" \
  "$REPO_DIR/docs/vision/vision.md" \
  "$REPO_DIR/docs/vision/principles.md" \
  "$REPO_DIR/docs/architecture/system-overview.md" \
  "$REPO_DIR/docs/workflows/encrypted-secrets.md" \
  "$REPO_DIR/docs/testing/strategy.md"; do
  if rg -n '(^|[[:space:]`])ress (backup|restore|share|apply|status|set|scan|doctor|link)|bin/ress|lib/ress|\.config/ress|\.local/(share|state)/ress|\.ress-bak' \
      "$current_doc" >/dev/null; then
    _fail "current Montage documentation retains a native Ress command or path: ${current_doc#"$REPO_DIR/"}"
  fi
done
_pass
assert_file_contains "$REPO_DIR/README.md" "Montage is an independent project" \
  "README states the separate-product direction"
assert_file_contains "$REPO_DIR/README.md" "tombychowski.montage" \
  "README uses the independent plugin id"
assert_file_contains "$REPO_DIR/docs/index.md" "panel/keyboard-workflow.md" \
  "documentation index links the keyboard workflow"
assert_file_contains "$REPO_DIR/docs/index.md" "panel/settings.md" \
  "documentation index links panel repository settings"
assert_equals "$(jq -r '.homepage' "$REPO_DIR/manifest.json")" \
  "https://github.com/tombychowski/omarchy-montage" \
  "manifest uses the independent Montage repository homepage"
assert_equals "$(jq -r '.version' "$REPO_DIR/manifest.json")" "1.0.0" \
  "manifest starts an independent Montage release line"
assert_file_contains "$REPO_DIR/docs/release/marketplace.md" "omarchy-montage-1.0.0.tar.gz" \
  "marketplace guidance uses Montage-specific release asset names"
assert_file_contains "$REPO_DIR/docs/release/marketplace.md" "omarchy plugin remove tombychowski.montage" \
  "marketplace guidance documents independent removal"
assert_file_contains "$REPO_DIR/CHANGELOG.md" "Montage 1.0.0 — independent release" \
  "changelog distinguishes current Montage release metadata from history"
assert_file_contains "$REPO_DIR/docs/index.md" "workflows/migrate-from-ress.md" \
  "documentation index links the release migration guide"
for migration_section in 'Command and identity map' 'Path map' \
  'Initialize native repositories' 'Why `profile.json` remains portable' \
  'Roll back Montage without touching Ress' 'private'; do
  assert_file_contains "$REPO_DIR/docs/workflows/migrate-from-ress.md" "$migration_section" \
    "migration guide includes $migration_section"
done
if rg -n '^```bash$' "$REPO_DIR/docs/workflows/migrate-from-ress.md" >/dev/null &&
   rg -n 'Automated contract|Real-machine-only' "$REPO_DIR/docs/workflows/migrate-from-ress.md" >/dev/null; then
  _pass
else
  _fail "migration guide does not classify command evidence"
fi
if rg -n -i 'ress\.sh|btsouth|omarchy-resurrect|tsouth89|bin/ress|ress (backup|restore|share|apply)' \
    "$REPO_DIR/site/public" "$REPO_DIR/site/worker.js" "$REPO_DIR/site/README.md" >/dev/null; then
  _fail "active site retains predecessor branding, commands, or repository links"
else
  _pass
fi
assert_file_contains "$REPO_DIR/site/public/index.html" "Montage · for Omarchy" \
  "site is visibly branded Montage"
assert_file_contains "$REPO_DIR/site/public/index.html" "tombychowski/omarchy-montage" \
  "site points to the independent Montage repository"
assert_file_contains "$REPO_DIR/docs/media/README.md" "montage-panel-1.0.0.png" \
  "media inventory defines Montage-specific screenshot names"
[[ -f "$REPO_DIR/docs/media/archive/ress-preview.jpg" &&
   -f "$REPO_DIR/site/archive/ress-assets/preview.jpg" ]] && _pass ||
  _fail "predecessor visual assets were not retained in explicit archives"
if find "$REPO_DIR/docs/media" -maxdepth 1 -type f ! -name README.md ! -name 'montage-*' -print -quit | grep -q .; then
  _fail "active documentation media contains an unclassified or non-Montage asset"
else
  _pass
fi
assert_file_contains "$REPO_DIR/docs/media/montage-repositories.svg" \
  "Ress v1 source → inspect/plan → separate Montage destination" \
  "current repository diagram shows the separate-path compatibility boundary"
for checklist_item in \
  'side-by-side Ress and Montage installation' \
  'ImageMagick `montage`' \
  'updating or removing either plugin leaves the other working' \
  'Git credential helper or SSH-agent' \
  'known-public visibility' \
  'Exact historical restore' \
  'Ress v1 port validation'; do
  assert_file_contains "$REPO_DIR/docs/testing/fresh-machine-validation.md" "$checklist_item" \
    "fresh-machine validation covers $checklist_item"
done
assert_file_contains "$REPO_DIR/docs/testing/fresh-machine-validation.md" \
  'Expected observations:' \
  "fresh-machine checks record explicit expected observations"
assert_file_contains "$REPO_DIR/docs/testing/strategy.md" \
  'real package transactions' \
  "testing strategy classifies non-automatable package evidence"
help_output=$("$MNTG" --help)
for documented in 'mntg backup' 'mntg restore' 'mntg status' 'mntg doctor' 'mntg link'; do
  [[ $help_output == *"$documented"* ]] || _fail "CLI help omits documented command: $documented"
done
_pass

FIXTURE="$SANDBOX/repo"
mkdir -p "$FIXTURE"
cp -a "$REPO_DIR/bin" "$REPO_DIR/lib" "$REPO_DIR/tests" "$FIXTURE/"
printf '\nunreachable_fixture() { :; }\n' >>"$FIXTURE/lib/montage/core.sh"
"$FIXTURE/tests/check-structure.sh" "$FIXTURE" >"$SANDBOX/dead.out" 2>&1
STATUS=$?; OUT=$(<"$SANDBOX/dead.out")
assert_fails "a deliberately unreachable fixture is rejected"
assert_output "unreachable function: unreachable_fixture"

cp "$REPO_DIR/lib/montage/machine/packages.sh" "$FIXTURE/lib/montage/machine/packages.sh"
printf '\nmachine_reverse_fixture() { registry_save "{}"; }\n' >>"$FIXTURE/lib/montage/machine/packages.sh"
printf 'machine_reverse_fixture\n' >>"$FIXTURE/tests/static-entrypoints.txt"
"$FIXTURE/tests/check-structure.sh" "$FIXTURE" >"$SANDBOX/reverse.out" 2>&1
STATUS=$?; OUT=$(<"$SANDBOX/reverse.out")
assert_fails "a representative reverse dependency is rejected"
assert_output "machine module has a reverse dependency"
