#!/bin/bash
#
# Live loadout-resource inspection and guarded install, removal, and theme-effect
# operations shared by apply and lifecycle commands.
# Depends on core.sh, safety.sh, registry.sh, and profile.sh. Used by share,
# check, repair, update, remove, and apply. Definitions only at source time.

resource_inspect_json() {
  local resource="$1" kind name definition state evidence target actual_url actual_sha dirty parts actual_icon current
  local resource_id effective_theme_loadout
  resource_id=$(jq -r '.id' <<<"$resource")
  kind=$(jq -r '.kind' <<<"$resource")
  name=$(jq -r '.name' <<<"$resource")
  definition=$(jq -c '.definition' <<<"$resource")
  state="missing"; evidence='{}'
  case "$kind" in
    package)
      if pacman -Q "$name" >/dev/null 2>&1; then
        state="present"; evidence=$(jq -nc --arg name "$name" '{package:$name}')
      fi
      ;;
    plugin)
      target="$HOME/.config/omarchy/plugins/$name"
      if [[ -L $target ]]; then
        state="unverifiable"; evidence=$(jq -nc --arg target "$(readlink "$target")" '{symlink:$target}')
      elif [[ -d $target ]]; then
        actual_url=$(canonical_remote "$(git -C "$target" remote get-url origin 2>/dev/null || true)")
        actual_sha=$(git -C "$target" rev-parse HEAD 2>/dev/null || true)
        dirty=$(git -C "$target" status --porcelain 2>/dev/null || echo unknown)
        evidence=$(jq -nc --arg url "$actual_url" --arg commit "$actual_sha" --arg dirty "$dirty" \
          '{url:$url,commit:$commit,dirty:($dirty != "")}')
        if [[ $actual_url != "$(jq -r '.url' <<<"$definition")" ]]; then state="conflicting"
        elif [[ -n $(jq -r '.commit' <<<"$definition") && $actual_sha != "$(jq -r '.commit' <<<"$definition")" ]]; then state="modified"
        elif [[ -n $dirty ]]; then state="modified"
        elif [[ -f $target/manifest.json ]]; then state="present"
        else state="conflicting"; fi
      fi
      ;;
    webapp)
      target="$HOME/.local/share/applications/$name.desktop"
      if [[ -f $target ]]; then
        parts=$(webapp_parts "$(launcher_exec "$target")" 2>/dev/null || true)
        actual_icon=$(sed -n 's/^Icon=//p' "$target" | head -1)
        if [[ -n $parts ]]; then
          local launcher actual_web_url flags
          IFS=$'\t' read -r launcher actual_web_url flags <<<"$parts"
          evidence=$(jq -nc --arg url "$actual_web_url" --arg icon "$actual_icon" \
            --arg digest "$(sha256sum "$target" | awk '{print $1}')" '{url:$url,icon:$icon,digest:$digest}')
          if [[ $actual_web_url == "$(jq -r '.url' <<<"$definition")" ]] &&
            { [[ -z $(jq -r '.icon' <<<"$definition") ]] || [[ $actual_icon == "$(jq -r '.icon' <<<"$definition")" ]]; }; then
            state="present"
          else state="modified"; fi
        else state="unverifiable"; evidence=$(jq -nc --arg digest "$(sha256sum "$target" | awk '{print $1}')" '{digest:$digest}'); fi
      fi
      ;;
    theme-install)
      target="$HOME/.config/omarchy/themes/$name"
      if [[ -d $target ]]; then
        actual_url=$(canonical_remote "$(git -C "$target" remote get-url origin 2>/dev/null || true)")
        actual_sha=$(git -C "$target" rev-parse HEAD 2>/dev/null || true)
        dirty=$(git -C "$target" status --porcelain 2>/dev/null || echo unknown)
        evidence=$(jq -nc --arg url "$actual_url" --arg commit "$actual_sha" --arg dirty "$dirty" \
          '{url:$url,commit:$commit,dirty:($dirty != "")}')
        if [[ -n $(jq -r '.url' <<<"$definition") && $actual_url != "$(jq -r '.url' <<<"$definition")" ]]; then state="conflicting"
        elif [[ -n $(jq -r '.commit' <<<"$definition") && $actual_sha != "$(jq -r '.commit' <<<"$definition")" ]]; then state="modified"
        elif [[ -n $dirty ]]; then state="modified"
        else state="present"; fi
      elif [[ -d $OMARCHY_DIR/themes/$name && -z $(jq -r '.url' <<<"$definition") ]]; then
        state="present"; evidence='{"bundled":true}'
      fi
      ;;
    theme-active)
      current=$(active_theme_name || true)
      effective_theme_loadout=$(jq -r '
        . as $root |
        [$root.claims[] as $claim |
          $root.resources[] | select(.id == $claim.resourceId and .kind == "theme-active") as $theme |
          $root.loadouts[] | select(.id == $claim.loadoutId) |
          {id:.id,precedence:.precedence}] |
        sort_by(.precedence) | last | .id // ""
      ' <<<"$REGISTRY")
      if jq -e --arg id "$resource_id" 'any(.resources[]; .id == $id)' <<<"$REGISTRY" >/dev/null &&
        [[ ${resource_id#theme-active:} != "$effective_theme_loadout" ]]; then
        state="present"
        evidence=$(jq -nc --arg current "$current" '{current:$current,effective:false}')
      else
        evidence=$(jq -nc --arg current "$current" '{current:$current,effective:true}')
        [[ $current == "$name" ]] && state="present" || state="missing"
      fi
      ;;
  esac
  jq -nc --arg state "$state" --argjson evidence "$evidence" '{state:$state,evidence:$evidence}'
}

critical_package() {
  case "$1" in
    ress|pacman|yay|sudo|base|base-devel|omarchy|omarchy-*|quickshell|hyprland|systemd|glibc|linux) return 0 ;;
    *) return 1 ;;
  esac
}

plugin_remove_supported() {
  local name="$1" target="$HOME/.config/omarchy/plugins/$1" shim rc=0

  # Prefer Omarchy's normal path so a live shell can report enabled state,
  # unload the plugin, and rescan after removal.
  omarchy plugin remove --yes "$name" >/dev/null 2>&1 && return 0
  [[ ! -e $target && ! -L $target ]] && return 0

  # omarchy-plugin-remove currently asks shell IPC for enabled state before it
  # deletes anything. A clean TTY/SSH machine has no shell to query. Once that
  # absence is confirmed, rerun the same supported remover with a narrowly
  # scoped shim: no running shell means no live enabled plugin to unload and no
  # live process to rescan. All path validation and deletion remain Omarchy's.
  omarchy-shell shell ping >/dev/null 2>&1 && return 1
  # IPC can fail while a shell process is starting or temporarily unhealthy.
  # In that case fail closed instead of pretending there is no live consumer.
  pgrep -u "$UID" -x quickshell >/dev/null 2>&1 && return 1
  shim=$(mktemp -d)
  cat >"$shim/omarchy-shell" <<'SHIM'
#!/bin/bash
case "${1:-} ${2:-}" in
  "shell listPlugins") printf '[]\n' ;;
  "shell rescanPlugins") ;;
  *) exit 1 ;;
esac
SHIM
  chmod 700 "$shim/omarchy-shell"
  PATH="$shim:$PATH" omarchy plugin remove --yes "$name" >/dev/null 2>&1 || rc=$?
  rm -f "$shim/omarchy-shell"
  rmdir "$shim" 2>/dev/null || true
  return "$rc"
}

resource_remove_adapter() {
  local resource="$1" allow_changed="${2:-0}" kind name observation current
  kind=$(jq -r '.kind' <<<"$resource"); name=$(jq -r '.name' <<<"$resource")
  observation=$(resource_inspect_json "$resource")
  current=$(jq -r '.state' <<<"$observation")
  if [[ $current != present ]]; then
    (( allow_changed )) && [[ $current == modified || $current == conflicting ]] || return 2
  fi
  case "$kind" in
    package)
      critical_package "$name" && return 3
      sudo pacman -R --noconfirm -- "$name" >/dev/null 2>&1 || return 1
      local orphans; orphans=$(pacman -Qtdq 2>/dev/null || true)
      [[ -z $orphans ]] || note "unneeded dependencies remain (not removed): $(tr '\n' ' ' <<<"$orphans")"
      ;;
    plugin) plugin_remove_supported "$name" || true ;;
    # Some Omarchy versions remove the launcher successfully and then return a
    # failure from a best-effort desktop-database refresh. The machine
    # postcondition is authoritative: keep the claim only when the launcher is
    # still present (or its state is otherwise unsafe), not merely because the
    # delegated command's final helper failed.
    webapp) omarchy webapp remove "$name" >/dev/null 2>&1 || true ;;
    theme-install) omarchy theme remove "$name" >/dev/null 2>&1 || return 1 ;;
    theme-active) return 0 ;;
    *) return 1 ;;
  esac
  [[ $kind == theme-active ]] || [[ $(jq -r '.state' <<<"$(resource_inspect_json "$resource")") == missing ]]
}

theme_release_effect() {
  local loadout="$1" resource="$2" current target fallback="" baseline
  target=$(jq -r '.name' <<<"$resource")
  current=$(active_theme_name || true)
  [[ $current == "$target" ]] || return 0
  fallback=$(jq -r --arg removed "$loadout" '
    . as $root |
    [$root.claims[] | select(.loadoutId != $removed) as $c |
      $root.resources[] | select(.id == $c.resourceId and .kind == "theme-active") as $r |
      $root.loadouts[] | select(.id == $c.loadoutId) | {name:$r.name,precedence}] |
    sort_by(.precedence) | last | .name // ""' <<<"$REGISTRY")
  baseline=$(jq -r '.baseline.activeTheme // ""' <<<"$REGISTRY")
  [[ -n $fallback ]] || fallback="$baseline"
  if [[ -n $fallback && $fallback != "$target" ]]; then
    omarchy theme set "$fallback" >/dev/null 2>&1 || return 1
  fi
}

release_claim() {
  local loadout="$1" rid="$2" decision="${3:-}" resource observation state cleanup others rc=0 next
  resource=$(jq -c --arg id "$rid" '.resources[] | select(.id == $id)' <<<"$REGISTRY")
  [[ -n $resource ]] || return 0
  cleanup=$(jq -r '.cleanupPolicy' <<<"$resource")
  others=$(jq --arg loadout "$loadout" --arg rid "$rid" '[.claims[] | select(.resourceId == $rid and .loadoutId != $loadout)] | length' <<<"$REGISTRY")
  observation=$(resource_inspect_json "$resource"); state=$(jq -r '.state' <<<"$observation")
  if (( others > 0 )) || [[ $cleanup == retain || $state == missing ]]; then
    :
  elif [[ $(jq -r '.kind' <<<"$resource") == theme-active ]]; then
    theme_release_effect "$loadout" "$resource" || return 1
  elif [[ $state == present && $cleanup == remove ]]; then
    resource_remove_adapter "$resource" || rc=$?
    (( rc == 0 )) || return "$rc"
  elif [[ $state == modified || $state == conflicting || $state == unverifiable || $state == uncertain ]]; then
    if [[ $decision == keep ]]; then
      REGISTRY=$(jq -c --arg rid "$rid" '.resources |= map(if .id == $rid then .cleanupPolicy="retain" else . end)' <<<"$REGISTRY")
    elif [[ $decision == remove ]]; then
      resource_remove_adapter "$resource" 1 || rc=$?
      (( rc == 0 )) || return "$rc"
    else return 4
    fi
  else return 4
  fi
  next=$(jq -c --arg loadout "$loadout" --arg rid "$rid" '
    .claims |= map(select(.loadoutId != $loadout or .resourceId != $rid)) |
    if any(.claims[]; .resourceId == $rid) then . else .resources |= map(select(.id != $rid)) end |
    if .operation != null then .operation.actions |= map(if .resourceId == $rid then .state="done" else . end) else . end
  ' <<<"$REGISTRY")
  registry_save "$next"
}

apply_one_resource() {
  local loadout="$1" item="$2" category="${3:-apply}" rid kind name definition observation state evidence error=""
  rid=$(jq -r '.id' <<<"$item"); kind=$(jq -r '.kind' <<<"$item"); name=$(jq -r '.name' <<<"$item")
  definition=$(jq -c '.definition' <<<"$item")
  registry_action_state "$rid" running
  case "$kind" in
    plugin)
      local purl psha
      purl=$(jq -r '.url' <<<"$definition"); psha=$(jq -r '.commit' <<<"$definition")
      if clone_pinned "$purl" "$HOME/.config/omarchy/plugins/$name" "$psha" &&
        omarchy plugin validate "$HOME/.config/omarchy/plugins/$name" >/dev/null 2>&1; then
        if [[ -z $psha ]]; then
          psha=$(git -C "$HOME/.config/omarchy/plugins/$name" rev-parse HEAD 2>/dev/null || true)
          if valid_sha "$psha"; then
            REGISTRY=$(jq -c --arg rid "$rid" --arg sha "$psha" '
              .resources |= map(if .id == $rid then .definition.commit = $sha else . end)' <<<"$REGISTRY")
          fi
        fi
        omarchy-shell shell ping >/dev/null 2>&1 && omarchy plugin enable "$name" >/dev/null 2>&1 || true
      else error="could not install plugin $name"; rm -rf "$HOME/.config/omarchy/plugins/$name"; fi
      ;;
    webapp)
      local wurl wicon
      wurl=$(jq -r '.url' <<<"$definition"); wicon=$(jq -r '.icon' <<<"$definition")
      omarchy webapp install "$name" "$wurl" "${wicon:-$wurl}" >/dev/null 2>&1 || error="could not add web app $name"
      ;;
    theme-install)
      local turl tsha
      turl=$(jq -r '.url' <<<"$definition"); tsha=$(jq -r '.commit' <<<"$definition")
      if [[ -n $turl ]]; then
        clone_pinned "$turl" "$HOME/.config/omarchy/themes/$name" "$tsha" || error="could not install theme $name"
      elif [[ ! -d $HOME/.config/omarchy/themes/$name && ! -d $OMARCHY_DIR/themes/$name ]]; then
        error="theme $name is unavailable"
      fi
      ;;
    theme-active)
      omarchy theme set "$name" >/dev/null 2>&1 || error="could not activate theme $name"
      ;;
  esac
  observation=$(resource_inspect_json "$(jq -c --arg id "$rid" '.resources[] | select(.id == $id)' <<<"$REGISTRY")")
  state=$(jq -r '.state' <<<"$observation"); evidence=$(jq -c '.evidence' <<<"$observation")
  if [[ -z $error && $state == present ]]; then
    registry_set_claim_result "$loadout" "$rid" healthy present "$evidence"
    step_ok "$category" "$kind $name"
  else
    [[ -n $error ]] || error="$kind $name is $state after installation"
    registry_set_claim_result "$loadout" "$rid" failed "$state" "$evidence" "$error"
    step_warn "$category" "$error"
  fi
}
