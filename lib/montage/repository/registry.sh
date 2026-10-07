#!/bin/bash
#
# Configured Montage repository registry. Entries bind a local selector to a
# canonical path, expected native envelope identity, kind, and safe remote.
# Definitions only; sourcing this module performs no I/O.

MONTAGE_REPOSITORY_REGISTRY_SCHEMA=1
MONTAGE_REPOSITORY_REGISTRY="$CONFIG_DIR/repositories.json"
REPOSITORY_REGISTRY=""
REPOSITORY_CONFIG_LOCK_FD=""

repository_registry_empty() {
  jq -nc '{schemaVersion:1,revision:0,repositories:[]}'
}

repository_registry_validate_file() {
  local file="$1" name path type id remote
  [[ -f $file && ! -L $file ]] || return 1
  jq -e --argjson schema "$MONTAGE_REPOSITORY_REGISTRY_SCHEMA" '
    def integer: type == "number" and floor == .;
    type == "object" and
    keys == ["repositories","revision","schemaVersion"] and
    .schemaVersion == $schema and (.schemaVersion | integer) and
    (.revision | integer and . >= 0) and
    (.repositories | type == "array") and
    (all(.repositories[];
      type == "object" and keys == ["id","name","path","remote","type"] and
      (.name | type == "string") and (.path | type == "string") and
      (.type == "loadouts" or .type == "vault") and
      (.id | type == "string") and (.remote | type == "string"))) and
    (([.repositories[].name] | length) == ([.repositories[].name] | unique | length))
  ' "$file" >/dev/null 2>&1 || return 1

  while IFS=$'\t' read -r name path type id remote; do
    repository_id_valid "$name" || return 1
    repository_id_valid "$id" || return 1
    repository_type_valid "$type" || return 1
    [[ $path == /* && $path != *$'\n'* && $path != *$'\r'* && $path != *$'\t'* ]] || return 1
    [[ -z $remote ]] || {
      valid_git_remote "$remote" && ! url_has_credentials "$remote" &&
        [[ $(strip_credentials "$remote") == "$remote" ]]
    } || return 1
  done < <(jq -r '.repositories[] | [.name,.path,.type,.id,.remote] | @tsv' "$file")
}

repository_registry_load() {
  if [[ ! -e $MONTAGE_REPOSITORY_REGISTRY ]]; then
    REPOSITORY_REGISTRY=$(repository_registry_empty)
    return 0
  fi
  repository_registry_validate_file "$MONTAGE_REPOSITORY_REGISTRY" || return 1
  REPOSITORY_REGISTRY=$(<"$MONTAGE_REPOSITORY_REGISTRY")
}

repository_registry_lock() {
  private_dir "$CONFIG_DIR"
  exec {REPOSITORY_CONFIG_LOCK_FD}>"$CONFIG_DIR/.lock"
  flock -w 5 "$REPOSITORY_CONFIG_LOCK_FD" || {
    exec {REPOSITORY_CONFIG_LOCK_FD}>&-
    REPOSITORY_CONFIG_LOCK_FD=""
    return 1
  }
}

repository_registry_unlock() {
  [[ -n ${REPOSITORY_CONFIG_LOCK_FD:-} ]] || return 0
  flock -u "$REPOSITORY_CONFIG_LOCK_FD" 2>/dev/null || true
  exec {REPOSITORY_CONFIG_LOCK_FD}>&-
  REPOSITORY_CONFIG_LOCK_FD=""
}

repository_registry_save() {
  local value="$1" tmp
  montage_make_temp_file "$CONFIG_DIR/.repositories.XXXXXX" || return 1
  tmp="$MONTAGE_TEMP_PATH"
  printf '%s\n' "$value" | jq -S . >"$tmp" || return 1
  chmod 600 "$tmp" 2>/dev/null || true
  repository_registry_validate_file "$tmp" || return 1
  mv -- "$tmp" "$MONTAGE_REPOSITORY_REGISTRY"
  REPOSITORY_REGISTRY=$(<"$MONTAGE_REPOSITORY_REGISTRY")
}

repository_registry_get() {
  local name="$1"
  repository_id_valid "$name" || return 1
  [[ -n $REPOSITORY_REGISTRY ]] || repository_registry_load || return 1
  jq -ce --arg name "$name" '.repositories[] | select(.name == $name)' \
    <<<"$REPOSITORY_REGISTRY"
}

# repository_registry_put NAME PATH TYPE [REMOTE] [replace]
# Returns 2 when a name already points at another repository identity and an
# explicit replacement was not requested.
repository_registry_put() {
  local name="$1" path="$2" type="$3" remote="${4:-}" replace="${5:-}" canonical manifest id
  local existing_id="" next rc=0
  repository_id_valid "$name" || return 1
  repository_type_valid "$type" || return 1
  [[ $path == /* && -d $path && ! -L $path ]] || return 1
  canonical=$(realpath -e -- "$path") || return 1
  [[ $canonical == /* ]] || return 1
  manifest="$canonical/$MONTAGE_REPOSITORY_MANIFEST"
  repository_envelope_validate_file "$manifest" "$type" || return 1
  id=$(jq -r '.id' "$manifest")
  remote=$(strip_credentials "$remote")
  [[ -z $remote ]] || valid_git_remote "$remote" || return 1

  repository_registry_lock || return 1
  if ! repository_registry_load; then repository_registry_unlock; return 1; fi
  existing_id=$(jq -r --arg name "$name" '.repositories[] | select(.name == $name) | .id' \
    <<<"$REPOSITORY_REGISTRY")
  if [[ -n $existing_id && $existing_id != "$id" && $replace != replace ]]; then
    repository_registry_unlock
    return 2
  fi
  next=$(jq -c --arg name "$name" --arg path "$canonical" --arg type "$type" \
    --arg id "$id" --arg remote "$remote" '
      .revision += 1 |
      .repositories = ([.repositories[] | select(.name != $name)] +
        [{name:$name,path:$path,type:$type,id:$id,remote:$remote}] | sort_by(.name))
    ' <<<"$REPOSITORY_REGISTRY") || rc=1
  if (( rc == 0 )); then repository_registry_save "$next" || rc=1; fi
  repository_registry_unlock
  return "$rc"
}

repository_registry_remove() {
  local name="$1" next rc=0
  repository_id_valid "$name" || return 1
  repository_registry_lock || return 1
  if ! repository_registry_load; then repository_registry_unlock; return 1; fi
  jq -e --arg name "$name" 'any(.repositories[]; .name == $name)' \
    <<<"$REPOSITORY_REGISTRY" >/dev/null || { repository_registry_unlock; return 1; }
  next=$(jq -c --arg name "$name" '
    .revision += 1 | .repositories = [.repositories[] | select(.name != $name)]
  ' <<<"$REPOSITORY_REGISTRY") || rc=1
  if (( rc == 0 )); then repository_registry_save "$next" || rc=1; fi
  repository_registry_unlock
  return "$rc"
}
