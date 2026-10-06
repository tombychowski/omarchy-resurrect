#!/bin/bash
#
# Applied-loadout registry validation, atomic persistence, revisions, and the
# operation journal.
# Depends on core.sh and safety.sh. Owns REGISTRY, REGISTRY_REVISION, and the
# registry schema/path; used by all tracked-loadout workflows. Uses profile-owned
# canonical URL normalization after startup; definitions only at source time.

# A loadout is public input; applied-loadout ownership is private machine state.
# Keep the two schemas separate so a portable profile can remain compatible
# without pretending provenance from one machine is valid on another.
LOADOUT_REGISTRY_SCHEMA=1
LOADOUT_REGISTRY="$STATE_DIR/loadouts.json"
REGISTRY=""
REGISTRY_REVISION=0

registry_empty() {
  jq -nc '{schemaVersion: 1, revision: 0,
    baseline: {activeTheme: null}, loadouts: [], resources: [], claims: [], operation: null}'
}

registry_definition_valid() {
  local kind="$1" name="$2" definition="$3" id url commit icon
  case "$kind" in
    package)
      jq -e --arg name "$name" 'type == "object" and keys == ["name"] and .name == $name' \
        <<<"$definition" >/dev/null
      ;;
    plugin)
      jq -e --arg name "$name" 'type == "object" and keys == ["commit","id","url"] and .id == $name and
        (.url | type == "string") and (.commit | type == "string")' <<<"$definition" >/dev/null || return 1
      id=$(jq -r '.id' <<<"$definition"); url=$(jq -r '.url' <<<"$definition"); commit=$(jq -r '.commit' <<<"$definition")
      valid_id "$id" && valid_https "$url" && [[ $(canonical_remote "$url") == "$url" ]] &&
        { [[ -z $commit ]] || valid_sha "$commit"; }
      ;;
    webapp)
      jq -e --arg name "$name" 'type == "object" and keys == ["icon","name","url"] and .name == $name and
        (.url | type == "string") and (.icon | type == "string")' <<<"$definition" >/dev/null || return 1
      url=$(jq -r '.url' <<<"$definition"); icon=$(jq -r '.icon' <<<"$definition")
      valid_https "$url" && { [[ -z $icon ]] || valid_icon "$icon"; }
      ;;
    theme-install)
      jq -e --arg name "$name" 'type == "object" and keys == ["commit","name","url"] and .name == $name and
        (.url | type == "string") and (.commit | type == "string")' <<<"$definition" >/dev/null || return 1
      url=$(jq -r '.url' <<<"$definition"); commit=$(jq -r '.commit' <<<"$definition")
      { [[ -z $url ]] || { valid_https "$url" && [[ $(canonical_remote "$url") == "$url" ]]; }; } &&
        { [[ -z $commit ]] || valid_sha "$commit"; }
      ;;
    theme-active)
      jq -e --arg name "$name" 'type == "object" and keys == ["name"] and .name == $name' \
        <<<"$definition" >/dev/null
      ;;
    *) return 1 ;;
  esac
}

registry_claim_request_valid() {
  local kind="$1" name="$2" requested="$3"
  if [[ $kind == package ]]; then
    jq -e --arg name "$name" '
      type == "object" and keys == ["channels","name"] and .name == $name and
      (.channels | type == "array" and length > 0 and length == (unique | length) and
       all(.[]; . == "native" or . == "aur"))
    ' <<<"$requested" >/dev/null
  else
    registry_definition_valid "$kind" "$name" "$requested"
  fi
}

registry_profile_valid() {
  local profile="$1" value id url commit icon
  jq -e '
    type == "object" and
    keys == ["author","createdAt","description","kind","name","omarchy","packages","plugins","schemaVersion","theme","webapps"] and
    .schemaVersion == 1 and .kind == "omarchy-loadout" and
    (.name | type == "string") and (.author | type == "string") and
    (.description | type == "string") and (.createdAt | type == "string") and (.omarchy | type == "string") and
    (.packages | type == "object" and keys == ["aur","native"] and
      (.native | type == "array") and (.aur | type == "array")) and
    (.plugins | type == "array") and (.webapps | type == "array") and
    (.theme | type == "object" and keys == ["commit","name","url"])
  ' <<<"$profile" >/dev/null || return 1

  while IFS= read -r value; do valid_pkg "$value" || return 1; done \
    < <(jq -r '.packages.native[], .packages.aur[]' <<<"$profile")
  jq -e '(.packages.native | length == (unique | length)) and
    (.packages.aur | length == (unique | length))' <<<"$profile" >/dev/null || return 1
  while IFS=$'\t' read -r id url commit; do
    valid_id "$id" && valid_https "$url" && [[ $(canonical_remote "$url") == "$url" ]] &&
      { [[ -z $commit ]] || valid_sha "$commit"; } || return 1
  done < <(jq -r '.plugins[] | [.id,.url,.commit] | @tsv' <<<"$profile")
  jq -e '([.plugins[].id] | length) == ([.plugins[].id] | unique | length)' <<<"$profile" >/dev/null || return 1
  while IFS=$'\t' read -r value url icon; do
    valid_label "$value" && valid_https "$url" && { [[ -z $icon ]] || valid_icon "$icon"; } || return 1
  done < <(jq -r '.webapps[] | [.name,.url,.icon] | @tsv' <<<"$profile")
  jq -e '([.webapps[].name] | length) == ([.webapps[].name] | unique | length)' <<<"$profile" >/dev/null || return 1
  value=$(jq -r '.theme.name' <<<"$profile"); url=$(jq -r '.theme.url' <<<"$profile"); commit=$(jq -r '.theme.commit' <<<"$profile")
  if [[ -n $value ]]; then
    valid_theme "$value" || return 1
    { [[ -z $url ]] || { valid_https "$url" && [[ $(canonical_remote "$url") == "$url" ]]; }; } || return 1
    { [[ -z $commit ]] || valid_sha "$commit"; } || return 1
  else
    [[ -z $url && -z $commit ]] || return 1
  fi
}

# The registry can authorize deletion, so it is validated more strictly than a
# display cache. It stores logical ids, never paths or command fragments.
registry_validate() {
  local file="$1"
  jq -e '
    def integer: type == "number" and floor == .;
    def localid: type == "string" and test("^[a-z0-9][a-z0-9-]{0,80}$");
    def cleanup: . == "retain" or . == "remove" or . == "unknown";
    def observed: . == "present" or . == "absent" or . == "unknown";
    def rstate: . == "present" or . == "missing" or . == "modified" or
      . == "conflicting" or . == "protected" or . == "pending" or
      . == "failed" or . == "uncertain" or . == "unverifiable";
    def cstate: . == "healthy" or . == "pending" or . == "deferred" or
      . == "conflicting" or . == "failed" or . == "uncertain" or
      . == "removal-pending";
    def lstate: . == "healthy" or . == "pending" or . == "drifted" or
      . == "conflicting" or . == "removal-pending" or . == "unavailable";
    def actionstate: . == "planned" or . == "running" or . == "done" or
      . == "failed" or . == "uncertain" or . == "skipped";
    type == "object" and
    (.schemaVersion == 1) and (.revision | integer and . >= 0) and
    (.baseline | type == "object") and
    (.baseline.activeTheme == null or (.baseline.activeTheme | type == "string")) and
    (.loadouts | type == "array") and (.resources | type == "array") and
    (.claims | type == "array") and
    (all(.loadouts[];
      (.id | localid) and (.name | type == "string") and
      (.source | type == "string") and (.digest | type == "string" and test("^[0-9a-f]{64}$")) and
      (.profile | type == "object") and (.state | lstate) and
      (.appliedAt | integer and . >= 0) and (.updatedAt | integer and . >= 0) and
      (.precedence | integer and . >= 0))) and
    (([.loadouts[].id] | length) == ([.loadouts[].id] | unique | length)) and
    (all(.resources[];
      (.id | type == "string" and test("^(package|plugin|webapp|theme-install|theme-active):")) and
      (.kind == "package" or .kind == "plugin" or .kind == "webapp" or
       .kind == "theme-install" or .kind == "theme-active") and
      (.name | type == "string") and (.definition | type == "object") and
      (.firstObserved | observed) and (.cleanupPolicy | cleanup) and
      (.state | rstate) and (.evidence | type == "object"))) and
    (([.resources[].id] | length) == ([.resources[].id] | unique | length)) and
    (all(.claims[];
      (.loadoutId | localid) and (.resourceId | type == "string") and
      (.requested | type == "object") and (.status | cstate) and
      (.lastError | type == "string"))) and
    (([.claims[] | [.loadoutId, .resourceId] | join("\u001f")] | length) ==
     ([.claims[] | [.loadoutId, .resourceId] | join("\u001f")] | unique | length)) and
    (.operation == null or
      ((.operation | type == "object") and
       (.operation.kind == "apply" or .operation.kind == "update" or
        .operation.kind == "repair" or .operation.kind == "remove") and
       (.operation.target | localid) and
       (.operation.phase == "planned" or .operation.phase == "running") and
       (.operation.actions | type == "array") and
       all(.operation.actions[];
         (.resourceId | type == "string") and (.state | actionstate))))
  ' "$file" >/dev/null 2>&1 || return 1

  local kind name id row definition requested resource source profile loadout_id
  while IFS= read -r row; do
    kind=$(jq -r '.kind' <<<"$row"); name=$(jq -r '.name' <<<"$row"); id=$(jq -r '.id' <<<"$row")
    case "$kind" in
      package) valid_pkg "$name" && [[ $id == "package:$name" ]] || return 1 ;;
      plugin) valid_id "$name" && [[ $id == "plugin:$name" ]] || return 1 ;;
      webapp) valid_label "$name" && [[ $id == "webapp:$name" ]] || return 1 ;;
      theme-install) valid_theme "$name" && [[ $id == "theme-install:$name" ]] || return 1 ;;
      theme-active)
        valid_theme "$name" || return 1
        [[ ${id#theme-active:} =~ ^[a-z0-9][a-z0-9-]{0,80}$ ]] || return 1
        ;;
      *) return 1 ;;
    esac
    definition=$(jq -c '.definition' <<<"$row")
    registry_definition_valid "$kind" "$name" "$definition" || return 1
  done < <(jq -c '.resources[]' "$file")

  while IFS= read -r row; do
    id=$(jq -r '.resourceId' <<<"$row")
    resource=$(jq -c --arg id "$id" '.resources[] | select(.id == $id)' "$file")
    [[ -n $resource ]] || return 1
    loadout_id=$(jq -r '.loadoutId' <<<"$row")
    jq -e --arg id "$loadout_id" 'any(.loadouts[]; .id == $id)' "$file" >/dev/null || return 1
    kind=$(jq -r '.kind' <<<"$resource"); name=$(jq -r '.name' <<<"$resource")
    requested=$(jq -c '.requested' <<<"$row")
    registry_claim_request_valid "$kind" "$name" "$requested" || return 1
  done < <(jq -c '.claims[]' "$file")

  while IFS= read -r row; do
    source=$(jq -r '.source' <<<"$row")
    [[ $source != *"://"* || $(strip_credentials "$source") == "$source" ]] || return 1
    profile=$(jq -c '.profile' <<<"$row")
    registry_profile_valid "$profile" || return 1
  done < <(jq -c '.loadouts[]' "$file")
}

registry_load() {
  local allow_missing="${1:-0}"
  if [[ ! -f $LOADOUT_REGISTRY ]]; then
    REGISTRY=$(registry_empty)
    REGISTRY_REVISION=0
    return 0
  fi
  if ! registry_validate "$LOADOUT_REGISTRY"; then
    (( allow_missing )) && return 1
    die "the applied-loadout registry is malformed or unsupported — refusing to mutate it"
  fi
  REGISTRY=$(<"$LOADOUT_REGISTRY")
  REGISTRY_REVISION=$(jq -r '.revision' <<<"$REGISTRY")
}

registry_save() {
  local next="$1" current_revision=0 tmp
  private_dir "$STATE_DIR"
  if [[ -f $LOADOUT_REGISTRY ]]; then
    registry_validate "$LOADOUT_REGISTRY" || die "the applied-loadout registry changed into an invalid state"
    current_revision=$(jq -r '.revision' "$LOADOUT_REGISTRY")
  fi
  (( current_revision == REGISTRY_REVISION )) ||
    die "the applied-loadout registry changed while this operation was planning; retry"
  next=$(jq -c --argjson revision "$((REGISTRY_REVISION + 1))" '.revision = $revision' <<<"$next")
  tmp=$(mktemp "$STATE_DIR/.loadouts.XXXXXX")
  printf '%s\n' "$next" >"$tmp"
  chmod 600 "$tmp"
  if ! registry_validate "$tmp"; then
    rm -f "$tmp"
    die "internal error: refusing to write an invalid applied-loadout registry"
  fi
  mv -f "$tmp" "$LOADOUT_REGISTRY"
  REGISTRY="$next"
  REGISTRY_REVISION=$((REGISTRY_REVISION + 1))
}

registry_begin_operation() {
  local kind="$1" target="$2" actions="${3:-[]}" next
  next=$(jq -c --arg kind "$kind" --arg target "$target" --argjson actions "$actions" \
    '.operation = {kind: $kind, target: $target, phase: "planned", actions: $actions}' <<<"$REGISTRY")
  registry_save "$next"
}

registry_action_state() {
  local resource="$1" state="$2" next
  next=$(jq -c --arg id "$resource" --arg state "$state" '
    .operation.phase = "running" |
    .operation.actions |= map(if .resourceId == $id then .state = $state else . end)
  ' <<<"$REGISTRY")
  registry_save "$next"
}

registry_finish_operation() {
  local next
  next=$(jq -c '.operation = null' <<<"$REGISTRY")
  registry_save "$next"
}
