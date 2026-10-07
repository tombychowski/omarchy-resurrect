# Format-neutral export orchestration.
#
# The shared engine selects an exact native source, gates named losses and
# format decisions, stages output, asks for consent, validates through the
# adapter, publishes atomically, and emits the report.

port_export_report_json() {
  local format="$1" operation="$2" type="$3" source="$4" destination="$5"
  local selected="$6" losses="$7" version="$PORT_ADAPTER_SUPPORTED_VERSION"
  port_report_json "$format" "$operation" "$type" "$version" "$version" "$source" "$destination" \
    "$selected" '[]' "$losses" '[{"code":"create-disposable-compatibility-copy"}]' true ""
}

port_export_refuse_unaccepted_loss() {
  local format="$1" operation="$2" type="$3" source="$4" destination="$5" loss="$6" as_json="$7"
  local report losses
  losses=$(jq -nc --arg code "$loss" '[{code:$code,waivable:true,accepted:false}]')
  report=$(port_export_report_json "$format" "$operation" "$type" "$source" \
    "$destination" '[]' "$losses") || return 1
  PORT_RESULT=$(jq -c '.compatible=false | .reason="loss-acceptance-required"' <<<"$report")
  port_report_output "$PORT_RESULT" "$as_json" 3
  return 3
}

port_export_publish() {
  local format="$1" kind="$2" source="$3" destination="$4" decisions="$5" stage
  montage_make_temp_dir "$(dirname "$destination")/.montage-port-export.XXXXXX" ||
    die "could not create export staging"
  stage="$MONTAGE_TEMP_PATH"
  port_adapter_call translate-export "$kind" "$source" "$stage" "$decisions" &&
    port_adapter_call validate-export "$kind" "$stage" ||
    die "$format $kind export failed translation or validation"
  port_publish_staged_directory "$stage" "$destination" ||
    die "could not publish $format $kind copy"
}

port_export_loadout() {
  local format="$1" repository="$2" loadout_id="$3" destination="$4" as_json="$5"
  local accepted_loss="$6" supplied="$7" loss root work profile report selected losses commit repository_id rc=0
  repository_id_valid "$loadout_id" || die "loadout id must be a bounded lowercase id"
  loss=$(port_adapter_call export-loss-code loadout) || return 1
  port_loss_is_accepted "$loss" "$accepted_loss" || {
    port_export_refuse_unaccepted_loss "$format" export-loadout loadout \
      "$repository:$loadout_id" "$destination" "$loss" "$as_json"
    return $?
  }
  port_destination_validate "" "$destination" ||
    die "$format export destination must be absent or explicitly empty"
  loadout_repository_resolve "$repository" || die "selected Montage loadout repository is invalid"
  root="$LOADOUT_REPOSITORY_PATH"
  private_dir "$STATE_DIR/port/$format"
  montage_make_temp_dir "$STATE_DIR/port/$format/export-loadout.XXXXXX" ||
    die "could not create loadout export workspace"
  work="$MONTAGE_TEMP_PATH"
  loadout_repository_fetch_profile "$root" "$loadout_id" "$work" ||
    die "could not read selected Montage loadout"
  profile="$work/profile.json"
  commit="$APPLY_REPOSITORY_COMMIT"
  repository_id="$APPLY_REPOSITORY_ID"
  selected=$(jq -nc --arg repositoryId "$repository_id" --arg loadoutId "$loadout_id" \
    --arg commit "$commit" '[{repositoryId:$repositoryId,loadoutId:$loadoutId,commit:$commit}]')
  losses=$(jq -nc --arg code "$loss" '[{code:$code,waivable:true,accepted:true}]')
  report=$(port_export_report_json "$format" export-loadout loadout "$root" "$destination" \
    "$selected" "$losses") || return 1
  port_adapter_call prepare-export-decisions loadout "$profile" "$supplied" || rc=$?
  if (( rc != 0 )); then
    port_report_refuse "$report" "$PORT_ADAPTER_REASON" "$as_json" "$rc"
    return $?
  fi
  report=$(port_report_merge_adapter_decisions "$report") || return 1
  if port_report_dry_run "$report" "$as_json"; then return 0; fi
  confirm "Export this Montage loadout to a separate $format copy at $destination?" || die "cancelled"
  port_export_publish "$format" loadout "$profile" "$destination" "$PORT_ADAPTER_DECISIONS_JSON"
  report=$(jq -c '.published=true' <<<"$report")
  port_report_complete "$report" "$as_json"
}

port_export_backup() {
  local format="$1" selector="$2" destination="$3" as_json="$4"
  local accepted_loss="$5" supplied="$6" loss tree repository_id commit selected losses report rc=0
  loss=$(port_adapter_call export-loss-code backup) || return 1
  port_loss_is_accepted "$loss" "$accepted_loss" || {
    port_export_refuse_unaccepted_loss "$format" export-backup vault \
      "configured-vault:$selector" "$destination" "$loss" "$as_json"
    return $?
  }
  port_destination_validate "" "$destination" ||
    die "$format export destination must be absent or explicitly empty"
  resolve_vault
  vault_select_backup_tree "$VAULT" "$selector" || die "selected Montage backup is invalid"
  tree="$VAULT_SELECTED_TREE"
  repository_id="$VAULT_SELECTED_REPOSITORY_ID"
  commit="$VAULT_SELECTED_COMMIT"
  selected=$(jq -nc --arg repositoryId "$repository_id" --arg commit "$commit" \
    '[{repositoryId:$repositoryId,commit:$commit}]')
  losses=$(jq -nc --arg code "$loss" '[{code:$code,waivable:true,accepted:true}]')
  report=$(port_export_report_json "$format" export-backup vault "$VAULT" "$destination" \
    "$selected" "$losses") || return 1
  port_adapter_call prepare-export-decisions backup "$tree" "$supplied" || rc=$?
  if (( rc != 0 )); then
    repository_history_release "$tree" >/dev/null 2>&1 || true
    port_report_refuse "$report" "$PORT_ADAPTER_REASON" "$as_json" "$rc"
    return $?
  fi
  report=$(port_report_merge_adapter_decisions "$report") || return 1
  if (( DRY_RUN )); then
    repository_history_release "$tree" >/dev/null 2>&1 || true
    port_report_dry_run "$report" "$as_json"
    return 0
  fi
  confirm "Export this exact Montage backup to a separate $format copy at $destination?" || die "cancelled"
  if ! port_export_publish "$format" backup "$tree" "$destination" \
       "$PORT_ADAPTER_DECISIONS_JSON"; then
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  fi
  repository_history_release "$tree" >/dev/null 2>&1 || die "could not release selected backup"
  report=$(jq -c '.published=true' <<<"$report")
  port_report_complete "$report" "$as_json"
}
