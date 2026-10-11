#!/bin/bash
#
# Focused, import-only Ress v1 portable-loadout migration. This module reads
# one contained profile, reports exact decisions, and publishes one selected
# native library item through the repository transaction boundary.

RESS_V1_SCHEMA=1
RESS_V1_SELF_PLUGIN="tsouth89.resurrect"
RESS_V1_MONTAGE_PLUGIN="tombychowski.montage"

RESS_MIGRATION_SOURCE_ROOT=""
RESS_MIGRATION_PROFILE=""
RESS_MIGRATION_SOURCE_VERSION=""
RESS_MIGRATION_SOURCE_DIGEST=""
RESS_MIGRATION_WARNINGS='[]'
RESS_MIGRATION_LOSSES='[]'
RESS_MIGRATION_DECISIONS='{"ressPlugin":"not-applicable","montagePlugin":"not-applicable"}'
RESS_MIGRATION_READY=false
RESS_MIGRATION_REASON=""
RESS_MIGRATION_RESULT=""
RESS_MIGRATION_DESTINATION='null'
RESS_MIGRATION_REPOSITORY_ROOT=""
RESS_MIGRATION_ITEM_PATH=""

ress_migration_reset() {
  RESS_MIGRATION_SOURCE_ROOT=""
  RESS_MIGRATION_PROFILE=""
  RESS_MIGRATION_SOURCE_VERSION=""
  RESS_MIGRATION_SOURCE_DIGEST=""
  RESS_MIGRATION_WARNINGS='[]'
  RESS_MIGRATION_LOSSES='[]'
  RESS_MIGRATION_DECISIONS='{"ressPlugin":"not-applicable","montagePlugin":"not-applicable"}'
  RESS_MIGRATION_READY=false
  RESS_MIGRATION_REASON=""
  RESS_MIGRATION_DESTINATION='null'
  RESS_MIGRATION_REPOSITORY_ROOT=""
  RESS_MIGRATION_ITEM_PATH=""
}

ress_migration_profile_version() {
  local file="$1"
  jq -er 'if (.schemaVersion|type)=="number" and
    (.schemaVersion|floor)==.schemaVersion then .schemaVersion
    else error("invalid") end' "$file" 2>/dev/null
}

ress_migration_source_discover() {
  local source="$1" canonical control="" extra
  ress_migration_reset
  if [[ -L $source || ! -e $source ]]; then
    RESS_MIGRATION_REASON=unsafe-or-missing-source
    return 2
  fi
  canonical=$(realpath -e -- "$source" 2>/dev/null) || {
    RESS_MIGRATION_REASON=unsafe-or-missing-source
    return 2
  }
  if [[ -f $canonical && ! -L $canonical ]]; then
    [[ $(basename "$canonical") == profile.json ]] || {
      RESS_MIGRATION_SOURCE_ROOT=$(dirname "$canonical")
      RESS_MIGRATION_REASON=outside-loadout-boundary
      return 2
    }
    RESS_MIGRATION_SOURCE_ROOT=$(dirname "$canonical")
    control=$(safe_control_file "$RESS_MIGRATION_SOURCE_ROOT" profile.json) || {
      RESS_MIGRATION_REASON=unsafe-profile-control
      return 2
    }
  elif [[ -d $canonical && ! -L $canonical ]]; then
    RESS_MIGRATION_SOURCE_ROOT="$canonical"
    if [[ ! -e $canonical/profile.json && ! -L $canonical/profile.json ]]; then
      RESS_MIGRATION_REASON=outside-loadout-boundary
      return 2
    fi
    control=$(safe_control_file "$canonical" profile.json) || {
      RESS_MIGRATION_REASON=unsafe-profile-control
      return 2
    }
  else
    RESS_MIGRATION_REASON=unsafe-or-missing-source
    return 2
  fi
  RESS_MIGRATION_PROFILE="$control"
  jq -e . "$control" >/dev/null 2>&1 || {
    RESS_MIGRATION_REASON=malformed-or-unsafe-profile
    return 2
  }
  RESS_MIGRATION_SOURCE_VERSION=$(ress_migration_profile_version "$control" || true)
  if [[ -z $RESS_MIGRATION_SOURCE_VERSION ]]; then
    RESS_MIGRATION_REASON=invalid-version
    return 2
  fi
  if [[ $RESS_MIGRATION_SOURCE_VERSION != "$RESS_V1_SCHEMA" ]]; then
    RESS_MIGRATION_REASON=unsupported-version
    return 2
  fi
  profile_document_valid "$(<"$control")" || {
    RESS_MIGRATION_REASON=malformed-or-unsafe-profile
    return 2
  }
  RESS_MIGRATION_SOURCE_DIGEST=$(sha256sum "$control" | awk '{print $1}')
  extra=$(find -P "$RESS_MIGRATION_SOURCE_ROOT" -mindepth 1 -maxdepth 1 \
    ! -name profile.json ! -name README.md ! -name .git -print -quit 2>/dev/null || true)
  if [[ -n $extra ]]; then
    RESS_MIGRATION_WARNINGS='[{"code":"non-profile-content-ignored"}]'
  fi
}

ress_migration_decisions_prepare() {
  local ress_decision="$1" montage_decision="$2" has_ress=false has_montage=false
  jq -e --arg id "$RESS_V1_SELF_PLUGIN" 'any(.plugins[]; .id==$id)' \
    "$RESS_MIGRATION_PROFILE" >/dev/null && has_ress=true
  jq -e --arg id "$RESS_V1_MONTAGE_PLUGIN" 'any(.plugins[]; .id==$id)' \
    "$RESS_MIGRATION_PROFILE" >/dev/null && has_montage=true
  [[ -z $ress_decision || $ress_decision == include || $ress_decision == omit ]] || return 1
  [[ -z $montage_decision || $montage_decision == include || $montage_decision == omit ]] || return 1

  local ress_value=not-applicable montage_value=not-applicable losses='[]'
  if [[ $has_ress == true ]]; then
    ress_value="${ress_decision:-required}"
    losses=$(jq -c --arg decision "$ress_value" \
      '. + [{code:"ress-self-plugin",waivable:true,decision:$decision,
        accepted:($decision=="include" or $decision=="omit")}]' <<<"$losses")
  fi
  if [[ $has_montage == true ]]; then
    montage_value="${montage_decision:-required}"
    losses=$(jq -c --arg decision "$montage_value" \
      '. + [{code:"montage-self-plugin",waivable:true,decision:$decision,
        accepted:($decision=="include" or $decision=="omit")}]' <<<"$losses")
  fi
  RESS_MIGRATION_LOSSES="$losses"
  RESS_MIGRATION_DECISIONS=$(jq -nc --arg ress "$ress_value" --arg montage "$montage_value" \
    '{ressPlugin:$ress,montagePlugin:$montage}')
  if [[ $ress_value != required && $montage_value != required ]]; then
    RESS_MIGRATION_READY=true
    RESS_MIGRATION_REASON=""
  else
    RESS_MIGRATION_READY=false
    RESS_MIGRATION_REASON=self-plugin-decision-required
  fi
}

ress_migration_destination_resolve() {
  local repository="$1" loadout_id="$2" repository_id journal
  repository_id_valid "$loadout_id" || {
    RESS_MIGRATION_REASON=invalid-loadout-id
    return 2
  }
  loadout_repository_resolve "$repository" || {
    RESS_MIGRATION_REASON=invalid-or-unavailable-repository
    return 2
  }
  RESS_MIGRATION_REPOSITORY_ROOT="$LOADOUT_REPOSITORY_PATH"
  RESS_MIGRATION_ITEM_PATH="$RESS_MIGRATION_REPOSITORY_ROOT/loadouts/$loadout_id"
  if [[ $RESS_MIGRATION_SOURCE_ROOT == "$RESS_MIGRATION_REPOSITORY_ROOT" ||
        $RESS_MIGRATION_SOURCE_ROOT == "$RESS_MIGRATION_REPOSITORY_ROOT"/* ||
        $RESS_MIGRATION_REPOSITORY_ROOT == "$RESS_MIGRATION_SOURCE_ROOT"/* ]]; then
    RESS_MIGRATION_REASON=source-destination-overlap
    return 2
  fi
  repository_destination_valid "$RESS_MIGRATION_REPOSITORY_ROOT" "loadouts/$loadout_id" || {
    RESS_MIGRATION_REASON=unsafe-destination-path
    return 2
  }
  repository_id=$(jq -r '.id' "$RESS_MIGRATION_REPOSITORY_ROOT/$MONTAGE_REPOSITORY_MANIFEST")
  RESS_MIGRATION_DESTINATION=$(jq -nc --arg name "$repository" --arg id "$repository_id" \
    --arg loadout "$loadout_id" --arg path "$RESS_MIGRATION_ITEM_PATH" \
    '{repositoryName:$name,repositoryId:$id,loadoutId:$loadout,path:$path}')
  journal=$(repository_journal_path "$RESS_MIGRATION_REPOSITORY_ROOT") || {
    RESS_MIGRATION_REASON=invalid-or-unavailable-repository
    return 2
  }
  [[ ! -e $journal && ! -L $journal ]] || {
    RESS_MIGRATION_REASON=repository-recovery-required
    return 2
  }
  repository_worktree_clean "$RESS_MIGRATION_REPOSITORY_ROOT" || {
    RESS_MIGRATION_REASON=repository-not-clean
    return 2
  }
  [[ ! -e $RESS_MIGRATION_ITEM_PATH && ! -L $RESS_MIGRATION_ITEM_PATH ]] || {
    RESS_MIGRATION_REASON=loadout-item-exists
    return 2
  }
}

ress_migration_result_build() {
  local operation="$1" compatible="$2" planned="$3" published="$4" commit="${5:-}"
  local source='null' version='null'
  if [[ -n $RESS_MIGRATION_SOURCE_ROOT ]]; then
    source=$(jq -nc --arg root "$RESS_MIGRATION_SOURCE_ROOT" --arg profile "$RESS_MIGRATION_PROFILE" \
      '{root:$root,profile:(if $profile=="" then null else $profile end)}')
  fi
  [[ -z $RESS_MIGRATION_SOURCE_VERSION ]] || version="$RESS_MIGRATION_SOURCE_VERSION"
  RESS_MIGRATION_RESULT=$(jq -nc --arg operation "$operation" \
    --argjson source "$source" --argjson version "$version" \
    --argjson destination "$RESS_MIGRATION_DESTINATION" \
    --argjson warnings "$RESS_MIGRATION_WARNINGS" --argjson losses "$RESS_MIGRATION_LOSSES" \
    --argjson decisions "$RESS_MIGRATION_DECISIONS" --argjson compatible "$compatible" \
    --argjson ready "$RESS_MIGRATION_READY" --arg reason "$RESS_MIGRATION_REASON" \
    --argjson planned "$planned" --argjson published "$published" --arg commit "$commit" \
    --argjson migration "$REPOSITORY_REGISTRY_MIGRATION" '
    {schemaVersion:1,kind:"montage-ress-loadout-migration",operation:$operation,
     format:"ress-v1",supportedSourceSchemaVersion:1,sourceSchemaVersion:$version,
     source:$source,destination:$destination,compatible:$compatible,ready:$ready,
     reason:(if $reason=="" then null else $reason end),warnings:$warnings,
     losses:$losses,decisions:$decisions,migration:$migration,
     publication:{planned:$planned,published:$published,
       commit:(if $commit=="" then null else $commit end)}}')
}

ress_migration_output() {
  local report="$1" as_json="$2" rc="${3:-0}" loss
  if (( PORCELAIN )); then
    emit "BEGIN|ress-migration|1"
    repository_migration_notice
    emit "RESS|1|$(jq -r '[.operation,(.compatible|tostring),(.ready|tostring),(.publication.published|tostring),(.reason // "")] | join("|")' <<<"$report")"
    while IFS= read -r loss; do
      emit "RESS_LOSS|$(jq -r '[.code,.decision,(.waivable|tostring)] | join("|")' <<<"$loss")"
    done < <(jq -c '.losses[]' <<<"$report")
    if (( rc == 0 )); then emit "DONE|ok|Ress loadout migration complete"
    elif (( rc == 3 )); then emit "DONE|decision|required"
    else emit "DONE|fail|Ress loadout migration refused"; fi
  elif (( as_json )); then
    printf '%s\n' "$report"
  else
    repository_migration_notice
    printf 'Ress v1 loadout migration: %s\n' "$(jq -r '.source.profile // .source.root // "unavailable"' <<<"$report")"
    printf '  compatible: %s\n  ready: %s\n' \
      "$(jq -r '.compatible' <<<"$report")" "$(jq -r '.ready' <<<"$report")"
    [[ $(jq -r '.reason // ""' <<<"$report") == "" ]] ||
      printf '  reason: %s\n' "$(jq -r '.reason' <<<"$report")"
    while IFS= read -r loss; do
      printf '  decision: %s = %s\n' "$(jq -r '.code' <<<"$loss")" "$(jq -r '.decision' <<<"$loss")"
    done < <(jq -c '.losses[]' <<<"$report")
    [[ $(jq -r '.destination // empty' <<<"$report") == "" ]] ||
      printf '  destination: %s/%s\n' "$(jq -r '.destination.repositoryId' <<<"$report")" \
        "$(jq -r '.destination.loadoutId' <<<"$report")"
    printf '  published: %s\n' "$(jq -r '.publication.published' <<<"$report")"
  fi
}

ress_migration_translate_profile() {
  local source="$1" destination="$2" ress_decision="$3" montage_decision="$4"
  jq --arg ress "$RESS_V1_SELF_PLUGIN" --arg montage "$RESS_V1_MONTAGE_PLUGIN" \
    --arg rd "$ress_decision" --arg md "$montage_decision" '
    .plugins |= map(select((.id != $ress or $rd == "include") and
                           (.id != $montage or $md == "include")))
  ' "$source" >"$destination" || return 1
  profile_document_valid "$(<"$destination")"
}

ress_migration_inspect() {
  local source="$1" as_json="$2" ress_decision="$3" montage_decision="$4" rc=0
  ress_migration_source_discover "$source" || rc=$?
  if (( rc == 0 )); then
    ress_migration_decisions_prepare "$ress_decision" "$montage_decision" ||
      die "self-plugin decisions must be include or omit"
    ress_migration_result_build inspect true false false
    ress_migration_output "$RESS_MIGRATION_RESULT" "$as_json" 0
    return 0
  fi
  RESS_MIGRATION_READY=false
  ress_migration_result_build inspect false false false
  ress_migration_output "$RESS_MIGRATION_RESULT" "$as_json" "$rc"
  return "$rc"
}

ress_migration_import() {
  local source="$1" repository="$2" loadout_id="$3" as_json="$4"
  local ress_decision="$5" montage_decision="$6" rc=0 stage commit current_digest
  ress_migration_source_discover "$source" || rc=$?
  if (( rc != 0 )); then
    RESS_MIGRATION_READY=false
    ress_migration_result_build import-loadout false false false
    ress_migration_output "$RESS_MIGRATION_RESULT" "$as_json" "$rc"
    return "$rc"
  fi
  ress_migration_decisions_prepare "$ress_decision" "$montage_decision" ||
    die "self-plugin decisions must be include or omit"
  ress_migration_destination_resolve "$repository" "$loadout_id" || rc=$?
  if (( rc != 0 )); then
    RESS_MIGRATION_READY=false
    ress_migration_result_build import-loadout false false false
    ress_migration_output "$RESS_MIGRATION_RESULT" "$as_json" "$rc"
    return "$rc"
  fi
  if [[ $RESS_MIGRATION_READY != true ]]; then
    ress_migration_result_build import-loadout true false false
    ress_migration_output "$RESS_MIGRATION_RESULT" "$as_json" 3
    return 3
  fi
  montage_make_temp_dir || die "could not create Ress migration staging"
  stage="$MONTAGE_TEMP_PATH"
  ress_migration_translate_profile "$RESS_MIGRATION_PROFILE" "$stage/profile.json" \
    "$(jq -r '.ressPlugin' <<<"$RESS_MIGRATION_DECISIONS")" \
    "$(jq -r '.montagePlugin' <<<"$RESS_MIGRATION_DECISIONS")" ||
    die "translated Ress profile is not a valid Montage loadout"
  ress_migration_result_build import-loadout true true false
  if (( DRY_RUN )); then
    ress_migration_output "$RESS_MIGRATION_RESULT" "$as_json" 0
    return 0
  fi
  confirm "Import this Ress v1 loadout into the selected Montage library item?" || die "cancelled"
  repository_lock "$RESS_MIGRATION_REPOSITORY_ROOT" || die "Montage repository is busy"
  if ! repository_recover_publication "$RESS_MIGRATION_REPOSITORY_ROOT" ||
     ! repository_worktree_clean "$RESS_MIGRATION_REPOSITORY_ROOT"; then
    repository_unlock
    die "Montage repository must be clean and recoverable"
  fi
  ress_migration_destination_resolve "$repository" "$loadout_id" || {
    repository_unlock
    die "Ress destination changed or is unsafe: $RESS_MIGRATION_REASON"
  }
  [[ ! -e $RESS_MIGRATION_ITEM_PATH && ! -L $RESS_MIGRATION_ITEM_PATH ]] || {
    repository_unlock
    die "loadout item already exists: $loadout_id"
  }
  current_digest=$(sha256sum "$RESS_MIGRATION_PROFILE" 2>/dev/null | awk '{print $1}')
  [[ $current_digest == "$RESS_MIGRATION_SOURCE_DIGEST" ]] || {
    repository_unlock
    die "Ress source changed after inspection"
  }
  profile_document_valid "$(<"$RESS_MIGRATION_PROFILE")" || {
    repository_unlock
    die "Ress source changed or became invalid"
  }
  repository_stage_dir "$RESS_MIGRATION_REPOSITORY_ROOT" || {
    repository_unlock
    die "could not create repository staging"
  }
  stage="$REPOSITORY_STAGE"
  ress_migration_translate_profile "$RESS_MIGRATION_PROFILE" "$stage/profile.json" \
    "$(jq -r '.ressPlugin' <<<"$RESS_MIGRATION_DECISIONS")" \
    "$(jq -r '.montagePlugin' <<<"$RESS_MIGRATION_DECISIONS")" || {
    repository_unlock
    die "could not translate Ress loadout"
  }
  loadout_repository_stage_item_valid "$stage" || {
    repository_unlock
    die "translated loadout failed native validation"
  }
  repository_publish_path "$RESS_MIGRATION_REPOSITORY_ROOT" "$stage" \
    "loadouts/$loadout_id" loadout_repository_stage_item_valid || {
    repository_unlock
    die "could not publish translated loadout"
  }
  repository_commit_if_changed "$RESS_MIGRATION_REPOSITORY_ROOT" \
    "Import Ress v1 loadout $loadout_id" || {
    repository_unlock
    die "could not commit translated loadout"
  }
  commit="$REPOSITORY_COMMIT_ID"
  repository_unlock
  ress_migration_result_build import-loadout true true true "$commit"
  ress_migration_output "$RESS_MIGRATION_RESULT" "$as_json" 0
}
