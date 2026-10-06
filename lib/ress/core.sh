#!/bin/bash
#
# Shared ress runtime: constants, configured paths, output/protocol primitives,
# configuration, locks, generic helpers, and process-wide cleanup.
#
# Loaded by bin/ress after it establishes PLUGIN_DIR. Owns CFG, global command
# flags, common temporary paths, and the primary operation/config locks. Used by
# every vault and loadout workflow. This module defines state and functions only;
# it must not parse arguments, install traps, perform I/O work, or emit output
# merely because it was sourced.

VERSION="1.2.0"
SCHEMA=1

# The vault's manifest and the suffix restore leaves on anything it replaces.
# Both were named after the project's old name; both are read under either name
# forever, because a vault written last year is still a vault.
VAULT_MANIFEST="ress.json"
VAULT_MANIFEST_LEGACY="resurrect.json"
BAK_SUFFIX=".ress-bak"
BAK_SUFFIX_LEGACY=".resurrect-bak"
DEFAULTS_DIR="$PLUGIN_DIR/defaults"

# Omarchy exports OMARCHY_PATH for exactly this, and the shell's own plugin
# catalog reads it rather than the fixed path. Following it means a checkout
# running under `omarchy dev link` sees its own themes and version, instead of
# the ones installed system-wide.
OMARCHY_DIR="${OMARCHY_PATH:-/usr/share/omarchy}"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ress"
CONFIG_FILE="$CONFIG_DIR/config"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ress"
DEFAULT_VAULT="${XDG_DATA_HOME:-$HOME/.local/share}/ress/vault"

CATEGORIES=(packages config omarchy webapps plugins secrets)

# ------------------------------------------------------------------- output

PORCELAIN=0
DRY_RUN=0
ASSUME_YES=0
ALLOW_UNPINNED=0
LOADOUT_LOCKED=0
# Set by --aur / --no-aur / --review-aur; empty leaves the decision to the AUR
# setting, which defaults to asking.
AUR_CHOICE=""
AUR_REVIEW=0

c_reset=$'\e[0m'; c_dim=$'\e[2m'; c_bold=$'\e[1m'
c_green=$'\e[32m'; c_red=$'\e[31m'; c_yellow=$'\e[33m'; c_blue=$'\e[34m'
if [[ ! -t 1 ]]; then c_reset=""; c_dim=""; c_bold=""; c_green=""; c_red=""; c_yellow=""; c_blue=""; fi

# The panel reads these on stdout. One record per line, pipe-separated, never
# translated or reordered — it is a protocol, not prose.
emit() { (( PORCELAIN )) && printf '%s\n' "$*" || true; }

step_start() { emit "STEP|$1|start|$2"; (( PORCELAIN )) || printf '%s▸ %s%s %s\n' "$c_blue" "$1" "$c_reset" "$2"; }
step_ok()    { emit "STEP|$1|ok|$2";    (( PORCELAIN )) || printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$2"; }
step_skip()  { emit "STEP|$1|skip|$2";  (( PORCELAIN )) || printf '  %s– %s: %s%s\n' "$c_dim" "$1" "$2" "$c_reset"; }
step_warn()  { emit "STEP|$1|warn|$2";  (( PORCELAIN )) || printf '  %s!%s %s: %s\n' "$c_yellow" "$c_reset" "$1" "$2"; }
step_fail()  { emit "STEP|$1|fail|$2";  FAILED_STEPS+=("$1: $2"); (( PORCELAIN )) || printf '  %s✗%s %s: %s\n' "$c_red" "$c_reset" "$1" "$2"; }
progress()   { emit "PROGRESS|$1|$2|$3"; }
note()       { emit "LOG|$1";           (( PORCELAIN )) || printf '  %s%s%s\n' "$c_dim" "$1" "$c_reset"; }

die() {
  emit "DONE|fail|$*"
  printf '%sress: %s%s\n' "$c_red" "$*" "$c_reset" >&2
  exit 1
}

confirm() {
  (( ASSUME_YES )) && return 0
  [[ -t 0 ]] || die "refusing to continue without confirmation; pass --yes"
  local reply=""
  read -r -p "$1 [y/N] " reply || reply=""
  [[ $reply == [yY]* ]]
}

# ------------------------------------------------------------------- config

declare -A CFG=(
  [VAULT]="$DEFAULT_VAULT"
  [REMOTE]=""
  [AUTO_BACKUP]="off"
  [AUTO_INTERVAL_HOURS]="24"
  [AUTO_PUSH]="0"
  [INCLUDE_PACKAGES]="1"
  [INCLUDE_CONFIG]="1"
  [INCLUDE_OMARCHY]="1"
  [INCLUDE_WEBAPPS]="1"
  [INCLUDE_PLUGINS]="1"
  [INCLUDE_SECRETS]="0"
  [SECRETS_MODE]="passphrase"
  [SECRETS_RECIPIENT]=""
  [PROFILE_URL]=""
  # Restore writes files. The one thing it can *turn on* is a systemd user
  # unit, so that is a separate decision with its own default: ask.
  [ENABLE_UNITS]="ask"
  # And the one thing it can *build* is an AUR package. Same reasoning, same
  # default.
  [AUR]="ask"
  # warn | block | off. What to do when a capture looks like it picked up a
  # credential.
  [SECRET_SCAN]="warn"
  # Every file in ~/.config/autostart is a command that runs at your next
  # login, which is why it is not captured by default. Turning this on is a
  # decision, so it is a setting rather than a line in a list.
  [CAPTURE_AUTOSTART]="0"
)

load_config() {
  [[ -f $CONFIG_FILE ]] || return 0
  local line key value
  while IFS= read -r line; do
    line="${line%%#*}"
    [[ $line == *=* ]] || continue
    key="${line%%=*}"; value="${line#*=}"
    key="${key//[[:space:]]/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    [[ -n $key ]] && CFG[$key]="$value"
  done <"$CONFIG_FILE"
}

save_config() {
  private_dir "$CONFIG_DIR"
  local tmp; tmp=$(mktemp "$CONFIG_DIR/.config.XXXXXX")
  {
    echo "# ress configuration. Written by \`ress set\` and by the panel."
    echo "# Both the CLI and the Quickshell panel read this file; there is no second source."
    echo
    local key
    for key in VAULT REMOTE AUTO_BACKUP AUTO_INTERVAL_HOURS AUTO_PUSH \
      INCLUDE_PACKAGES INCLUDE_CONFIG INCLUDE_OMARCHY INCLUDE_WEBAPPS \
      INCLUDE_PLUGINS INCLUDE_SECRETS SECRETS_MODE SECRETS_RECIPIENT PROFILE_URL \
      ENABLE_UNITS AUR SECRET_SCAN CAPTURE_AUTOSTART; do
      printf '%s=%s\n' "$key" "${CFG[$key]}"
    done
  } >"$tmp"
  mv "$tmp" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

cat_enabled() {
  local key="INCLUDE_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  [[ ${CFG[$key]:-0} == 1 ]]
}

# ---------------------------------------------------- settings, as JSON
#
# The config file is meant to be edited by hand, so a value in it can be
# anything. Raw values used to go straight into `jq --argjson`, and
# `INCLUDE_OMARCHY=` or `AUTO_INTERVAL_HOURS=24h` then made
# `ress status --json` exit 2 with no output at all — while the panel reads
# nothing but that command, so the panel's whole backup summary went blank
# without a word anywhere. Nothing below trusts the text any more: a flag is
# read exactly the way cat_enabled reads it, and a number has to be a number.

json_flag() { [[ ${1:-} == 1 ]] && printf 'true' || printf 'false'; }

json_number() {
  local value="${1:-}" fallback="${2:-0}"
  [[ $value =~ ^[0-9]{1,9}$ ]] || value="$fallback"
  printf '%s' "$value"
}

have() { command -v "$1" >/dev/null 2>&1; }
private_dir() { mkdir -p "$1" && chmod 700 "$1" 2>/dev/null || true; }

# The panel-owned engine and the headless scheduler are separate processes with
# separate ideas of "busy". Without a lock they will both write the same git
# vault; without the marker file the bar shows nothing while the scheduler runs.
DRYRUN_VAULT=""
PROFILE_WORK=""
ress_cleanup() {
  [[ -n ${DRYRUN_VAULT:-} ]] && rm -rf "$DRYRUN_VAULT" 2>/dev/null
  [[ -n ${STATE_DIR:-} ]] && rm -f "$STATE_DIR/running" 2>/dev/null
  [[ -n ${APPLY_WORK:-} ]] && rm -rf "$APPLY_WORK" 2>/dev/null
  [[ -n ${PROFILE_WORK:-} ]] && rm -rf "$PROFILE_WORK" 2>/dev/null
  return 0
}
# `ress set` is a read-modify-write of one small file, and the panel fires one
# per toggle through execDetached — nine rows now write this way. Two in quick
# succession could read the same config and the later one drop the earlier one's
# change. This is deliberately not the vault lock: a settings change is not
# vault work, and taking that one would make the bar show a backup running.
take_config_lock() {
  private_dir "$CONFIG_DIR"
  exec 8>"$CONFIG_DIR/.lock"
  flock -w 5 8 || true
}

take_lock() {
  private_dir "$STATE_DIR"
  exec 9>"$STATE_DIR/lock"
  flock -n 9 || die "another ress operation is already running"
  # The lock is still taken for a dry run — it clones into a temp directory and
  # reads the vault, and two of those at once is still two — but the marker the
  # bar reads as "busy" is not written, because nothing is happening to this
  # machine.
  (( DRY_RUN )) || date -u +%s >"$STATE_DIR/running"
  LOADOUT_LOCKED=1
}

ensure_loadout_lock() { (( LOADOUT_LOCKED )) || take_lock; }

# "1 plugins" reads like a bug even when the number is right.
plural() {
  local n=$1 one=$2 many=${3:-$2s}
  if (( n == 1 )); then printf '%d %s' "$n" "$one"; else printf '%d %s' "$n" "$many"; fi
}

duration() {
  local s=$1
  if (( s < 60 )); then printf '%ds' "$s"
  else printf '%dm %ds' $((s / 60)) $((s % 60)); fi
}

json_escape() { printf '%s' "$1" | jq -Rs .; }

# grep -c prints a count and still exits 1 on zero matches, so the naive
# `grep -c ... || echo 0` prints "0\n0" and poisons every jq --argjson downstream.
count_lines() {
  if [[ -f $1 ]]; then
    grep -cve '^[[:space:]]*$' "$1" 2>/dev/null || true
  else
    printf '0\n'
  fi
}

# Concatenate the shipped list with the user's, dropping comments and blanks.
merged_list() {
  local name="$1"
  { [[ -f "$DEFAULTS_DIR/$name.txt" ]] && cat "$DEFAULTS_DIR/$name.txt"
    [[ -f "$CONFIG_DIR/$name" ]] && cat "$CONFIG_DIR/$name"
  } 2>/dev/null | sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d'
}
