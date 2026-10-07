#!/bin/bash
#
# Montage repository envelope primitives. This module owns the native
# `montage.json` container identity shared by loadout and vault repositories.
# It performs no I/O merely by being sourced.

MONTAGE_REPOSITORY_SCHEMA=1
MONTAGE_REPOSITORY_MANIFEST="montage.json"

repository_id_valid() {
  local value="${1:-}"
  [[ $value =~ ^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$ ]]
}

repository_type_valid() { [[ ${1:-} == loadouts || ${1:-} == vault ]]; }

repository_timestamp_valid() {
  [[ ${1:-} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

repository_generate_id() {
  local prefix="$1" seed digest
  repository_id_valid "$prefix" || return 1
  seed="$(date -u +%s%N 2>/dev/null || date -u +%s)-$$-${RANDOM:-0}-$(hostname 2>/dev/null || printf machine)"
  digest=$(printf '%s' "$seed" | sha256sum 2>/dev/null | cut -c1-12) || return 1
  repository_id_valid "$prefix-$digest" || return 1
  printf '%s\n' "$prefix-$digest"
}

# Validate one native envelope as data. The expected type is optional for
# inspection and mandatory at mutation call sites.
repository_envelope_validate_file() {
  local file="$1" expected_type="${2:-}" id type created machine_id
  [[ -f $file && ! -L $file ]] || return 1
  [[ -z $expected_type ]] || repository_type_valid "$expected_type" || return 1

  jq -e --argjson schema "$MONTAGE_REPOSITORY_SCHEMA" '
    def integer: type == "number" and floor == .;
    type == "object" and
    .schemaVersion == $schema and (.schemaVersion | integer) and
    .kind == "montage-repository" and
    (.repositoryType == "loadouts" or .repositoryType == "vault") and
    (.id | type == "string") and
    (.createdAt | type == "string") and
    (if .repositoryType == "loadouts" then
       keys == ["createdAt","id","kind","repositoryType","schemaVersion"]
     else
       keys == ["createdAt","id","kind","machineId","repositoryType","schemaVersion"] and
       (.machineId | type == "string")
     end)
  ' "$file" >/dev/null 2>&1 || return 1

  id=$(jq -r '.id' "$file")
  type=$(jq -r '.repositoryType' "$file")
  created=$(jq -r '.createdAt' "$file")
  repository_id_valid "$id" || return 1
  repository_type_valid "$type" || return 1
  repository_timestamp_valid "$created" || return 1
  [[ -z $expected_type || $type == "$expected_type" ]] || return 1
  if [[ $type == vault ]]; then
    machine_id=$(jq -r '.machineId' "$file")
    repository_id_valid "$machine_id" || return 1
  fi
}

repository_envelope_json() {
  local type="$1" id="$2" created="$3" machine_id="${4:-}"
  repository_type_valid "$type" || return 1
  repository_id_valid "$id" || return 1
  repository_timestamp_valid "$created" || return 1
  if [[ $type == vault ]]; then
    repository_id_valid "$machine_id" || return 1
    jq -nc --argjson schema "$MONTAGE_REPOSITORY_SCHEMA" --arg type "$type" \
      --arg id "$id" --arg created "$created" --arg machine "$machine_id" \
      '{schemaVersion:$schema,kind:"montage-repository",repositoryType:$type,
        id:$id,createdAt:$created,machineId:$machine}'
  else
    [[ -z $machine_id ]] || return 1
    jq -nc --argjson schema "$MONTAGE_REPOSITORY_SCHEMA" --arg type "$type" \
      --arg id "$id" --arg created "$created" \
      '{schemaVersion:$schema,kind:"montage-repository",repositoryType:$type,
        id:$id,createdAt:$created}'
  fi
}
