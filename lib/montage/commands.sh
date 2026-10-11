#!/bin/bash
#
# Loadout-only application commands. This module owns product-wide queries and
# commands whose state is not owned by one loadout resource domain. Definitions
# only; sourcing performs no I/O.

status_operation_json() {
  local marker="$STATE_DIR/running" lock="$STATE_DIR/lock" token="" valid=true active=false
  local owner_pid=null marker_fd=""
  if [[ -e $marker || -L $marker ]]; then
    if [[ ! -f $marker || -L $marker ]]; then
      valid=false
    else
      IFS= read -r token <"$marker" || token=""
      if [[ $token =~ ^([0-9]+):[0-9]+:[0-9]+$ ]] && [[ -f $lock && ! -L $lock ]]; then
        owner_pid="${BASH_REMATCH[1]}"
        if exec {marker_fd}<"$lock" && ! flock -n "$marker_fd"; then
          active=true
        else
          valid=false
        fi
        [[ -z $marker_fd ]] || exec {marker_fd}>&-
      else
        valid=false
      fi
    fi
  fi
  jq -nc --argjson active "$active" --argjson valid "$valid" --argjson ownerPid "$owner_pid" \
    '{active:$active,valid:$valid,ownerPid:$ownerPid}'
}

status_loadouts_json() {
  local check count attention repair drift partial evidence updates='[]' evidence_valid=true items
  if [[ -e $LOADOUT_REGISTRY || -L $LOADOUT_REGISTRY ]]; then
    if [[ ! -f $LOADOUT_REGISTRY || -L $LOADOUT_REGISTRY ]] ||
       ! registry_validate "$LOADOUT_REGISTRY"; then
      jq -nc '{available:false,evidenceValid:true,count:null,attention:null,repairNeeded:0,drifted:0,
        partialOrFailed:0,updateAvailable:0,items:[]}'
      return 0
    fi
  fi
  registry_load 1 || {
    jq -nc '{available:false,evidenceValid:true,count:null,attention:null,repairNeeded:0,drifted:0,
      partialOrFailed:0,updateAvailable:0,items:[]}'
    return 0
  }
  check=$(loadout_check_json) || {
    jq -nc '{available:false,evidenceValid:true,count:null,attention:null,repairNeeded:0,drifted:0,
      partialOrFailed:0,updateAvailable:0,items:[]}'
    return 0
  }
  count=$(jq '.loadouts | length' <<<"$check")
  attention=$(jq '[.loadouts[] | select(.attentionCount > 0)] | length' <<<"$check")
  repair=$(jq '[.loadouts[].resources[]? |
    select(.healthState == "missing" or .healthState == "pending" or
      .claimStatus == "pending" or .claimStatus == "deferred")] | length' <<<"$check")
  drift=$(jq '[.loadouts[].resources[]? |
    select(.healthState == "modified" or .healthState == "conflicting" or
      .healthState == "uncertain" or .healthState == "unverifiable" or
      .claimStatus == "conflicting" or .claimStatus == "uncertain")] | length' <<<"$check")
  partial=$(jq '[.loadouts[].resources[]? |
    select(.claimStatus == "failed" or .claimStatus == "uncertain")] | length' <<<"$check")
  if jq -e '.operation != null' <<<"$REGISTRY" >/dev/null; then
    partial=$((partial + 1))
  fi
  if loadout_status_evidence_load; then
    evidence="$LOADOUT_STATUS_EVIDENCE_JSON"
    updates=$(jq -nc --argjson registry "$REGISTRY" --argjson evidence "$evidence" '
      [$evidence.updates[] as $update |
       $registry.loadouts[] |
       select(.id == $update.loadoutId and
         .repositoryId == $update.repositoryId and
         .loadoutId == $update.itemId and
         .commit == $update.baselineCommit and
         .digest != $update.digest) |
       $update]')
  else
    evidence_valid=false
  fi
  items=$(jq -nc --argjson loadouts "$(jq -c '.loadouts' <<<"$check")" --argjson updates "$updates" '
    [$loadouts[] | . as $loadout |
      . + {updateAvailable:any($updates[]; .loadoutId == $loadout.id)}]')
  jq -nc --argjson count "$count" --argjson attention "$attention" \
    --argjson repair "$repair" --argjson drift "$drift" --argjson partial "$partial" \
    --argjson evidenceValid "$evidence_valid" --argjson items "$items" \
    --argjson updates "$(jq 'length' <<<"$updates")" \
    '{available:true,evidenceValid:$evidenceValid,count:$count,attention:$attention,
      repairNeeded:$repair,drifted:$drift,partialOrFailed:$partial,
      updateAvailable:$updates,items:$items}'
}

status_repository_sync_json() {
  local entry="$1" valid="$2" root id remote local_commit="" remote_commit="" tracking status=unknown
  root=$(jq -r '.path' <<<"$entry"); id=$(jq -r '.id' <<<"$entry"); remote=$(jq -r '.remote' <<<"$entry")
  if [[ $valid != true ]]; then
    status=unavailable
  elif [[ -z $remote ]]; then
    status=not-configured
  elif local_commit=$(git -C "$root" rev-parse --verify HEAD^{commit} 2>/dev/null) &&
       tracking="refs/montage/remotes/$id" &&
       remote_commit=$(git -C "$root" rev-parse --verify "$tracking^{commit}" 2>/dev/null); then
    if [[ $local_commit == "$remote_commit" ]]; then status=equal
    elif git -C "$root" merge-base --is-ancestor "$remote_commit" "$local_commit" 2>/dev/null; then status=local-ahead
    elif git -C "$root" merge-base --is-ancestor "$local_commit" "$remote_commit" 2>/dev/null; then status=remote-ahead
    else status=divergent
    fi
  fi
  jq -nc --arg status "$status" --arg localCommit "$local_commit" --arg remoteCommit "$remote_commit" '
    {status:$status,localCommit:(if $localCommit == "" then null else $localCommit end),
     remoteCommit:(if $remoteCommit == "" then null else $remoteCommit end),
     evidence:(if $remoteCommit == "" then "none" else "cached-explicit-sync" end)}'
}

status_repositories_json() {
  local catalog items='[]' count attention item entry sync
  if [[ -e $MONTAGE_REPOSITORY_REGISTRY || -L $MONTAGE_REPOSITORY_REGISTRY ]]; then
    if [[ ! -f $MONTAGE_REPOSITORY_REGISTRY || -L $MONTAGE_REPOSITORY_REGISTRY ]]; then
      jq -nc '{available:false,count:null,attention:null,items:[],migration:null}'
      return 0
    fi
  fi
  catalog=$(repository_catalog_json status) || {
    jq -nc '{available:false,count:null,attention:null,items:[],migration:null}'
    return 0
  }
  while IFS= read -r item; do
    entry=$(jq -c '{name,path,type,id,remote}' <<<"$item")
    sync=$(status_repository_sync_json "$entry" "$(jq -r '.valid' <<<"$item")")
    items=$(jq -nc --argjson items "$items" --argjson item "$item" --argjson sync "$sync" \
      '$items + [$item + {sync:$sync}]')
  done < <(jq -c '.repositories[]' <<<"$catalog")
  count=$(jq 'length' <<<"$items")
  attention=$(jq '[.[] | select(.valid != true or .sync.status == "remote-ahead" or
    .sync.status == "divergent")] | length' <<<"$items")
  jq -nc --argjson count "$count" --argjson attention "$attention" --argjson items "$items" \
    --argjson migration "$(jq -c '.migration' <<<"$catalog")" \
    '{available:true,count:$count,attention:$attention,items:$items,migration:$migration}'
}

status_result_json() {
  local operation loadouts repositories attention causes='[]'
  operation=$(status_operation_json)
  loadouts=$(status_loadouts_json)
  repositories=$(status_repositories_json)

  if [[ $(jq -r '.active' <<<"$operation") == true ]]; then
    attention=operation-active
  elif (( $(jq -r '.partialOrFailed' <<<"$loadouts") > 0 )); then
    attention=operation-partial-or-failed
  elif [[ $(jq -r '.valid' <<<"$operation") != true ||
          $(jq -r '.available' <<<"$loadouts") != true ||
          $(jq -r '.evidenceValid' <<<"$loadouts") != true ||
          $(jq -r '.available' <<<"$repositories") != true ]]; then
    attention=unavailable-or-invalid
  elif (( $(jq -r '.attention' <<<"$repositories") > 0 )); then
    attention=repository-attention
  elif (( $(jq -r '.drifted' <<<"$loadouts") > 0 )); then
    attention=drifted
  elif (( $(jq -r '.repairNeeded' <<<"$loadouts") > 0 )); then
    attention=repair-needed
  elif (( $(jq -r '.updateAvailable' <<<"$loadouts") > 0 )); then
    attention=update-available
  else
    attention=healthy
  fi

  [[ $(jq -r '.valid' <<<"$operation") == true ]] ||
    causes=$(jq -c '. + ["operation-state-invalid"]' <<<"$causes")
  [[ $(jq -r '.available' <<<"$loadouts") == true ]] ||
    causes=$(jq -c '. + ["applied-loadout-state-invalid"]' <<<"$causes")
  [[ $(jq -r '.evidenceValid' <<<"$loadouts") == true ]] ||
    causes=$(jq -c '. + ["status-evidence-invalid"]' <<<"$causes")
  [[ $(jq -r '.available' <<<"$repositories") == true ]] ||
    causes=$(jq -c '. + ["repository-state-invalid"]' <<<"$causes")
  (( $(jq -r '.attention // 0' <<<"$repositories") == 0 )) ||
    causes=$(jq -c '. + ["repository-attention"]' <<<"$causes")
  (( $(jq -r '.drifted // 0' <<<"$loadouts") == 0 )) ||
    causes=$(jq -c '. + ["loadout-drift"]' <<<"$causes")
  (( $(jq -r '.repairNeeded // 0' <<<"$loadouts") == 0 )) ||
    causes=$(jq -c '. + ["repair-needed"]' <<<"$causes")
  (( $(jq -r '.partialOrFailed // 0' <<<"$loadouts") == 0 )) ||
    causes=$(jq -c '. + ["operation-partial-or-failed"]' <<<"$causes")
  (( $(jq -r '.updateAvailable // 0' <<<"$loadouts") == 0 )) ||
    causes=$(jq -c '. + ["update-available"]' <<<"$causes")
  [[ $(jq -r '.active' <<<"$operation") != true ]] ||
    causes=$(jq -c '. + ["operation-active"]' <<<"$causes")

  jq -nc --arg attention "$attention" --arg aur "$(config_aur_policy)" \
    --argjson operation "$operation" --argjson loadouts "$loadouts" \
    --argjson repositories "$repositories" --argjson causes "$causes" \
    '{schemaVersion:1,kind:"montage-status",attention:$attention,causes:$causes,
      operation:$operation,loadouts:$loadouts,repositories:$repositories,
      settings:{aur:$aur},migration:$repositories.migration}'
}

cmd_status() {
  local as_json=0 arg result
  for arg in "$@"; do
    case "$arg" in
      --json) as_json=1 ;;
      *) die "usage: mntg status [--json]" ;;
    esac
  done
  result=$(status_result_json)
  if (( PORCELAIN )); then
    emit "BEGIN|status|1"
    repository_migration_emit_porcelain "$(jq -c '.migration' <<<"$result")"
    emit "STATUS|1|$(jq -r '[.attention,(.loadouts.count // ""|tostring),(.repositories.count // ""|tostring)] | join("|")' <<<"$result")"
    emit "DONE|ok|status complete"
  elif (( as_json )); then
    printf '%s\n' "$result"
  else
    repository_migration_print_human "$(jq -c '.migration' <<<"$result")"
    printf '%sMontage%s %s\n\n' "$c_bold" "$c_reset" "$VERSION"
    printf '  attention     %s\n' "$(jq -r '.attention' <<<"$result")"
    if [[ $(jq -r '.loadouts.available' <<<"$result") == true ]]; then
      printf '  loadouts      %s tracked, %s need attention\n' \
        "$(jq -r '.loadouts.count' <<<"$result")" "$(jq -r '.loadouts.attention' <<<"$result")"
    else
      printf '  loadouts      unavailable or invalid\n'
    fi
    if [[ $(jq -r '.repositories.available' <<<"$result") == true ]]; then
      printf '  libraries     %s configured, %s need attention\n' \
        "$(jq -r '.repositories.count' <<<"$result")" "$(jq -r '.repositories.attention' <<<"$result")"
    else
      printf '  libraries     unavailable or invalid\n'
    fi
  fi
}

cmd_set() {
  (( $# > 0 )) || die "usage: mntg set AUR=<ask|yes|no>"
  local pair key value keys=() values=()
  for pair in "$@"; do
    [[ $pair == *=* ]] || die "expected KEY=VALUE, got: $pair"
    key="${pair%%=*}"; value="${pair#*=}"
    key=$(printf '%s' "$key" | tr '[:lower:]-' '[:upper:]_')
    [[ -v CONFIG_DEFAULTS[$key] ]] || die "unknown setting: $key"
    config_validate_value "$key" "$value"
    keys+=("$key"); values+=("$value")
  done

  take_config_lock
  load_config
  local i
  for i in "${!keys[@]}"; do CFG[${keys[$i]}]="${values[$i]}"; done
  save_config
  printf 'Saved to %s\n' "$CONFIG_FILE"
}

cmd_link() {
  local target="$HOME/.local/bin/mntg" source="$SELF_DIR/mntg" action="${1:-install}"
  local target_resolved source_resolved
  mkdir -p "$HOME/.local/bin"

  source_resolved=$(realpath -e -- "$source") || die "cannot resolve the active Montage CLI: $source"
  if [[ -L $target ]]; then
    target_resolved=$(realpath -e -- "$target" 2>/dev/null || true)
  else
    target_resolved=""
  fi

  case "$action" in
    install|"")
      if [[ -e $target || -L $target ]]; then
        [[ -L $target && $target_resolved == "$source_resolved" ]] ||
          die "$target belongs to another program; move it explicitly before linking Montage"
      fi
      ln -sfn -- "$source_resolved" "$target"
      printf 'Linked %s -> %s\n' "$target" "$source_resolved"
      ;;
    --remove|remove|unlink)
      if [[ ! -e $target && ! -L $target ]]; then
        printf 'No Montage link at %s\n' "$target"
        return 0
      fi
      [[ -L $target && $target_resolved == "$source_resolved" ]] ||
        die "$target is not the active Montage link; refusing to remove it"
      rm -- "$target"
      printf 'Removed Montage link %s\n' "$target"
      return 0
      ;;
    *) die "usage: mntg link [--remove]" ;;
  esac
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) printf 'Run: %smntg doctor%s\n' "$c_green" "$c_reset" ;;
    *) printf '%s~/.local/bin is not on your PATH. Add it to ~/.bashrc:%s\n  export PATH="$HOME/.local/bin:$PATH"\n' "$c_yellow" "$c_reset" ;;
  esac
}

doctor_path_parent_writable() {
  local path="$1" kind="${2:-file}"
  if [[ -e $path || -L $path ]]; then
    [[ ! -L $path && -w $path ]] || return 1
    if [[ $kind == directory ]]; then [[ -d $path ]]; else [[ -f $path ]]; fi
    return
  fi
  while [[ ! -e $path ]]; do
    [[ $path != / ]] || return 1
    path=$(dirname "$path")
  done
  [[ -d $path && ! -L $path && -w $path ]]
}

doctor_config_valid() {
  [[ ${CFG[AUR]} == ask || ${CFG[AUR]} == yes || ${CFG[AUR]} == no ]]
}

doctor_repositories_valid() {
  local catalog
  catalog=$(repository_catalog_json) || return 1
  jq -e 'all(.repositories[]; .valid == true)' <<<"$catalog" >/dev/null
}

cmd_doctor() {
  local problems=0
  printf '%smntg doctor%s\n\n' "$c_bold" "$c_reset"
  doctor_check() {
    local label="$1" hint="$2"; shift 2
    if "$@" >/dev/null 2>&1; then
      printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$label"
    else
      printf '  %s✗%s %s%s\n' "$c_red" "$c_reset" "$label" "${hint:+ — $hint}"
      problems=$((problems + 1))
    fi
  }
  doctor_check "git" "" have git
  doctor_check "jq" "" have jq
  doctor_check "curl" "needed for AUR package resolution" have curl
  doctor_check "pacman" "" have pacman
  doctor_check "yay (AUR)" "needed only when an accepted loadout has AUR packages" have yay
  doctor_check "omarchy CLI" "needed for plugin and theme effects" have omarchy
  doctor_check "shell running" "the panel needs omarchy-shell; the CLI does not" omarchy-shell shell ping
  doctor_check "configuration" "run: mntg set AUR=ask" doctor_config_valid
  doctor_check "configuration path" "Montage cannot save settings" doctor_path_parent_writable "$CONFIG_FILE"
  doctor_check "state path" "Montage cannot persist applied loadout state" doctor_path_parent_writable "$STATE_DIR" directory
  doctor_check "loadout libraries" "inspect with: mntg repository list" doctor_repositories_valid
  doctor_check "git identity" "required to publish library changes" git config --global user.email
  doctor_check "mntg on PATH" "run: $SELF_DIR/mntg link" command -v mntg
  printf '\n'
  (( problems == 0 )) && printf '%sReady.%s\n' "$c_green" "$c_reset" ||
    printf '%s%s.%s\n' "$c_yellow" "$(plural "$problems" problem)" "$c_reset"
  return 0
}
