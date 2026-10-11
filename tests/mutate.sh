#!/bin/bash
#
# Mutation testing for the mntg suite.
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
WORK="${TMPDIR:-/tmp}/mntg-mutation.$$"
FILTER="${1:-}"
BASELINE_FILTER="${MONTAGE_MUTATION_BASELINE_FILTER:-}"

# Only the mutation-runner self-test may narrow the baseline, and it selects no
# mutations. A real sweep, including a filtered mutation sweep, always proves a
# clean full-suite baseline first.
if [[ -n $BASELINE_FILTER && $FILTER != no-such-mutation ]]; then
  printf 'MONTAGE_MUTATION_BASELINE_FILTER is only valid with the no-such-mutation self-test filter\n' >&2
  exit 2
fi

trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK"

# Visible to the cases: one of them exercises this runner, and the runner's full
# baseline must not recursively exercise its own baseline self-test.
export MONTAGE_MUTATION_RUN=1

# A mutation is caught when the suite goes red, so a case that is already red
# makes every mutation below look caught. A clean sweep on a red baseline is
# worse than no run at all: it is a false claim of coverage, and it is the way a
# mutation that changes nothing gets believed. So the baseline is checked first.
printf 'Baseline\n'
baseline_args=()
[[ -z $BASELINE_FILTER ]] || baseline_args+=("$BASELINE_FILTER")
baseline=$(cd "$SRC" && ./tests/run.sh --jobs "${MONTAGE_TEST_JOBS:-4}" "${baseline_args[@]}" 2>&1)
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
  [audit-destination-containment]=50-repository-transaction
  [audit-ress-overlap]=61-ress-loadout-import
  [audit-journal-upgrade]=50-repository-transaction
  [audit-package-inventory]=71-observation-failure
  [audit-preview-provenance]=73-preview-migration
  [audit-migration-output]=73-preview-migration
  [audit-panel-health-exit]=72-panel-producer-consumer
  [audit-ress-consumer]=72-panel-producer-consumer
  [audit-panel-field-focus]=72-panel-producer-consumer
  [audit-preset-theme]=16-qml
  [aur-always-builds]=38-loadout-repair-aur
  [aur-ignores-flag]=38-loadout-repair-aur
  [aur-ignores-denylist]=38-loadout-repair-aur
  [operation-dryrun-marker]=23-loadout-lock
  [operation-marker-token-ignored]=23-loadout-lock
  [source-scheme-ignored]=43-url-credentials
  [plain-not-applied]=44-untrusted-controls
  [webapp-quotes-kept]=44-untrusted-controls
  [webapp-share-publishes-refused]=40-share-compose
  [webapp-long-line-unbounded]=44-untrusted-controls
  [settings-unvalidated]=13-settings
  [config-no-lock]=42-config-lock
  [operation-config-lock-timeout-ignored]=42-config-lock
  [security-repository-remote-unsanitized]=43-url-credentials
  [security-profile-webapp-credential-accepted]=43-url-credentials
  [security-control-symlink-followed]=44-untrusted-controls
  [status-invalid-state-healthy]=68-loadout-protocol
  [status-update-evidence-ignored]=70-status-attention
  [status-uses-mutating-registry-loader]=70-status-attention
  [repository-migration-skips-retained-validation]=58-repository-migration
  [repository-migration-opens-retired-path]=58-repository-migration
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
  [porcelain-prose]=28-tracked-apply
  [link-overwrites-foreign]=41-cli-modules
  [repository-lock-ignored]=50-repository-transaction
  [repository-staged-validation-skipped]=50-repository-transaction
  [repository-noop-commits]=50-repository-transaction
  [repository-recovery-drops-original]=50-repository-transaction
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
  local production_files=("$dir/bin/mntg") file
  if [[ -d $dir/lib/montage ]]; then
    while IFS= read -r file; do production_files+=("$file"); done < <(
      find "$dir/lib/montage" -type f -name '*.sh' -print | sort
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

run_mutation aur-always-builds lib/montage/machine/packages.sh \
  '  AUR_KEPT=()
  AUR_MODE="skip"' \
  '  AUR_KEPT=()
  AUR_MODE="build"'

run_mutation aur-ignores-flag lib/montage/machine/packages.sh \
  'local decision="${AUR_CHOICE:-}"' \
  'local decision="yes"'

run_mutation aur-ignores-denylist lib/montage/machine/packages.sh \
  'aur_denied() { merged_list aur-deny | grep -qxF -- "$1"; }' \
  'aur_denied() { return 1; }'

run_mutation operation-dryrun-marker lib/montage/core.sh \
  'if (( ! DRY_RUN )); then' \
  'if (( 1 )); then'

run_mutation operation-marker-token-ignored lib/montage/core.sh \
  'if [[ $marker_token == "$RUNNING_MARKER_TOKEN" ]]; then' \
  'if [[ -n $marker_token ]]; then'

run_mutation source-scheme-ignored lib/montage/safety.sh \
  '  case "$src" in
    http://*|https://*) ;;  # the https forms the shorthands below are written for' \
  '  case "" in
    http://*|https://*) ;;  # the guard can never match, so nothing is passed through'

run_mutation plain-not-applied lib/montage/safety.sh \
  'plain() { printf '"'"'%s'"'"' "$1" | tr -d '"'"'\000-\037\177'"'"'; }' \
  'plain() { printf '"'"'%s'"'"' "$1"; }'

# ---- web app launchers ----------------------------------------------------

run_mutation webapp-quotes-kept lib/montage/safety.sh \
  'in_quote=1; i=$((i + 1)); continue; fi' \
  'in_quote=1; i=$((i + 1)); fi'

run_mutation webapp-share-publishes-refused lib/montage/loadout/share.sh \
  '    definition=$(jq -nc --arg name "$name" --arg url "$web_url" --arg icon "$icon" \
      '\''{name:$name,url:$url,icon:$icon}'\'')
    if [[ -z $code ]]; then
      rows+=("$(share_candidate_json "$id" webapp "$name" true "" "" "$none" false "$definition")")' \
  '    definition=$(jq -nc --arg name "$name" --arg url "$web_url" --arg icon "$icon" \
      '\''{name:$name,url:$url,icon:$icon}'\'')
    if true; then
      rows+=("$(share_candidate_json "$id" webapp "$name" true "" "" "$none" false "$definition")")'

run_mutation webapp-long-line-unbounded lib/montage/safety.sh \
  '  (( ${#exec_line} <= WEBAPP_MAX_EXEC )) || return 1' \
  '  :'

run_mutation settings-unvalidated lib/montage/commands.sh \
  '    config_validate_value "$key" "$value"' \
  '    :'

run_mutation config-no-lock lib/montage/commands.sh \
  'take_config_lock
  load_config' \
  ':'

run_mutation operation-config-lock-timeout-ignored lib/montage/core.sh \
  'flock -w 5 8 || die "configuration is busy; try again"' \
  'flock -w 5 8 || true'

run_mutation security-repository-remote-unsanitized lib/montage/safety.sh \
  'strip_credentials() {
  local url="$1"
  if url_has_credentials "$url"; then
    url="${url%%://*}://${url#*://}"
    url="${url%%://*}://${url#*@}"
  fi
  printf '\''%s'\'' "$url"
}' \
  'strip_credentials() { printf '\''%s'\'' "$1"; }'

run_mutation security-profile-webapp-credential-accepted lib/montage/loadout/profile.sh \
  'url_has_credentials "$url" &&
      die "loadout contains a credential-bearing web app URL"' \
  'false &&
      die "loadout contains a credential-bearing web app URL"'

run_mutation security-control-symlink-followed lib/montage/safety.sh \
  '[[ -f $candidate && ! -L $candidate ]] || return 1' \
  '[[ -f $candidate ]] || return 1'

# ---- loadout-only status --------------------------------------------------

run_mutation status-invalid-state-healthy lib/montage/commands.sh \
  '          $(jq -r '"'"'.available'"'"' <<<"$loadouts") != true ||' \
  '          false ||'

run_mutation status-update-evidence-ignored lib/montage/commands.sh \
  '  if loadout_status_evidence_load; then' \
  '  if false; then'

run_mutation status-uses-mutating-registry-loader lib/montage/repository/commands.sh \
  '  if [[ $mode == status ]]; then repository_registry_load_for_status || return 1' \
  '  if [[ $mode == status ]]; then repository_registry_load || return 1'

# ---- configured-registry migration ---------------------------------------

run_mutation repository-migration-skips-retained-validation lib/montage/repository/registry.sh \
  '    if ! repository_registry_validate_retained_entry "$entry"; then' \
  '    if false; then'

run_mutation repository-migration-opens-retired-path lib/montage/repository/registry.sh \
  '.repositories[] | select(.type == "loadouts") | .' \
  '.repositories[] | .'

# ---- applied-loadout lifecycle -------------------------------------------

run_mutation loadout-registry-schema-ignored lib/montage/loadout/registry.sh \
  '    (.schemaVersion == 1) and (.revision | integer and . >= 0) and' \
  '    true and (.revision | integer and . >= 0) and'

run_mutation loadout-new-fabricated-claim-accepted lib/montage/loadout/registry.sh \
  '    jq -e --arg id "$loadout_id" '\''any(.loadouts[]; .id == $id)'\'' "$file" >/dev/null || return 1' \
  '    :'

run_mutation loadout-isolation-path-name-accepted lib/montage/loadout/registry.sh \
  '      package) valid_pkg "$name" && [[ $id == "package:$name" ]] || return 1 ;;' \
  '      package) : ;;'

run_mutation loadout-preexisting-gains-ownership lib/montage/loadout/planning.sh \
  '          action="protect"; first="present"; cleanup="retain"; claim_status="healthy" ;;' \
  '          action="protect"; first="absent"; cleanup="remove"; claim_status="healthy" ;;'

run_mutation loadout-isolation-conflicts-compatible lib/montage/loadout/planning.sh \
  'definitions_compatible() {' \
  'definitions_compatible() { return 0; #'

run_mutation loadout-shared-resource-deleted lib/montage/loadout/resources.sh \
  '  if (( others > 0 )) || [[ $cleanup == retain || $state == missing ]]; then' \
  '  if (( 0 )) || [[ $cleanup == retain || $state == missing ]]; then'

run_mutation loadout-modified-resource-deleted lib/montage/loadout/resources.sh \
  '  elif [[ $state == present && $cleanup == remove ]]; then' \
  '  elif [[ ( $state == present || $state == modified ) && $cleanup == remove ]]; then'

run_mutation loadout-package-removal-cascades lib/montage/loadout/resources.sh \
  'sudo pacman -R --noconfirm -- "$name"' \
  'sudo pacman -R --cascade --noconfirm -- "$name"'

run_mutation loadout-partial-apply-says-ok lib/montage/loadout/apply.sh \
  '  if [[ $final == healthy ]]; then' \
  '  if [[ $final != healthy ]]; then'

run_mutation loadout-new-check-implicitly-repairs lib/montage/loadout/lifecycle.sh \
  '      result=$(loadout_check_json "$id")' \
  '      ASSUME_YES=1; repair_loadout "$id" >/dev/null 2>&1 || true
      result=$(loadout_check_json "$id")'

# ---- custom Share composition --------------------------------------------

run_mutation share-hides-unshareable lib/montage/loadout/share.sh \
  "public=\$(jq -c '[.[] | del(.definition)]' <<<\"\$candidates\")" \
  "public=\$(jq -c '[.[] | select(.shareable) | del(.definition)]' <<<\"\$candidates\")"

run_mutation share-skips-final-selection-check lib/montage/loadout/share.sh \
  '      [[ -n $candidate ]] || die "selected resource is not on this machine: $(plain "$id")"' \
  '      [[ -n $candidate ]] || continue'

run_mutation share-trusts-panel-definition-option lib/montage/loadout/share.sh \
  '      *) die "unknown share option: $1" ;;' \
  '      --definition) shift 2 ;;
      *) die "unknown share option: $1" ;;'

run_mutation share-skips-withdrawal-ack lib/montage/loadout/share.sh \
  '        [[ ${acknowledgements[$id]:-} == "$fingerprint" ]] ||
          die "acknowledgement required before removing unavailable resource: $(plain "$id")"' \
  '        true ||
          die "acknowledgement required before removing unavailable resource: $(plain "$id")"'

run_mutation share-allows-many-themes lib/montage/loadout/share.sh \
  '    (( theme_count <= 1 )) || die "a schema-version-1 loadout can select at most one theme"' \
  '    (( theme_count >= 0 )) || die "a schema-version-1 loadout can select at most one theme"'

# ---- retained command and repository boundaries --------------------------

run_mutation link-overwrites-foreign lib/montage/commands.sh \
  '        [[ -L $target && $target_resolved == "$source_resolved" ]] ||
          die "$target belongs to another program; move it explicitly before linking Montage"' \
  '        true ||
          die "$target belongs to another program; move it explicitly before linking Montage"'

run_mutation repository-lock-ignored lib/montage/repository/transaction.sh \
  '  flock -n "$REPOSITORY_LOCK_FD" || {
    exec {REPOSITORY_LOCK_FD}>&-
    REPOSITORY_LOCK_FD=""
    return 1
  }' \
  '  flock -n "$REPOSITORY_LOCK_FD" || true'

run_mutation repository-staged-validation-skipped lib/montage/repository/transaction.sh \
  '  [[ -z $validator ]] || "$validator" "$staged_real" || return 1' \
  '  :'

run_mutation repository-noop-commits lib/montage/repository/transaction.sh \
  '    REPOSITORY_COMMIT_ID=$(git -C "$root" rev-parse HEAD 2>/dev/null || true)
    return 0
  fi' \
  '    REPOSITORY_COMMIT_ID=$(git -C "$root" rev-parse HEAD 2>/dev/null || true)
  fi'

run_mutation repository-recovery-drops-original lib/montage/repository/transaction.sh \
  '        mv -- "$original" "$target"' \
  '        rm -rf -- "$original"'

# ---- the protocol ---------------------------------------------------------

run_mutation cleanup-containment-removed lib/montage/core.sh \
  '  [[ $path_real == "$parent_real"/* && -d $path && ! -L $path ]] ||' \
  '  [[ -d $path && ! -L $path ]] ||'

run_mutation porcelain-prose lib/montage/loadout/apply.sh \
  '    (( PORCELAIN )) || printf '"'"'%sDry run — nothing was installed. Nothing was tracked.%s\n'"'"' "$c_dim" "$c_reset"' \
  '    printf '"'"'%sDry run — nothing was installed. Nothing was tracked.%s\n'"'"' "$c_dim" "$c_reset"'


# ---- independent audit regression detectors --------------------------------

run_mutation audit-destination-containment lib/montage/repository/transaction.sh \
  '  canonical=$(realpath -m -- "$target") || return 1
  [[ $canonical == "$target" && ! -L $target ]] || return 1
  parent=$(dirname "$target")
  while [[ $parent != "$root" ]]; do
    [[ ! -L $parent && ( ! -e $parent || -d $parent ) ]] || return 1
    parent=$(dirname "$parent")
  done' \
  '  return 0'

run_mutation audit-ress-overlap lib/montage/port/ress.sh \
  '  if [[ $RESS_MIGRATION_SOURCE_ROOT == "$RESS_MIGRATION_REPOSITORY_ROOT" ||
        $RESS_MIGRATION_SOURCE_ROOT == "$RESS_MIGRATION_REPOSITORY_ROOT"/* ||
        $RESS_MIGRATION_REPOSITORY_ROOT == "$RESS_MIGRATION_SOURCE_ROOT"/* ]]; then
    RESS_MIGRATION_REASON=source-destination-overlap
    return 2
  fi' \
  '  :'

run_mutation audit-journal-upgrade lib/montage/repository/transaction.sh \
  '    (keys == ["backup","root","schemaVersion","staged","state","target"] or
     keys == ["original","root","schemaVersion","staged","state","target"]) and' \
  '    keys == ["original","root","schemaVersion","staged","state","target"] and'

run_mutation audit-package-inventory lib/montage/machine/packages.sh \
  '  if ! inventory=$(pacman -Qq 2>/dev/null); then
    MACHINE_PACKAGE_SNAPSHOT_READY=-1
    return 1
  fi' \
  '  inventory=$(pacman -Qq 2>/dev/null || true)'

run_mutation audit-preview-provenance lib/montage/loadout/lifecycle.sh \
  '    if (( ! DRY_RUN )) && [[ -n $repository_id && $resolved_commit != "$(jq -r '"'"'.commit'"'"' <<<"$old")" ]]; then' \
  '    if [[ -n $repository_id && $resolved_commit != "$(jq -r '"'"'.commit'"'"' <<<"$old")" ]]; then'

run_mutation audit-migration-output lib/montage/loadout/share.sh \
  'counts:$counts,limits:{themes:1},migration:$migration}' \
  'counts:$counts,limits:{themes:1}}'

run_mutation audit-panel-health-exit Service.qml \
  '      if (exitCode !== 0 && exitCode !== 1) root.rejectLoadouts()' \
  '      if (exitCode !== 0) root.rejectLoadouts()'

run_mutation audit-ress-consumer Model.js \
  '      !value.decisions || Array.isArray(value.decisions) ||' \
  '      !Array.isArray(value.decisions) ||'

run_mutation audit-panel-field-focus Panel.qml \
  '    if (id === "share-search") { shareSearchField.forceActiveFocus(); return }' \
  '    if (id === "share-search") return'

run_mutation audit-preset-theme Model.js \
  '      conflict = id
      continue' \
  '      conflict = id'
printf '\n'
if (( survived > 0 || skipped > 0 )); then
  printf '\e[31m%d caught, %d survived, %d skipped\e[0m\n' "$caught" "$survived" "$skipped"
  exit 1
fi
printf '\e[32mall %d mutations caught\e[0m\n' "$caught"
