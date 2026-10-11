#!/bin/bash
#
# Montage loadout-library envelope primitives. Native Montage repositories
# have one kind: a loadout library. It performs no I/O merely by being sourced.

MONTAGE_REPOSITORY_SCHEMA=1
MONTAGE_REPOSITORY_MANIFEST="montage.json"

repository_id_valid() {
  local value="${1:-}"
  [[ $value =~ ^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$ ]]
}

repository_timestamp_valid() {
  [[ ${1:-} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# Validate the one native envelope as data. Montage has no repository-kind
# parameter: every native repository is a loadout library.
repository_envelope_validate_file() {
  local file="$1" id created
  [[ -f $file && ! -L $file ]] || return 1

  jq -e --argjson schema "$MONTAGE_REPOSITORY_SCHEMA" '
    def integer: type == "number" and floor == .;
    type == "object" and
    .schemaVersion == $schema and (.schemaVersion | integer) and
    .kind == "montage-repository" and
    .repositoryType == "loadouts" and
    (.id | type == "string") and
    (.createdAt | type == "string") and
    keys == ["createdAt","id","kind","repositoryType","schemaVersion"]
  ' "$file" >/dev/null 2>&1 || return 1

  id=$(jq -r '.id' "$file")
  created=$(jq -r '.createdAt' "$file")
  repository_id_valid "$id" || return 1
  repository_timestamp_valid "$created" || return 1
}

repository_envelope_json() {
  local id="$1" created="$2"
  repository_id_valid "$id" || return 1
  repository_timestamp_valid "$created" || return 1
  jq -nc --argjson schema "$MONTAGE_REPOSITORY_SCHEMA" \
    --arg id "$id" --arg created "$created" \
    '{schemaVersion:$schema,kind:"montage-repository",repositoryType:"loadouts",
      id:$id,createdAt:$created}'
}
