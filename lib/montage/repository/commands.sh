#!/bin/bash
#
# Human and JSON command surface for configured native repositories. This is
# the consumer boundary used by the panel; callers do not inspect envelopes or
# the registry directly.

repository_inspect_path_json() {
  local name="$1" path="$2" expected_type="${3:-}" expected_id="${4:-}" remote="${5:-}"
  local status=healthy valid=true canonical="" envelope=null current_type="" current_id=""

  if [[ $path != /* || ! -d $path || -L $path ]]; then
    status=unsafe-path; valid=false
  elif ! canonical=$(realpath -e -- "$path" 2>/dev/null) || [[ $canonical != "$path" ]]; then
    status=path-not-canonical; valid=false
  elif ! repository_envelope_validate_file "$path/$MONTAGE_REPOSITORY_MANIFEST"; then
    status=invalid-envelope; valid=false
  else
    envelope=$(<"$path/$MONTAGE_REPOSITORY_MANIFEST")
    current_type=$(jq -r '.repositoryType' <<<"$envelope")
    current_id=$(jq -r '.id' <<<"$envelope")
    if [[ -n $expected_type && $current_type != "$expected_type" ]]; then
      status=type-mismatch; valid=false
    elif [[ -n $expected_id && $current_id != "$expected_id" ]]; then
      status=identity-mismatch; valid=false
    fi
  fi

  jq -nc --arg name "$name" --arg path "$path" --arg type "$expected_type" \
    --arg id "$expected_id" --arg remote "$remote" --arg status "$status" \
    --arg currentType "$current_type" --arg currentId "$current_id" \
    --argjson valid "$valid" --argjson envelope "$envelope" '
      {name:$name,path:$path,type:$type,id:$id,remote:$remote,valid:$valid,
       status:$status,currentType:$currentType,currentId:$currentId,envelope:$envelope}'
}

repository_inspect_entry_json() {
  local entry="$1"
  repository_inspect_path_json \
    "$(jq -r '.name' <<<"$entry")" \
    "$(jq -r '.path' <<<"$entry")" \
    "$(jq -r '.type' <<<"$entry")" \
    "$(jq -r '.id' <<<"$entry")" \
    "$(jq -r '.remote' <<<"$entry")"
}

repository_catalog_json() {
  local entry inspected items='[]'
  repository_registry_load || return 1
  while IFS= read -r entry; do
    inspected=$(repository_inspect_entry_json "$entry") || return 1
    items=$(jq -nc --argjson items "$items" --argjson item "$inspected" '$items + [$item]') || return 1
  done < <(jq -c '.repositories[]' <<<"$REPOSITORY_REGISTRY")
  jq -nc --argjson revision "$(jq -r '.revision' <<<"$REPOSITORY_REGISTRY")" \
    --argjson repositories "$items" \
    '{schemaVersion:1,kind:"montage-repository-list",revision:$revision,repositories:$repositories}'
}

repository_print_human() {
  local item="$1" remote
  remote=$(jq -r '.remote' <<<"$item")
  printf '%s  %s  %s  %s\n' \
    "$(jq -r '.name // "(unconfigured)"' <<<"$item")" \
    "$(jq -r '.type // ""' <<<"$item")" \
    "$(jq -r '.status' <<<"$item")" \
    "$(jq -r '.path' <<<"$item")"
  [[ -z $remote ]] || printf '  remote: %s\n' "$remote"
}

repository_command_json_flag() {
  REPOSITORY_COMMAND_JSON=0
  REPOSITORY_COMMAND_ARGS=()
  while (( $# > 0 )); do
    case "$1" in
      --json) REPOSITORY_COMMAND_JSON=1 ;;
      *) REPOSITORY_COMMAND_ARGS+=("$1") ;;
    esac
    shift
  done
}

cmd_repository_list() {
  repository_command_json_flag "$@"
  (( ${#REPOSITORY_COMMAND_ARGS[@]} == 0 )) || die "repository list accepts only --json"
  local catalog item
  catalog=$(repository_catalog_json) || die "repository configuration is malformed or unsupported"
  if (( REPOSITORY_COMMAND_JSON )); then
    printf '%s\n' "$catalog"
    return
  fi
  if [[ $(jq -r '.repositories | length' <<<"$catalog") == 0 ]]; then
    printf 'No Montage repositories are configured.\n'
    return
  fi
  while IFS= read -r item; do repository_print_human "$item"; done \
    < <(jq -c '.repositories[]' <<<"$catalog")
}

cmd_repository_show() {
  repository_command_json_flag "$@"
  (( ${#REPOSITORY_COMMAND_ARGS[@]} == 1 )) || die "usage: mntg repository show NAME [--json]"
  local entry item name="${REPOSITORY_COMMAND_ARGS[0]}"
  repository_registry_load || die "repository configuration is malformed or unsupported"
  entry=$(repository_registry_get "$name") || die "repository is not configured: $name"
  item=$(repository_inspect_entry_json "$entry") || die "could not inspect repository: $name"
  if (( REPOSITORY_COMMAND_JSON )); then
    jq -nc --argjson repository "$item" \
      '{schemaVersion:1,kind:"montage-repository-show",repository:$repository}'
  else
    repository_print_human "$item"
    printf '  expected id: %s\n' "$(jq -r '.id' <<<"$item")"
    [[ $(jq -r '.currentId' <<<"$item") == "" ]] ||
      printf '  current id:  %s\n' "$(jq -r '.currentId' <<<"$item")"
  fi
  jq -e '.valid' <<<"$item" >/dev/null
}

cmd_repository_validate() {
  repository_command_json_flag "$@"
  local expected_type="" target="" index=0 arg entry item name=""
  while (( index < ${#REPOSITORY_COMMAND_ARGS[@]} )); do
    arg="${REPOSITORY_COMMAND_ARGS[index]}"
    case "$arg" in
      --type)
        index=$((index + 1)); expected_type="${REPOSITORY_COMMAND_ARGS[index]:-}"
        repository_type_valid "$expected_type" || die "--type must be loadouts or vault"
        ;;
      --type=*)
        expected_type="${arg#*=}"; repository_type_valid "$expected_type" || die "--type must be loadouts or vault"
        ;;
      *) [[ -z $target ]] || die "usage: mntg repository validate NAME|PATH [--type TYPE] [--json]"; target="$arg" ;;
    esac
    index=$((index + 1))
  done
  [[ -n $target ]] || die "usage: mntg repository validate NAME|PATH [--type TYPE] [--json]"

  if [[ $target == /* ]]; then
    item=$(repository_inspect_path_json "" "$target" "$expected_type" "" "") ||
      die "could not inspect repository path"
  else
    repository_registry_load || die "repository configuration is malformed or unsupported"
    entry=$(repository_registry_get "$target") || die "repository is not configured: $target"
    name="$target"
    if [[ -n $expected_type && $(jq -r '.type' <<<"$entry") != "$expected_type" ]]; then
      entry=$(jq -c --arg type "$expected_type" '.type=$type' <<<"$entry")
    fi
    item=$(repository_inspect_entry_json "$entry") || die "could not inspect repository: $name"
  fi

  if (( REPOSITORY_COMMAND_JSON )); then
    jq -nc --argjson repository "$item" \
      '{schemaVersion:1,kind:"montage-repository-validation",repository:$repository}'
  else
    repository_print_human "$item"
  fi
  jq -e '.valid' <<<"$item" >/dev/null
}

cmd_repository_configure() {
  repository_command_json_flag "$@"
  local name="" path="" type="" remote="" replace="" index=0 arg rc entry item visibility=unknown
  while (( index < ${#REPOSITORY_COMMAND_ARGS[@]} )); do
    arg="${REPOSITORY_COMMAND_ARGS[index]}"
    case "$arg" in
      --remote)
        index=$((index + 1)); remote="${REPOSITORY_COMMAND_ARGS[index]:-}"
        ;;
      --remote=*) remote="${arg#*=}" ;;
      --replace) replace=replace ;;
      *)
        if [[ -z $name ]]; then name="$arg"
        elif [[ -z $path ]]; then path="$arg"
        elif [[ -z $type ]]; then type="$arg"
        else die "usage: mntg repository configure NAME PATH TYPE [--remote URL] [--replace] [--json]"
        fi
        ;;
    esac
    index=$((index + 1))
  done
  [[ -n $name && -n $path && -n $type ]] ||
    die "usage: mntg repository configure NAME PATH TYPE [--remote URL] [--replace] [--json]"
  remote=$(strip_credentials "$remote")
  [[ -z $remote ]] || valid_git_remote "$remote" || die "repository remote is unsafe or malformed"
  if [[ $type == vault && -n $remote ]]; then
    repository_remote_visibility "$remote"
    visibility="$REPOSITORY_REMOTE_VISIBILITY"
    if [[ $visibility == public ]]; then
      (( REPOSITORY_COMMAND_JSON )) ||
        printf 'Warning: this GitHub repository is public. A Montage vault contains personal configuration, inventory, host evidence, and possibly encrypted-secret ciphertext.\n' >&2
      confirm "Configure this known-public repository for private vault storage?" || die "cancelled"
    fi
  fi
  if repository_registry_put "$name" "$path" "$type" "$remote" "$replace"; then rc=0; else rc=$?; fi
  if (( rc == 2 )); then die "repository identity changed; repeat with --replace after inspection"; fi
  (( rc == 0 )) || die "repository configuration was refused"
  repository_registry_load || die "could not reload repository configuration"
  entry=$(repository_registry_get "$name") || die "configured repository disappeared"
  item=$(repository_inspect_entry_json "$entry") || die "could not inspect configured repository"
  if (( REPOSITORY_COMMAND_JSON )); then
    jq -nc --argjson repository "$item" --arg visibility "$visibility" \
      '{schemaVersion:1,kind:"montage-repository-configured",repository:$repository,
        visibility:$visibility,
        warning:(if $visibility == "public" then
          "Public vault storage can expose personal backup metadata and encrypted-secret ciphertext."
          else null end)}'
  else
    printf 'Configured Montage repository:\n'
    repository_print_human "$item"
    [[ $type != vault || -z $remote ]] || printf '  visibility: %s\n' "$visibility"
  fi
}

cmd_repository_remove() {
  repository_command_json_flag "$@"
  (( ${#REPOSITORY_COMMAND_ARGS[@]} == 1 )) || die "usage: mntg repository remove NAME [--json]"
  local name="${REPOSITORY_COMMAND_ARGS[0]}"
  repository_registry_remove "$name" || die "repository is not configured: $name"
  if (( REPOSITORY_COMMAND_JSON )); then
    jq -nc --arg name "$name" '{schemaVersion:1,kind:"montage-repository-removed",name:$name}'
  else
    printf 'Removed repository configuration %s. Repository content was not changed.\n' "$name"
  fi
}

cmd_repository_sync() {
  local name="" as_json=0 action=preview arg entry rc=0 validator
  for arg in "$@"; do
    case "$arg" in
      --json) as_json=1 ;;
      --pull) [[ $action == preview ]] || die "choose only one sync action"; action=pull ;;
      --push) [[ $action == preview ]] || die "choose only one sync action"; action=push ;;
      -*) die "usage: mntg repository sync NAME [--pull|--push] [--json]" ;;
      *) [[ -z $name ]] || die "usage: mntg repository sync NAME [--pull|--push] [--json]"; name="$arg" ;;
    esac
  done
  [[ -n $name ]] || die "usage: mntg repository sync NAME [--pull|--push] [--json]"
  repository_registry_load || die "repository configuration is malformed or unsupported"
  entry=$(repository_registry_get "$name") || die "repository is not configured: $name"
  if [[ $action == preview ]]; then
    repository_sync_classify "$entry" || rc=$?
    REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$REPOSITORY_SYNC_RESULT" preview fetch "$([[ $rc == 0 ]] && printf true || printf false)" "$([[ $rc == 0 ]] || printf classification-failed)")
  else
    case "$(jq -r '.type' <<<"$entry")" in
      loadouts) validator=loadout_repository_history_valid ;;
      vault) validator=vault_repository_history_valid ;;
      *) die "repository type is unsupported" ;;
    esac
    repository_sync_apply "$entry" "$action" "$validator" || rc=$?
    if ! jq -e '.action' <<<"$REPOSITORY_SYNC_RESULT" >/dev/null 2>&1; then
      REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json \
        "$REPOSITORY_SYNC_RESULT" "$action" fetch false classification-failed)
    fi
  fi
  if (( PORCELAIN )); then
    emit "BEGIN|sync|$(jq -r '.repositoryId' <<<"$REPOSITORY_SYNC_RESULT")|$(jq -r '.repositoryType' <<<"$REPOSITORY_SYNC_RESULT")"
    emit "SYNC|1|$(jq -r '[.status,(.ahead|tostring),(.behind|tostring),(.fetch.ok|tostring),(.action.performed // "none"),(.action.ok|tostring),(.action.reason // "")] | join("|")' <<<"$REPOSITORY_SYNC_RESULT")"
    if (( rc == 0 )); then emit "DONE|ok|synchronization complete"
    elif (( rc == 3 )); then emit "DONE|decision|required"
    else emit "DONE|fail|synchronization failed"; fi
  elif (( as_json )); then printf '%s\n' "$REPOSITORY_SYNC_RESULT"
  else repository_sync_print_human "$REPOSITORY_SYNC_RESULT"; fi
  (( rc == 0 )) || return "$rc"
}

cmd_repository_initialize() {
  repository_command_json_flag "$@"
  local type="${REPOSITORY_COMMAND_ARGS[0]:-}" path="${REPOSITORY_COMMAND_ARGS[1]:-}"
  local id="" index=2 arg envelope
  [[ $type == loadouts ]] || die "usage: mntg repository init loadouts PATH --id ID [--json]"
  while (( index < ${#REPOSITORY_COMMAND_ARGS[@]} )); do
    arg="${REPOSITORY_COMMAND_ARGS[index]}"
    case "$arg" in
      --id) index=$((index + 1)); id="${REPOSITORY_COMMAND_ARGS[index]:-}" ;;
      --id=*) id="${arg#*=}" ;;
      *) die "usage: mntg repository init loadouts PATH --id ID [--json]" ;;
    esac
    index=$((index + 1))
  done
  [[ -n $path && -n $id ]] || die "usage: mntg repository init loadouts PATH --id ID [--json]"
  loadout_repository_initialize "$path" "$id" || die "could not initialize loadout repository"
  envelope=$(<"$path/$MONTAGE_REPOSITORY_MANIFEST")
  if (( REPOSITORY_COMMAND_JSON )); then
    jq -nc --arg path "$path" --argjson repository "$envelope" \
      '{schemaVersion:1,kind:"montage-loadout-repository-initialized",path:$path,repository:$repository}'
  else
    printf 'Initialized Montage loadout repository %s at %s.\n' "$id" "$path"
  fi
}

cmd_repository_loadouts() {
  repository_command_json_flag "$@"
  (( ${#REPOSITORY_COMMAND_ARGS[@]} == 1 )) ||
    die "usage: mntg repository loadouts NAME|PATH [--json]"
  local catalog item
  catalog=$(loadout_repository_catalog_json "${REPOSITORY_COMMAND_ARGS[0]}") ||
    die "loadout repository is invalid or unavailable"
  if (( REPOSITORY_COMMAND_JSON )); then
    printf '%s\n' "$catalog"
    return
  fi
  printf 'Loadouts in %s:\n' "$(jq -r '.repositoryId' <<<"$catalog")"
  if [[ $(jq -r '.items | length' <<<"$catalog") == 0 ]]; then printf '  (none)\n'; fi
  while IFS= read -r item; do
    printf '  %s  %s\n' "$(jq -r '.id' <<<"$item")" "$(jq -r '.name' <<<"$item")"
  done < <(jq -c '.items[]' <<<"$catalog")
  if [[ $(jq -r '.invalid | length' <<<"$catalog") != 0 ]]; then
    printf 'Invalid entries:\n'
    while IFS= read -r item; do
      printf '  %s  %s\n' "$(jq -r '.id' <<<"$item")" "$(jq -r '.reason' <<<"$item")"
    done < <(jq -c '.invalid[]' <<<"$catalog")
  fi
}

cmd_repository_loadout() {
  local action="${1:-}" selector="${2:-}" id="${3:-}"
  [[ -n $action && -n $selector && -n $id ]] ||
    die "usage: mntg repository loadout <show|rename> NAME|PATH ID ..."
  shift 3
  repository_command_json_flag "$@"
  local item name="" description="" index=0 arg
  case "$action" in
    show)
      (( ${#REPOSITORY_COMMAND_ARGS[@]} == 0 )) ||
        die "usage: mntg repository loadout show NAME|PATH ID [--json]"
      item=$(loadout_repository_item_json "$selector" "$id") || die "loadout item is invalid or unavailable: $id"
      if (( REPOSITORY_COMMAND_JSON )); then
        jq -nc --argjson item "$item" '{schemaVersion:1,kind:"montage-loadout-show",item:$item}'
      else
        printf '%s [%s]\n%s\ndigest: %s\n' "$(jq -r '.name' <<<"$item")" "$id" \
          "$(jq -r '.description' <<<"$item")" "$(jq -r '.digest' <<<"$item")"
      fi
      ;;
    rename)
      item=$(loadout_repository_item_json "$selector" "$id") || die "loadout item is invalid or unavailable: $id"
      description=$(jq -r '.description' <<<"$item")
      while (( index < ${#REPOSITORY_COMMAND_ARGS[@]} )); do
        arg="${REPOSITORY_COMMAND_ARGS[index]}"
        case "$arg" in
          --name) index=$((index + 1)); name="${REPOSITORY_COMMAND_ARGS[index]:-}" ;;
          --name=*) name="${arg#*=}" ;;
          --description) index=$((index + 1)); description="${REPOSITORY_COMMAND_ARGS[index]:-}" ;;
          --description=*) description="${arg#*=}" ;;
          *) die "usage: mntg repository loadout rename NAME|PATH ID --name DISPLAY [--description TEXT] [--json]" ;;
        esac
        index=$((index + 1))
      done
      [[ -n $name ]] || die "loadout rename requires --name"
      item=$(loadout_repository_rename "$selector" "$id" "$name" "$description") ||
        die "loadout rename was refused"
      if (( REPOSITORY_COMMAND_JSON )); then
        jq -nc --argjson item "$item" '{schemaVersion:1,kind:"montage-loadout-renamed",item:$item}'
      else
        printf 'Renamed loadout %s to %s; its stable id and path are unchanged.\n' "$id" "$name"
      fi
      ;;
    *) die "unknown repository loadout command: $action" ;;
  esac
}

cmd_repository() {
  local subcommand="${1:-list}"
  shift || true
  case "$subcommand" in
    list) cmd_repository_list "$@" ;;
    show) cmd_repository_show "$@" ;;
    validate) cmd_repository_validate "$@" ;;
    configure) cmd_repository_configure "$@" ;;
    remove) cmd_repository_remove "$@" ;;
    sync) cmd_repository_sync "$@" ;;
    init) cmd_repository_initialize "$@" ;;
    loadouts) cmd_repository_loadouts "$@" ;;
    loadout) cmd_repository_loadout "$@" ;;
    *) die "unknown repository command: $subcommand" ;;
  esac
}
