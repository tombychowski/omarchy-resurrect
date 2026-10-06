#!/bin/bash
#
# Loadout application: legacy compatibility, planning, claim registration and
# outcomes, guarded resource application, and apply orchestration.
# Depends on core.sh, safety.sh, registry.sh, profile.sh, and resources.sh. Used
# by apply. Definitions only at source time.

cmd_apply_legacy() {
  local source="${1:-}"
  [[ -n $source ]] || die "usage: ress apply <ress.sh/gh/user/repo | git-url | profile.json>"
  source=$(normalize_source "$source")
  shift || true
  while (( $# > 0 )); do
    case "$1" in
      --restart) shift ;;
      *) die "unknown apply option: $1" ;;
    esac
  done

  APPLY_WORK=$(mktemp -d)
  local work="$APPLY_WORK"
  step_start apply "Fetching the loadout"
  fetch_profile "$source" "$work"
  local profile="$work/profile.json"

  local name author created
  # A loadout picks its own name, author and description. They are shown right
  # above a confirmation prompt that leads to sudo, so they are stripped of
  # anything that could redraw the screen.
  name=$(plain "$(jq -r '.name // "Untitled"' "$profile")")
  author=$(plain "$(jq -r '.author // "unknown"' "$profile")")
  created=$(plain "$(jq -r '.createdAt // "?"' "$profile")")
  step_ok apply "$name by $author ($created)"

  # ------------------------------------------------------------- the preview
  #
  # Everything below is computed and shown before anything is installed. This
  # is the whole safety story: you see the exact list, and nothing outside the
  # list can happen, because apply only knows four verbs.

  local installed; installed=$(mktemp); pacman -Qq | sort >"$installed"
  local want_native want_aur missing_native missing_aur
  # Filtering through the shared helper rather than a `while read` inside a
  # pipeline: that construct exits non-zero whenever the *last* entry is
  # rejected, and with pipefail + set -e that aborted the whole run before the
  # preview — the exact input this is meant to survive.
  keep_valid valid_pkg apply "package names" <<<"$(jq -r '.packages.native[]? // empty' "$profile")"
  want_native=$(printf '%s\n' "${KEPT[@]:-}" | grep -v '^$' | sort -u || true)
  keep_valid valid_pkg apply "package names" <<<"$(jq -r '.packages.aur[]? // empty' "$profile")"
  want_aur=$(printf '%s\n' "${KEPT[@]:-}" | grep -v '^$' | sort -u || true)
  missing_native=$(comm -23 <(printf '%s\n' "$want_native" | grep -v '^$' || true) "$installed" || true)
  missing_aur=$(comm -23 <(printf '%s\n' "$want_aur" | grep -v '^$' || true) "$installed" || true)
  rm -f "$installed"

  local n_native n_aur
  n_native=$(printf '%s' "$missing_native" | grep -c . || true)
  n_aur=$(printf '%s' "$missing_aur" | grep -c . || true)

  local plugin_rows=() webapp_rows=() theme_name theme_url
  local id url label sha
  while IFS=$'\t' read -r id url sha; do
    [[ -n $id ]] || continue
    valid_id "$id" && valid_https "$url" || continue
    [[ -d $HOME/.config/omarchy/plugins/$id ]] && continue
    # A loadout points at someone else's repo. Installing its branch head means
    # running whatever they push next, not what they shared.
    if ! valid_sha "$sha"; then
      if (( ALLOW_UNPINNED )); then sha=""
      else step_warn apply "$id names no commit — skipped (pass --allow-unpinned to take the branch head)"; continue; fi
    fi
    plugin_rows+=("$id"$'\t'"$url"$'\t'"$sha")
  done < <(jq -r '.plugins[]? | [.id, .url, (.commit // "")] | @tsv' "$profile")

  while IFS=$'\t' read -r label url id; do
    [[ -n $label ]] || continue
    valid_label "$label" && valid_https "$url" || continue
    valid_icon "$id" || id=""
    [[ -f $HOME/.local/share/applications/$label.desktop ]] && continue
    webapp_rows+=("$label"$'\t'"$url"$'\t'"$id")
  done < <(jq -r '.webapps[]? | [.name, .url, (.icon // "")] | @tsv' "$profile")

  theme_name=$(jq -r '.theme.name // ""' "$profile"); valid_theme "$theme_name" || theme_name=""
  theme_url=$(jq -r '.theme.url // ""' "$profile");   valid_https "$theme_url"  || theme_url=""
  local theme_sha; theme_sha=$(jq -r '.theme.commit // ""' "$profile"); valid_sha "$theme_sha" || theme_sha=""

  local current_theme=""
  current_theme=$(active_theme_name || true)
  [[ $theme_name == "$current_theme" ]] && theme_name=""

  # A theme repo is code the shell sources on every reload, so the pin rule that
  # covers plugins covers it too: with no commit to agree to there is nothing to
  # clone, and all that is left is setting a theme that may already be here.
  local theme_clone=0
  if [[ -n $theme_name && -n $theme_url && ! -d $HOME/.config/omarchy/themes/$theme_name ]]; then
    if [[ -n $theme_sha ]] || (( ALLOW_UNPINNED )); then
      theme_clone=1
    else
      step_warn apply "theme $theme_name names no commit — it will not be cloned (pass --allow-unpinned to take the branch head)"
      theme_url=""
    fi
  fi

  local total=$(( n_native + n_aur + ${#plugin_rows[@]} + ${#webapp_rows[@]} ))
  if (( total == 0 )) && [[ -z $theme_name ]]; then
    printf '\n%s%s%s — by %s\n\n' "$c_bold" "$name" "$c_reset" "$author"
    printf '%sYou already have everything in this loadout.%s\n' "$c_green" "$c_reset"
    return 0
  fi

  printf '\n%s%s%s — by %s\n' "$c_bold" "$name" "$c_reset" "$author"
  printf '%s%s%s\n\n' "$c_dim" "$(plain "$(jq -r '.description // ""' "$profile")")" "$c_reset"

  printf '%sThis will install:%s\n\n' "$c_bold" "$c_reset"
  if (( n_native > 0 )); then
    printf '  %s%s from the Arch repos%s\n' "$c_green" "$(plural "$n_native" package)" "$c_reset"
    printf '%s\n' "$missing_native" | fmt -w 76 | sed 's/^/      /'
  fi
  if (( n_aur > 0 )); then
    printf '  %s%s from the AUR%s %s(built here from a PKGBUILD; asked about separately)%s\n' \
      "$c_yellow" "$(plural "$n_aur" package)" "$c_reset" "$c_dim" "$c_reset"
    printf '%s\n' "$missing_aur" | fmt -w 76 | sed 's/^/      /'
  fi
  if (( ${#plugin_rows[@]} > 0 )); then
    printf '  %s%s%s\n' "$c_green" "$(plural "${#plugin_rows[@]}" "shell plugin")" "$c_reset"
    printf '%s\n' "${plugin_rows[@]}" | awk -F'\t' '{printf "      %-32s %s\n", $1, $2}'
  fi
  if (( ${#webapp_rows[@]} > 0 )); then
    printf '  %s%s%s\n' "$c_green" "$(plural "${#webapp_rows[@]}" "web app")" "$c_reset"
    printf '%s\n' "${webapp_rows[@]}" | awk -F'\t' '{printf "      %-32s %s\n", $1, $2}'
  fi
  if (( theme_clone )); then
    printf '  %stheme%s %s %s%s%s\n' "$c_green" "$c_reset" "$theme_name" "$c_dim" "$theme_url" "$c_reset"
  elif [[ -n $theme_name ]]; then
    printf '  %stheme%s %s %s(set only; nothing is cloned)%s\n' \
      "$c_green" "$c_reset" "$theme_name" "$c_dim" "$c_reset"
  fi

  printf '\n%sThis will not:%s remove anything, touch your dotfiles, run any script\n' "$c_bold" "$c_reset"
  printf '  from the profile, or read anything outside the four actions above.\n\n'

  if (( DRY_RUN )); then
    printf '%sDry run — nothing was installed.%s\n' "$c_dim" "$c_reset"
    return 0
  fi
  confirm "Apply this loadout?" || die "cancelled"

  # ------------------------------------------------------------- the actions

  local apply_native=() apply_aur=() pkg
  if (( n_native > 0 )); then
    step_start apply "Installing $n_native packages"
    while IFS= read -r pkg; do [[ -n $pkg ]] && apply_native+=("$pkg"); done <<<"$missing_native"
    sudo pacman -S --needed --noconfirm -- "${apply_native[@]}" &&
      step_ok apply "repo packages installed" ||
      { step_fail apply "some repo packages failed"; RESTORE_FAILED=1; }
  fi
  if (( n_aur > 0 )) && have yay; then
    while IFS= read -r pkg; do [[ -n $pkg ]] && apply_aur+=("$pkg"); done <<<"$missing_aur"
    # A loadout comes from a stranger by design, so its AUR list gets exactly
    # the same question a vault's does — asked here rather than folded into
    # "apply this loadout?", because it is a different question.
    aur_gate apply "${apply_aur[@]}"
    if [[ $AUR_MODE != skip ]]; then
      aur_install apply "${AUR_KEPT[@]}" || step_warn apply "some AUR packages failed"
    fi
  elif (( n_aur > 0 )); then
    step_warn apply "yay is not installed; skipped $n_aur AUR packages"
  fi

  local row
  for row in "${plugin_rows[@]:-}"; do
    [[ -n $row ]] || continue
    IFS=$'\t' read -r id url sha <<<"$row"
    if clone_pinned "$url" "$HOME/.config/omarchy/plugins/$id" "$sha" &&
      omarchy plugin validate "$HOME/.config/omarchy/plugins/$id" >/dev/null 2>&1; then
      omarchy-shell shell ping >/dev/null 2>&1 && omarchy plugin enable "$id" >/dev/null 2>&1 || true
      step_ok apply "plugin $id"
    else
      rm -rf "$HOME/.config/omarchy/plugins/$id"
      step_warn apply "could not install plugin $id"
    fi
  done

  for row in "${webapp_rows[@]:-}"; do
    [[ -n $row ]] || continue
    IFS=$'\t' read -r label url id <<<"$row"
    # Rebuilt through the real installer from a name, a URL and an icon name —
    # never by copying a .desktop file, which could carry any Exec at all.
    omarchy webapp install "$label" "$url" "${id:-$url}" >/dev/null 2>&1 &&
      step_ok apply "web app $label" ||
      step_warn apply "could not add web app $label"
  done

  if [[ -n $theme_name ]]; then
    # Only ever at the commit the loadout named. An unpinned theme never gets
    # here as a clone, which leaves `theme set` — the one thing that can still
    # succeed, because the theme may be bundled or already installed.
    if (( theme_clone )); then
      clone_pinned "$theme_url" "$HOME/.config/omarchy/themes/$theme_name" "$theme_sha" || true
    fi
    omarchy theme set "$theme_name" >/dev/null 2>&1 &&
      step_ok apply "theme $theme_name" ||
      step_warn apply "theme $theme_name is not available here"
  fi

  emit "DONE|ok|apply complete"
  printf '\n%sLoadout applied.%s Your dotfiles and your home directory were not touched.\n' "$c_bold" "$c_reset"
}

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
  local action first cleanup claim_status registry_resource requested note existing_channels requested_channels plan='[]'
  resources=$(profile_resources_json "$profile" "$loadout_id")
  while IFS= read -r item; do
    rid=$(jq -r '.id' <<<"$item"); kind=$(jq -r '.kind' <<<"$item")
    definition=$(jq -c '.definition' <<<"$item"); requested=$(jq -c '.requested' <<<"$item")
    existing=$(jq -c --arg id "$rid" '.resources[] | select(.id == $id)' <<<"$REGISTRY")
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
    plan=$(jq -c --argjson item "$item" --argjson resource "$registry_resource" \
      --argjson observation "$observation" --arg action "$action" --arg status "$claim_status" \
      --arg note "$note" \
      '. + [{item:$item,resource:$resource,observation:$observation,action:$action,claimStatus:$status,note:$note}]' <<<"$plan")
  done < <(jq -c '.[]' <<<"$resources")
  printf '%s' "$plan"
}

registry_register_apply_plan() {
  local id="$1" source="$2" digest="$3" profile="$4" plan="$5" now precedence baseline actions next
  now=$(date -u +%s)
  precedence=$(jq '[.loadouts[].precedence] | max // 0 | . + 1' <<<"$REGISTRY")
  baseline=$(active_theme_name || true)
  actions=$(jq -c '[.[] | select(.action == "install" or .action == "activate") |
    {resourceId:.item.id,state:"planned"}]' <<<"$plan")
  next=$(jq -c --arg id "$id" --arg source "$source" --arg digest "$digest" \
    --argjson profile "$(<"$profile")" --argjson plan "$plan" --argjson now "$now" \
    --argjson precedence "$precedence" --arg baseline "$baseline" --argjson actions "$actions" '
    if .baseline.activeTheme == null and any($plan[]; .item.kind == "theme-active")
      then .baseline.activeTheme = $baseline else . end |
    .loadouts += [{id:$id,name:$profile.name,author:$profile.author,description:$profile.description,
      source:$source,digest:$digest,profile:$profile,appliedAt:$now,updatedAt:$now,
      precedence:$precedence,state:(if any($plan[]; .claimStatus == "conflicting") then "conflicting"
        elif any($plan[]; .claimStatus != "healthy") then "pending" else "healthy" end)}] |
    reduce $plan[] as $p (.;
      if any(.resources[]; .id == $p.resource.id) then . else .resources += [$p.resource] end |
      .claims += [{loadoutId:$id,resourceId:$p.resource.id,requested:($p.item.definition + $p.item.requested),
        status:$p.claimStatus,lastError:(if $p.claimStatus == "conflicting" then "incompatible or changed resource" else "" end)}]) |
    .operation = {kind:"apply",target:$id,phase:"planned",actions:$actions}
  ' <<<"$REGISTRY")
  registry_save "$next"
}

registry_set_claim_result() {
  local loadout="$1" resource="$2" claim_state="$3" observed_state="$4" evidence="$5" error="${6:-}" action_state="done" next
  [[ $claim_state == healthy ]] || action_state=$claim_state
  case "$action_state" in pending|deferred) action_state="skipped";; conflicting) action_state="failed";; esac
  next=$(jq -c --arg loadout "$loadout" --arg resource "$resource" --arg claim "$claim_state" \
    --arg observed "$observed_state" --argjson evidence "$evidence" --arg error "$error" --arg action "$action_state" '
    .claims |= map(if .loadoutId == $loadout and .resourceId == $resource
      then .status = $claim | .lastError = $error else . end) |
    .resources |= map(if .id == $resource then .state = $observed | .evidence = $evidence else . end) |
    if .operation != null then .operation.phase = "running" |
      .operation.actions |= map(if .resourceId == $resource then .state = $action else . end)
    else . end
  ' <<<"$REGISTRY")
  # Derive the target lifecycle from all of its claims after the relation update.
  next=$(jq -c --arg id "$loadout" '
    . as $root | .loadouts |= map(if .id == $id then
      .state = (if any($root.claims[]; .loadoutId == $id and .status == "conflicting") then "conflicting"
        elif any($root.claims[]; .loadoutId == $id and .status != "healthy") then "pending"
        else "healthy" end) else . end)
  ' <<<"$next")
  registry_save "$next"
}


cmd_apply() {
  local source="${1:-}"
  [[ -n $source ]] || die "usage: ress apply <ress.sh/gh/user/repo | git-url | profile.json>"
  source=$(normalize_source "$source"); shift || true
  while (( $# )); do case "$1" in --restart) shift;; *) die "unknown apply option: $1";; esac; done

  take_lock
  APPLY_WORK=$(mktemp -d)
  step_start apply "Fetching the loadout"
  fetch_profile "$source" "$APPLY_WORK"
  local profile="$APPLY_WORK/normalized.json"
  normalize_profile "$APPLY_WORK/profile.json" "$profile"
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
        observation=$(resource_inspect_json "$(jq -c --arg id "package:$pkg" '.resources[] | select(.id == $id)' <<<"$REGISTRY")")
        evidence=$(jq -c '.evidence' <<<"$observation")
        registry_set_claim_result "$id" "package:$pkg" healthy present "$evidence"
      done
      step_ok apply "repo packages installed"
    else
      for pkg in "${native[@]}"; do
        observation=$(resource_inspect_json "$(jq -c --arg id "package:$pkg" '.resources[] | select(.id == $id)' <<<"$REGISTRY")")
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
        observation=$(resource_inspect_json "$(jq -c --arg id "package:$pkg" '.resources[] | select(.id == $id)' <<<"$REGISTRY")")
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
