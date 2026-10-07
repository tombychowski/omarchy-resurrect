#!/bin/bash
#
# Loadout definition compatibility and apply/update/repair plan construction.
# Depends on core.sh, profile.sh, registry.sh, and resources.sh. Owns no
# external mutation or persistent representation. Definitions only at source time.

definitions_compatible() {
  local kind="$1" existing="$2" requested="$3"
  if [[ $kind == plugin || $kind == theme-install ]] && [[ -z $(jq -r '.commit // ""' <<<"$requested") ]]; then
    jq -e --argjson other "$requested" 'del(.commit) == ($other | del(.commit))' <<<"$existing" >/dev/null
  else
    jq -e --argjson other "$requested" '. == $other' <<<"$existing" >/dev/null
  fi
}

build_apply_plan() {
  local profile="$1" loadout_id="$2" resources item rid kind definition existing observation
  local action first cleanup claim_status registry_resource requested note existing_channels requested_channels
  local plan_rows=()
  machine_observation_snapshot_build
  resources=$(profile_resources_json "$profile" "$loadout_id")
  while IFS= read -r item; do
    rid=$(jq -r '.id' <<<"$item"); kind=$(jq -r '.kind' <<<"$item")
    definition=$(jq -c '.definition' <<<"$item"); requested=$(jq -c '.requested' <<<"$item")
    existing=$(registry_resource_json "$rid")
    action=""; first="unknown"; cleanup="unknown"; claim_status="pending"; note=""
    if [[ -n $existing ]]; then
      registry_resource="$existing"
      observation=$(resource_inspect_json "$existing")
      if definitions_compatible "$kind" "$(jq -c '.definition' <<<"$existing")" "$definition"; then
        case "$(jq -r '.state' <<<"$observation")" in
          present) action="share"; claim_status="healthy" ;;
          missing) action="defer"; claim_status="pending" ;;
          *) action="conflict"; claim_status="conflicting" ;;
        esac
        if [[ $kind == package ]]; then
          existing_channels=$(jq -c --arg rid "$rid" '[.claims[] | select(.resourceId == $rid) | .requested.channels[]?] | unique' <<<"$REGISTRY")
          requested_channels=$(jq -c '.channels | unique' <<<"$requested")
          [[ $existing_channels == "$requested_channels" ]] ||
            note="package channel differs from an existing claim; package presence is name-based"
        fi
      else
        action="conflict"; claim_status="conflicting"
      fi
      first=$(jq -r '.firstObserved' <<<"$existing")
      cleanup=$(jq -r '.cleanupPolicy' <<<"$existing")
    else
      observation=$(resource_inspect_json "$item")
      case "$(jq -r '.state' <<<"$observation")" in
        present)
          action="protect"; first="present"; cleanup="retain"; claim_status="healthy" ;;
        missing)
          first="absent"; cleanup="remove"; claim_status="pending"
          [[ $kind == theme-active ]] && action="activate" || action="install"
          ;;
        *)
          action="conflict"; first="unknown"; cleanup="unknown"; claim_status="conflicting" ;;
      esac
      registry_resource=$(jq -nc --argjson item "$item" --arg first "$first" --arg cleanup "$cleanup" \
        --argjson observation "$observation" '
        $item | {id,kind,name,definition} + {firstObserved:$first,cleanupPolicy:$cleanup,
          state:$observation.state,evidence:$observation.evidence}')
    fi
    if [[ $action == install && ( $kind == plugin || $kind == theme-install ) ]] &&
      [[ -n $(jq -r '.url // ""' <<<"$definition") && -z $(jq -r '.commit // ""' <<<"$definition") ]] &&
      (( ! ALLOW_UNPINNED )); then
      action="refuse"; claim_status="deferred"
      registry_resource=$(jq -c '.cleanupPolicy = "unknown" | .state = "uncertain"' <<<"$registry_resource")
    fi
    plan_rows+=("$(jq -nc --argjson item "$item" --argjson resource "$registry_resource" \
      --argjson observation "$observation" --arg action "$action" --arg status "$claim_status" \
      --arg note "$note" \
      '{item:$item,resource:$resource,observation:$observation,action:$action,claimStatus:$status,note:$note}')")
  done < <(jq -c '.[]' <<<"$resources")
  printf '%s\n' "${plan_rows[@]}" | jq -sc '.'
}
