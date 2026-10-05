#!/usr/bin/env bash

# Read-only inventory for the clean-Omarchy loadout lifecycle procedure.

set -u

state_home=${XDG_STATE_HOME:-$HOME/.local/state}

printf 'HOST=%s\n' "$(hostname)"
printf 'OMARCHY=%s\n' "$(cat /usr/share/omarchy/version 2>/dev/null || echo missing)"
printf 'KERNEL=%s\n' "$(uname -r)"
printf 'RESS=%s\n' "$(command -v ress 2>/dev/null || echo missing)"
printf 'PACMAN_COUNT=%s\n' "$(pacman -Qq 2>/dev/null | wc -l)"
printf 'REGISTRY=%s\n' "$(test -f "$state_home/ress/loadouts.json" && echo present || echo absent)"
printf 'RESS_PLUGIN=%s\n' "$(test -e "$HOME/.config/omarchy/plugins/tsouth89.resurrect" && echo present || echo absent)"
printf 'SESSION=%s|%s|%s\n' "${XDG_CURRENT_DESKTOP:-}" "${WAYLAND_DISPLAY:-}" "${DISPLAY:-}"
printf 'QUICKSHELL=%s\n' "$(pgrep -af quickshell 2>/dev/null | head -1 || true)"
printf 'SUDO_NONINTERACTIVE='
if sudo -n true 2>/dev/null; then
  printf 'yes\n'
else
  printf 'no\n'
fi

printf 'USER_PLUGINS='
find "$HOME/.config/omarchy/plugins" -mindepth 1 -maxdepth 1 -printf '%f ' 2>/dev/null || true
printf '\nUSER_THEMES='
find "$HOME/.config/omarchy/themes" -mindepth 1 -maxdepth 1 -printf '%f ' 2>/dev/null || true
printf '\nUSER_WEBAPPS='
find "$HOME/.local/share/applications" -maxdepth 1 -name '*.desktop' -printf '%f ' 2>/dev/null |
  head -c 1000 || true
printf '\nCURRENT_THEME=%s\n' "$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo missing)"
