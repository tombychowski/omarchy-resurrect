#!/bin/bash
#
# Share candidate discovery, catalog construction, selective validation, and
# profile/README rendering.
# Depends on core.sh, safety.sh, registry.sh, profile.sh, and resources.sh. Owns
# profile-export temporary state; used by share. Definitions only at source time.

# ============================================================ SHARE / APPLY
#
# A loadout is your setup with your data removed: what is installed, not what
# is in your files. The format is one JSON file with a fixed set of keys, all
# of them names and URLs. There is no field that holds file contents and no
# field that holds a command, so a profile cannot carry a secret and cannot
# carry a script — not by policy, but because there is nowhere to put one.


# One unavailable candidate still needs a stable, non-path identity so the
# panel can keep it visible and explain why it cannot travel.
share_unavailable_id() {
  local kind="$1" seed="$2" digest
  digest=$(printf '%s' "$seed" | sha256sum | awk '{print substr($1,1,16)}')
  printf 'unavailable:%s:%s' "$kind" "$digest"
}

share_candidate_json() {
  local id="$1" kind="$2" name="$3" shareable="$4" code="$5" reason="$6"
  local channels="$7" active="$8" definition="$9"
  jq -nc --arg id "$id" --arg kind "$kind" --arg name "$name" \
    --arg code "$code" --arg reason "$reason" --argjson shareable "$shareable" \
    --argjson channels "$channels" --argjson active "$active" --argjson definition "$definition" \
    '{id:$id,kind:$kind,name:$name,shareable:$shareable,reasonCode:$code,reason:$reason,
      channels:$channels,active:$active,definition:$definition}'
}

# The canonical live-machine inventory behind both `share catalog` and export.
# Definitions never come from QML; selected ids are resolved against a fresh
# answer from here immediately before the profile is written.
share_candidates_json() {
  local rows=() value id dir raw_url url sha code reason definition
  local file name icon parts launcher web_url flags active=false base
  local native='["native"]' aur='["aur"]' none='[]'
  declare -A seen_themes=()

  while IFS= read -r value; do
    [[ -n $value ]] || continue
    if valid_pkg "$value"; then
      definition=$(jq -nc --arg name "$value" '{name:$name}')
      rows+=("$(share_candidate_json "package:$value" package "$value" true "" "" "$native" false "$definition")")
    fi
  done < <(pacman -Qqen 2>/dev/null || true)
  while IFS= read -r value; do
    [[ -n $value ]] || continue
    if valid_pkg "$value"; then
      definition=$(jq -nc --arg name "$value" '{name:$name}')
      rows+=("$(share_candidate_json "package:$value" package "$value" true "" "" "$aur" false "$definition")")
    fi
  done < <(pacman -Qqem 2>/dev/null || true)

  for dir in "$HOME"/.config/omarchy/plugins/*/; do
    [[ -d $dir ]] || continue
    base=$(basename "$dir")
    code=""; reason=""; id=""; raw_url=""; url=""; sha=""
    if [[ ! -f $dir/manifest.json ]]; then
      code="missing-manifest"; reason="plugin manifest is missing"
    else
      id=$(jq -r '.id // empty' "$dir/manifest.json" 2>/dev/null || true)
      if ! valid_id "$id"; then code="unsafe-id"; reason="plugin id is missing or unsafe"; fi
    fi
    if [[ -z $code ]]; then
      raw_url=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
      url=$(canonical_remote "$raw_url")
      if [[ -z $raw_url ]]; then code="missing-remote"; reason="plugin has no origin remote"
      elif ! valid_https "$url"; then code="unsafe-remote"; reason="plugin remote is not safe HTTPS"
      fi
    fi
    if [[ -z $code ]]; then
      sha=$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)
      valid_sha "$sha" || { code="unpinned"; reason="plugin has no exact commit"; }
    fi
    if [[ -z $id || ! $id =~ ^[A-Za-z0-9] ]]; then
      id=$(share_unavailable_id plugin "$base")
      name="$base"
    else
      name="$id"; id="plugin:$id"
    fi
    definition=$(jq -nc --arg id "${id#plugin:}" --arg url "$url" --arg commit "$sha" \
      '{id:$id,url:$url,commit:$commit}')
    if [[ -z $code ]]; then
      rows+=("$(share_candidate_json "$id" plugin "$name" true "" "" "$none" false "$definition")")
    else
      rows+=("$(share_candidate_json "$id" plugin "$name" false "$code" "$reason" "$none" false "$definition")")
    fi
  done

  for file in "$HOME"/.local/share/applications/*.desktop; do
    [[ -f $file ]] || continue
    package_owned_launcher "$file" "$(basename "$file")" && continue
    grep -Eq '^Exec=omarchy-launch-(webapp|or-focus-webapp)([[:space:]]|$)' "$file" || continue
    base=$(basename "$file" .desktop)
    name=$(sed -n 's/^Name=//p' "$file" | head -1)
    icon=$(sed -n 's/^Icon=//p' "$file" | head -1)
    code=""; reason=""; launcher=""; web_url=""; flags=""
    if webapp_url_has_credentials "$(launcher_exec "$file")"; then
      code="credential-url"; reason="launcher URL contains credentials"
    elif ! launcher_travels "$file"; then
      code="unsupported-launcher"; reason="launcher has executable fields the loadout cannot represent"
    else
      parts=$(webapp_parts "$(launcher_exec "$file")" 2>/dev/null || true)
      if [[ -z $parts ]]; then code="unsupported-launcher"; reason="launcher command is not reconstructible"
      else IFS=$'\t' read -r launcher web_url flags <<<"$parts"; fi
    fi
    [[ -n $code || -z $flags && $launcher == omarchy-launch-webapp ]] || {
      code="unsupported-launcher"; reason="browser flags or focus launchers are not in profile schema 1";
    }
    [[ -n $code ]] || valid_label "$name" || { code="unsafe-name"; reason="web app name is unsafe"; }
    [[ -n $code || -z $icon ]] || valid_icon "$icon" || { code="unsafe-icon"; reason="web app icon id is unsafe"; }
    if valid_label "$name"; then id="webapp:$name"; else id=$(share_unavailable_id webapp "$base"); name="${name:-$base}"; fi
    definition=$(jq -nc --arg name "$name" --arg url "$web_url" --arg icon "$icon" \
      '{name:$name,url:$url,icon:$icon}')
    if [[ -z $code ]]; then
      rows+=("$(share_candidate_json "$id" webapp "$name" true "" "" "$none" false "$definition")")
    else
      rows+=("$(share_candidate_json "$id" webapp "$name" false "$code" "$reason" "$none" false "$definition")")
    fi
  done

  value=$(active_theme_name || true)
  for dir in "$HOME"/.config/omarchy/themes/*/; do
    [[ -d $dir ]] || continue
    name=$(basename "$dir"); code=""; reason=""; raw_url=""; url=""; sha=""
    valid_theme "$name" || { code="unsafe-name"; reason="theme name is unsafe"; }
    if [[ -z $code ]]; then
      raw_url=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
      url=$(canonical_remote "$raw_url")
      if [[ -z $raw_url ]]; then code="local-only"; reason="custom theme has no fetchable remote"
      elif ! valid_https "$url"; then code="unsafe-remote"; reason="theme remote is not safe HTTPS"
      fi
    fi
    if [[ -z $code ]]; then
      sha=$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)
      valid_sha "$sha" || { code="unpinned"; reason="theme has no exact commit"; }
    fi
    if valid_theme "$name"; then id="theme-install:$name"; seen_themes[$name]=1
    else id=$(share_unavailable_id theme "$name"); fi
    [[ $name == "$value" ]] && active=true || active=false
    definition=$(jq -nc --arg name "$name" --arg url "$url" --arg commit "$sha" \
      '{name:$name,url:$url,commit:$commit}')
    if [[ -z $code ]]; then
      rows+=("$(share_candidate_json "$id" theme "$name" true "" "" "$none" "$active" "$definition")")
    else
      rows+=("$(share_candidate_json "$id" theme "$name" false "$code" "$reason" "$none" "$active" "$definition")")
    fi
  done
  for dir in "$OMARCHY_DIR"/themes/*/; do
    [[ -d $dir ]] || continue
    name=$(basename "$dir"); valid_theme "$name" || continue
    [[ -z ${seen_themes[$name]:-} ]] || continue
    seen_themes[$name]=1; [[ $name == "$value" ]] && active=true || active=false
    definition=$(jq -nc --arg name "$name" '{name:$name,url:"",commit:""}')
    rows+=("$(share_candidate_json "theme-install:$name" theme "$name" true "" "" "$none" "$active" "$definition")")
  done
  if [[ -n $value && -z ${seen_themes[$value]:-} ]]; then
    definition=$(jq -nc --arg name "$value" '{name:$name,url:"",commit:""}')
    rows+=("$(share_candidate_json "theme-install:$value" theme "$value" false missing-theme \
      "active theme is not installed in a shareable location" "$none" true "$definition")")
  fi

  (( ${#rows[@]} > 0 )) || { printf '[]'; return 0; }
  printf '%s\n' "${rows[@]}" | jq -sc '
    sort_by(.id) | group_by(.id) | map(
      if length == 1 then .[0]
      elif all(.[]; .kind == "package") then
        .[0] + {channels:([.[].channels[]] | unique)}
      else .[0] end) | sort_by(.kind,.name,.id)'
}

profile_share_resources_json() {
  local file="$1"
  jq -c '
    ([.packages.native[]? | {id:("package:" + .),kind:"package",name:.,channels:["native"],definition:{name:.}}] +
     [.packages.aur[]? | {id:("package:" + .),kind:"package",name:.,channels:["aur"],definition:{name:.}}] +
     [.plugins[]? | {id:("plugin:" + .id),kind:"plugin",name:.id,channels:[],definition:{id:.id,url:.url,commit:.commit}}] +
     [.webapps[]? | {id:("webapp:" + .name),kind:"webapp",name:.name,channels:[],definition:{name:.name,url:.url,icon:.icon}}] +
     [select(.theme.name != "") | {id:("theme-install:" + .theme.name),kind:"theme",name:.theme.name,channels:[],definition:{name:.theme.name,url:.theme.url,commit:.theme.commit}}]) |
    sort_by(.id) | group_by(.id) | map(
      if length == 1 then .[0]
      else .[0] + {channels:([.[].channels[]] | unique)} end) | sort_by(.id)
  ' "$file"
}

share_definition_fingerprint() {
  jq -Sc '{id,kind,name,channels,definition}' <<<"$1" | sha256sum | awk '{print $1}'
}

share_candidate_matches_item() {
  local candidate="$1" item="$2" exact_channels="${3:-1}"
  jq -e --argjson item "$item" --argjson channels "$exact_channels" '
    .shareable == true and .kind == $item.kind and .definition == $item.definition and
    ($channels == 0 or .kind != "package" or ((.channels | sort) == ($item.channels | sort)))
  ' <<<"$candidate" >/dev/null
}

share_current_export_json() {
  local candidates="$1" out="$2" file="$out/profile.json" items item candidate
  local available='[]' unavailable='[]' code reason fingerprint
  if [[ ! -f $file ]]; then
    jq -nc --arg name "$(whoami)'s Omarchy" \
      '{state:"absent",name:$name,description:"",resourceIds:[],unavailable:[]}'
    return 0
  fi
  if [[ -L $file ]]; then
    jq -nc --arg name "$(whoami)'s Omarchy" \
      '{state:"unavailable",name:$name,description:"",resourceIds:[],unavailable:[],reasonCode:"invalid-profile",reason:"current profile must be a regular file inside the output directory"}'
    return 0
  fi
  if ! jq -e . "$file" >/dev/null 2>&1 || ! profile_document_valid "$(<"$file")"; then
    jq -nc --arg name "$(whoami)'s Omarchy" \
      '{state:"unavailable",name:$name,description:"",resourceIds:[],unavailable:[],reasonCode:"invalid-profile",reason:"current profile is malformed or unsupported"}'
    return 0
  fi
  items=$(profile_share_resources_json "$file")
  while IFS= read -r item; do
    candidate=$(jq -c --arg id "$(jq -r '.id' <<<"$item")" '.[] | select(.id == $id)' <<<"$candidates")
    if [[ -n $candidate ]] && share_candidate_matches_item "$candidate" "$item" 1; then
      available=$(jq -c --arg id "$(jq -r '.id' <<<"$item")" '. + [$id]' <<<"$available")
      continue
    fi
    if [[ -n $candidate && $(jq -r '.shareable' <<<"$candidate") == false ]]; then
      code=$(jq -r '.reasonCode' <<<"$candidate"); reason=$(jq -r '.reason' <<<"$candidate")
    elif [[ -n $candidate ]]; then
      code="definition-mismatch"; reason="current machine definition differs from the exported profile"
    else
      code="missing"; reason="resource is not present on this machine"
    fi
    fingerprint=$(share_definition_fingerprint "$item")
    unavailable=$(jq -c --argjson item "$item" --arg code "$code" --arg reason "$reason" --arg fingerprint "$fingerprint" \
      '. + [($item | del(.definition,.channels) + {reasonCode:$code,reason:$reason,fingerprint:$fingerprint})]' <<<"$unavailable")
  done < <(jq -c '.[]' <<<"$items")
  jq -nc --arg name "$(jq -r '.name' "$file")" --arg description "$(jq -r '.description' "$file")" \
    --argjson ids "$available" --argjson unavailable "$unavailable" \
    '{state:"valid",name:$name,description:$description,resourceIds:($ids|unique),unavailable:$unavailable}'
}

share_presets_json() {
  local candidates="$1" loadout item candidate resource observation claim claim_status state
  local presets='[]' ids warnings loadout_id profile_items
  machine_observation_snapshot_build
  if [[ -f $LOADOUT_REGISTRY ]]; then
    if ! registry_validate "$LOADOUT_REGISTRY"; then
      printf '%s' '{"state":"unavailable","loadouts":[],"reasonCode":"invalid-registry","reason":"applied-loadout state is malformed or unsupported"}'
      return 0
    fi
    REGISTRY=$(<"$LOADOUT_REGISTRY")
  else
    REGISTRY=$(registry_empty)
  fi
  while IFS= read -r loadout; do
    loadout_id=$(jq -r '.id' <<<"$loadout"); ids='[]'; warnings='[]'
    profile_items=$(jq -c '.profile' <<<"$loadout" | profile_share_resources_json /dev/stdin)
    while IFS= read -r item; do
      candidate=$(jq -c --arg id "$(jq -r '.id' <<<"$item")" '.[] | select(.id == $id)' <<<"$candidates")
      resource=$(registry_resource_json "$(jq -r '.id' <<<"$item")")
      claim=$(registry_claim_json "$loadout_id" "$(jq -r '.id' <<<"$item")")
      claim_status=""
      [[ -z $claim ]] || claim_status=$(jq -r '.status' <<<"$claim")
      state="missing"
      [[ -z $resource ]] || state=$(jq -r '.state' <<<"$(resource_inspect_json "$resource")")
      if [[ -n $candidate ]] && share_candidate_matches_item "$candidate" "$item" 0 &&
        [[ $claim_status == healthy && $state == present ]]; then
        ids=$(jq -c --arg id "$(jq -r '.id' <<<"$item")" '. + [$id]' <<<"$ids")
      else
        code="unavailable"
        [[ -n $candidate ]] || code="missing"
        [[ $state == present ]] || code="$state"
        # Claim conflict/defer/failure is specific to this preset and therefore
        # more informative than the shared resource's live observation.
        [[ -z $claim_status || $claim_status == healthy ]] || code="$claim_status"
        [[ -z $candidate || $(jq -r '.shareable' <<<"$candidate") == true ]] || code=$(jq -r '.reasonCode' <<<"$candidate")
        warnings=$(jq -c --arg id "$(jq -r '.id' <<<"$item")" --arg code "$code" \
          '. + [{id:$id,state:$code}]' <<<"$warnings")
      fi
    done < <(jq -c '.[]' <<<"$profile_items")
    presets=$(jq -c --arg id "$loadout_id" --arg name "$(jq -r '.name' <<<"$loadout")" \
      --argjson ids "$ids" --argjson warnings "$warnings" \
      '. + [{id:$id,name:$name,resourceIds:($ids|unique),warnings:$warnings}]' <<<"$presets")
  done < <(jq -c '.loadouts[]' <<<"$REGISTRY")
  jq -nc --argjson loadouts "$presets" '{state:"valid",loadouts:$loadouts}'
}

share_catalog_json() {
  local out="${1:-$PROFILE_DIR_DEFAULT}" repository_id="${2:-}" loadout_id="${3:-}" repository_commit="${4:-}"
  local candidates current presets public counts
  candidates=$(share_candidates_json)
  current=$(share_current_export_json "$candidates" "$out")
  presets=$(share_presets_json "$candidates")
  public=$(jq -c '[.[] | del(.definition)]' <<<"$candidates")
  counts=$(jq -c 'reduce .[] as $r ({}; .[$r.kind] = ((.[$r.kind] // 0) + 1))' <<<"$candidates")
  jq -nc --arg repositoryId "$repository_id" --arg loadoutId "$loadout_id" \
    --arg repositoryCommit "$repository_commit" --argjson resources "$public" \
    --argjson current "$current" --argjson presets "$presets" --argjson counts "$counts" '
    {schemaVersion:1,kind:"montage-share-catalog",
     repositoryId:(if $repositoryId=="" then null else $repositoryId end),
     loadoutId:(if $loadoutId=="" then null else $loadoutId end),
     repositoryCommit:(if $repositoryCommit=="" then null else $repositoryCommit end),
     resources:$resources,currentExport:$current,presets:$presets,counts:$counts,limits:{themes:1}}'
}

cmd_share_catalog() {
  local as_json=0 out="$PROFILE_DIR_DEFAULT" repository="" loadout_id="" repository_id="" repository_commit=""
  while (( $# > 0 )); do
    case "$1" in
      --json) as_json=1; shift ;;
      --out) out="${2:-}"; shift 2 ;;
      --repository) repository="${2:-}"; shift 2 ;;
      --loadout) loadout_id="${2:-}"; shift 2 ;;
      *) die "unknown share catalog option: $1" ;;
    esac
  done
  (( as_json )) || die "usage: mntg share catalog --json"
  if [[ -n $repository || -n $loadout_id ]]; then
    [[ -n $repository && -n $loadout_id ]] || die "share catalog requires both --repository and --loadout"
    repository_id_valid "$loadout_id" || die "invalid stable loadout id"
    loadout_repository_resolve "$repository" || die "loadout repository is invalid or unavailable"
    out="$LOADOUT_REPOSITORY_PATH/loadouts/$loadout_id"
    repository_id=$(jq -r '.id' "$LOADOUT_REPOSITORY_PATH/$MONTAGE_REPOSITORY_MANIFEST")
    repository_commit=$(git -C "$LOADOUT_REPOSITORY_PATH" rev-parse HEAD^{commit} 2>/dev/null || true)
  fi
  [[ -n $out ]] || die "profile output directory must not be empty"
  share_catalog_json "$out" "$repository_id" "$loadout_id" "$repository_commit" | jq .
}

take_profile_lock() {
  local out="$1" digest lock_dir="$STATE_DIR/profile-locks"
  out=$(realpath -m -- "$out")
  digest=$(printf '%s' "$out" | sha256sum | awk '{print substr($1,1,24)}')
  private_dir "$lock_dir"
  exec 7>"$lock_dir/$digest.lock"
  flock -n 7 || die "another export is already writing this profile"
}

render_share_profile() {
  local candidates="$1" selected="$2" output="$3" name="$4" description="$5"
  jq -n --argjson schemaVersion "$PROFILE_SCHEMA" --arg kind omarchy-loadout \
    --arg name "$name" --arg author "$(git config --global user.name 2>/dev/null || whoami)" \
    --arg description "$description" --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg omarchy "$( [[ -f $OMARCHY_DIR/version ]] && cat "$OMARCHY_DIR/version" || echo unknown )" \
    --argjson candidates "$candidates" --argjson selected "$selected" '
    ($candidates | map(select(.id as $id | $selected | index($id)))) as $items |
    {schemaVersion:$schemaVersion,kind:$kind,name:$name,author:$author,description:$description,
     createdAt:$createdAt,omarchy:$omarchy,
     packages:{
       native:[$items[]|select(.kind=="package" and (.channels|index("native")))|.name] | sort,
       aur:[$items[]|select(.kind=="package" and ((.channels|index("native"))|not))|.name] | sort},
     plugins:[$items[]|select(.kind=="plugin")|.definition] | sort_by(.id),
     webapps:[$items[]|select(.kind=="webapp")|.definition] | sort_by(.name),
     theme:(([$items[]|select(.kind=="theme")|.definition]|first) // {name:"",url:"",commit:""})}
  ' >"$output"
}

render_share_readme() {
  local profile="$1" output="$2" loadout_id="${3:-}" repository_url="${4:-<repository-url>}"
  local name theme n_pkg n_aur n_plug n_web apply_command
  name=$(jq -r '.name' "$profile"); theme=$(jq -r '.theme.name' "$profile")
  n_pkg=$(jq '.packages.native | length' "$profile"); n_aur=$(jq '.packages.aur | length' "$profile")
  n_plug=$(jq '.plugins | length' "$profile"); n_web=$(jq '.webapps | length' "$profile")
  apply_command="mntg apply $repository_url"
  [[ -z $loadout_id ]] || apply_command+=" --loadout $loadout_id"
  cat >"$output" <<PROFILE_README
# $name

An [Omarchy](https://omarchy.org) loadout: $n_pkg packages, $n_aur from the AUR,
$n_plug shell plugins, $n_web web apps, on the \`${theme:-no selected}\` theme.

Make your machine look like this one:

\`\`\`bash
$apply_command
\`\`\`

It shows you everything it would install and asks before it installs any of it.

This profile is a package list, not a backup. It contains no dotfiles, no keys,
and nothing from a home directory — the format has no field that could hold them.
PROFILE_README
}

cmd_share() {
  if [[ ${1:-} == catalog ]]; then shift; cmd_share_catalog "$@"; return; fi

  local out="$PROFILE_DIR_DEFAULT" name="" description="" custom=0 candidates selected='[]'
  local repository="" loadout_id="" repository_mode=0 repository_root=""
  local configured_remote="" share_url=""
  local current item candidate id fingerprint theme_count unavailable provided
  local selected_ids=() ack_ids=() ack_fingerprints=()
  declare -A seen_selected=() acknowledgements=()
  while (( $# > 0 )); do
    case "$1" in
      --out) out="${2:-}"; shift 2 ;;
      --repository) repository="${2:-}"; shift 2 ;;
      --loadout) loadout_id="${2:-}"; shift 2 ;;
      --name) name="${2:-}"; shift 2 ;;
      --description) description="${2:-}"; shift 2 ;;
      --custom) custom=1; shift ;;
      --select) selected_ids+=("${2:-}"); shift 2 ;;
      --acknowledge-unavailable)
        ack_ids+=("${2:-}"); ack_fingerprints+=("${3:-}"); shift 3 ;;
      *) die "unknown share option: $1" ;;
    esac
  done
  [[ -n $name ]] || name="$(whoami)'s Omarchy"
  profile_metadata_valid "$name" "$description" ||
    die "loadout name must be 1-120 display-safe characters and description at most 1000"
  if [[ -n $repository || -n $loadout_id ]]; then
    [[ -n $repository && -n $loadout_id ]] || die "share requires both --repository and --loadout"
    repository_id_valid "$loadout_id" || die "invalid stable loadout id"
    loadout_repository_resolve "$repository" || die "loadout repository is invalid or unavailable"
    repository_root="$LOADOUT_REPOSITORY_PATH"
    if [[ $repository != /* ]]; then
      configured_remote=$(repository_registry_get "$repository" | jq -r '.remote')
    fi
    out="$repository_root/loadouts/$loadout_id"
    repository_mode=1
  fi
  [[ -n $out ]] || die "profile output directory must not be empty"
  if (( custom )); then
    (( ${#selected_ids[@]} > 0 )) || die "a custom loadout must select at least one resource"
  elif (( ${#selected_ids[@]} + ${#ack_ids[@]} > 0 )); then
    die "--select and --acknowledge-unavailable require --custom"
  fi

  emit "BEGIN|share|$out"
  step_start share "Reading this machine"
  if (( repository_mode )); then
    repository_lock "$repository_root" || die "another operation is using this repository"
    repository_recover_publication "$repository_root" || die "repository publication recovery failed"
    repository_worktree_clean "$repository_root" || die "repository working tree must be clean before sharing"
  else
    take_profile_lock "$out"
  fi
  candidates=$(share_candidates_json)

  if (( custom )); then
    for id in "${selected_ids[@]}"; do
      [[ -n $id ]] || die "selected resource id must not be empty"
      [[ -z ${seen_selected[$id]:-} ]] || die "duplicate selected resource: $(plain "$id")"
      seen_selected[$id]=1
      candidate=$(jq -c --arg id "$id" '.[] | select(.id == $id)' <<<"$candidates")
      [[ -n $candidate ]] || die "selected resource is not on this machine: $(plain "$id")"
      [[ $(jq -r '.shareable' <<<"$candidate") == true ]] ||
        die "selected resource is unavailable: $(plain "$id") ($(plain "$(jq -r '.reasonCode' <<<"$candidate")"))"
      selected=$(jq -c --arg id "$id" '. + [$id]' <<<"$selected")
    done
    theme_count=$(jq --argjson ids "$selected" '[.[]|select(.kind=="theme" and (.id as $id|$ids|index($id)))]|length' <<<"$candidates")
    (( theme_count <= 1 )) || die "a schema-version-1 loadout can select at most one theme"

    for (( provided=0; provided<${#ack_ids[@]}; provided++ )); do
      id=${ack_ids[$provided]}; fingerprint=${ack_fingerprints[$provided]}
      [[ -n $id && -n $fingerprint && -z ${acknowledgements[$id]:-} ]] ||
        die "invalid duplicate or empty unavailable-resource acknowledgement"
      acknowledgements[$id]="$fingerprint"
    done
    current=$(share_current_export_json "$candidates" "$out")
    [[ $(jq -r '.state' <<<"$current") != unavailable ]] ||
      die "current profile is malformed or unsupported; refusing selective replacement"
    if [[ $(jq -r '.state' <<<"$current") == valid ]]; then
      while IFS= read -r unavailable; do
        id=$(jq -r '.id' <<<"$unavailable"); fingerprint=$(jq -r '.fingerprint' <<<"$unavailable")
        [[ ${acknowledgements[$id]:-} == "$fingerprint" ]] ||
          die "acknowledgement required before removing unavailable resource: $(plain "$id")"
        unset 'acknowledgements[$id]'
      done < <(jq -c '.unavailable[]' <<<"$current")
    fi
    (( ${#acknowledgements[@]} == 0 )) || die "stale acknowledgement does not match the current profile"
  else
    selected=$(jq -c '[.[] | select(.shareable and (.kind != "theme" or .active)) | .id]' <<<"$candidates")
    local left_out
    left_out=$(jq '[.[] | select(.kind == "webapp" and (.shareable|not))] | length' <<<"$candidates")
    (( left_out == 0 )) || step_warn share \
      "$(plural "$left_out" "web app") left out of the profile — the format cannot reproduce its launcher"
  fi

  local parent; parent=$(dirname "$out")
  if (( repository_mode )); then
    repository_stage_dir "$repository_root" || die "could not create repository staging directory"
    PROFILE_WORK="$REPOSITORY_STAGE"
  else
    mkdir -p "$parent"
    montage_make_temp_dir "$parent/.mntg-profile.XXXXXX" || die "could not create profile workspace"
    PROFILE_WORK="$MONTAGE_TEMP_PATH"
  fi
  render_share_profile "$candidates" "$selected" "$PROFILE_WORK/profile.json" "$name" "$description"
  if (( repository_mode )); then
    share_url=$(canonical_share_url \
      "${configured_remote:-$(git -C "$repository_root" remote get-url origin 2>/dev/null || true)}" \
      2>/dev/null || true)
  fi
  render_share_readme "$PROFILE_WORK/profile.json" "$PROFILE_WORK/README.md" \
    "$([[ $repository_mode == 1 ]] && printf '%s' "$loadout_id")" "${share_url:-<repository-url>}"

  local n_pkg n_aur n_plug n_web
  n_pkg=$(jq '.packages.native | length' "$PROFILE_WORK/profile.json")
  n_aur=$(jq '.packages.aur | length' "$PROFILE_WORK/profile.json")
  n_plug=$(jq '.plugins | length' "$PROFILE_WORK/profile.json")
  n_web=$(jq '.webapps | length' "$PROFILE_WORK/profile.json")

  if (( repository_mode )); then
    repository_publish_path "$repository_root" "$PROFILE_WORK" "loadouts/$loadout_id" \
      loadout_repository_stage_item_valid || die "generated loadout failed validation"
    PROFILE_WORK=""
    repository_commit_if_changed "$repository_root" "Update loadout $loadout_id" ||
      die "could not commit loadout update"
    repository_unlock
  else
    mkdir -p "$out"
    mv "$PROFILE_WORK/profile.json" "$out/profile.json"
    mv "$PROFILE_WORK/README.md" "$out/README.md"
    rm -rf "$PROFILE_WORK"; PROFILE_WORK=""

    if [[ ! -d $out/.git ]]; then
      git -C "$out" init -q -b main
      git -C "$out" add -A
      git -C "$out" -c commit.gpgsign=false commit -q -m "Loadout: $name" 2>/dev/null || true
    else
      git -C "$out" add -A
      git -C "$out" diff --cached --quiet ||
        git -C "$out" -c commit.gpgsign=false commit -q -m "Update loadout" 2>/dev/null || true
    fi
  fi

  step_ok share "$(plural "$n_pkg" package), $n_aur AUR, $(plural "$n_plug" plugin), $(plural "$n_web" "web app")"

  local origin link
  if (( repository_mode )); then
    origin=$(canonical_remote "$(git -C "$repository_root" remote get-url origin 2>/dev/null || true)")
    [[ -z $origin ]] || git -C "$repository_root" remote set-url origin "$origin" 2>/dev/null || true
  else
    origin=$(canonical_remote "$(git -C "$out" remote get-url origin 2>/dev/null || true)")
    [[ -z $origin ]] || git -C "$out" remote set-url origin "$origin" 2>/dev/null || true
  fi
  link=""
  [[ -n $origin ]] && link=$(canonical_share_url "$origin" 2>/dev/null || true)
  if (( repository_mode )) && [[ -n $configured_remote ]]; then
    link=$(canonical_share_url "$configured_remote" 2>/dev/null || true)
  fi
  if [[ -n $link ]]; then CFG[PROFILE_URL]="$link"; save_config; fi
  emit "DONE|ok|$out"

  if (( ! PORCELAIN )); then
    printf '\n%sLoadout written to %s%s\n\n' "$c_bold" "$out" "$c_reset"
    if [[ -n $link ]]; then
      if (( repository_mode )); then
        printf 'Share this line:\n\n  %smntg apply %s --loadout %s%s\n\n' \
          "$c_green" "$link" "$loadout_id" "$c_reset"
      else
        printf 'Share this line:\n\n  %smntg apply %s%s\n\n' "$c_green" "$link" "$c_reset"
      fi
    else
      printf 'Push it to a public repo, then share the one-liner:\n\n'
      printf '  %scd %s\n  git remote add origin git@github.com:you/my-omarchy-loadouts.git\n  git push -u origin main%s\n\n' \
        "$c_dim" "${repository_root:-$out}" "$c_reset"
      if (( repository_mode )); then
        printf '  %smntg apply https://github.com/you/my-omarchy-loadouts --loadout %s%s\n\n' \
          "$c_green" "$loadout_id" "$c_reset"
      else
        printf '  %smntg apply https://github.com/you/my-omarchy-loadout%s\n\n' "$c_green" "$c_reset"
      fi
    fi
  fi
}
