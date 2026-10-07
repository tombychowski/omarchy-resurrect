# Format-neutral artifact-port lifecycle primitives.
#
# Adapters own foreign schemas and translation. This module owns invariants
# that every adapter must preserve: stable reports, isolated history reads,
# separate destinations, exact loss consent, and staged publication.

PORT_DESTINATION_REASON=""
PORT_MATERIALIZED_ROOT=""

port_format_id_valid() {
  [[ $1 =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]]
}

port_report_json() {
  local format="$1" operation="$2" artifact_type="$3" artifact_version="$4"
  local supported_version="$5" source="$6" destination="$7" selected="$8"
  local warnings="$9" losses="${10}" mutations="${11}" compatible="${12}" reason="${13}"
  port_format_id_valid "$format" || return 1
  port_format_id_valid "$operation" || return 1
  port_format_id_valid "$artifact_type" || return 1
  jq -nc --arg format "$format" --arg operation "$operation" --arg type "$artifact_type" \
    --arg version "$artifact_version" --arg supported "$supported_version" \
    --arg source "$source" --arg destination "$destination" \
    --argjson selected "$selected" --argjson warnings "$warnings" \
    --argjson losses "$losses" --argjson mutations "$mutations" \
    --arg compatible "$compatible" --arg reason "$reason" '
    {schemaVersion:1,kind:"montage-port-report",format:$format,operation:$operation,
     artifactType:$type,
     artifactVersion:(if $version=="" then null else ($version|tonumber) end),
     supportedArtifactVersion:($supported|tonumber),source:$source,
     destination:(if $destination=="" then null else $destination end),
     selectedRevisions:$selected,warnings:$warnings,losses:$losses,mutations:$mutations,
     compatible:($compatible=="true"),reason:(if $reason=="" then null else $reason end),
     published:false}'
}

port_destination_validate() {
  local source_root="$1" destination="$2" parent destination_real
  PORT_DESTINATION_REASON=""
  if [[ $destination != /* ]]; then
    PORT_DESTINATION_REASON=unsafe-destination
    return 1
  fi
  if [[ -n $source_root ]] &&
     [[ $destination == "$source_root" || $destination == "$source_root"/* ||
        $source_root == "$destination"/* ]]; then
    PORT_DESTINATION_REASON=source-destination-overlap
    return 1
  fi
  parent=$(dirname "$destination")
  if [[ ! -d $parent || -L $parent ||
        $(realpath -e -- "$parent" 2>/dev/null) != "$parent" ]]; then
    PORT_DESTINATION_REASON=unsafe-destination-parent
    return 1
  fi
  if [[ -e $destination || -L $destination ]]; then
    if [[ ! -d $destination || -L $destination ||
          -n $(find "$destination" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ]]; then
      PORT_DESTINATION_REASON=destination-not-empty
      return 1
    fi
    destination_real=$(realpath -e -- "$destination")
    if [[ $destination_real != "$destination" ]]; then
      PORT_DESTINATION_REASON=unsafe-destination
      return 1
    fi
  fi
}

port_materialize_git_commit() {
  local root="$1" commit="$2"
  valid_sha "$commit" || return 1
  repository_materialize_git_tree "$root" "$commit" || return 1
  PORT_MATERIALIZED_ROOT="$REPOSITORY_HISTORY_TREE"
}

port_loss_is_accepted() {
  local required="$1" supplied="$2"
  [[ -n $required && $supplied == "$required" ]]
}

port_report_merge_adapter_decisions() {
  local report="$1"
  jq -c --argjson fields "$PORT_ADAPTER_DECISION_FIELDS_JSON" '. + $fields' <<<"$report"
}

port_report_refuse() {
  local report="$1" reason="$2" as_json="$3" rc="${4:-3}"
  PORT_RESULT=$(jq -c --arg reason "$reason" \
    '.compatible=false | .reason=$reason | .published=false' <<<"$report") || return 1
  port_report_output "$PORT_RESULT" "$as_json" "$rc"
  return "$rc"
}

port_report_dry_run() {
  local report="$1" as_json="$2"
  PORT_RESULT="$report"
  (( DRY_RUN )) || return 1
  port_report_output "$report" "$as_json" 0
}

port_report_complete() {
  PORT_RESULT="$1"
  port_report_output "$1" "$2" 0
}

port_publish_staged_directory() {
  local stage="$1" destination="$2"
  [[ -d $stage && ! -L $stage ]] || return 1
  port_destination_validate "" "$destination" || return 1
  if [[ -d $destination ]]; then
    rmdir -- "$destination" || return 1
  fi
  mv -- "$stage" "$destination"
}

port_report_print_human() {
  local report="$1"
  printf '%s %s: %s\n' "$(jq -r '.format' <<<"$report")" \
    "$(jq -r '.artifactType' <<<"$report")" "$(jq -r '.source' <<<"$report")"
  printf '  compatible: %s (supported version %s)\n' \
    "$(jq -r '.compatible' <<<"$report")" "$(jq -r '.supportedArtifactVersion' <<<"$report")"
  [[ $(jq -r '.destination // ""' <<<"$report") == "" ]] ||
    printf '  destination: %s\n' "$(jq -r '.destination' <<<"$report")"
  [[ $(jq -r '.reason // ""' <<<"$report") == "" ]] ||
    printf '  reason: %s\n' "$(jq -r '.reason' <<<"$report")"
  printf '  selected revisions: %s\n  warnings: %s\n  losses: %s\n  planned mutations: %s\n' \
    "$(jq -r '.selectedRevisions|length' <<<"$report")" \
    "$(jq -r '.warnings|length' <<<"$report")" \
    "$(jq -r '.losses|length' <<<"$report")" \
    "$(jq -r '.mutations|length' <<<"$report")"
}

port_report_output() {
  local report="$1" as_json="$2" rc="${3:-0}" revision loss
  if (( PORCELAIN )); then
    emit "BEGIN|port|$(jq -r '.format' <<<"$report")|$(jq -r '.operation' <<<"$report")|$(jq -r '.artifactType' <<<"$report")"
    emit "PORT|1|$(jq -r '[.format,.operation,.artifactType,(.compatible|tostring),(.published // false|tostring),(.reason // "")] | join("|")' <<<"$report")"
    if jq -e '.repositoryId or .loadoutId or .commit' <<<"$report" >/dev/null 2>&1; then
      emit "PORT_IDENTITY|$(jq -r '.repositoryId // ""' <<<"$report")|$(jq -r '.loadoutId // ""' <<<"$report")|$(jq -r '.commit // ""' <<<"$report")"
    fi
    while IFS= read -r revision; do
      emit "PORT_REVISION|$(jq -r '[.sourceCommit // .commit // .selector // "",(.compatible // true|tostring),(.reason // "")] | join("|")' <<<"$revision")"
    done < <(jq -c '.selectedRevisions[]?' <<<"$report")
    while IFS= read -r loss; do
      emit "PORT_LOSS|$(jq -r '[.code,(.accepted // false|tostring),(.waivable // false|tostring)] | join("|")' <<<"$loss")"
    done < <(jq -c '.losses[]?' <<<"$report")
    if (( rc == 0 )); then emit "DONE|ok|port operation complete"
    elif (( rc == 3 )); then emit "DONE|decision|required"
    else emit "DONE|fail|port operation refused"; fi
  elif (( as_json )); then
    printf '%s\n' "$report"
  else
    port_report_print_human "$report"
  fi
}
