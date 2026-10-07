#!/usr/bin/env bash

# Real-tool integration checks for the applied-loadout lifecycle. Everything
# mutable is redirected beneath a throwaway HOME; the pacman check is a
# read-only dependency-planning request.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
mntg="$repo_root/bin/mntg"
omarchy_root=${OMARCHY_PATH:-/usr/share/omarchy}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/mntg-loadout-real.XXXXXX")

cleanup() {
  case "$scratch" in
    "${TMPDIR:-/tmp}"/mntg-loadout-real.*) rm -rf -- "$scratch" ;;
  esac
}
trap cleanup EXIT

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -x $mntg ]] || fail "mntg is not executable"
[[ -x $omarchy_root/bin/omarchy-plugin-remove ]] || fail "real Omarchy plugin removal is unavailable"
[[ -x $omarchy_root/bin/omarchy-webapp-remove ]] || fail "real Omarchy web-app removal is unavailable"
[[ -x $omarchy_root/bin/omarchy-theme-remove ]] || fail "real Omarchy theme removal is unavailable"
[[ -x $omarchy_root/bin/omarchy-theme-set ]] || fail "real Omarchy theme switching is unavailable"

export HOME="$scratch/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_RUNTIME_DIR="$scratch/run"
export OMARCHY_PATH="$omarchy_root"
export OMARCHY_THEME_HEADLESS=1
export OMARCHY_THEME_SKIP_BACKGROUND=1
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$scratch/profiles" "$scratch/bin"

registry_profile="$scratch/profiles/registry.json"
jq -n '{schemaVersion: 1, kind: "omarchy-loadout", name: "Real scratch registry", author: "mntg validation", description: "isolated real-command check", createdAt: "2026-10-04T00:00:00Z", omarchy: "scratch", packages: {native: ["bash"], aur: []}, plugins: [], webapps: [], theme: {name: "", url: "", commit: ""}}' >"$registry_profile"
"$mntg" apply --yes --no-aur "$registry_profile" >/dev/null

registry="$XDG_STATE_HOME/montage/loadouts.json"
[[ -f $registry ]] || fail "tracked apply did not create a registry"
[[ $(stat -c '%a' "$registry") == 600 ]] || fail "registry mode is not 0600"
pass "tracked apply creates a 0600 registry in a scratch HOME"

if pacman -R --print --noconfirm libpng >"$scratch/pacman.out" 2>"$scratch/pacman.err"; then
  fail "pacman unexpectedly accepted removal of dependency-bearing libpng"
fi
grep -qi 'breaks dependency\|could not satisfy dependencies' "$scratch/pacman.err" ||
  fail "pacman refusal did not report dependency evidence"
pacman -Q libpng >/dev/null || fail "read-only pacman planning changed the installed package"
pass "real pacman refuses an unsafe direct removal without mutating the machine"

plugin_id=acme.scratch
plugin_dir="$XDG_CONFIG_HOME/omarchy/plugins/$plugin_id"
mkdir -p "$plugin_dir"
git -C "$plugin_dir" init -q
git -C "$plugin_dir" -c user.name='mntg scratch' -c user.email='mntg-scratch@example.invalid' \
  commit --allow-empty -qm initial
jq -n --arg source 'https://example.invalid/upstream.git' '{omarchy: {clonedFrom: $source}}' >"$plugin_dir/manifest.json"

cat >"$scratch/bin/omarchy-shell" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${MONTAGE_SCRATCH_SHELL_LOG:?}"
case "$*" in
  'shell listPlugins') printf '[{"id":"acme.scratch","enabled":true}]\n' ;;
  'shell setPluginEnabled acme.scratch false') printf 'ok\n' ;;
  'shell rescanPlugins') printf 'ok\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$scratch/bin/omarchy-shell"
export MONTAGE_SCRATCH_SHELL_LOG="$scratch/omarchy-shell.log"
PATH="$scratch/bin:/usr/bin:/bin" "$omarchy_root/bin/omarchy-plugin-remove" "$plugin_id" --yes >/dev/null
[[ ! -e $plugin_dir ]] || fail "real Omarchy plugin removal left the plugin directory"
grep -Fx 'shell setPluginEnabled acme.scratch false' "$MONTAGE_SCRATCH_SHELL_LOG" >/dev/null ||
  fail "real plugin removal did not disable the enabled plugin"
grep -Fx 'shell rescanPlugins' "$MONTAGE_SCRATCH_SHELL_LOG" >/dev/null ||
  fail "real plugin removal did not request a shell rescan"
pass "real Omarchy plugin removal disables, deletes, and rescans a disposable plugin"

desktop_dir="$XDG_DATA_HOME/applications"
icon_dir="$XDG_DATA_HOME/icons/hicolor/256x256/apps"
mkdir -p "$desktop_dir" "$icon_dir"
cat >"$desktop_dir/Acme Scratch.desktop" <<'EOF'
[Desktop Entry]
Name=Acme Scratch
Exec=omarchy-launch-webapp "https://example.invalid/app"
Type=Application
EOF
: >"$icon_dir/acme-scratch.png"
OMARCHY_REMOVE_NOTIFY=false "$omarchy_root/bin/omarchy-webapp-remove" 'Acme Scratch' >/dev/null
[[ ! -e $desktop_dir/Acme\ Scratch.desktop ]] || fail "real Omarchy web-app removal left the launcher"
[[ ! -e $icon_dir/acme-scratch.png ]] || fail "real Omarchy web-app removal left the attributable icon"
pass "real Omarchy web-app removal deletes its disposable launcher and icon"

theme_dir="$XDG_CONFIG_HOME/omarchy/themes/scratch-theme"
mkdir -p "$theme_dir"
cat >"$scratch/bin/omarchy-notification-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$scratch/bin/omarchy-notification-send"
PATH="$scratch/bin:/usr/bin:/bin" "$omarchy_root/bin/omarchy-theme-remove" scratch-theme >/dev/null
[[ ! -e $theme_dir ]] || fail "real Omarchy theme removal left the disposable theme"
pass "real Omarchy theme removal deletes a disposable user theme"

"$omarchy_root/bin/omarchy-theme-set" tokyo-night >/dev/null
theme_a="$scratch/profiles/theme-a.json"
theme_b="$scratch/profiles/theme-b.json"
jq -n '{schemaVersion: 1, kind: "omarchy-loadout", name: "Real scratch theme A", author: "mntg validation", description: "theme fallback check", createdAt: "2026-10-04T00:00:00Z", omarchy: "scratch", packages: {native: [], aur: []}, plugins: [], webapps: [], theme: {name: "catppuccin", url: "", commit: ""}}' >"$theme_a"
jq -n '{schemaVersion: 1, kind: "omarchy-loadout", name: "Real scratch theme B", author: "mntg validation", description: "theme fallback check", createdAt: "2026-10-04T00:00:00Z", omarchy: "scratch", packages: {native: [], aur: []}, plugins: [], webapps: [], theme: {name: "gruvbox", url: "", commit: ""}}' >"$theme_b"
"$mntg" apply --yes --no-aur "$theme_a" >/dev/null
"$mntg" apply --yes --no-aur "$theme_b" >/dev/null
[[ $(<"$XDG_STATE_HOME/omarchy/current/theme.name") == gruvbox ]] ||
  fail "second loadout did not become the active theme request"
theme_b_id=$(jq -r '.loadouts[] | select(.name == "Real scratch theme B") | .id' "$registry")
theme_a_id=$(jq -r '.loadouts[] | select(.name == "Real scratch theme A") | .id' "$registry")
[[ -n $theme_a_id && -n $theme_b_id ]] || fail "tracked theme loadout ids were not recorded"
"$mntg" loadout remove --yes "$theme_b_id" >/dev/null
[[ $(<"$XDG_STATE_HOME/omarchy/current/theme.name") == catppuccin ]] ||
  fail "removing the effective theme request did not activate the remaining request"
"$mntg" loadout remove --yes "$theme_a_id" >/dev/null
[[ $(<"$XDG_STATE_HOME/omarchy/current/theme.name") == tokyo-night ]] ||
  fail "removing the final theme request did not restore the captured baseline"
pass "real headless Omarchy theme switching honors loadout precedence and baseline fallback"

printf 'All real-machine scratch checks passed; scratch state was isolated at %s.\n' "$scratch"
