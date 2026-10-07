# Format-neutral import orchestration.
#
# Adapters translate one already-selected artifact. This module owns native
# repository selection, decisions, consent, staging, validation, commits,
# history iteration, atomic publication, and consumer output.

port_clear_native_snapshot() {
  local root="$1" path base
  while IFS= read -r -d '' path; do
    base=$(basename "$path")
    case "$base" in .git|montage.json|README.md) continue ;; esac
    rm -rf -- "$path" || return 1
  done < <(find "$root" -mindepth 1 -maxdepth 1 -print0)
}

port_initialize_vault_stage() {
  local stage="$1" description="$2" repository_id machine_id created
  repository_id=$(repository_generate_id vault) || return 1
  machine_id=$(repository_generate_id machine) || return 1
  created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  repository_envelope_json vault "$repository_id" "$created" "$machine_id" |
    jq -S . >"$stage/$MONTAGE_REPOSITORY_MANIFEST" || return 1
  printf '# Montage vault\n\n%s\n' "$description" >"$stage/README.md" || return 1
  git -C "$stage" init -q -b main || return 1
  PORT_NATIVE_REPOSITORY_ID="$repository_id"
  PORT_NATIVE_MACHINE_ID="$machine_id"
}

port_validate_native_vault_stage() {
  local stage="$1" repository_id="$2"
  vault_repository_validate_root "$stage" "$repository_id" 1 || return 1
  (VAULT="$stage"; validate_vault_artifact) >/dev/null 2>&1
}

port_publish_history_import() {
  local format="$1" source_root="$2" destination="$3" selected="$4" decisions="$5"
  local parent stage source_commit source_tree destination_commit translations='[]'
  parent=$(dirname "$destination")
  montage_make_temp_dir "$parent/.montage-port-history.XXXXXX" || return 1
  stage="$MONTAGE_TEMP_PATH"
  port_initialize_vault_stage "$stage" "Translated from isolated $format history." || return 1
  while IFS= read -r source_commit; do
    [[ -n $source_commit ]] || continue
    port_materialize_git_commit "$source_root" "$source_commit" || return 1
    source_tree="$PORT_MATERIALIZED_ROOT"
    if ! port_adapter_call validate-history-tree "$source_tree" ||
       ! port_clear_native_snapshot "$stage" ||
       ! port_adapter_call translate-import vault "$source_tree" "$stage" \
          "$PORT_NATIVE_MACHINE_ID" "$decisions" ||
       ! port_validate_native_vault_stage "$stage" "$PORT_NATIVE_REPOSITORY_ID"; then
      repository_history_release "$source_tree" >/dev/null 2>&1 || true
      return 1
    fi
    repository_history_release "$source_tree" >/dev/null 2>&1 || return 1
    git -C "$stage" add -A || return 1
    git -C "$stage" -c commit.gpgsign=false commit -q \
      -m "Translate $format revision ${source_commit:0:12}" || return 1
    destination_commit=$(git -C "$stage" rev-parse HEAD) || return 1
    translations=$(jq -nc --argjson values "$translations" --arg source "$source_commit" \
      --arg destination "$destination_commit" '
      $values + [{sourceCommit:$source,destinationCommit:$destination}]') || return 1
  done < <(jq -r '.[].sourceCommit' <<<"$selected")
  [[ $(jq -r 'length' <<<"$translations") -gt 0 ]] || return 1
  port_publish_staged_directory "$stage" "$destination" || return 1
  PORT_HISTORY_TRANSLATIONS="$translations"
}

port_import_loadout() {
  local format="$1" source="$2" repository="$3" loadout_id="$4" as_json="$5" supplied="$6"
  local root profile item_path report stage rc=0 repository_id commit
  repository_id_valid "$loadout_id" || die "loadout id must be a bounded lowercase id"
  loadout_repository_resolve "$repository" || die "selected Montage loadout repository is invalid"
  root="$LOADOUT_REPOSITORY_PATH"
  item_path="$root/loadouts/$loadout_id"
  port_plan_json "$format" "$source" "$item_path" 0 || rc=$?
  report="$PORT_RESULT"
  if (( rc != 0 )); then
    port_report_output "$report" "$as_json" "$rc"
    return "$rc"
  fi
  [[ $(jq -r '.artifactType' <<<"$report") == loadout ]] || die "source is not a $format loadout"
  profile="$PORT_ADAPTER_CONTROL"
  port_adapter_call prepare-import-decisions loadout "$profile" "$report" "$supplied" || rc=$?
  if (( rc != 0 )); then
    port_report_refuse "$report" "$PORT_ADAPTER_REASON" "$as_json" "$rc"
    return $?
  fi
  repository_id=$(jq -r '.id' "$root/$MONTAGE_REPOSITORY_MANIFEST")
  report=$(port_report_merge_adapter_decisions "$report") || return 1
  report=$(jq -c --arg repositoryId "$repository_id" --arg loadoutId "$loadout_id" '
    .operation="import-loadout" | .repositoryId=$repositoryId | .loadoutId=$loadoutId |
    .published=false' <<<"$report")
  if port_report_dry_run "$report" "$as_json"; then return 0; fi
  confirm "Import this $format loadout as $loadout_id in Montage repository $repository_id?" || die "cancelled"
  repository_lock "$root" || die "Montage repository is busy"
  if ! repository_recover_publication "$root" || ! repository_worktree_clean "$root"; then
    repository_unlock; die "Montage repository must be clean and recoverable"
  fi
  [[ ! -e $item_path && ! -L $item_path ]] || {
    repository_unlock; die "loadout item already exists: $loadout_id"
  }
  repository_stage_dir "$root" || { repository_unlock; die "could not create import staging"; }
  stage="$REPOSITORY_STAGE"
  port_adapter_call validate-import loadout "$profile" || {
    repository_unlock; die "$format loadout changed or became invalid before translation"
  }
  port_adapter_call translate-import loadout "$profile" "$stage" "" \
    "$PORT_ADAPTER_DECISIONS_JSON" || {
    repository_unlock; die "could not translate $format loadout"
  }
  loadout_repository_stage_item_valid "$stage" || {
    repository_unlock; die "translated loadout failed Montage validation"
  }
  repository_publish_path "$root" "$stage" "loadouts/$loadout_id" \
    loadout_repository_stage_item_valid || {
    repository_unlock; die "could not publish translated loadout"
  }
  repository_commit_if_changed "$root" "Import $format loadout $loadout_id" || {
    repository_unlock; die "could not commit translated loadout"
  }
  commit="$REPOSITORY_COMMIT_ID"
  repository_unlock
  report=$(jq -c --arg commit "$commit" '.published=true | .commit=$commit' <<<"$report")
  port_report_complete "$report" "$as_json"
}

port_import_vault() {
  local format="$1" source="$2" destination="$3" as_json="$4" supplied="$5"
  local history="${6:-0}" compatible_only="${7:-0}" accepted_loss="${8:-}"
  local report rc=0 source_root parent stage commit omitted selected
  port_plan_json "$format" "$source" "$destination" "$history" || rc=$?
  report="$PORT_RESULT"
  if (( rc == 3 )) && (( history && compatible_only )) &&
     port_loss_is_accepted unsupported-history-revisions "$accepted_loss"; then
    omitted=$(jq -c '[.selectedRevisions[] | select(.compatible|not) | .sourceCommit]' <<<"$report")
    selected=$(jq -c '[.selectedRevisions[] | select(.compatible)]' <<<"$report")
    if [[ $(jq -r 'length' <<<"$selected") -eq 0 ]]; then
      port_report_output "$report" "$as_json" 2
      return 2
    fi
    report=$(jq -c --argjson selected "$selected" --argjson omitted "$omitted" '
      .selectedRevisions=$selected | .compatible=true | .reason=null |
      .losses += [{code:"unsupported-history-revisions",waivable:true,
        accepted:true,omittedSourceCommits:$omitted}]' <<<"$report")
    rc=0
  fi
  if (( rc != 0 )); then
    port_report_output "$report" "$as_json" "$rc"
    return "$rc"
  fi
  [[ $(jq -r '.artifactType' <<<"$report") == vault ]] || die "source is not a $format vault"
  source_root=$(jq -r '.source' <<<"$report")
  port_adapter_call prepare-import-decisions vault "$source_root" "$report" "$supplied" || rc=$?
  if (( rc != 0 )); then
    port_report_refuse "$report" "$PORT_ADAPTER_REASON" "$as_json" "$rc"
    return $?
  fi
  report=$(port_report_merge_adapter_decisions "$report") || return 1
  if (( history )); then
    report=$(jq -c '.operation="import-vault-history" | .published=false' <<<"$report")
  else
    report=$(jq -c '.operation="import-vault" | .published=false' <<<"$report")
  fi
  if port_report_dry_run "$report" "$as_json"; then return 0; fi
  confirm "Import this $format snapshot into a new Montage vault at $destination?" || die "cancelled"
  if (( history )); then
    selected=$(jq -c '.selectedRevisions' <<<"$report")
    port_publish_history_import "$format" "$source_root" "$destination" "$selected" \
      "$PORT_ADAPTER_DECISIONS_JSON" || die "$format history translation failed before publication"
    report=$(jq -c --arg repositoryId "$PORT_NATIVE_REPOSITORY_ID" \
      --arg machineId "$PORT_NATIVE_MACHINE_ID" --argjson translations "$PORT_HISTORY_TRANSLATIONS" '
      .published=true | .repositoryId=$repositoryId | .machineId=$machineId |
      .translations=$translations | .commit=($translations[-1].destinationCommit)' <<<"$report")
    port_report_complete "$report" "$as_json"
    return 0
  fi
  parent=$(dirname "$destination")
  montage_make_temp_dir "$parent/.montage-port.XXXXXX" || die "could not create vault import staging"
  stage="$MONTAGE_TEMP_PATH"
  port_initialize_vault_stage "$stage" "Imported from a separate $format snapshot." ||
    die "could not initialize translated vault"
  port_adapter_call validate-import vault "$source_root" ||
    die "$format vault changed or became invalid before translation"
  port_adapter_call translate-import vault "$source_root" "$stage" \
    "$PORT_NATIVE_MACHINE_ID" "$PORT_ADAPTER_DECISIONS_JSON" ||
    die "could not translate $format vault snapshot"
  port_validate_native_vault_stage "$stage" "$PORT_NATIVE_REPOSITORY_ID" ||
    die "translated vault failed native validation"
  git -C "$stage" add -A || die "could not stage translated vault"
  git -C "$stage" -c commit.gpgsign=false commit -q -m "Import $format current snapshot" ||
    die "could not commit translated vault"
  commit=$(git -C "$stage" rev-parse HEAD) || die "could not identify translated vault commit"
  port_publish_staged_directory "$stage" "$destination" || die "could not publish translated vault"
  report=$(jq -c --arg repositoryId "$PORT_NATIVE_REPOSITORY_ID" \
    --arg machineId "$PORT_NATIVE_MACHINE_ID" --arg commit "$commit" '
    .published=true | .repositoryId=$repositoryId | .machineId=$machineId | .commit=$commit' <<<"$report")
  port_report_complete "$report" "$as_json"
}
