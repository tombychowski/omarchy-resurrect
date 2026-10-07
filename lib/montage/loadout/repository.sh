#!/bin/bash
#
# Native multi-loadout repository lifecycle and discovery. Stable loadout ids
# live in directory names; portable profile.json leaves retain their independent
# Omarchy loadout schema.

LOADOUT_REPOSITORY_PATH=""
APPLY_REPOSITORY_ID=""
APPLY_LOADOUT_ID=""
APPLY_REPOSITORY_COMMIT=""
APPLY_REPOSITORY_SOURCE=""

loadout_repository_resolve() {
  local selector="$1" entry path
  if [[ $selector == /* ]]; then
    path="$selector"
  else
    repository_registry_load || return 1
    entry=$(repository_registry_get "$selector") || return 1
    [[ $(jq -r '.type' <<<"$entry") == loadouts ]] || return 1
    path=$(jq -r '.path' <<<"$entry")
    [[ $(jq -r '.id' <<<"$entry") == "$(jq -r '.id' "$path/$MONTAGE_REPOSITORY_MANIFEST" 2>/dev/null)" ]] || return 1
  fi
  repository_root_valid "$path" || return 1
  repository_envelope_validate_file "$path/$MONTAGE_REPOSITORY_MANIFEST" loadouts || return 1
  LOADOUT_REPOSITORY_PATH="$path"
}

loadout_repository_profile_valid() {
  local file="$1" profile
  [[ -f $file && ! -L $file ]] || return 1
  profile=$(<"$file")
  profile_document_valid "$profile"
}

loadout_repository_history_valid() {
  local root="$1" commit="$2" expected_id="$3" tree catalog
  repository_materialize_history "$root" "$commit" loadouts || return 1
  tree="$REPOSITORY_HISTORY_TREE"
  [[ $(jq -r '.id' "$tree/$MONTAGE_REPOSITORY_MANIFEST") == "$expected_id" ]] || {
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  }
  catalog=$(loadout_repository_catalog_json "$tree") || {
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  }
  repository_history_release "$tree" || return 1
  [[ $(jq -r '.invalid | length' <<<"$catalog") == 0 ]]
}

loadout_repository_catalog_json() {
  local root="$1" repo_id repository_commit loadouts_dir entry id profile profile_json digest reason
  local items='[]' invalid='[]'
  loadout_repository_resolve "$root" || return 1
  root="$LOADOUT_REPOSITORY_PATH"
  repo_id=$(jq -r '.id' "$root/$MONTAGE_REPOSITORY_MANIFEST")
  repository_commit=$(git -C "$root" rev-parse --verify HEAD^{commit} 2>/dev/null || true)
  loadouts_dir="$root/loadouts"
  if [[ -e $loadouts_dir || -L $loadouts_dir ]]; then
    [[ -d $loadouts_dir && ! -L $loadouts_dir ]] || return 1
    [[ $(realpath -e -- "$loadouts_dir") == "$root/loadouts" ]] || return 1
  else
    jq -nc --arg repositoryId "$repo_id" --arg repositoryCommit "$repository_commit" --arg path "$root" \
      '{schemaVersion:1,kind:"montage-loadout-catalog",repositoryId:$repositoryId,
       repositoryCommit:(if $repositoryCommit=="" then null else $repositoryCommit end),
       path:$path,items:[],invalid:[]}'
    return
  fi

  while IFS= read -r -d '' entry; do
    id=$(basename "$entry")
    reason=""
    profile=""
    if ! repository_id_valid "$id"; then
      reason=hostile-id
    elif [[ ! -d $entry || -L $entry ]] || [[ $(realpath -e -- "$entry" 2>/dev/null) != "$entry" ]]; then
      reason=unsafe-directory
    elif ! profile=$(repository_loadout_profile_path "$root" "$id"); then
      reason=missing-or-unsafe-profile
    elif ! loadout_repository_profile_valid "$profile"; then
      reason=invalid-profile
    fi
    if [[ -n $reason ]]; then
      invalid=$(jq -nc --argjson values "$invalid" --arg id "$id" --arg reason "$reason" \
        '$values + [{id:$id,reason:$reason}]') || return 1
      continue
    fi
    profile_json=$(<"$profile")
    digest=$(profile_digest "$profile") || return 1
    items=$(jq -nc --argjson values "$items" --arg id "$id" --arg digest "$digest" \
      --arg repositoryId "$repo_id" --arg repositoryCommit "$repository_commit" \
      --arg relativePath "loadouts/$id/profile.json" --argjson profile "$profile_json" '
        $values + [{id:$id,name:$profile.name,author:$profile.author,
          description:$profile.description,createdAt:$profile.createdAt,digest:$digest,
          repositoryId:$repositoryId,
          repositoryCommit:(if $repositoryCommit=="" then null else $repositoryCommit end),
          relativePath:$relativePath}]') || return 1
  done < <(find "$loadouts_dir" -mindepth 1 -maxdepth 1 -print0 | sort -z)

  jq -nc --arg repositoryId "$repo_id" --arg repositoryCommit "$repository_commit" --arg path "$root" \
    --argjson items "$items" --argjson invalid "$invalid" '
      {schemaVersion:1,kind:"montage-loadout-catalog",repositoryId:$repositoryId,
       repositoryCommit:(if $repositoryCommit=="" then null else $repositoryCommit end),
       path:$path,items:($items|sort_by(.id)),invalid:($invalid|sort_by(.id))}'
}

loadout_repository_initialize() {
  local path="$1" id="$2" created="${3:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" parent stage
  repository_id_valid "$id" || return 1
  repository_timestamp_valid "$created" || return 1
  [[ $path == /* && ! -e $path && ! -L $path ]] || return 1
  parent=$(dirname "$path")
  [[ -d $parent && ! -L $parent ]] || return 1
  [[ $(realpath -e -- "$parent") == "$parent" ]] || return 1
  montage_make_temp_dir "$parent/.montage-loadouts.XXXXXX" || return 1
  stage="$MONTAGE_TEMP_PATH"
  mkdir "$stage/loadouts" || { rm -rf -- "$stage"; return 1; }
  repository_envelope_json loadouts "$id" "$created" >"$stage/$MONTAGE_REPOSITORY_MANIFEST" || {
    rm -rf -- "$stage"; return 1
  }
  git -C "$stage" init -q -b main || { rm -rf -- "$stage"; return 1; }
  git -C "$stage" add -A || { rm -rf -- "$stage"; return 1; }
  git -C "$stage" -c commit.gpgsign=false commit -q -m "Initialize Montage loadout repository" || {
    rm -rf -- "$stage"; return 1
  }
  mv -- "$stage" "$path" || { rm -rf -- "$stage"; return 1; }
  LOADOUT_REPOSITORY_PATH="$path"
}

loadout_repository_item_json() {
  local selector="$1" id="$2" catalog
  repository_id_valid "$id" || return 1
  catalog=$(loadout_repository_catalog_json "$selector") || return 1
  jq -ce --arg id "$id" '.items[] | select(.id == $id)' <<<"$catalog"
}

loadout_repository_rename() {
  local selector="$1" id="$2" name="$3" description="$4" root item profile stage next
  profile_metadata_valid "$name" "$description" || return 1
  repository_id_valid "$id" || return 1
  loadout_repository_resolve "$selector" || return 1
  root="$LOADOUT_REPOSITORY_PATH"
  repository_lock "$root" || return 1
  if ! repository_recover_publication "$root" || ! repository_worktree_clean "$root"; then
    repository_unlock; return 1
  fi
  item=$(loadout_repository_item_json "$root" "$id") || { repository_unlock; return 1; }
  profile=$(repository_loadout_profile_path "$root" "$id") || { repository_unlock; return 1; }
  repository_stage_dir "$root" || { repository_unlock; return 1; }
  stage="$REPOSITORY_STAGE"
  cp -a -- "$(dirname "$profile")/." "$stage/" || { repository_unlock; return 1; }
  next="$stage/.profile.next"
  jq --arg name "$name" --arg description "$description" \
    '.name=$name | .description=$description' "$stage/profile.json" >"$next" || {
      repository_unlock; return 1
    }
  mv -- "$next" "$stage/profile.json"
  if ! repository_publish_path "$root" "$stage" "loadouts/$id" loadout_repository_stage_item_valid; then
    repository_unlock; return 1
  fi
  if ! repository_commit_if_changed "$root" "Rename loadout $id"; then
    repository_unlock; return 1
  fi
  repository_unlock
  loadout_repository_item_json "$root" "$id"
}

loadout_repository_stage_item_valid() {
  local stage="$1" profile
  repository_tree_links_contained "$stage" || return 1
  profile=$(safe_control_file "$stage" profile.json) || return 1
  loadout_repository_profile_valid "$profile"
}

# Resolve a configured selector, local repository, or remote repository once;
# pin its current HEAD to an exact commit; and copy only the selected portable
# leaf from the isolated historical tree into DEST.
loadout_repository_fetch_profile() {
  local source="$1" loadout_id="$2" dest="$3" root="" entry="" configured_remote=""
  local commit history profile repository_id stored_source clone="$dest/repository"
  repository_id_valid "$loadout_id" || return 1
  APPLY_REPOSITORY_ID=""; APPLY_LOADOUT_ID=""; APPLY_REPOSITORY_COMMIT=""; APPLY_REPOSITORY_SOURCE=""

  if repository_id_valid "$source" && repository_registry_load 2>/dev/null; then
    entry=$(repository_registry_get "$source" 2>/dev/null || true)
  fi
  if [[ -n $entry ]]; then
    [[ $(jq -r '.type' <<<"$entry") == loadouts ]] || return 1
    root=$(jq -r '.path' <<<"$entry")
    configured_remote=$(jq -r '.remote' <<<"$entry")
    stored_source="${configured_remote:-$root}"
  elif [[ -d $source && ! -L $source ]]; then
    root=$(realpath -e -- "$source") || return 1
    stored_source="$root"
  else
    source=$(normalize_source "$source") || return 1
    valid_git_remote "$source" || return 1
    git clone -q -- "$source" "$clone" >/dev/null 2>&1 || return 1
    root=$(realpath -e -- "$clone") || return 1
    stored_source=$(strip_credentials "$source")
    git -C "$root" remote set-url origin "$stored_source" >/dev/null 2>&1 || true
  fi

  repository_root_valid "$root" || return 1
  repository_envelope_validate_file "$root/$MONTAGE_REPOSITORY_MANIFEST" loadouts || return 1
  if [[ -n $entry ]]; then
    [[ $(jq -r '.id' <<<"$entry") == "$(jq -r '.id' "$root/$MONTAGE_REPOSITORY_MANIFEST")" ]] || return 1
  fi
  commit=$(repository_resolve_commit "$root" HEAD) || return 1
  repository_materialize_history "$root" "$commit" loadouts || return 1
  history="$REPOSITORY_HISTORY_TREE"
  profile=$(repository_loadout_profile_path "$history" "$loadout_id") || {
    repository_history_release "$history"; return 1
  }
  loadout_repository_profile_valid "$profile" || {
    repository_history_release "$history"; return 1
  }
  cp -- "$profile" "$dest/profile.json" || {
    repository_history_release "$history"; return 1
  }
  repository_id=$(jq -r '.id' "$history/$MONTAGE_REPOSITORY_MANIFEST")
  repository_history_release "$history" || return 1

  APPLY_REPOSITORY_ID="$repository_id"
  APPLY_LOADOUT_ID="$loadout_id"
  APPLY_REPOSITORY_COMMIT="$commit"
  APPLY_REPOSITORY_SOURCE=$(strip_credentials "$stored_source")
}
