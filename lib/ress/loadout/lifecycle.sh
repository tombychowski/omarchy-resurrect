#!/bin/bash
#
# Tracked loadout/resource queries, recovery, drift checking, repair, update,
# and safe removal orchestration.
# Depends on core.sh, safety.sh, registry.sh, profile.sh, and resources.sh. Used
# by loadout and resource commands. Definitions only at source time.

loadout_json_view() {
  local include_content="${1:-0}"
  jq -c --argjson content "$include_content" '
    [.loadouts[] as $l |
      ([.claims[] | select(.loadoutId == $l.id)] | length) as $count |
      ([.claims[] | select(.loadoutId == $l.id and .status != "healthy")] | length) as $attention |
      ($l + {resourceCount:$count, attentionCount:$attention} |
       if $content == 1 then . else del(.profile) end)]
  ' <<<"$REGISTRY"
}

loadout_require() {
  local id="$1"
  [[ -n $(registry_loadout_json "$id") ]] || die "no tracked loadout: $(plain "$id")"
}

loadout_check_json() {
  local wanted="${1:-}" loadout claims claim resource observation rows state attention claim_state cleanup health_state
  local loadout_rows=() resource_rows=()
  machine_observation_snapshot_build
  while IFS= read -r loadout; do
    claims=$(registry_claims_json "$(jq -r '.id' <<<"$loadout")")
    resource_rows=(); attention=0
    while IFS= read -r claim; do
      resource=$(registry_resource_json "$(jq -r '.resourceId' <<<"$claim")")
      observation=$(resource_inspect_json "$resource")
      state=$(jq -r '.state' <<<"$observation")
      claim_state=$(jq -r '.status' <<<"$claim"); cleanup=$(jq -r '.cleanupPolicy' <<<"$resource")
      if [[ $claim_state != healthy ]]; then
        case "$claim_state" in deferred|removal-pending) health_state="pending" ;; *) health_state="$claim_state" ;; esac
      elif [[ $state == present && $cleanup == retain ]]; then health_state="protected"
      else health_state="$state"
      fi
      [[ $health_state == present || $health_state == protected ]] || attention=$((attention + 1))
      resource_rows+=("$(jq -nc --argjson resource "$resource" --argjson claim "$claim" --argjson observation "$observation" \
        --arg health "$health_state" \
        '$resource + {claimStatus:$claim.status,healthState:$health,currentState:$observation.state,currentEvidence:$observation.evidence}')")
    done < <(jq -c '.[]' <<<"$claims")
    rows=$(printf '%s\n' "${resource_rows[@]}" | jq -sc '.')
    loadout_rows+=("$(jq -nc --argjson loadout "$loadout" --argjson resources "$rows" --argjson attention "$attention" \
      '$loadout | del(.profile) | . + {attentionCount:$attention,resources:$resources} |
        if $attention > 0 and .state != "removal-pending" then .state="drifted" else . end')")
  done < <(jq -c --arg id "$wanted" '.loadouts[] | select($id == "" or .id == $id)' <<<"$REGISTRY")
  local loadouts
  loadouts=$(printf '%s\n' "${loadout_rows[@]}" | jq -sc '.')
  jq -nc --argjson loadouts "$loadouts" '{healthy:(all($loadouts[]; .attentionCount == 0)),loadouts:$loadouts}'
}

registry_recover_operation() {
  [[ $(jq -r '.operation == null' <<<"$REGISTRY") == true ]] && return 0
  local kind target action rid resource observation state next
  kind=$(jq -r '.operation.kind' <<<"$REGISTRY")
  target=$(jq -r '.operation.target' <<<"$REGISTRY")
  while IFS= read -r action; do
    [[ $(jq -r '.state' <<<"$action") == running ]] || continue
    rid=$(jq -r '.resourceId' <<<"$action")
    resource=$(jq -c --arg id "$rid" '.resources[] | select(.id == $id)' <<<"$REGISTRY")
    [[ -n $resource ]] || continue
    observation=$(resource_inspect_json "$resource" live); state=$(jq -r '.state' <<<"$observation")
    if [[ $kind == remove ]]; then
      if [[ $state == missing ]]; then
        next=$(jq -c --arg rid "$rid" '.operation.actions |= map(if .resourceId == $rid then .state="done" else . end)' <<<"$REGISTRY")
      elif [[ $state == present ]]; then
        next=$(jq -c --arg rid "$rid" '.operation.actions |= map(if .resourceId == $rid then .state="planned" else . end)' <<<"$REGISTRY")
      else
        next=$(jq -c --arg rid "$rid" --arg target "$target" '
          .operation.actions |= map(if .resourceId == $rid then .state="uncertain" else . end) |
          .claims |= map(if .loadoutId == $target and .resourceId == $rid then .status="uncertain" | .lastError="interrupted removal has ambiguous evidence" else . end)' <<<"$REGISTRY")
      fi
    else
      if [[ $state == present ]]; then
        next=$(jq -c --arg rid "$rid" --arg target "$target" --argjson evidence "$(jq -c '.evidence' <<<"$observation")" '
          .operation.actions |= map(if .resourceId == $rid then .state="done" else . end) |
          .resources |= map(if .id == $rid then .state="present" | .evidence=$evidence else . end) |
          .claims |= map(if .loadoutId == $target and .resourceId == $rid then .status="healthy" | .lastError="" else . end)' <<<"$REGISTRY")
      elif [[ $state == missing ]]; then
        next=$(jq -c --arg rid "$rid" '.operation.actions |= map(if .resourceId == $rid then .state="planned" else . end)' <<<"$REGISTRY")
      else
        next=$(jq -c --arg rid "$rid" --arg target "$target" '
          .operation.actions |= map(if .resourceId == $rid then .state="uncertain" else . end) |
          .claims |= map(if .loadoutId == $target and .resourceId == $rid then .status="uncertain" | .lastError="interrupted action has ambiguous evidence" else . end)' <<<"$REGISTRY")
      fi
    fi
    registry_save "$next"
  done < <(jq -c '.operation.actions[]' <<<"$REGISTRY")
  if jq -e --arg target "$target" '.loadouts[] | select(.id == $target)' <<<"$REGISTRY" >/dev/null; then
    next=$(jq -c --arg target "$target" '
      . as $root | .loadouts |= map(if .id == $target then
        .state=(if any($root.claims[]; .loadoutId == $target and .status == "conflicting") then "conflicting"
          elif any($root.claims[]; .loadoutId == $target and .status != "healthy") then "pending"
          else "healthy" end) else . end)' <<<"$REGISTRY")
    [[ $next == "$REGISTRY" ]] || registry_save "$next"
  fi
  if jq -e '.operation != null and all(.operation.actions[]; .state == "done" or .state == "skipped")' <<<"$REGISTRY" >/dev/null; then
    registry_finish_operation
  fi
  note "reconciled an interrupted $kind operation for $target"
}

repair_loadout() {
  local wanted="${1:-}" check plan='[]' loadout claim resource observation state item actions id
  [[ -z $wanted ]] || loadout_require "$wanted"
  machine_observation_snapshot_build
  while IFS= read -r loadout; do
    id=$(jq -r '.id' <<<"$loadout")
    while IFS= read -r claim; do
      resource=$(jq -c --arg rid "$(jq -r '.resourceId' <<<"$claim")" '.resources[] | select(.id == $rid)' <<<"$REGISTRY")
      observation=$(resource_inspect_json "$resource"); state=$(jq -r '.state' <<<"$observation")
      if [[ $state == missing ]]; then
        item=$(jq -nc --argjson r "$resource" --argjson c "$claim" '$r | {id,kind,name,definition} + {requested:$c.requested}')
        local repair_action="repair"
        if [[ $(jq -r '.kind' <<<"$resource") == plugin || $(jq -r '.kind' <<<"$resource") == theme-install ]] &&
          [[ -n $(jq -r '.definition.url // ""' <<<"$resource") && -z $(jq -r '.definition.commit // ""' <<<"$resource") ]] &&
          (( ! ALLOW_UNPINNED )); then repair_action="defer"; fi
        plan=$(jq -c --arg id "$id" --argjson item "$item" --arg action "$repair_action" \
          '. + [{loadoutId:$id,item:$item,action:$action}]' <<<"$plan")
      fi
    done < <(jq -c --arg id "$id" '.claims[] | select(.loadoutId == $id)' <<<"$REGISTRY")
  done < <(jq -c --arg id "$wanted" '.loadouts[] | select($id == "" or .id == $id)' <<<"$REGISTRY")
  if [[ $(jq 'length' <<<"$plan") == 0 ]]; then
    emit "DONE|ok|no missing loadout resources"
    (( PORCELAIN )) || printf 'No missing loadout resources need repair.\n'
    return 0
  fi
  if (( PORCELAIN )); then
    while IFS= read -r item; do emit "LOG|plan: $(jq -r 'if .action == "repair" then "REINSTALL" else "DEFER" end' <<<"$item") $(jq -r '.item.id' <<<"$item")"; done < <(jq -c '.[]' <<<"$plan")
  else
    printf 'Repair plan:\n'
    jq -r '.[] | "  " + (if .action == "repair" then "REINSTALL" else "DEFER   " end) + "  " + .item.id +
      (if .action == "defer" then " (names no commit; pass --allow-unpinned)" else "" end)' <<<"$plan"
  fi
  if (( DRY_RUN )); then emit "DONE|ok|repair dry run complete"; (( PORCELAIN )) || printf 'Dry run — nothing was changed.\n'; return 0; fi
  if ! jq -e 'any(.[]; .action == "repair")' <<<"$plan" >/dev/null; then
    emit "DONE|partial|no safely pinned resources can be repaired"
    (( PORCELAIN )) || printf 'No safely pinned resources can be repaired in this run.\n'
    return 1
  fi
  confirm "Repair these loadout resources?" || die "cancelled"
  actions=$(jq -c '[.[] | {resourceId:.item.id,state:"planned"}]' <<<"$plan")
  # Repairing more than one loadout is intentionally performed as one target at
  # a time so every journal target remains a valid loadout identity.
  while IFS= read -r id; do
    local scoped native=() aur=() entry pkg rid result observation evidence
    scoped=$(jq -c --arg id "$id" '[.[] | select(.loadoutId == $id and .action == "repair")]' <<<"$plan")
    [[ $(jq 'length' <<<"$scoped") -gt 0 ]] || continue
    registry_begin_operation repair "$id" "$(jq -c '[.[] | {resourceId:.item.id,state:"planned"}]' <<<"$scoped")"
    while IFS= read -r entry; do
      [[ $(jq -r '.item.kind' <<<"$entry") == package ]] || continue
      pkg=$(jq -r '.item.name' <<<"$entry")
      if jq -e '.item.requested.channels | index("native")' <<<"$entry" >/dev/null; then native+=("$pkg"); else aur+=("$pkg"); fi
    done < <(jq -c 'sort_by(if .item.kind == "theme-active" then 1 else 0 end)[]' <<<"$scoped")
    if (( ${#native[@]} )); then
      sudo pacman -S --needed --noconfirm -- "${native[@]}" >/dev/null 2>&1 || true
    fi
    if (( ${#aur[@]} )); then
      aur_gate repair "${aur[@]}"
      [[ $AUR_MODE == skip ]] || { have yay && aur_install repair "${AUR_KEPT[@]}"; } || true
    fi
    while IFS= read -r entry; do
      rid=$(jq -r '.item.id' <<<"$entry")
      if [[ $(jq -r '.item.kind' <<<"$entry") != package ]]; then
        apply_one_resource "$id" "$(jq -c '.item' <<<"$entry")" repair
        continue
      fi
      observation=$(resource_inspect_json "$(jq -c --arg rid "$rid" '.resources[] | select(.id == $rid)' <<<"$REGISTRY")" live)
      evidence=$(jq -c '.evidence' <<<"$observation")
      if [[ $(jq -r '.state' <<<"$observation") == present ]]; then
        registry_set_claim_result "$id" "$rid" healthy present "$evidence"
      else
        registry_set_claim_result "$id" "$rid" pending missing "$evidence" "package remains missing"
      fi
    done < <(jq -c 'sort_by(if .item.kind == "theme-active" then 1 else 0 end)[]' <<<"$scoped")
    registry_finish_operation
  done < <(jq -r '.[].loadoutId' <<<"$plan" | sort -u)
  machine_observation_snapshot_reset
  check=$(loadout_check_json "$wanted")
  if [[ $(jq -r '.healthy' <<<"$check") == true ]]; then emit "DONE|ok|repair complete"; return 0; fi
  emit "DONE|partial|repair finished with unresolved resources"
  return 1
}

remove_loadout() {
  local id="$1" decision="${2:-}" claim rid resource observation state cleanup others classification plan='[]' actions next failures=0 rc
  loadout_require "$id"
  machine_observation_snapshot_build
  while IFS= read -r claim; do
    rid=$(jq -r '.resourceId' <<<"$claim")
    resource=$(jq -c --arg rid "$rid" '.resources[] | select(.id == $rid)' <<<"$REGISTRY")
    observation=$(resource_inspect_json "$resource"); state=$(jq -r '.state' <<<"$observation")
    cleanup=$(jq -r '.cleanupPolicy' <<<"$resource")
    others=$(jq --arg id "$id" --arg rid "$rid" '[.claims[] | select(.resourceId == $rid and .loadoutId != $id)] | length' <<<"$REGISTRY")
    if (( others > 0 )); then classification="release-only"
    elif [[ $cleanup == retain ]]; then classification="retain"
    elif [[ $state == missing ]]; then classification="already-absent"
    elif [[ $(jq -r '.kind' <<<"$resource") == package ]] && critical_package "$(jq -r '.name' <<<"$resource")"; then classification="protected"
    elif [[ $state == present && $cleanup == remove ]]; then classification="delete"
    else classification="decision-required"; fi
    plan=$(jq -c --argjson resource "$resource" --arg state "$state" --arg classification "$classification" \
      '. + [{resource:$resource,currentState:$state,classification:$classification}]' <<<"$plan")
  done < <(jq -c --arg id "$id" '.claims[] | select(.loadoutId == $id)' <<<"$REGISTRY")
  if (( PORCELAIN )); then
    while IFS= read -r item; do emit "LOG|plan: $(jq -r '.classification|ascii_upcase' <<<"$item") $(jq -r '.resource.id' <<<"$item") ($(jq -r '.currentState' <<<"$item"))"; done < <(jq -c '.[]' <<<"$plan")
  else
    printf 'Remove loadout %s:\n' "$id"
    jq -r '.[] | "  " + (.classification|ascii_upcase) + "  " + .resource.id + " (" + .currentState + ")"' <<<"$plan"
  fi
  if jq -e 'any(.[]; .classification == "decision-required")' <<<"$plan" >/dev/null && [[ -z $decision ]]; then
    emit "DONE|partial|changed resources need an explicit keep or remove decision"
    (( PORCELAIN )) || printf 'Changed or unverifiable resources need an explicit --keep-modified or --remove-modified decision.\n'
    return 2
  fi
  if (( DRY_RUN )); then emit "DONE|ok|remove dry run complete"; (( PORCELAIN )) || printf 'Dry run — nothing was changed.\n'; return 0; fi
  confirm "Remove this loadout and the eligible resources above?" || die "cancelled"
  actions=$(jq -c '[.[] | {resourceId:.resource.id,state:"planned"}]' <<<"$plan")
  next=$(jq -c --arg id "$id" '.loadouts |= map(if .id == $id then .state="removal-pending" else . end) |
    .claims |= map(if .loadoutId == $id then .status="removal-pending" else . end)' <<<"$REGISTRY")
  registry_save "$next"
  registry_begin_operation remove "$id" "$actions"
  while IFS= read -r rid; do
    registry_action_state "$rid" running
    rc=0; release_claim "$id" "$rid" "$decision" || rc=$?
    if (( rc != 0 )); then
      failures=$((failures + 1))
      next=$(jq -c --arg id "$id" --arg rid "$rid" --arg msg "cleanup refused or failed (code $rc)" '
        .claims |= map(if .loadoutId == $id and .resourceId == $rid then .status="removal-pending" | .lastError=$msg else . end) |
        .operation.actions |= map(if .resourceId == $rid then .state=(if $msg|contains("code 4") then "uncertain" else "failed" end) else . end)' <<<"$REGISTRY")
      registry_save "$next"
    fi
  done < <(jq -r '.[].resource.id' <<<"$plan")
  if (( failures == 0 )) && ! jq -e --arg id "$id" '.claims[] | select(.loadoutId == $id)' <<<"$REGISTRY" >/dev/null; then
    next=$(jq -c --arg id "$id" '.loadouts |= map(select(.id != $id)) | .operation=null' <<<"$REGISTRY")
    registry_save "$next"
    emit "DONE|ok|loadout removed"
    (( PORCELAIN )) || printf 'Loadout %s removed from tracking.\n' "$id"
    return 0
  fi
  emit "DONE|partial|loadout remains removal-pending"
  (( PORCELAIN )) || printf 'Loadout %s remains removal-pending; rerun after resolving the reported resources.\n' "$id"
  return 1
}

update_loadout() {
  local id="$1" source="${2:-}" decision="${3:-}" old new_profile digest new_resources old_ids new_ids retained added withdrawn plan='[]'
  local rid item resource definition observation action status next now precedence failures=0 rc
  loadout_require "$id"
  old=$(jq -c --arg id "$id" '.loadouts[] | select(.id == $id)' <<<"$REGISTRY")
  [[ -n $source ]] || source=$(jq -r '.source' <<<"$old")
  [[ -n $source ]] || die "this loadout has no reusable source; pass SOURCE"
  source=$(normalize_source "$source")
  ress_make_temp_dir || die "could not create update workspace"
  APPLY_WORK="$RESS_TEMP_PATH"
  fetch_profile "$source" "$APPLY_WORK"
  new_profile="$APPLY_WORK/normalized.json"
  normalize_profile "$APPLY_WORK/profile.json" "$new_profile"
  digest=$(profile_digest "$new_profile")
  if [[ $digest == "$(jq -r '.digest' <<<"$old")" ]]; then
    emit "LOG|profile unchanged; checking for repair"
    (( PORCELAIN )) || printf 'The fetched profile is unchanged; checking for repair instead.\n'
    repair_loadout "$id"
    return $?
  fi
  new_resources=$(profile_resources_json "$new_profile" "$id")
  old_ids=$(jq -c --arg id "$id" '[.claims[] | select(.loadoutId == $id) | .resourceId]' <<<"$REGISTRY")
  new_ids=$(jq -c '[.[].id]' <<<"$new_resources")
  retained=$(jq -nc --argjson old "$old_ids" --argjson new "$new_ids" '$old - ($old - $new)')
  added=$(jq -nc --argjson old "$old_ids" --argjson new "$new_ids" '$new - $old')
  withdrawn=$(jq -nc --argjson old "$old_ids" --argjson new "$new_ids" '$old - $new')
  if (( PORCELAIN )); then
    while IFS= read -r rid; do emit "LOG|plan: RETAIN $rid"; done < <(jq -r '.[]' <<<"$retained")
    while IFS= read -r rid; do emit "LOG|plan: ADD $rid"; done < <(jq -r '.[]' <<<"$added")
    while IFS= read -r rid; do emit "LOG|plan: WITHDRAW $rid"; done < <(jq -r '.[]' <<<"$withdrawn")
  else
    printf 'Update loadout %s:\n' "$id"
    jq -r '.[] | "  RETAIN    " + .' <<<"$retained"
    jq -r '.[] | "  ADD       " + .' <<<"$added"
    jq -r '.[] | "  WITHDRAW  " + .' <<<"$withdrawn"
  fi
  # Build the complete new claim plan so definition conflicts are reviewed too.
  plan=$(build_apply_plan "$new_profile" "$id")
  if (( PORCELAIN )); then
    while IFS= read -r rid; do emit "LOG|plan: CONFLICT $rid"; done < <(jq -r '.[] | select(.action == "conflict") | .item.id' <<<"$plan")
  else jq -r '.[] | select(.action == "conflict") | "  CONFLICT  " + .item.id' <<<"$plan"; fi
  if (( DRY_RUN )); then emit "DONE|ok|update dry run complete"; (( PORCELAIN )) || printf 'Dry run — nothing was changed.\n'; return 0; fi
  confirm "Update this tracked loadout?" || die "cancelled"

  registry_begin_operation update "$id" "$(jq -nc --argjson old "$withdrawn" --argjson plan "$plan" '
    ([$old[] | {resourceId:.,state:"planned"}] +
     [$plan[] | select(.action == "install" or .action == "activate") | {resourceId:.item.id,state:"planned"}])')"
  while IFS= read -r rid; do
    registry_action_state "$rid" running
    rc=0; release_claim "$id" "$rid" "$decision" || rc=$?
    if (( rc != 0 )); then failures=$((failures + 1)); fi
  done < <(jq -r '.[]' <<<"$withdrawn")
  if (( failures > 0 )); then
    emit "DONE|partial|withdrawn resources could not be resolved"
    (( PORCELAIN )) || printf 'Update is pending because withdrawn resources could not be resolved.\n'
    return 1
  fi

  now=$(date -u +%s)
  precedence=$(jq '[.loadouts[].precedence] | max // 0 | . + 1' <<<"$REGISTRY")
  next=$(jq -c --arg id "$id" --arg source "$(strip_credentials "$source")" --arg digest "$digest" \
    --argjson profile "$(<"$new_profile")" --argjson plan "$plan" --argjson now "$now" --argjson precedence "$precedence" '
    .loadouts |= map(if .id == $id then
      .name=$profile.name | .author=$profile.author | .description=$profile.description |
      .source=$source | .digest=$digest | .profile=$profile | .updatedAt=$now |
      .precedence=$precedence | .state="pending" else . end) |
    reduce $plan[] as $p (.;
      if any(.resources[]; .id == $p.resource.id) then . else .resources += [$p.resource] end |
      if any(.claims[]; .loadoutId == $id and .resourceId == $p.resource.id) then
        .claims |= map(if .loadoutId == $id and .resourceId == $p.resource.id then
          .requested=($p.item.definition + $p.item.requested) | .status=$p.claimStatus |
          .lastError=(if $p.claimStatus == "conflicting" then "incompatible resource definition" else "" end)
          else . end)
      else .claims += [{loadoutId:$id,resourceId:$p.resource.id,
        requested:($p.item.definition + $p.item.requested),status:$p.claimStatus,
        lastError:(if $p.claimStatus == "conflicting" then "incompatible resource definition" else "" end)}] end) |
    .operation=null
  ' <<<"$REGISTRY")
  registry_save "$next"
  ASSUME_YES=1
  repair_loadout "$id" || true
  local check; check=$(loadout_check_json "$id")
  if [[ $(jq -r '.healthy' <<<"$check") == true ]]; then
    emit "DONE|ok|loadout updated"
    (( PORCELAIN )) || printf 'Loadout %s updated.\n' "$id"
    return 0
  fi
  emit "DONE|partial|loadout updated with resources that need attention"
  (( PORCELAIN )) || printf 'Loadout %s updated with resources that still need attention.\n' "$id"
  return 1
}

cmd_loadout_mutation() {
  local sub="$1"; shift
  case "$sub" in
    check)
      local id="" as_json=0 result
      while (( $# )); do case "$1" in --json) as_json=1;; *) [[ -z $id ]] || die "usage: ress loadout check [ID] [--json]"; id="$1";; esac; shift; done
      registry_load
      [[ -z $id ]] || loadout_require "$id"
      result=$(loadout_check_json "$id")
      if (( as_json )); then jq . <<<"$result"
      else
        if [[ $(jq '.loadouts|length' <<<"$result") == 0 ]]; then printf 'No loadouts are tracked on this machine.\n'
        else jq -r '.loadouts[] | .name + " [" + .id + "]: " + (if .attentionCount == 0 then "healthy" else (.attentionCount|tostring) + " resources need attention" end), (.resources[] | "  " + .currentState + "  " + .id)' <<<"$result"; fi
      fi
      [[ $(jq -r '.healthy' <<<"$result") == true ]]
      ;;
    repair)
      local id="${1:-}"; [[ $# -le 1 ]] || die "usage: ress loadout repair [ID]"
      ensure_operation_lock; registry_load; registry_recover_operation
      repair_loadout "$id"
      ;;
    remove)
      local id="${1:-}" decision=""; [[ -n $id ]] || die "usage: ress loadout remove ID [--keep-modified|--remove-modified]"; shift || true
      while (( $# )); do case "$1" in --keep-modified) decision=keep;; --remove-modified) decision=remove;; *) die "unknown loadout remove option: $1";; esac; shift; done
      ensure_operation_lock; registry_load; registry_recover_operation
      remove_loadout "$id" "$decision"
      ;;
    update)
      local id="${1:-}" source="" decision=""; [[ -n $id ]] || die "usage: ress loadout update ID [SOURCE] [--keep-modified|--remove-modified]"; shift || true
      while (( $# )); do
        case "$1" in
          --keep-modified) decision=keep ;;
          --remove-modified) decision=remove ;;
          *) [[ -z $source ]] || die "usage: ress loadout update ID [SOURCE] [--keep-modified|--remove-modified]"; source="$1" ;;
        esac
        shift
      done
      ensure_operation_lock; registry_load; registry_recover_operation
      update_loadout "$id" "$source" "$decision"
      ;;
  esac
}

cmd_loadout() {
  local sub="${1:-list}"; shift || true
  case "$sub" in
    list)
      local as_json=0 details=0 contents=0
      while (( $# )); do
        case "$1" in --json) as_json=1;; --details) details=1;; --contents) contents=1;; *) die "unknown loadout list option: $1";; esac
        shift
      done
      registry_load
      local view; view=$(loadout_json_view "$contents")
      if (( as_json )); then jq -n --argjson loadouts "$view" '{loadouts:$loadouts}'; return; fi
      if [[ $(jq 'length' <<<"$view") == 0 ]]; then printf 'No loadouts are tracked on this machine.\n'; return; fi
      jq -r --argjson details "$details" '.[] |
        (.id + "\t" + .state + "\t" + (.resourceCount|tostring) + " resources" +
         (if .attentionCount > 0 then ", " + (.attentionCount|tostring) + " need attention" else "" end) +
         (if $details == 1 then "\t" + .name + " by " + .author else "" end))' <<<"$view" |
        column -t -s $'\t'
      ;;
    show)
      local id="${1:-}" as_json=0 contents=0; [[ -n $id ]] || die "usage: ress loadout show <id> [--json] [--contents]"; shift || true
      while (( $# )); do case "$1" in --json) as_json=1;; --contents) contents=1;; *) die "unknown loadout show option: $1";; esac; shift; done
      registry_load
      local result
      result=$(jq -c --arg id "$id" --argjson content "$contents" '
        . as $root | $root.loadouts[] | select(.id == $id) as $l |
        [$l, ([$root.claims[] | select(.loadoutId == $id)]),
         ([$root.resources[] as $r | select(any($root.claims[]; .loadoutId == $id and .resourceId == $r.id)) | $r])] |
        {loadout:(.[0] + {resourceCount:(.[1]|length),attentionCount:([.[1][]|select(.status != "healthy")]|length)} |
          if $content == 1 then . else del(.profile) end), claims:.[1], resources:.[2]}
      ' <<<"$REGISTRY")
      [[ -n $result ]] || die "no tracked loadout: $(plain "$id")"
      (( as_json )) && { jq . <<<"$result"; return; }
      jq -r '.loadout | "\(.name) [\(.id)]\nstate: \(.state)\nsource: \(.source)\nresources: \(.resourceCount // 0)"' <<<"$result"
      (( contents )) && jq '.loadout.profile' <<<"$result"
      ;;
    check|repair|remove|update) cmd_loadout_mutation "$sub" "$@" ;;
    *) die "unknown loadout command: $(plain "$sub")" ;;
  esac
}

cmd_resource() {
  local sub="${1:-list}"; shift || true
  registry_load
  case "$sub" in
    list)
      local as_json=0 wanted=""
      while (( $# )); do case "$1" in --json) as_json=1;; --state) wanted="${2:-}"; shift;; *) die "unknown resource list option: $1";; esac; shift; done
      local result; result=$(jq -c --arg state "$wanted" '[.resources[] | select($state == "" or .state == $state)]' <<<"$REGISTRY")
      (( as_json )) && { jq -n --argjson resources "$result" '{resources:$resources}'; return; }
      jq -r '.[] | [.id,.state,.cleanupPolicy] | @tsv' <<<"$result" | column -t -s $'\t'
      ;;
    show)
      local id="${1:-}" as_json=0; [[ -n $id ]] || die "usage: ress resource show <kind:name> [--json]"; shift || true
      [[ ${1:-} == --json ]] && as_json=1
      local result; result=$(jq -c --arg id "$id" '
        . as $root | $root.resources[] | select(.id == $id) as $r |
        $r + {claimants:[$root.claims[] | select(.resourceId == $id) | .loadoutId]}
      ' <<<"$REGISTRY")
      [[ -n $result ]] || die "no tracked resource: $(plain "$id")"
      (( as_json )) && { jq . <<<"$result"; return; }
      jq -r '"\(.id)\nstate: \(.state)\norigin: \(if .firstObserved == "absent" then "installed by ress" elif .firstObserved == "present" then "already present" else "unknown" end)\ncleanup: \(.cleanupPolicy)\nloadouts: \(.claimants | join(", "))"' <<<"$result"
      ;;
    *) die "unknown resource command: $(plain "$sub")" ;;
  esac
}
