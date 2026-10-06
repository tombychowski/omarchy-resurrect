#!/bin/bash
#
# Mutation testing for the ress suite.
#
#   tests/mutate.sh              run every mutation
#   tests/mutate.sh aur          run the ones whose name matches "aur"
#
# A passing test suite says the tests agree with the code. It does not say the
# tests would notice if the code were wrong. This breaks one behaviour at a
# time in a throwaway copy of the repo and checks that at least one case goes
# red. A mutation that SURVIVES is a feature the suite only appears to cover.
#
# The full suite establishes one clean baseline. Each mutation then runs its
# explicitly owned detector case: mutation evidence needs one red case, not the
# same unrelated integration cases repeated 57 times.

set -uo pipefail

TESTS_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC=$(dirname "$TESTS_DIR")
WORK="${TMPDIR:-/tmp}/ress-mutation.$$"
FILTER="${1:-}"
BASELINE_FILTER="${RESS_MUTATION_BASELINE_FILTER:-}"

# Only the mutation-runner self-test may narrow the baseline, and it selects no
# mutations. A real sweep, including a filtered mutation sweep, always proves a
# clean full-suite baseline first.
if [[ -n $BASELINE_FILTER && $FILTER != no-such-mutation ]]; then
  printf 'RESS_MUTATION_BASELINE_FILTER is only valid with the no-such-mutation self-test filter\n' >&2
  exit 2
fi

trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK"

# Visible to the cases: one of them exercises this runner, and the runner's full
# baseline must not recursively exercise its own baseline self-test.
export RESS_MUTATION_RUN=1

# A mutation is caught when the suite goes red, so a case that is already red
# makes every mutation below look caught. A clean sweep on a red baseline is
# worse than no run at all: it is a false claim of coverage, and it is the way a
# mutation that changes nothing gets believed. So the baseline is checked first.
printf 'Baseline\n'
baseline_args=()
[[ -z $BASELINE_FILTER ]] || baseline_args+=("$BASELINE_FILTER")
baseline=$(cd "$SRC" && ./tests/run.sh --jobs "${RESS_TEST_JOBS:-4}" "${baseline_args[@]}" 2>&1)
if ! grep -q 'cases passed' <<<"$baseline"; then
  printf '\e[31m  The suite does not pass on its own, so every mutation would look caught.\e[0m\n'
  # The failing cases, and then the assertions inside them. The case lines carry
  # colour, so they are matched by shape rather than by column; and the ✗ marker
  # on its own names nothing, because a case's own output is full of ✗ marks from
  # the step lines of the tool under test.
  grep -E '[0-9]+/[0-9]+ assertions failed' <<<"$baseline" |
    sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^/  /' || true
  # No trailing space: the word carries colour around it, so "FAIL " never matches.
  grep -E 'FAIL' <<<"$baseline" | head -20 |
    sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^/    /' || true
  printf '  Fix that first: an unrelated failing case is not evidence of anything.\n'
  exit 1
fi
printf '\e[32m  %s\e[0m\n\n' "$(grep 'cases passed' <<<"$baseline")"

survived=0
caught=0
skipped=0

# Every mutation owns one exact detector case. The full baseline above proves
# all other cases are green; the focused rerun proves this particular fault is
# observable without multiplying the complete integration suite.
declare -A MUTATION_CASE=(
  [aur-always-builds]=05-aur
  [aur-ignores-flag]=05-aur
  [aur-ignores-denylist]=05-aur
  [units-always-enable]=03-units
  [units-no-validation]=03-units
  [eof-kills-restore]=03-units
  [scanner-finds-nothing]=07-secret-scan
  [scanner-block-commits]=07-secret-scan
  [scanner-leaks-match]=07-secret-scan
  [verify-always-complete]=08-verify
  [verify-ignores-packages]=08-verify
  [manifest-no-legacy]=02-vault-format
  [bak-suffix-old]=02-vault-format
  [partial-marks-done]=05-aur
  [progress-not-scoped]=11-empty
  [category-not-validated]=11-empty
  [dryrun-writes-state]=06-dry-run
  [operation-dryrun-marker]=23-loadout-lock
  [operation-marker-token-ignored]=23-loadout-lock
  [first-contact-never]=04-first-contact
  [source-scheme-ignored]=17-ssh-source
  [schema-unvalidated]=14-hostile-vault
  [plain-not-applied]=14-hostile-vault
  [webapp-captures-stock]=18-webapp-launchers
  [webapp-quotes-kept]=18-webapp-launchers
  [webapp-percent-not-read]=18-webapp-launchers
  [webapp-flags-dropped]=18-webapp-launchers
  [webapp-restore-refused-unnamed]=18-webapp-launchers
  [webapp-verify-file-name]=18-webapp-launchers
  [webapp-share-publishes-refused]=40-share-compose
  [webapp-restore-label-unchecked]=18-webapp-launchers
  [webapp-or-focus-flattened]=18-webapp-launchers
  [webapp-long-line-unbounded]=18-webapp-launchers
  [webapp-capture-misses-two-exec]=18-webapp-launchers
  [verify-lists-split-on-spaces]=18-webapp-launchers
  [plugin-remote-unchecked]=21-plugin-remotes
  [plugin-verify-counts-uncloneable]=21-plugin-remotes
  [theme-remote-unchecked]=21-plugin-remotes
  [autostart-always]=09-autostart
  [settings-unvalidated]=13-settings
  [config-no-lock]=13-settings
  [operation-config-lock-timeout-ignored]=42-config-lock
  [security-init-remote-unsanitized]=43-url-credentials
  [security-profile-webapp-credential-accepted]=43-url-credentials
  [security-vault-scan-narrowed]=07-secret-scan
  [security-control-symlink-followed]=44-untrusted-controls
  [status-json-raw-config]=19-status-config
  [status-manifest-unchecked]=19-status-config
  [loadout-registry-schema-ignored]=22-loadout-registry
  [loadout-new-fabricated-claim-accepted]=22-loadout-registry
  [loadout-isolation-path-name-accepted]=22-loadout-registry
  [loadout-preexisting-gains-ownership]=28-tracked-apply
  [loadout-isolation-conflicts-compatible]=25-loadout-resources
  [loadout-shared-resource-deleted]=26-loadout-claims
  [loadout-modified-resource-deleted]=34-loadout-plugin-remove
  [loadout-package-removal-cascades]=33-loadout-package-remove
  [loadout-partial-apply-says-ok]=28-tracked-apply
  [loadout-new-check-implicitly-repairs]=29-loadout-check
  [share-hides-unshareable]=40-share-compose
  [share-skips-final-selection-check]=40-share-compose
  [share-trusts-panel-definition-option]=40-share-compose
  [share-skips-withdrawal-ack]=40-share-compose
  [share-allows-many-themes]=40-share-compose
  [porcelain-prose]=12-porcelain
  [cleanup-containment-removed]=45-cleanup-registry
)

run_mutation() {
  local name="$1" target="$2" old="$3" new="$4" case_filter="${MUTATION_CASE[$1]:-}"
  [[ -n $FILTER && $name != *"$FILTER"* ]] && return 0

  if [[ -z $case_filter || ! -f $TESTS_DIR/cases/$case_filter.sh ]]; then
    printf '  \e[35m?\e[0m %-24s missing detector case mapping: %s\n' "$name" "${case_filter:-<none>}"
    skipped=$((skipped + 1))
    return 0
  fi

  local dir="$WORK/$name"
  cp -a "$SRC" "$dir"
  rm -rf "$dir/.git"

  if [[ $target == /* || $target == *../* || ! -f $dir/$target ]]; then
    printf '  \e[35m?\e[0m %-24s invalid or missing target: %s\n' "$name" "$target"
    skipped=$((skipped + 1))
    rm -rf "$dir"
    return 0
  fi

  python3 - "$dir/$target" "$old" "$new" <<'PY'
import sys, pathlib
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path); s = p.read_text()
if s.count(old) != 1:
    sys.exit(3)
p.write_text(s.replace(old, new, 1))
PY
  local rc=$?
  if (( rc == 3 )); then
    printf '  \e[35m?\e[0m %-24s anchor missing or ambiguous in %s — update this mutation\n' "$name" "$target"
    skipped=$((skipped + 1))
    rm -rf "$dir"
    return 0
  fi
  local production_files=("$dir/bin/ress") file
  if [[ -d $dir/lib/ress ]]; then
    while IFS= read -r file; do production_files+=("$file"); done < <(
      find "$dir/lib/ress" -type f -name '*.sh' -print | sort
    )
  fi
  for file in "${production_files[@]}"; do
    if ! bash -n "$file" 2>/dev/null; then
      printf '  \e[35m?\e[0m %-24s mutation does not parse: %s\n' "$name" "${file#"$dir/"}"
      skipped=$((skipped + 1))
      rm -rf "$dir"
      return 0
    fi
  done

  local out
  out=$(cd "$dir" && ./tests/run.sh "$case_filter" 2>&1)
  if grep -q 'cases passed' <<<"$out"; then
    printf '  \e[31m✗\e[0m %-24s SURVIVED — nothing noticed\n' "$name"
    survived=$((survived + 1))
  else
    printf '  \e[32m✓\e[0m %-24s caught by %s\n' "$name" \
      "$(grep '✗' <<<"$out" | grep -oE '[0-9]+-[a-z-]+' | sort -u | tr '\n' ' ')"
    caught=$((caught + 1))
  fi
  rm -rf "$dir"
}

# ---- the two consent gates ------------------------------------------------

run_mutation aur-always-builds lib/ress/machine/packages.sh \
  '  AUR_KEPT=()
  AUR_MODE="skip"' \
  '  AUR_KEPT=()
  AUR_MODE="build"'

run_mutation aur-ignores-flag lib/ress/machine/packages.sh \
  'local decision="${AUR_CHOICE:-}"' \
  'local decision="yes"'

run_mutation aur-ignores-denylist lib/ress/machine/packages.sh \
  'aur_denied() { merged_list aur-deny | grep -qxF -- "$1"; }' \
  'aur_denied() { return 1; }'

run_mutation units-always-enable lib/ress/vault/restore.sh \
  'case "$(units_decision_kind)" in
    no)' \
  'case "yes" in
    no)'

run_mutation units-no-validation lib/ress/vault/restore.sh \
  'valid_unit "$unit" || continue
    systemctl --user is-enabled' \
  'systemctl --user is-enabled'

run_mutation eof-kills-restore lib/ress/vault/restore.sh \
  'read -r -p "Enable $(plural "${#units[@]}" "user service")? [y/N] " reply || reply=""' \
  'read -r -p "Enable $(plural "${#units[@]}" "user service")? [y/N] " reply'

# ---- the secret scanner ---------------------------------------------------

run_mutation scanner-finds-nothing lib/ress/vault/backup.sh \
  'SECRET_FINDINGS=$(printf' \
  'found=""; SECRET_FINDINGS=$(printf'

run_mutation scanner-block-commits lib/ress/vault/backup.sh \
  'if [[ $(secret_scan_mode) == block ]]; then' \
  'if false; then'

run_mutation scanner-leaks-match lib/ress/vault/backup.sh \
  'printf '"'"'%s\n'"'"' "$SECRET_FINDINGS" | awk -F'"'"'\t'"'"' '"'"'NF { printf "    %-52s %s\n", $1, $2 }'"'"'' \
  'printf '"'"'%s\n'"'"' "$SECRET_FINDINGS" | awk -F'"'"'\t'"'"' '"'"'NF { printf "    %-52s %s\n", $1, $2 }'"'"'; grep -rIhE "ghp_[A-Za-z0-9]{36}" "$VAULT" 2>/dev/null | head -1'

# ---- verify ---------------------------------------------------------------

run_mutation verify-always-complete lib/ress/vault/verify.sh \
  '(( ${have[$category]} < ${want[$category]} )) && complete=0' \
  '(( ${have[$category]} < ${want[$category]} )) && complete=1'

run_mutation verify-ignores-packages lib/ress/vault/verify.sh \
  'missing[packages]=$(comm -23 "$wanted_pkgs" "$installed" | tr' \
  'missing[packages]=$(true | tr'

# ---- the vault format -----------------------------------------------------

run_mutation manifest-no-legacy lib/ress/vault/common.sh \
  'if [[ -e $VAULT/$VAULT_MANIFEST_LEGACY || -L $VAULT/$VAULT_MANIFEST_LEGACY ]]; then' \
  'if false; then'

run_mutation bak-suffix-old lib/ress/core.sh \
  'BAK_SUFFIX=".ress-bak"' \
  'BAK_SUFFIX=".resurrect-bak"'

# ---- restore mechanics ----------------------------------------------------

run_mutation partial-marks-done lib/ress/vault/restore.sh \
  '&& ! was_partial "$category"; then' \
  '; then'

run_mutation progress-not-scoped lib/ress/vault/restore.sh \
  'local identity="# $VAULT $(jq -r '"'"'.createdAt // "?"'"'"' "$manifest" 2>/dev/null || echo "?")"' \
  'local identity="# fixed"'

run_mutation category-not-validated lib/ress/vault/restore.sh \
  '(( known )) || { set +f; die "no such category' \
  '(( 1 )) || { set +f; die "no such category'

run_mutation dryrun-writes-state lib/ress/vault/restore.sh \
  'if (( ! DRY_RUN )); then
    (( restart )) && rm -f "$RESTORE_STATE"' \
  'if (( 1 )); then
    (( restart )) && rm -f "$RESTORE_STATE"'

run_mutation operation-dryrun-marker lib/ress/core.sh \
  'if (( ! DRY_RUN )); then' \
  'if (( 1 )); then'

run_mutation operation-marker-token-ignored lib/ress/core.sh \
  'if [[ $marker_token == "$RUNNING_MARKER_TOKEN" ]]; then' \
  'if [[ -n $marker_token ]]; then'

run_mutation first-contact-never lib/ress/vault/restore.sh \
  'same_remote "$from" "$(normalize_source "${CFG[REMOTE]:-}")" || FIRST_CONTACT=1' \
  ':'

run_mutation source-scheme-ignored lib/ress/safety.sh \
  '  case "$src" in
    http://*|https://*) ;;  # the https forms the shorthands below are written for' \
  '  case "" in
    http://*|https://*) ;;  # the guard can never match, so nothing is passed through'

# ---- untrusted input ------------------------------------------------------

run_mutation schema-unvalidated lib/ress/vault/restore.sh \
  'valid_int "$schema" ||
    die "this vault does not declare a schema version as a number — refusing to read it"' \
  ':'

run_mutation plain-not-applied lib/ress/safety.sh \
  'plain() { printf '"'"'%s'"'"' "$1" | tr -d '"'"'\000-\037\177'"'"'; }' \
  'plain() { printf '"'"'%s'"'"' "$1"; }'

# ---- web app launchers ----------------------------------------------------

run_mutation webapp-captures-stock lib/ress/vault/backup.sh \
  '    if package_owned_launcher "$desktop" "$name"; then stock=$((stock + 1)); continue; fi' \
  ':'

run_mutation webapp-quotes-kept lib/ress/safety.sh \
  'in_quote=1; i=$((i + 1)); continue; fi' \
  'in_quote=1; i=$((i + 1)); fi'

run_mutation webapp-percent-not-read lib/ress/safety.sh \
  '"${url//%/%%}"' \
  '"$url"'

run_mutation webapp-flags-dropped lib/ress/vault/restore.sh \
  '      install_args+=("$(webapp_exec_line "$launcher" "$url" "${flag_words[@]}")")' \
  '      install_args+=("$(webapp_exec_line "$launcher" "$url")")'

run_mutation webapp-restore-refused-unnamed lib/ress/vault/restore.sh \
  '    if ! launcher_travels "$desktop"; then refused+=("$(plain "$name")"); continue; fi' \
  '    if ! launcher_travels "$desktop"; then continue; fi'

run_mutation webapp-verify-file-name lib/ress/vault/verify.sh \
  '      if [[ -f $HOME/.local/share/applications/$label.desktop ]]; then' \
  '      if [[ -f $HOME/.local/share/applications/$app.desktop ]]; then'

run_mutation webapp-share-publishes-refused lib/ress/loadout/share.sh \
  '    definition=$(jq -nc --arg name "$name" --arg url "$web_url" --arg icon "$icon" \
      '\''{name:$name,url:$url,icon:$icon}'\'')
    if [[ -z $code ]]; then
      rows+=("$(share_candidate_json "$id" webapp "$name" true "" "" "$none" false "$definition")")' \
  '    definition=$(jq -nc --arg name "$name" --arg url "$web_url" --arg icon "$icon" \
      '\''{name:$name,url:$url,icon:$icon}'\'')
    if true; then
      rows+=("$(share_candidate_json "$id" webapp "$name" true "" "" "$none" false "$definition")")'

run_mutation webapp-restore-label-unchecked lib/ress/vault/restore.sh \
  '    if ! valid_label "$name"; then refused+=("$(plain "$name")"); continue; fi' \
  '    :'

run_mutation webapp-or-focus-flattened lib/ress/vault/restore.sh \
  '      install_args+=("$(webapp_exec_line "$launcher" "$url")")' \
  '      :'

run_mutation webapp-long-line-unbounded lib/ress/safety.sh \
  '  (( ${#exec_line} <= WEBAPP_MAX_EXEC )) || return 1' \
  '  :'

run_mutation webapp-capture-misses-two-exec lib/ress/vault/backup.sh \
  '    launcher_travels "$desktop" || unrebuildable+=("${name%.desktop}")' \
  '    webapp_parts "$(launcher_exec "$desktop")" >/dev/null || unrebuildable+=("${name%.desktop}")'

run_mutation verify-lists-split-on-spaces lib/ress/vault/verify.sh \
  'list_join() { local IFS=$'"'"'\037'"'"'; printf '"'"'%s'"'"' "$*"; }' \
  'list_join() { printf '"'"'%s'"'"' "$*"; }'

# ---- remotes a restore will not take --------------------------------------

run_mutation plugin-remote-unchecked lib/ress/vault/backup.sh \
  '    elif ! valid_git_remote "$url"; then' \
  '    elif false; then'

run_mutation plugin-verify-counts-uncloneable lib/ress/vault/verify.sh \
  '      if [[ -z $purl ]] || ! valid_git_remote "$purl"; then' \
  '      if [[ -z $purl ]]; then'

run_mutation theme-remote-unchecked lib/ress/vault/backup.sh \
  '      valid_git_remote "$url" ||
        step_warn omarchy "theme $name has a remote a restore will not clone ($(plain "$url")) — it will travel as nothing at all"' \
  '      :'

# ---- settings and capture -------------------------------------------------

run_mutation autostart-always lib/ress/vault/backup.sh \
  '[[ ${CFG[CAPTURE_AUTOSTART]:-0} == 1 ]] && [[ -d $HOME/.config/autostart ]]' \
  '[[ -d $HOME/.config/autostart ]]'

run_mutation settings-unvalidated lib/ress/vault/commands.sh \
  '    config_validate_value "$key" "$value"' \
  '    :'

run_mutation config-no-lock lib/ress/vault/commands.sh \
  'take_config_lock
  load_config' \
  ':'

run_mutation operation-config-lock-timeout-ignored lib/ress/core.sh \
  'flock -w 5 8 || die "configuration is busy; try again"' \
  'flock -w 5 8 || true'

run_mutation security-init-remote-unsanitized lib/ress/vault/commands.sh \
  '[[ -n $remote ]] && CFG[REMOTE]="$(strip_credentials "$remote")"' \
  '[[ -n $remote ]] && CFG[REMOTE]="$remote"'

run_mutation security-profile-webapp-credential-accepted lib/ress/loadout/profile.sh \
  'url_has_credentials "$url" &&
      die "loadout contains a credential-bearing web app URL"' \
  'false &&
      die "loadout contains a credential-bearing web app URL"'

run_mutation security-vault-scan-narrowed lib/ress/vault/backup.sh \
  'if secret_scan "$VAULT"; then' \
  'if secret_scan "$VAULT/home" "$VAULT/omarchy"; then'

run_mutation security-control-symlink-followed lib/ress/safety.sh \
  '[[ -f $candidate && ! -L $candidate ]] || return 1' \
  '[[ -f $candidate ]] || return 1'

# ---- status reads a config it did not write -------------------------------

run_mutation status-json-raw-config lib/ress/vault/commands.sh \
  '        --argjson packages "$(config_status_flag INCLUDE_PACKAGES)" \' \
  '        --argjson packages "${CFG[INCLUDE_PACKAGES]}" \'

run_mutation status-manifest-unchecked lib/ress/vault/common.sh \
  '  if jq -e . "$file" >/dev/null 2>&1; then jq -c . "$file"; else printf '"'"'null'"'"'; fi' \
  '  cat "$file" 2>/dev/null || printf '"'"'null'"'"''

# ---- applied-loadout lifecycle -------------------------------------------

run_mutation loadout-registry-schema-ignored lib/ress/loadout/registry.sh \
  '    (.schemaVersion == 1) and (.revision | integer and . >= 0) and' \
  '    true and (.revision | integer and . >= 0) and'

run_mutation loadout-new-fabricated-claim-accepted lib/ress/loadout/registry.sh \
  '    jq -e --arg id "$loadout_id" '\''any(.loadouts[]; .id == $id)'\'' "$file" >/dev/null || return 1' \
  '    :'

run_mutation loadout-isolation-path-name-accepted lib/ress/loadout/registry.sh \
  '      package) valid_pkg "$name" && [[ $id == "package:$name" ]] || return 1 ;;' \
  '      package) : ;;'

run_mutation loadout-preexisting-gains-ownership lib/ress/loadout/planning.sh \
  '          action="protect"; first="present"; cleanup="retain"; claim_status="healthy" ;;' \
  '          action="protect"; first="absent"; cleanup="remove"; claim_status="healthy" ;;'

run_mutation loadout-isolation-conflicts-compatible lib/ress/loadout/planning.sh \
  'definitions_compatible() {' \
  'definitions_compatible() { return 0; #'

run_mutation loadout-shared-resource-deleted lib/ress/loadout/resources.sh \
  '  if (( others > 0 )) || [[ $cleanup == retain || $state == missing ]]; then' \
  '  if (( 0 )) || [[ $cleanup == retain || $state == missing ]]; then'

run_mutation loadout-modified-resource-deleted lib/ress/loadout/resources.sh \
  '  elif [[ $state == present && $cleanup == remove ]]; then' \
  '  elif [[ ( $state == present || $state == modified ) && $cleanup == remove ]]; then'

run_mutation loadout-package-removal-cascades lib/ress/loadout/resources.sh \
  'sudo pacman -R --noconfirm -- "$name"' \
  'sudo pacman -R --cascade --noconfirm -- "$name"'

run_mutation loadout-partial-apply-says-ok lib/ress/loadout/apply.sh \
  '  if [[ $final == healthy ]]; then' \
  '  if [[ $final != healthy ]]; then'

run_mutation loadout-new-check-implicitly-repairs lib/ress/loadout/lifecycle.sh \
  '      result=$(loadout_check_json "$id")' \
  '      ASSUME_YES=1; repair_loadout "$id" >/dev/null 2>&1 || true
      result=$(loadout_check_json "$id")'

# ---- custom Share composition --------------------------------------------

run_mutation share-hides-unshareable lib/ress/loadout/share.sh \
  "public=\$(jq -c '[.[] | del(.definition)]' <<<\"\$candidates\")" \
  "public=\$(jq -c '[.[] | select(.shareable) | del(.definition)]' <<<\"\$candidates\")"

run_mutation share-skips-final-selection-check lib/ress/loadout/share.sh \
  '      [[ -n $candidate ]] || die "selected resource is not on this machine: $(plain "$id")"' \
  '      [[ -n $candidate ]] || continue'

run_mutation share-trusts-panel-definition-option lib/ress/loadout/share.sh \
  '      *) die "unknown share option: $1" ;;' \
  '      --definition) shift 2 ;;
      *) die "unknown share option: $1" ;;'

run_mutation share-skips-withdrawal-ack lib/ress/loadout/share.sh \
  '        [[ ${acknowledgements[$id]:-} == "$fingerprint" ]] ||
          die "acknowledgement required before removing unavailable resource: $(plain "$id")"' \
  '        true ||
          die "acknowledgement required before removing unavailable resource: $(plain "$id")"'

run_mutation share-allows-many-themes lib/ress/loadout/share.sh \
  '    (( theme_count <= 1 )) || die "a schema-version-1 loadout can select at most one theme"' \
  '    (( theme_count >= 0 )) || die "a schema-version-1 loadout can select at most one theme"'

# ---- the protocol ---------------------------------------------------------

run_mutation cleanup-containment-removed lib/ress/core.sh \
  '  [[ $path_real == "$parent_real"/* && -d $path && ! -L $path ]] ||' \
  '  [[ -d $path && ! -L $path ]] ||'

run_mutation porcelain-prose lib/ress/vault/restore-preview.sh \
  'if (( PORCELAIN )); then
    for line in "${lines[@]}"; do emit "LOG|will run: $line"; done
    return 0
  fi' \
  'if (( 0 )); then
    for line in "${lines[@]}"; do emit "LOG|will run: $line"; done
    return 0
  fi'

printf '\n'
if (( survived > 0 || skipped > 0 )); then
  printf '\e[31m%d caught, %d survived, %d skipped\e[0m\n' "$caught" "$survived" "$skipped"
  exit 1
fi
printf '\e[32mall %d mutations caught\e[0m\n' "$caught"
