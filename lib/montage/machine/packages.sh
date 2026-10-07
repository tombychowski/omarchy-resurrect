#!/bin/bash
#
# Neutral machine package operations shared by private-vault restore and
# public-loadout workflows. Owns package/AUR observation, consent, and
# installation helpers; owns no vault, profile, or registry representation.
# Depends on core.sh and safety.sh. Definitions only at source time.

# Stable batch facts are read at most once by each planning/check command. The
# snapshot is process-local and deliberately excludes mutation-sensitive facts.
MACHINE_PACKAGE_SNAPSHOT_READY=0
MACHINE_THEME_SNAPSHOT_READY=0
declare -A MACHINE_INSTALLED_PACKAGES=()
MACHINE_ACTIVE_THEME=""

machine_observation_snapshot_reset() {
  MACHINE_PACKAGE_SNAPSHOT_READY=0
  MACHINE_THEME_SNAPSHOT_READY=0
  MACHINE_INSTALLED_PACKAGES=()
  MACHINE_ACTIVE_THEME=""
}

machine_package_snapshot_build() {
  (( MACHINE_PACKAGE_SNAPSHOT_READY )) && return 0
  [[ -z ${MONTAGE_OBSERVATION_LOG:-} ]] || printf 'package-inventory\n' >>"$MONTAGE_OBSERVATION_LOG"
  MACHINE_INSTALLED_PACKAGES=()
  local package
  while IFS= read -r package; do [[ -n $package ]] && MACHINE_INSTALLED_PACKAGES[$package]=1; done \
    < <(pacman -Qq 2>/dev/null || true)
  MACHINE_PACKAGE_SNAPSHOT_READY=1
}

machine_theme_snapshot_build() {
  (( MACHINE_THEME_SNAPSHOT_READY )) && return 0
  [[ -z ${MONTAGE_OBSERVATION_LOG:-} ]] || printf 'active-theme\n' >>"$MONTAGE_OBSERVATION_LOG"
  MACHINE_ACTIVE_THEME=$(active_theme_name || true)
  MACHINE_THEME_SNAPSHOT_READY=1
}

machine_observation_snapshot_build() {
  machine_package_snapshot_build
  machine_theme_snapshot_build
}

machine_package_present() {
  machine_package_snapshot_build
  [[ -v MACHINE_INSTALLED_PACKAGES[$1] ]]
}

machine_active_theme() {
  machine_theme_snapshot_build
  printf '%s' "$MACHINE_ACTIVE_THEME"
}

aur_denied() { merged_list aur-deny | grep -qxF -- "$1"; }

# Which of these names actually exist on aur.archlinux.org. A name in a vault
# with nothing behind it is the interesting one: a package renamed, deleted, or
# never there — which is also what a typo and a squat look like from here.
#
# Not reaching the AUR is reported and never fatal. This annotates a list; it
# does not gate one.
AUR_KNOWN=""
AUR_PROBED=0
aur_probe() {
  AUR_KNOWN=""
  AUR_PROBED=0
  have curl || return 1
  local pending=("$@") chunk=() name encoded url out
  while (( ${#pending[@]} > 0 )); do
    chunk=("${pending[@]:0:40}")
    pending=("${pending[@]:40}")
    url="https://aur.archlinux.org/rpc/v5/info?"
    for name in "${chunk[@]}"; do
      # A `+` in a query string means a space, and plenty of package names have
      # one. Everything else valid_pkg admits is safe unencoded.
      encoded="${name//+/%2B}"
      url+="arg%5B%5D=$encoded&"
    done
    # -g: the encoded brackets are part of the URL, not a curl range glob.
    out=$(curl -gfsSL --max-time 15 -- "${url%&}" 2>/dev/null) || return 1
    jq -e . >/dev/null 2>&1 <<<"$out" || return 1
    AUR_KNOWN+=$'\n'$(jq -r '.results[]?.Name // empty' <<<"$out")
  done
  AUR_PROBED=1
  return 0
}

aur_knows() { grep -qxF -- "$1" <<<"$AUR_KNOWN"; }

# Which of these names the official repositories now carry. A package can move
# from the AUR into extra, and once it has, building it from a PKGBUILD is the
# wrong way to get it. One batched call: pacman prints what it knows and exits
# non-zero for the rest, which is exactly the shape wanted here.
IN_REPOS=""
repo_probe() {
  IN_REPOS=$(pacman -Si -- "$@" 2>/dev/null | sed -n 's/^Name[[:space:]]*: //p' || true)
}

# What to say about one name beyond the name itself. Empty for the ordinary
# case, so the list stays readable and the odd entry stands out.
aur_note() {
  local name="$1"
  (( AUR_PROBED )) && ! aur_knows "$name" && { printf 'not on aur.archlinux.org'; return 0; }
  grep -qxF -- "$name" <<<"$IN_REPOS" && { printf 'now in the official repos'; return 0; }
  printf ''
}

# build | review | skip — decided once, by the flag, then the setting, then the
# person at the terminal. AUR_KEPT holds the names that survived the deny list.
AUR_MODE="skip"
AUR_KEPT=()
aur_gate() {
  local category="$1"; shift
  local names=("$@")
  AUR_KEPT=()
  AUR_MODE="skip"

  local name denied=()
  for name in "${names[@]}"; do
    if aur_denied "$name"; then denied+=("$name"); else AUR_KEPT+=("$name"); fi
  done
  (( ${#denied[@]} == 0 )) ||
    step_warn "$category" "$(plural "${#denied[@]}" "AUR package") on your deny list: ${denied[*]}"
  (( ${#AUR_KEPT[@]} > 0 )) || return 0

  # Settled without a prompt?
  local decision="${AUR_CHOICE:-}"
  if [[ -z $decision ]]; then
    case "${CFG[AUR]:-ask}" in
      yes|1|on|true) decision=yes ;;
      no|0|off|false) decision=no ;;
      *) decision=ask ;;
    esac
  fi
  if [[ $decision == yes ]]; then
    AUR_MODE=$( (( AUR_REVIEW )) && printf 'review' || printf 'build' )
    return 0
  fi
  if [[ $decision == no ]]; then
    step_skip "$category" "$(plural "${#AUR_KEPT[@]}" "AUR package") skipped (AUR=no)"
    return 0
  fi
  if (( PORCELAIN )) || [[ ! -t 0 ]]; then
    step_skip "$category" "$(plural "${#AUR_KEPT[@]}" "AUR package") skipped — no terminal to ask at; pass --aur to build them"
    return 0
  fi

  if ! aur_probe "${AUR_KEPT[@]}"; then
    note "could not reach aur.archlinux.org to check these names"
  fi
  repo_probe "${AUR_KEPT[@]}"

  printf '\n%s%s from the AUR:%s\n\n' "$c_bold" "$(plural "${#AUR_KEPT[@]}" package)" "$c_reset"
  local note_text
  for name in "${AUR_KEPT[@]}"; do
    note_text=$(aur_note "$name")
    if [[ -n $note_text ]]; then
      printf '    %-32s %s%s%s\n' "$name" "$c_yellow" "$note_text" "$c_reset"
    else
      printf '    %s\n' "$name"
    fi
  done
  printf '\n%sEach one is a PKGBUILD fetched from aur.archlinux.org and run here as it\nbuilds. Nothing signs them and nobody reviews them.%s\n\n' \
    "$c_dim" "$c_reset"
  printf '  %s[y]%s build them   %s[r]%s review each PKGBUILD first   %s[N]%s skip\n' \
    "$c_green" "$c_reset" "$c_blue" "$c_reset" "$c_dim" "$c_reset"
  local reply=""
  read -r -p "  > " reply || reply=""
  case "$reply" in
    [yY]*) AUR_MODE="build" ;;
    [rR]*) AUR_MODE="review" ;;
    *)     AUR_MODE="skip"; step_skip "$category" "$(plural "${#AUR_KEPT[@]}" "AUR package") skipped" ;;
  esac
  return 0
}

# The two ways to run the helper. `build` is the unattended one: yay answers its
# own prompts. `review` is yay's normal interactive flow, where it shows the
# PKGBUILD and the diff since the last build and waits.
aur_install() {
  local category="$1"; shift
  case "$AUR_MODE" in
    build)
      step_start "$category" "Building $(plural "$#" "AUR package")"
      yay -S --needed --noconfirm --answerclean None --answerdiff None -- "$@"
      ;;
    review)
      step_start "$category" "Building $(plural "$#" "AUR package") — yay will show each PKGBUILD"
      yay -S --needed -- "$@"
      ;;
    *) return 1 ;;
  esac
}
