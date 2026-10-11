#!/bin/bash
#
# Configured Montage loadout-library registry. Schema 2 is the active format.
# Schema 1 exists only at this boundary so a mixed legacy document can be
# migrated once without opening or changing any retired vault path.

MONTAGE_REPOSITORY_REGISTRY_SCHEMA=2
MONTAGE_REPOSITORY_REGISTRY_LEGACY_SCHEMA=1
MONTAGE_REPOSITORY_REGISTRY="$CONFIG_DIR/repositories.json"
MONTAGE_REPOSITORY_REGISTRY_BACKUP="$MONTAGE_REPOSITORY_REGISTRY.pre-schema2"
REPOSITORY_REGISTRY=""
REPOSITORY_REGISTRY_MIGRATION=null
REPOSITORY_REGISTRY_ERROR_ENTRY=""
REPOSITORY_CONFIG_LOCK_FD=""

repository_registry_empty() {
  jq -nc --argjson schema "$MONTAGE_REPOSITORY_REGISTRY_SCHEMA" \
    '{schemaVersion:$schema,revision:0,repositories:[]}'
}

repository_registry_validate_entries() {
  local file="$1" allowed_kinds="$2" name path type id remote
  while IFS=$'\t' read -r name path type id remote; do
    repository_id_valid "$name" || return 1
    repository_id_valid "$id" || return 1
    case "$allowed_kinds:$type" in
      legacy:loadouts|legacy:vault|active:loadouts) ;;
      *) return 1 ;;
    esac
    [[ $path == /* && $path != *$'\n'* && $path != *$'\r'* && $path != *$'\t'* ]] || return 1
    [[ -z $remote ]] || {
      valid_git_remote "$remote" && ! url_has_credentials "$remote" &&
        [[ $(strip_credentials "$remote") == "$remote" ]]
    } || return 1
  done < <(jq -r '.repositories[] | [.name,.path,.type,.id,.remote] | @tsv' "$file")
}

repository_registry_validate_shape() {
  local file="$1" schema="$2" kind_expression="$3"
  [[ -f $file && ! -L $file ]] || return 1
  jq -e --argjson schema "$schema" "$kind_expression"' and
    type == "object" and
    keys == ["repositories","revision","schemaVersion"] and
    .schemaVersion == $schema and
    (.schemaVersion | type == "number" and floor == .) and
    (.revision | type == "number" and floor == . and . >= 0) and
    (.repositories | type == "array") and
    (all(.repositories[];
      type == "object" and keys == ["id","name","path","remote","type"] and
      (.name | type == "string") and (.path | type == "string") and
      (.id | type == "string") and (.remote | type == "string"))) and
    (([.repositories[].name] | length) == ([.repositories[].name] | unique | length))
  ' "$file" >/dev/null 2>&1
}

repository_registry_validate_file() {
  local file="$1"
  repository_registry_validate_shape "$file" "$MONTAGE_REPOSITORY_REGISTRY_SCHEMA" \
    '(all(.repositories[]; .type == "loadouts"))' || return 1
  repository_registry_validate_entries "$file" active
}

repository_registry_validate_legacy_file() {
  local file="$1"
  repository_registry_validate_shape "$file" "$MONTAGE_REPOSITORY_REGISTRY_LEGACY_SCHEMA" \
    '(all(.repositories[]; .type == "loadouts" or .type == "vault"))' || return 1
  repository_registry_validate_entries "$file" legacy
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
  chmod 600 "$tmp" 2>/dev/null || return 1
  repository_registry_validate_file "$tmp" || return 1
  mv -- "$tmp" "$MONTAGE_REPOSITORY_REGISTRY" || return 1
  REPOSITORY_REGISTRY=$(<"$MONTAGE_REPOSITORY_REGISTRY")
}

repository_registry_migration_json() {
  local performed="$1" prior="$2" retired="$3" backup="${4:-}"
  jq -nc --argjson performed "$performed" --argjson prior "$prior" \
    --argjson current "$MONTAGE_REPOSITORY_REGISTRY_SCHEMA" \
    --argjson retired "$retired" --arg backup "$backup" '
      {performed:$performed,priorSchema:$prior,newSchema:$current,
       retiredVaults:$retired,backup:(if $backup == "" then null else $backup end)}'
}

repository_registry_set_noop_migration() {
  [[ $REPOSITORY_REGISTRY_MIGRATION == null ]] || return 0
  REPOSITORY_REGISTRY_MIGRATION=$(repository_registry_migration_json false 2 '[]')
}

repository_registry_validate_retained_entry() {
  local entry="$1" name path id canonical
  name=$(jq -r '.name' <<<"$entry")
  path=$(jq -r '.path' <<<"$entry")
  id=$(jq -r '.id' <<<"$entry")
  REPOSITORY_REGISTRY_ERROR_ENTRY="$name"
  [[ -d $path && ! -L $path ]] || return 1
  canonical=$(realpath -e -- "$path") || return 1
  [[ $canonical == "$path" ]] || return 1
  repository_envelope_validate_file "$path/$MONTAGE_REPOSITORY_MANIFEST" || return 1
  [[ $(jq -r '.id' "$path/$MONTAGE_REPOSITORY_MANIFEST") == "$id" ]] || return 1
}

repository_registry_preserve_legacy() {
  local tmp mode
  if [[ -e $MONTAGE_REPOSITORY_REGISTRY_BACKUP || -L $MONTAGE_REPOSITORY_REGISTRY_BACKUP ]]; then
    [[ -f $MONTAGE_REPOSITORY_REGISTRY_BACKUP && ! -L $MONTAGE_REPOSITORY_REGISTRY_BACKUP ]] || return 1
    mode=$(stat -c '%a' "$MONTAGE_REPOSITORY_REGISTRY_BACKUP" 2>/dev/null) || return 1
    [[ $mode == 600 ]] || return 1
    cmp -s -- "$MONTAGE_REPOSITORY_REGISTRY" "$MONTAGE_REPOSITORY_REGISTRY_BACKUP"
    return
  fi
  montage_make_temp_file "$CONFIG_DIR/.repositories-pre-schema2.XXXXXX" || return 1
  tmp="$MONTAGE_TEMP_PATH"
  cp -- "$MONTAGE_REPOSITORY_REGISTRY" "$tmp" || return 1
  chmod 600 "$tmp" || return 1
  ln -- "$tmp" "$MONTAGE_REPOSITORY_REGISTRY_BACKUP" || return 1
}

repository_registry_migrate_locked() {
  local entry retained='[]' retired candidate
  repository_registry_validate_legacy_file "$MONTAGE_REPOSITORY_REGISTRY" || return 1

  while IFS= read -r entry; do
    if ! repository_registry_validate_retained_entry "$entry"; then
      printf 'mntg: configured loadout repository is invalid: %s\n' \
        "$REPOSITORY_REGISTRY_ERROR_ENTRY" >&2
      return 1
    fi
    retained=$(jq -nc --argjson values "$retained" --argjson item "$entry" \
      '$values + [$item] | sort_by(.name)') || return 1
  done < <(jq -c '.repositories[] | select(.type == "loadouts") | .' \
    "$MONTAGE_REPOSITORY_REGISTRY")

  retired=$(jq -c '[.repositories[] | select(.type == "vault") | .name] | sort' \
    "$MONTAGE_REPOSITORY_REGISTRY") || return 1
  candidate=$(jq -c --argjson schema "$MONTAGE_REPOSITORY_REGISTRY_SCHEMA" \
    --argjson repositories "$retained" \
    '{schemaVersion:$schema,revision:(.revision + 1),repositories:$repositories}' \
    "$MONTAGE_REPOSITORY_REGISTRY") || return 1
  repository_registry_preserve_legacy || return 1

  # Test-only interruption point: the rollback copy exists, but the active
  # schema-1 registry has not been replaced and can be retried safely.
  [[ ${MONTAGE_TEST_INTERRUPT_REPOSITORY_MIGRATION_BEFORE_REPLACE:-0} != 1 ]] || return 75
  repository_registry_save "$candidate" || return 1
  REPOSITORY_REGISTRY_MIGRATION=$(repository_registry_migration_json true 1 "$retired" \
    "$MONTAGE_REPOSITORY_REGISTRY_BACKUP") || return 1
}

repository_registry_load_locked() {
  local schema
  if [[ ! -e $MONTAGE_REPOSITORY_REGISTRY ]]; then
    REPOSITORY_REGISTRY=$(repository_registry_empty)
    [[ $REPOSITORY_REGISTRY_MIGRATION != null ]] ||
      REPOSITORY_REGISTRY_MIGRATION=$(repository_registry_migration_json false null '[]')
    return 0
  fi
  [[ -f $MONTAGE_REPOSITORY_REGISTRY && ! -L $MONTAGE_REPOSITORY_REGISTRY ]] || return 1
  schema=$(jq -er '.schemaVersion |
    select(type == "number" and floor == . and (. == 1 or . == 2))' \
    "$MONTAGE_REPOSITORY_REGISTRY" 2>/dev/null) || return 1
  case "$schema" in
    1) repository_registry_migrate_locked ;;
    2)
      repository_registry_validate_file "$MONTAGE_REPOSITORY_REGISTRY" || return 1
      REPOSITORY_REGISTRY=$(<"$MONTAGE_REPOSITORY_REGISTRY")
      repository_registry_set_noop_migration
      ;;
    *) return 1 ;;
  esac
}

repository_registry_load() {
  local rc=0
  # A read of valid empty state must remain a read. In particular, ordinary
  # status must not create the configuration directory or its lock file merely
  # to report that no libraries are configured.
  if [[ ! -e $MONTAGE_REPOSITORY_REGISTRY && ! -L $MONTAGE_REPOSITORY_REGISTRY ]]; then
    REPOSITORY_REGISTRY=$(repository_registry_empty)
    REPOSITORY_REGISTRY_MIGRATION=$(repository_registry_migration_json false null '[]')
    return 0
  fi
  repository_registry_lock || return 1
  repository_registry_load_locked || rc=$?
  repository_registry_unlock
  return "$rc"
}

# Status needs a read-only fast path for the active schema. The only exception
# is a legacy schema-1 document, whose first read performs the specified locked
# one-time migration before any consumer can interpret it.
repository_registry_load_for_status() {
  local schema
  if [[ ! -e $MONTAGE_REPOSITORY_REGISTRY && ! -L $MONTAGE_REPOSITORY_REGISTRY ]]; then
    REPOSITORY_REGISTRY=$(repository_registry_empty)
    REPOSITORY_REGISTRY_MIGRATION=$(repository_registry_migration_json false null '[]')
    return 0
  fi
  [[ -f $MONTAGE_REPOSITORY_REGISTRY && ! -L $MONTAGE_REPOSITORY_REGISTRY ]] || return 1
  schema=$(jq -er '.schemaVersion | select(type == "number" and floor == .)' \
    "$MONTAGE_REPOSITORY_REGISTRY" 2>/dev/null) || return 1
  if [[ $schema == 1 ]]; then
    repository_registry_load
    return
  fi
  [[ $schema == 2 ]] || return 1
  repository_registry_validate_file "$MONTAGE_REPOSITORY_REGISTRY" || return 1
  REPOSITORY_REGISTRY=$(<"$MONTAGE_REPOSITORY_REGISTRY")
  repository_registry_set_noop_migration
}

repository_registry_get() {
  local name="$1"
  repository_id_valid "$name" || return 1
  [[ -n $REPOSITORY_REGISTRY ]] || repository_registry_load || return 1
  jq -ce --arg name "$name" '.repositories[] | select(.name == $name)' \
    <<<"$REPOSITORY_REGISTRY"
}

# repository_registry_put NAME PATH [REMOTE] [replace]
# Returns 2 when a name already points at another repository identity and an
# explicit replacement was not requested.
repository_registry_put() {
  local name="$1" path="$2" remote="${3:-}" replace="${4:-}" canonical manifest id
  local existing_id="" next rc=0
  repository_id_valid "$name" || return 1
  [[ $path == /* && -d $path && ! -L $path ]] || return 1
  canonical=$(realpath -e -- "$path") || return 1
  [[ $canonical == /* ]] || return 1
  manifest="$canonical/$MONTAGE_REPOSITORY_MANIFEST"
  repository_envelope_validate_file "$manifest" || return 1
  id=$(jq -r '.id' "$manifest")
  remote=$(strip_credentials "$remote")
  [[ -z $remote ]] || valid_git_remote "$remote" || return 1

  repository_registry_lock || return 1
  repository_registry_load_locked
  rc=$?
  if (( rc != 0 )); then repository_registry_unlock; return "$rc"; fi
  existing_id=$(jq -r --arg name "$name" '.repositories[] | select(.name == $name) | .id' \
    <<<"$REPOSITORY_REGISTRY")
  if [[ -n $existing_id && $existing_id != "$id" && $replace != replace ]]; then
    repository_registry_unlock
    return 2
  fi
  next=$(jq -c --arg name "$name" --arg path "$canonical" --arg type loadouts \
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
  repository_registry_load_locked
  rc=$?
  if (( rc != 0 )); then repository_registry_unlock; return "$rc"; fi
  jq -e --arg name "$name" 'any(.repositories[]; .name == $name)' \
    <<<"$REPOSITORY_REGISTRY" >/dev/null || { repository_registry_unlock; return 1; }
  next=$(jq -c --arg name "$name" '
    .revision += 1 | .repositories = [.repositories[] | select(.name != $name)]
  ' <<<"$REPOSITORY_REGISTRY") || rc=1
  if (( rc == 0 )); then repository_registry_save "$next" || rc=1; fi
  repository_registry_unlock
  return "$rc"
}

repository_migration_print_human() {
  local migration="$1" retired
  [[ $migration != null && $(jq -r '.performed' <<<"$migration") == true ]] || return 0
  retired=$(jq -r '.retiredVaults | if length == 0 then "none" else join(", ") end' \
    <<<"$migration")
  printf 'Migrated repository registry from schema %s to %s; retired vault entries: %s.\n' \
    "$(jq -r '.priorSchema' <<<"$migration")" "$(jq -r '.newSchema' <<<"$migration")" "$retired"
  printf 'Rollback copy: %s\n' "$(jq -r '.backup' <<<"$migration")"
}

repository_migration_emit_porcelain() {
  local migration="$1"
  [[ $migration != null ]] || return 0
  emit "MIGRATION|1|$(jq -r '[.performed,.priorSchema,.newSchema,
    (.retiredVaults | join(",")),(.backup // "")] | map(tostring) | join("|")' <<<"$migration")"
}

# Report a performed migration once in ordinary non-JSON command output.
repository_migration_notice() {
  [[ $REPOSITORY_REGISTRY_MIGRATION != null &&
     $(jq -r '.performed' <<<"$REPOSITORY_REGISTRY_MIGRATION") == true &&
     ${REPOSITORY_MIGRATION_REPORTED:-0} == 0 ]] || return 0
  if (( PORCELAIN )); then repository_migration_emit_porcelain "$REPOSITORY_REGISTRY_MIGRATION"
  else repository_migration_print_human "$REPOSITORY_REGISTRY_MIGRATION"; fi
  REPOSITORY_MIGRATION_REPORTED=1
}
