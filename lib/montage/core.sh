#!/bin/bash
#
# Shared mntg runtime: constants, configured paths, output/protocol primitives,
# configuration, locks, generic helpers, and process-wide cleanup.
#
# Loaded by bin/mntg after it establishes PLUGIN_DIR. Owns CFG, global command
# flags, bounded temporary cleanup, and the primary operation/config locks. Used by
# every vault and loadout workflow. This module defines state and functions only;
# it must not parse arguments, install traps, perform I/O work, or emit output
# merely because it was sourced.

VERSION="1.2.0"
SCHEMA=1

# Native vaults use a repository envelope plus one current snapshot manifest.
# Ress control names belong exclusively to the explicit port adapter.
VAULT_MANIFEST="backup.json"
BAK_SUFFIX=".montage-bak"
DEFAULTS_DIR="$PLUGIN_DIR/defaults"

# Omarchy exports OMARCHY_PATH for exactly this, and the shell's own plugin
# catalog reads it rather than the fixed path. Following it means a checkout
# running under `omarchy dev link` sees its own themes and version, instead of
# the ones installed system-wide.
OMARCHY_DIR="${OMARCHY_PATH:-/usr/share/omarchy}"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/montage"
CONFIG_FILE="$CONFIG_DIR/config"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/montage"
DEFAULT_VAULT="${XDG_DATA_HOME:-$HOME/.local/share}/montage/vault"

CATEGORIES=(packages config omarchy webapps plugins secrets)

# ------------------------------------------------------------------- output

PORCELAIN=0
DRY_RUN=0
ASSUME_YES=0
ALLOW_UNPINNED=0
OPERATION_LOCKED=0
RUNNING_MARKER_TOKEN=""
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
  printf '%smntg: %s%s\n' "$c_red" "$*" "$c_reset" >&2
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

# One schema owns every persisted setting. CONFIG_KEYS is also the stable file
# order; loading deliberately preserves malformed values for known keys so the
# CLI can report hand edits while each consumer still applies its safe fallback.
CONFIG_KEYS=(
  VAULT REMOTE AUTO_BACKUP AUTO_INTERVAL_HOURS AUTO_PUSH
  INCLUDE_PACKAGES INCLUDE_CONFIG INCLUDE_OMARCHY INCLUDE_WEBAPPS
  INCLUDE_PLUGINS INCLUDE_SECRETS SECRETS_MODE SECRETS_RECIPIENT PROFILE_URL
  ENABLE_UNITS AUR SECRET_SCAN CAPTURE_AUTOSTART
)
declare -A CONFIG_DEFAULTS=(
  [VAULT]="$DEFAULT_VAULT" [REMOTE]="" [AUTO_BACKUP]="off"
  [AUTO_INTERVAL_HOURS]="24" [AUTO_PUSH]="0" [INCLUDE_PACKAGES]="1"
  [INCLUDE_CONFIG]="1" [INCLUDE_OMARCHY]="1" [INCLUDE_WEBAPPS]="1"
  [INCLUDE_PLUGINS]="1" [INCLUDE_SECRETS]="0" [SECRETS_MODE]="passphrase"
  [SECRETS_RECIPIENT]="" [PROFILE_URL]="" [ENABLE_UNITS]="ask" [AUR]="ask"
  [SECRET_SCAN]="warn" [CAPTURE_AUTOSTART]="0"
)
declare -A CONFIG_TYPES=(
  [VAULT]="nonempty" [REMOTE]="url" [AUTO_BACKUP]="choice"
  [AUTO_INTERVAL_HOURS]="uint" [AUTO_PUSH]="choice" [INCLUDE_PACKAGES]="choice"
  [INCLUDE_CONFIG]="choice" [INCLUDE_OMARCHY]="choice" [INCLUDE_WEBAPPS]="choice"
  [INCLUDE_PLUGINS]="choice" [INCLUDE_SECRETS]="choice" [SECRETS_MODE]="choice"
  [SECRETS_RECIPIENT]="string" [PROFILE_URL]="url" [ENABLE_UNITS]="choice"
  [AUR]="choice" [SECRET_SCAN]="choice" [CAPTURE_AUTOSTART]="choice"
)
declare -A CONFIG_CHOICES=(
  [AUR]="ask yes no" [ENABLE_UNITS]="ask yes no" [SECRET_SCAN]="warn block off"
  [AUTO_BACKUP]="on off" [AUTO_PUSH]="0 1" [CAPTURE_AUTOSTART]="0 1"
  [INCLUDE_PACKAGES]="0 1" [INCLUDE_CONFIG]="0 1" [INCLUDE_OMARCHY]="0 1"
  [INCLUDE_WEBAPPS]="0 1" [INCLUDE_PLUGINS]="0 1" [INCLUDE_SECRETS]="0 1"
  [SECRETS_MODE]="passphrase recipient"
)
declare -A CFG=()
for config_key in "${CONFIG_KEYS[@]}"; do CFG[$config_key]="${CONFIG_DEFAULTS[$config_key]}"; done
unset config_key

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
    [[ -n $key && -v CONFIG_DEFAULTS[$key] ]] && CFG[$key]="$value"
  done <"$CONFIG_FILE"
  # Older hand-written configs may contain transport credentials. Once loaded,
  # every consumer sees only the credential-free identity.
  CFG[REMOTE]=$(strip_credentials "${CFG[REMOTE]:-}")
  CFG[PROFILE_URL]=$(strip_credentials "${CFG[PROFILE_URL]:-}")
}

save_config() {
  private_dir "$CONFIG_DIR"
  local tmp
  montage_make_temp_file "$CONFIG_DIR/.config.XXXXXX" || die "could not create temporary config"
  tmp="$MONTAGE_TEMP_PATH"
  {
    echo "# mntg configuration. Written by \`mntg set\` and by the panel."
    echo "# Both the CLI and the Quickshell panel read this file; there is no second source."
    echo
    local key
    for key in "${CONFIG_KEYS[@]}"; do
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
# `mntg status --json` exit 2 with no output at all — while the panel reads
# nothing but that command, so the panel's whole backup summary went blank
# without a word anywhere. Nothing below trusts the text any more: a flag is
# read exactly the way cat_enabled reads it, and a number has to be a number.

json_flag() { [[ ${1:-} == 1 ]] && printf 'true' || printf 'false'; }

json_number() {
  local value="${1:-}" fallback="${2:-0}"
  [[ $value =~ ^[0-9]{1,9}$ ]] || value="$fallback"
  printf '%s' "$value"
}

config_status_flag() { json_flag "${CFG[$1]}"; }
config_status_onoff() { [[ ${CFG[$1]} == on ]] && printf true || printf false; }
config_status_number() { json_number "${CFG[$1]}" "${CONFIG_DEFAULTS[$1]}"; }

config_validate_value() {
  local key="$1" value="$2" choice
  case "${CONFIG_TYPES[$key]}" in
    choice)
      for choice in ${CONFIG_CHOICES[$key]}; do [[ $value == "$choice" ]] && return 0; done
      die "$key must be one of: ${CONFIG_CHOICES[$key]} (got: $value)"
      ;;
    uint) [[ $value =~ ^[0-9]+$ ]] || die "$key must be a whole number of hours (got: $value)" ;;
    nonempty) [[ -n $value ]] || die "$key cannot be empty" ;;
    url)
      [[ -z $value ]] && return 0
      case "$key" in
        REMOTE) valid_git_remote "$value" && ! url_has_credentials "$value" ||
          die "$key must be a credential-free HTTPS, SSH, or Git remote" ;;
        PROFILE_URL) valid_public_https "$value" ||
          die "$key must be a credential-free HTTPS URL" ;;
      esac
      ;;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }
private_dir() { mkdir -p "$1" && chmod 700 "$1" 2>/dev/null || true; }

# The panel-owned engine and the headless scheduler are separate processes with
# separate ideas of "busy". Without a lock they will both write the same git
# vault; without the marker file the bar shows nothing while the scheduler runs.
declare -a MONTAGE_CLEANUP_FILES=()
declare -a MONTAGE_CLEANUP_DIRS=()
MONTAGE_TEMP_PATH=""

montage_make_temp_file() {
  local template="${1:-${TMPDIR:-/tmp}/mntg.XXXXXX}" parent path parent_real path_real
  parent=$(dirname "$template")
  parent_real=$(realpath -m -- "$parent") || return 1
  path=$(mktemp "$template") || return 1
  path_real=$(realpath -m -- "$path") || { rm -f -- "$path"; return 1; }
  [[ $path_real == "$parent_real"/* && -f $path && ! -L $path ]] ||
    { rm -f -- "$path"; return 1; }
  MONTAGE_CLEANUP_FILES+=("$path_real")
  MONTAGE_TEMP_PATH="$path_real"
}

montage_make_temp_dir() {
  local template="${1:-${TMPDIR:-/tmp}/mntg.XXXXXX}" parent path parent_real path_real
  parent=$(dirname "$template")
  parent_real=$(realpath -m -- "$parent") || return 1
  path=$(mktemp -d "$template") || return 1
  path_real=$(realpath -m -- "$path") || { rmdir -- "$path" 2>/dev/null; return 1; }
  [[ $path_real == "$parent_real"/* && -d $path && ! -L $path ]] ||
    { rm -rf -- "$path"; return 1; }
  MONTAGE_CLEANUP_DIRS+=("$path_real")
  MONTAGE_TEMP_PATH="$path_real"
}

montage_cleanup() {
  local path
  for path in "${MONTAGE_CLEANUP_FILES[@]:-}"; do
    [[ -n $path && ( -f $path || -L $path ) ]] && rm -f -- "$path" 2>/dev/null
  done
  for path in "${MONTAGE_CLEANUP_DIRS[@]:-}"; do
    [[ -n $path && -d $path && ! -L $path ]] && rm -rf -- "$path" 2>/dev/null
  done
  if [[ -n ${RUNNING_MARKER_TOKEN:-} && -n ${STATE_DIR:-} && -f $STATE_DIR/running ]]; then
    local marker_token=""
    IFS= read -r marker_token <"$STATE_DIR/running" || true
    if [[ $marker_token == "$RUNNING_MARKER_TOKEN" ]]; then
      rm -f -- "$STATE_DIR/running" 2>/dev/null
    fi
  fi
  return 0
}
# `mntg set` is a read-modify-write of one small file, and the panel fires one
# per toggle through execDetached — nine rows now write this way. Two in quick
# succession could read the same config and the later one drop the earlier one's
# change. This is deliberately not the vault lock: a settings change is not
# vault work, and taking that one would make the bar show a backup running.
take_config_lock() {
  private_dir "$CONFIG_DIR"
  exec 8>"$CONFIG_DIR/.lock"
  flock -w 5 8 || die "configuration is busy; try again"
}

take_lock() {
  private_dir "$STATE_DIR"
  exec 9>"$STATE_DIR/lock"
  flock -n 9 || die "another mntg operation is already running"
  OPERATION_LOCKED=1
  # The lock is still taken for a dry run — it clones into a temp directory and
  # reads the vault, and two of those at once is still two — but the marker the
  # bar reads as "busy" is not written, because nothing is happening to this
  # machine.
  if (( ! DRY_RUN )); then
    local marker_token
    marker_token="${BASHPID:-$$}:$(date -u +%s%N):$RANDOM"
    printf '%s\n' "$marker_token" >"$STATE_DIR/running"
    RUNNING_MARKER_TOKEN="$marker_token"
  fi
}

ensure_operation_lock() { (( OPERATION_LOCKED )) || take_lock; }

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
