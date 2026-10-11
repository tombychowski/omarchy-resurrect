#!/bin/bash
#
# Shared mntg runtime: constants, configured paths, output/protocol primitives,
# configuration, locks, generic helpers, and process-wide cleanup.
#
# Loaded by bin/mntg after it establishes PLUGIN_DIR. Owns CFG, global command
# flags, bounded temporary cleanup, and the primary operation/config locks. Used by
# every loadout workflow. This module defines state and functions only;
# it must not parse arguments, install traps, perform I/O work, or emit output
# merely because it was sourced.

VERSION="1.0.0"
DEFAULTS_DIR="$PLUGIN_DIR/defaults"

# Omarchy exports OMARCHY_PATH for exactly this, and the shell's own plugin
# catalog reads it rather than the fixed path. Following it means a checkout
# running under `omarchy dev link` sees its own themes and version, instead of
# the ones installed system-wide.
OMARCHY_DIR="${OMARCHY_PATH:-/usr/share/omarchy}"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/montage"
CONFIG_FILE="$CONFIG_DIR/config"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/montage"

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
CONFIG_KEYS=(AUR)
declare -A CONFIG_DEFAULTS=([AUR]="ask")
declare -A CONFIG_TYPES=([AUR]="choice")
declare -A CONFIG_CHOICES=([AUR]="ask yes no")
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
  return 0
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

config_validate_value() {
  local key="$1" value="$2" choice
  case "${CONFIG_TYPES[$key]}" in
    choice)
      for choice in ${CONFIG_CHOICES[$key]}; do [[ $value == "$choice" ]] && return 0; done
      die "$key must be one of: ${CONFIG_CHOICES[$key]} (got: $value)"
      ;;
    *) die "internal error: unsupported setting type for $key" ;;
  esac
}

config_aur_policy() {
  case "${CFG[AUR]:-}" in
    ask|yes|no) printf '%s' "${CFG[AUR]}" ;;
    *) printf 'ask' ;;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }
private_dir() { mkdir -p "$1" && chmod 700 "$1" 2>/dev/null || true; }

# Mutating commands share one lock and publish a tokenized marker while they
# hold it. Status accepts the marker only while the operation lock is genuinely
# held, so a stale file cannot make the bar report fabricated activity.
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
# per selection through execDetached. Two in quick
# succession could read the same config and the later one drop the earlier one's
# change. This is deliberately not the operation lock: configuration does not
# mutate a library or applied loadout and must not make the bar show activity.
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
  # Dry runs still take the lock so two plans do not race over shared temporary
  # or advisory evidence, but publish no marker because machine state is not
  # changing.
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

# Concatenate the shipped list with the user's, dropping comments and blanks.
merged_list() {
  local name="$1"
  { [[ -f "$DEFAULTS_DIR/$name.txt" ]] && cat "$DEFAULTS_DIR/$name.txt"
    [[ -f "$CONFIG_DIR/$name" ]] && cat "$CONFIG_DIR/$name"
  } 2>/dev/null | sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d'
}
