"$REPO_DIR/tests/check-structure.sh" "$REPO_DIR" >"$SANDBOX/structure.out" 2>&1
STATUS=$?; OUT=$(<"$SANDBOX/structure.out")
assert_ok "the checked-in ownership and entrypoint structure passes"
assert_output "modules" "the structural check reports its scope"
assert_file_contains "$REPO_DIR/tests/module-dependencies.tsv" \
  $'lib/montage/commands.sh\tcore safety repository-common repository-registry registry resources lifecycle application-commands' \
  "dependency map assigns the neutral application-command owner"
assert_file_contains "$REPO_DIR/tests/mutate.sh" \
  '[aur-always-builds]=38-loadout-repair-aur' \
  "AUR mutation evidence points to the focused loadout detector"
assert_file_contains "$REPO_DIR/tests/mutate.sh" \
  '[repository-lock-ignored]=50-repository-transaction' \
  "repository locking mutation evidence points to the transaction detector"
assert_file_contains "$REPO_DIR/tests/mutate.sh" \
  '[security-repository-remote-unsanitized]=43-url-credentials' \
  "repository credential mutation evidence points to the sharing detector"
if rg -n '\.ress-bak|\.resurrect-bak|\.local/bin/ress|\.config/ress|\.local/(state|share)/ress' \
    "$REPO_DIR/bin" "$REPO_DIR/lib/montage" "$REPO_DIR/defaults" \
    --glob '!**/port/**' >/dev/null; then
  _fail "active Montage code retains Ress-owned artifact paths"
else
  _pass
fi
assert_file_contains "$REPO_DIR/docs/index.md" "architecture/application-identity.md" \
  "the documentation index links the application identity contract"
assert_file_contains "$REPO_DIR/docs/index.md" "contracts/repository-format.md" \
  "the documentation index links the repository format contract"
assert_file_contains "$REPO_DIR/docs/architecture/cli-modules.md" "repository/transaction.sh" \
  "CLI architecture records repository module ownership"
assert_file_contains "$REPO_DIR/docs/architecture/cli-modules.md" "port/ress.sh" \
  "CLI architecture records focused Ress migration ownership"
assert_file_contains "$REPO_DIR/docs/index.md" "architecture/port-adapters.md" \
  "the documentation index links the Ress migration architecture"
assert_file_contains "$REPO_DIR/docs/architecture/port-adapters.md" \
  "A future foreign format or reverse conversion requires a new product decision" \
  "migration architecture rejects an unused future-format framework"
assert_file_contains "$REPO_DIR/docs/contracts/repository-format.md" "There is no repository-kind argument" \
  "repository contract records the single-kind CLI boundary"
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
for removed_doc in \
  "$REPO_DIR/docs/contracts/vault-format.md" \
  "$REPO_DIR/docs/contracts/restore-safety.md" \
  "$REPO_DIR/docs/workflows/backup-restore.md" \
  "$REPO_DIR/docs/workflows/encrypted-secrets.md"; do
  [[ ! -e $removed_doc ]] || _fail "retired current documentation still exists: ${removed_doc#"$REPO_DIR/"}"
done
_pass
for removed_stub in "$REPO_DIR/tests/bin/age" "$REPO_DIR/tests/bin/systemctl"; do
  if [[ -e $removed_stub ]]; then
    _fail "retired test double still exists: ${removed_stub#"$REPO_DIR/"}"
  else
    _pass
  fi
done
assert_file_contains "$REPO_DIR/docs/index.md" "workflows/repository-sync.md" \
  "the documentation index links repository synchronization guidance"
assert_file_contains "$REPO_DIR/docs/workflows/repository-sync.md" \
  "credential helper, an SSH agent" \
  "synchronization guidance assigns authentication to Git transport"
assert_file_contains "$REPO_DIR/docs/workflows/repository-sync.md" \
  "designed to be shareable and may be public" \
  "synchronization guidance records the shareable library boundary"
assert_file_contains "$REPO_DIR/docs/workflows/repository-sync.md" \
  "Divergence is always decision-required" \
  "synchronization guidance explains divergence resolution"
assert_file_contains "$REPO_DIR/docs/workflows/repository-sync.md" \
  "force-push" \
  "synchronization guidance records the no-force guarantee"
assert_file_contains "$REPO_DIR/docs/index.md" "workflows/ress-portability.md" \
  "the documentation index links the bounded Ress migration workflow"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "Montage has one frozen foreign-input boundary" \
  "migration guidance states the single supported boundary"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "does not import Ress vaults, backups, history" \
  "migration guidance refuses vault and history conversion"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "Decide self-plugin entries explicitly" \
  "migration guidance explains exact self-plugin decisions"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "private keys" \
  "migration guidance records the private-authority boundary"
assert_file_contains "$REPO_DIR/docs/workflows/ress-portability.md" \
  "Manual fallback" \
  "port guidance includes a separate-path manual fallback"
if rg -n '^\s*ress(?:\s|$)' \
    "$REPO_DIR/docs/contracts/loadout-profile.md" \
    "$REPO_DIR/docs/contracts/loadout-registry.md" \
    "$REPO_DIR/docs/workflows/share-apply.md" >/dev/null; then
  _fail "current native loadout documentation contains a Ress command example"
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
assert_equals "$(jq -c '.kinds' "$REPO_DIR/manifest.json")" '["bar-widget"]' \
  "manifest registers no scheduler or background service"
assert_equals "$("$MNTG" --version)" "1.0.0" \
  "CLI version agrees with independent release metadata"
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
  "Ress v1 source → inspect/decide → separate Montage library item" \
  "current repository diagram shows the separate-path compatibility boundary"
for checklist_item in \
  'Ress side by side' \
  'ImageMagick `montage`' \
  'Update and remove either plugin' \
  'Git credential helper or SSH-agent' \
  'ordinary status makes no network request' \
  'Configured-registry migration' \
  'Ress v1 migration'; do
  assert_file_contains "$REPO_DIR/docs/testing/fresh-machine-validation.md" "$checklist_item" \
    "fresh-machine validation covers $checklist_item"
done
assert_file_contains "$REPO_DIR/docs/testing/fresh-machine-validation.md" \
  'No clean-machine or rendered result is implied by this checklist' \
  "fresh-machine checks distinguish planned evidence from executed results"
assert_file_contains "$REPO_DIR/docs/testing/strategy.md" \
  'real package/AUR transactions' \
  "testing strategy classifies non-automatable package evidence"
[[ ! -e "$REPO_DIR/defaults/include.txt" && ! -e "$REPO_DIR/defaults/exclude.txt" ]] ||
  _fail "backup-only default include or exclude list remains"
_pass
help_output=$("$MNTG" --help)
for documented in 'mntg status' 'mntg doctor' 'mntg link' 'mntg repository' \
  'mntg share' 'mntg apply' 'mntg loadout' 'mntg resource' 'mntg port ress inspect'; do
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
