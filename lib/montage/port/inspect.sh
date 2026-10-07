# Format-neutral inspection, history selection, and mutation planning.

PORT_RESULT=""
PORT_HISTORY_PLAN='[]'

port_inspection_json() {
  local format="$1" source="$2" destination="${3:-}" operation="${4:-inspect}"
  local rc=0 compatible=true report
  port_adapter_call inspect "$source" || rc=$?
  if (( rc != 0 )); then
    compatible=false
    PORT_ADAPTER_ARTIFACT_TYPE=unknown
    PORT_ADAPTER_SOURCE_ROOT="$source"
  fi
  report=$(port_report_json "$format" "$operation" "$PORT_ADAPTER_ARTIFACT_TYPE" \
    "$PORT_ADAPTER_VERSION" "$PORT_ADAPTER_SUPPORTED_VERSION" \
    "$PORT_ADAPTER_SOURCE_ROOT" "$destination" '[]' \
    "$PORT_ADAPTER_WARNINGS_JSON" "$PORT_ADAPTER_LOSSES_JSON" '[]' \
    "$compatible" "$PORT_ADAPTER_REASON") || return 1
  PORT_RESULT=$(jq -c --argjson fields "$PORT_ADAPTER_REPORT_FIELDS_JSON" '. + $fields' <<<"$report") || return 1
  (( rc == 0 )) || return 2
}

port_history_plan_json() {
  local format="$1" root="$2" commit tree reason created selected='[]'
  [[ -d $root/.git && ! -L $root/.git ]] || return 1
  while IFS= read -r commit; do
    [[ -n $commit ]] || continue
    reason=""; created=""; tree=""
    if port_materialize_git_commit "$root" "$commit"; then
      tree="$PORT_MATERIALIZED_ROOT"
      PORT_ADAPTER_REASON=""
      if port_adapter_call validate-history-tree "$tree"; then
        created=$(port_adapter_call revision-created-at "$tree") || reason=malformed-or-unsupported-revision
      else
        reason="${PORT_ADAPTER_REASON:-malformed-or-unsupported-revision}"
      fi
      repository_history_release "$tree" >/dev/null 2>&1 || true
    else
      reason=materialization-failed
    fi
    selected=$(jq -nc --argjson values "$selected" --arg commit "$commit" \
      --arg created "$created" --arg reason "$reason" '
      $values + [{sourceCommit:$commit,createdAt:(if $created=="" then null else $created end),
        compatible:($reason==""),reason:(if $reason=="" then null else $reason end)}]') || return 1
  done < <(git -C "$root" rev-list --reverse --first-parent HEAD 2>/dev/null)
  [[ $(jq -r 'length' <<<"$selected") -gt 0 ]] || return 1
  PORT_HISTORY_PLAN="$selected"
}

port_plan_mutations_json() {
  local artifact_type="$1" history="$2"
  if (( history )); then
    printf '[{"code":"create-vault-repository"},{"code":"translate-history"}]'
  elif [[ $artifact_type == loadout ]]; then
    printf '[{"code":"create-loadout-item"},{"code":"create-montage-commit"}]'
  elif [[ $artifact_type == vault ]]; then
    printf '[{"code":"create-vault-repository"},{"code":"create-montage-commit"}]'
  else
    return 1
  fi
}

port_plan_json() {
  local format="$1" source="$2" destination="$3" history="${4:-0}" rc=0
  local selected='[]' mutations='[]' source_root artifact_type report
  port_inspection_json "$format" "$source" "$destination" plan || return $?
  report="$PORT_RESULT"
  source_root=$(jq -r '.source' <<<"$report")
  artifact_type=$(jq -r '.artifactType' <<<"$report")
  if [[ $artifact_type != loadout && $artifact_type != vault ]]; then
    PORT_RESULT=$(jq -c '.compatible=false | .reason="incomplete-artifact" | .mutations=[]' <<<"$report")
    return 2
  fi
  if ! port_destination_validate "$source_root" "$destination"; then
    PORT_RESULT=$(jq -c --arg reason "$PORT_DESTINATION_REASON" \
      '.compatible=false | .reason=$reason' <<<"$report")
    return 2
  fi
  if (( history )); then
    if [[ $artifact_type != vault ]]; then
      PORT_RESULT=$(jq -c '.compatible=false | .reason="history-requires-vault"' <<<"$report")
      return 2
    fi
    if ! port_history_plan_json "$format" "$source_root"; then
      PORT_RESULT=$(jq -c '.compatible=false | .reason="history-unavailable"' <<<"$report")
      return 2
    fi
    selected="$PORT_HISTORY_PLAN"
    jq -e 'any(.[]; .compatible|not)' <<<"$selected" >/dev/null && rc=3
  else
    selected='[{"selector":"current","compatible":true,"reason":null}]'
  fi
  mutations=$(port_plan_mutations_json "$artifact_type" "$history") || return 1
  PORT_RESULT=$(jq -c --argjson selected "$selected" --argjson mutations "$mutations" '
    .selectedRevisions=$selected | .mutations=$mutations |
    if any($selected[]; .compatible|not) then
      .compatible=false | .reason="unsupported-history-revision"
    else . end' <<<"$report") || return 1
  return "$rc"
}
