#!/bin/bash
#
# Loadout application orchestration.
# Depends on core.sh, safety.sh, machine/packages.sh, registry.sh, profile.sh,
# resources.sh, and planning.sh. Used
# by apply. Definitions only at source time.

cmd_apply() {
  local source="${1:-}"
  [[ -n $source ]] || die "usage: ress apply <ress.sh/gh/user/repo | git-url | profile.json>"
  source=$(normalize_source "$source"); shift || true
  while (( $# )); do case "$1" in --restart) shift;; *) die "unknown apply option: $1";; esac; done

  ress_make_temp_dir || die "could not create apply workspace"
  APPLY_WORK="$RESS_TEMP_PATH"
  step_start apply "Fetching the loadout"
  fetch_profile "$source" "$APPLY_WORK"
  local profile="$APPLY_WORK/normalized.json"
  normalize_profile "$APPLY_WORK/profile.json" "$profile"
  take_lock
  (( NORMALIZE_REFUSED_PACKAGES == 0 )) ||
    step_warn apply "refused $NORMALIZE_REFUSED_PACKAGES unsafe package names from this loadout"
  (( NORMALIZE_REFUSED_INTEGRATIONS == 0 )) ||
    step_warn apply "refused $NORMALIZE_REFUSED_INTEGRATIONS unsafe integration entries from this loadout"
  registry_load
  local digest id existing_id same_source plan name author
  digest=$(profile_digest "$profile")
  existing_id=$(jq -r --arg digest "$digest" '.loadouts[] | select(.digest == $digest) | .id' <<<"$REGISTRY" | head -1)
  source=$(strip_credentials "$source")
  if [[ -n $existing_id ]]; then
    step_ok apply "already tracked as $existing_id"
    if (( DRY_RUN )); then emit "DONE|ok|exact loadout dry run complete"; (( PORCELAIN )) || printf '\n%sDry run — nothing was changed.%s\n' "$c_dim" "$c_reset"; return 0; fi
    cmd_loadout_mutation repair "$existing_id"
    return $?
  fi
  same_source=$(jq -r --arg source "$source" '.loadouts[] | select(.source == $source) | .id' <<<"$REGISTRY" | head -1)
  [[ -z $same_source ]] || die "this source has changed since $same_source was applied — use: ress loadout update $same_source $(printf '%q' "$source")"
  name=$(jq -r '.name' "$profile"); author=$(jq -r '.author' "$profile")
  id=$(loadout_local_id "$name" "$digest")
  plan=$(build_apply_plan "$profile" "$id")
  step_ok apply "$name by $author (local id: $id)"

  local preview_native preview_aur
  preview_native=$(jq '[.[] | select(.action == "install" and .item.kind == "package" and (.item.requested.channels | index("native")))] | length' <<<"$plan")
  preview_aur=$(jq '[.[] | select(.action == "install" and .item.kind == "package" and ((.item.requested.channels | index("native")) == null))] | length' <<<"$plan")
  if (( PORCELAIN )); then
    while IFS= read -r entry; do emit "LOG|plan: $(jq -r '.action|ascii_upcase' <<<"$entry") $(jq -r '.item.id' <<<"$entry")$(jq -r 'if .note == "" then "" else " (" + .note + ")" end' <<<"$entry")"; done < <(jq -c '.[]' <<<"$plan")
  else
    printf '\n%sThis will install or track:%s\n\n' "$c_bold" "$c_reset"
    (( preview_native == 0 )) || printf '  %s%s from the Arch repos%s\n' "$c_green" "$(plural "$preview_native" package)" "$c_reset"
    (( preview_aur == 0 )) || printf '  %s%s from the AUR%s %s(built here from a PKGBUILD; asked about separately)%s\n' \
      "$c_yellow" "$(plural "$preview_aur" package)" "$c_reset" "$c_dim" "$c_reset"
    jq -r '.[] | "  " + (.action | ascii_upcase) + "  " + .item.id +
      (if .action == "protect" then " (already present; will be retained)"
       elif .action == "share" then " (shared with another loadout)"
       elif .action == "conflict" then " (requires resolution)"
       elif .action == "refuse" then " (names no commit; pass --allow-unpinned to install)"
       elif .action == "defer" then " (currently missing; repair separately)" else "" end) +
      (if .note != "" then " (" + .note + ")" else "" end)' <<<"$plan"
    printf '\n%sThis will not:%s touch dotfiles, run profile scripts, or remove unrelated state.\n\n' "$c_bold" "$c_reset"
  fi
  if (( DRY_RUN )); then
    emit "DONE|ok|apply dry run complete"
    (( PORCELAIN )) || printf '%sDry run — nothing was installed. Nothing was tracked.%s\n' "$c_dim" "$c_reset"
    return 0
  fi
  confirm "Apply and track this loadout?" || die "cancelled"

  registry_register_apply_plan "$id" "$source" "$digest" "$profile" "$plan"

  local native=() aur=() entry rid pkg observation evidence
  while IFS= read -r entry; do
    [[ $(jq -r '.action' <<<"$entry") == install && $(jq -r '.item.kind' <<<"$entry") == package ]] || continue
    pkg=$(jq -r '.item.name' <<<"$entry")
    if jq -e '.item.requested.channels | index("native")' <<<"$entry" >/dev/null; then native+=("$pkg"); else aur+=("$pkg"); fi
  done < <(jq -c 'sort_by(if .item.kind == "theme-active" then 1 else 0 end)[]' <<<"$plan")

  if (( ${#native[@]} )); then
    for pkg in "${native[@]}"; do registry_action_state "package:$pkg" running; done
    if sudo pacman -S --needed --noconfirm -- "${native[@]}"; then
      for pkg in "${native[@]}"; do
        observation=$(resource_inspect_json "$(jq -c --arg id "package:$pkg" '.resources[] | select(.id == $id)' <<<"$REGISTRY")" live)
        evidence=$(jq -c '.evidence' <<<"$observation")
        registry_set_claim_result "$id" "package:$pkg" healthy present "$evidence"
      done
      step_ok apply "repo packages installed"
    else
      for pkg in "${native[@]}"; do
        observation=$(resource_inspect_json "$(jq -c --arg id "package:$pkg" '.resources[] | select(.id == $id)' <<<"$REGISTRY")" live)
        if [[ $(jq -r '.state' <<<"$observation") == present ]]; then
          registry_set_claim_result "$id" "package:$pkg" healthy present "$(jq -c '.evidence' <<<"$observation")"
        else registry_set_claim_result "$id" "package:$pkg" failed missing '{}' "package install failed"; fi
      done
      step_warn apply "some repo packages failed"
    fi
  fi

  if (( ${#aur[@]} )); then
    aur_gate apply "${aur[@]}"
    if [[ $AUR_MODE != skip ]] && have yay && aur_install apply "${AUR_KEPT[@]}"; then
      for pkg in "${aur[@]}"; do
        observation=$(resource_inspect_json "$(jq -c --arg id "package:$pkg" '.resources[] | select(.id == $id)' <<<"$REGISTRY")" live)
        if [[ $(jq -r '.state' <<<"$observation") == present ]]; then
          registry_set_claim_result "$id" "package:$pkg" healthy present "$(jq -c '.evidence' <<<"$observation")"
        else registry_set_claim_result "$id" "package:$pkg" failed missing '{}' "AUR package was not installed"; fi
      done
    else
      for pkg in "${aur[@]}"; do registry_set_claim_result "$id" "package:$pkg" deferred missing '{}' "AUR build left for later"; done
    fi
  fi

  while IFS= read -r entry; do
    case "$(jq -r '.action' <<<"$entry")" in
      install|activate)
        [[ $(jq -r '.item.kind' <<<"$entry") == package ]] || apply_one_resource "$id" "$(jq -c '.item' <<<"$entry")"
        ;;
    esac
  done < <(jq -c 'sort_by(if .item.kind == "theme-active" then 1 else 0 end)[]' <<<"$plan")

  registry_finish_operation
  local final; final=$(jq -r --arg id "$id" '.loadouts[] | select(.id == $id) | .state' <<<"$REGISTRY")
  if [[ $final == healthy ]]; then
    emit "DONE|ok|apply complete"
    (( PORCELAIN )) || printf '\n%sLoadout applied and tracked as %s.%s\n' "$c_bold" "$id" "$c_reset"
    return 0
  fi
  emit "DONE|partial|apply finished with unresolved resources"
  (( PORCELAIN )) || printf '\n%sLoadout tracked as %s with state: %s.%s Run: ress loadout check %s\n' "$c_yellow" "$id" "$final" "$c_reset" "$id"
  return 1
}
