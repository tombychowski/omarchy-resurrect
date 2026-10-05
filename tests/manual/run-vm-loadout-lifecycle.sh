#!/usr/bin/env bash

# Destructive fresh-VM validation for the applied-loadout lifecycle.
# Run only on the disposable montage-target VM from an interactive SSH TTY so
# pacman can ask for sudo credentials. The script deliberately refuses to
# start unless the tracked loadout state and every disposable fixture resource
# are absent.

set -Eeuo pipefail

validation_root=${RESS_VM_VALIDATION_ROOT:-$HOME/.local/share/ress-validation}
ress=$validation_root/current/bin/ress
profile_a=$validation_root/profiles/vm-loadout-a.json
profile_b=$validation_root/profiles/vm-loadout-b.json
registry=${XDG_STATE_HOME:-$HOME/.local/state}/ress/loadouts.json
plugin_dir=$HOME/.config/omarchy/plugins/tsouth89.resurrect
theme_state=$HOME/.local/state/omarchy/current/theme.name
canary=$HOME/.local/share/ress-vm-canary/data
log=$validation_root/target-lifecycle.log

export OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}
export OMARCHY_THEME_HEADLESS=1
export OMARCHY_THEME_SKIP_BACKGROUND=1

mkdir -p "$validation_root" "$(dirname "$canary")"
exec > >(tee -a "$log") 2>&1

phase() { printf '\n===== %s =====\n' "$*"; }
fail() { printf 'VALIDATION FAILURE: %s\n' "$*" >&2; exit 1; }
require_absent_package() { pacman -Q "$1" >/dev/null 2>&1 && fail "package $1 is not initially absent" || :; }
require_present_package() { pacman -Q "$1" >/dev/null 2>&1 || fail "package $1 is missing"; }
current_theme() { cat "$theme_state" 2>/dev/null || true; }
loadout_json() { "$ress" loadout list --json --contents; }
loadout_count() { loadout_json | jq '.loadouts | length'; }
id_for() {
  local name=$1
  loadout_json | jq -r --arg name "$name" '.loadouts[] | select(.name == $name) | .id'
}
assert_empty_registry() {
  local state
  state=$(loadout_json)
  jq -e '.loadouts == []' <<<"$state" >/dev/null || fail "tracked loadouts remain"
  if [[ -f $registry ]]; then
    jq -e '.resources == [] and .claims == [] and .operation == null' "$registry" >/dev/null ||
      fail "registry relationships were not fully cleaned"
  fi
}
assert_fixture_absent() {
  local package
  for package in tree figlet sl; do require_absent_package "$package"; done
  [[ ! -e $plugin_dir ]] || fail "fixture plugin remains"
  [[ ! -e $HOME/.config/omarchy/themes/sunset-drive ]] || fail "sunset-drive remains"
  [[ ! -e $HOME/.config/omarchy/themes/hermarchy ]] || fail "hermarchy remains"
  [[ ! -e $HOME/.local/share/applications/Ress\ VM\ A.desktop ]] || fail "Ress VM A launcher remains"
  [[ ! -e $HOME/.local/share/applications/Ress\ VM\ B.desktop ]] || fail "Ress VM B launcher remains"
}
assert_healthy() {
  local result
  result=$("$ress" loadout check --json) || fail "loadout check reported drift"
  jq -e '.healthy == true and ([.loadouts[] | .state == "healthy" and .attentionCount == 0] | all)' <<<"$result" >/dev/null ||
    fail "loadout check JSON was not healthy"
}
remove_plugin_without_live_shell() {
  local shim rc=0
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
  PATH="$shim:$PATH" omarchy plugin remove --yes tsouth89.resurrect || rc=$?
  rm -f "$shim/omarchy-shell"
  rmdir "$shim" 2>/dev/null || true
  return "$rc"
}
apply_pair() {
  "$ress" apply --yes --no-aur "$profile_a"
  "$ress" apply --yes --no-aur "$profile_b"
  [[ $(loadout_count) == 2 ]] || fail "two loadouts were not tracked"
  require_present_package tree
  require_present_package figlet
  require_present_package sl
  [[ -d $plugin_dir ]] || fail "shared plugin was not installed"
  [[ -d $HOME/.config/omarchy/themes/sunset-drive ]] || fail "sunset-drive was not installed"
  [[ -d $HOME/.config/omarchy/themes/hermarchy ]] || fail "hermarchy was not installed"
  [[ $(current_theme) == hermarchy ]] || fail "last-applied theme did not win"
  assert_healthy
  "$ress" loadout list --details
  "$ress" resource show package:tree
  "$ress" resource show plugin:tsouth89.resurrect
}

trap 'printf "VALIDATION STOPPED at line %s (exit %s). State and log were preserved for inspection.\n" "$LINENO" "$?" >&2' ERR

[[ -x $ress ]] || fail "validation ress executable is missing: $ress"
jq -e '.name == "VM Lifecycle A"' "$profile_a" >/dev/null || fail "profile A is missing or wrong"
jq -e '.name == "VM Lifecycle B"' "$profile_b" >/dev/null || fail "profile B is missing or wrong"
resume_cycle1_removal=0
resume_cycle1_final=0
resume_modified_decision=0
if [[ ${RESS_VM_RESUME_MODIFIED_DECISION:-0} == 1 ]]; then
  phase "resume checkpoint: modified plugin awaits an explicit decision"
  [[ $(loadout_count) == 1 ]] || fail "modified-decision resume requires exactly one tracked loadout"
  baseline=$(jq -r '.baseline.activeTheme // ""' "$registry")
  [[ $baseline == tokyo-night ]] || fail "resume baseline is not tokyo-night"
  baseline_orphans=()
  [[ -f $canary && $(<"$canary") == 'preserve me' ]] || fail "resume canary is missing or changed"
  id_a=$(id_for 'VM Lifecycle A')
  jq -e --arg id "$id_a" '.operation == null and any(.loadouts[]; .id == $id and .state == "healthy")' "$registry" >/dev/null ||
    fail "decision-required preview unexpectedly started a removal transaction"
  [[ -n $(git -C "$plugin_dir" status --porcelain) ]] || fail "plugin is not modified at the resume checkpoint"
  resume_modified_decision=1
elif [[ ${RESS_VM_RESUME_CYCLE1_FINAL:-0} == 1 ]]; then
  phase "resume checkpoint: cycle 1 final plugin removal is pending"
  [[ $(loadout_count) == 1 ]] || fail "final-removal resume requires exactly one tracked loadout"
  baseline=$(jq -r '.baseline.activeTheme // ""' "$registry")
  [[ $baseline == tokyo-night ]] || fail "resume baseline is not tokyo-night"
  baseline_orphans=()
  [[ -f $canary && $(<"$canary") == 'preserve me' ]] || fail "resume canary is missing or changed"
  id_b=$(id_for 'VM Lifecycle B')
  jq -e --arg id "$id_b" '.loadouts[] | select(.id == $id and .state == "removal-pending")' "$registry" >/dev/null ||
    fail "loadout B is not at the expected removal-pending checkpoint"
  "$ress" loadout remove --yes "$id_b"
  resume_cycle1_final=1
elif [[ ${RESS_VM_RESUME_CYCLE1_REMOVAL:-0} == 1 ]]; then
  phase "resume checkpoint: cycle 1 first removal is pending"
  [[ $(loadout_count) == 2 ]] || fail "removal resume requires exactly two tracked loadouts"
  baseline=$(jq -r '.baseline.activeTheme // ""' "$registry")
  [[ $baseline == tokyo-night ]] || fail "resume baseline is not tokyo-night"
  baseline_orphans=()
  [[ -f $canary && $(<"$canary") == 'preserve me' ]] || fail "resume canary is missing or changed"
  id_a=$(id_for 'VM Lifecycle A')
  id_b=$(id_for 'VM Lifecycle B')
  jq -e --arg id "$id_a" '.loadouts[] | select(.id == $id and .state == "removal-pending")' "$registry" >/dev/null ||
    fail "loadout A is not at the expected removal-pending checkpoint"
  "$ress" loadout remove --yes "$id_a"
  resume_cycle1_removal=1
elif [[ ${RESS_VM_RESUME_AFTER_PAIR:-0} == 1 ]]; then
  phase "resume checkpoint: cycle 1 pair is already applied"
  [[ $(loadout_count) == 2 ]] || fail "resume requires exactly two tracked loadouts"
  baseline=$(jq -r '.baseline.activeTheme // ""' "$registry")
  [[ $baseline == tokyo-night ]] || fail "resume baseline is not tokyo-night"
  baseline_orphans=()
  [[ -f $canary && $(<"$canary") == 'preserve me' ]] || fail "resume canary is missing or changed"
  id_a=$(id_for 'VM Lifecycle A')
  id_b=$(id_for 'VM Lifecycle B')
  [[ -n $id_a && -n $id_b ]] || fail "resume loadout ids are missing"
  assert_healthy
else
  phase "preflight: clean disposable boundary"
  [[ $(loadout_count) == 0 ]] || fail "target already tracks a loadout"
  assert_fixture_absent
  baseline=$(current_theme)
  [[ $baseline == tokyo-night ]] || fail "expected clean target baseline tokyo-night, got ${baseline:-missing}"
  printf 'preserve me\n' >"$canary"
  mapfile -t baseline_orphans < <(pacman -Qtdq 2>/dev/null || true)
  printf 'Host: %s\nBaseline theme: %s\nPre-existing orphans: %s\n' "$(hostname)" "$baseline" "${#baseline_orphans[@]}"

  phase "cycle 1: apply A then B; remove A then B"
  apply_pair
  id_a=$(id_for 'VM Lifecycle A')
  id_b=$(id_for 'VM Lifecycle B')
  [[ -n $id_a && -n $id_b ]] || fail "could not resolve loadout ids"
fi

if (( ! resume_modified_decision )); then
  if (( ! resume_cycle1_final )); then
    if (( ! resume_cycle1_removal )); then
      "$ress" loadout remove --dry-run "$id_a"
      "$ress" loadout remove --yes "$id_a"
    fi
    [[ $(loadout_count) == 1 ]] || fail "first claim release did not leave one loadout"
    require_present_package tree
    require_present_package sl
    require_absent_package figlet
    [[ -d $plugin_dir ]] || fail "shared plugin was removed with the first claim"
    [[ $(current_theme) == hermarchy ]] || fail "removing standby theme changed the effective theme"
    assert_healthy

    "$ress" loadout remove --dry-run "$id_b"
    "$ress" loadout remove --yes "$id_b"
  fi
  assert_empty_registry
  assert_fixture_absent
  [[ $(current_theme) == "$baseline" ]] || fail "final removal did not restore theme baseline"

  phase "cycle 2: apply A then B; remove B then A with modified-plugin decision"
  apply_pair
  id_a=$(id_for 'VM Lifecycle A')
  id_b=$(id_for 'VM Lifecycle B')
  "$ress" loadout remove --yes "$id_b"
  [[ $(loadout_count) == 1 ]] || fail "opposite-order first removal did not leave one loadout"
  require_present_package tree
  require_present_package figlet
  require_absent_package sl
  [[ -d $plugin_dir ]] || fail "shared plugin was removed before its final claim"
  [[ $(current_theme) == sunset-drive ]] || fail "effective-theme removal did not activate the remaining request"
  assert_healthy

  printf 'deliberate live validation modification\n' >"$plugin_dir/.ress-live-validation-marker"
  trap - ERR
  set +e
  "$ress" loadout remove --yes "$id_a"
  remove_rc=$?
  set -e
  trap 'printf "VALIDATION STOPPED at line %s (exit %s). State and log were preserved for inspection.\n" "$LINENO" "$?" >&2' ERR
  [[ $remove_rc == 2 ]] || fail "modified plugin removal returned $remove_rc instead of decision-required (2)"
  jq -e --arg id "$id_a" '.operation == null and any(.loadouts[]; .id == $id and .state == "healthy")' "$registry" >/dev/null ||
    fail "decision-required preview unexpectedly started a removal transaction"
  [[ -d $plugin_dir ]] || fail "modified plugin was removed without a decision"
fi

"$ress" loadout remove --yes "$id_a" --keep-modified
assert_empty_registry
[[ -d $plugin_dir ]] || fail "keep-modified did not preserve the plugin"
remove_plugin_without_live_shell
[[ ! -e $plugin_dir ]] || fail "manual cleanup did not remove the released plugin"
assert_fixture_absent
[[ $(current_theme) == "$baseline" ]] || fail "opposite-order final removal did not restore baseline"

phase "cycle 3: preserve an external theme selection"
"$ress" apply --yes --no-aur "$profile_a"
id_a=$(id_for 'VM Lifecycle A')
omarchy theme set "$baseline"
[[ $(current_theme) == "$baseline" ]] || fail "external theme selection did not take effect"
"$ress" loadout remove --yes "$id_a"
assert_empty_registry
assert_fixture_absent
[[ $(current_theme) == "$baseline" ]] || fail "cleanup overwrote the external theme selection"

phase "preservation and no-orphan-sweep assertions"
[[ $(<"$canary") == 'preserve me' ]] || fail "unrelated application data canary changed"
for orphan in "${baseline_orphans[@]}"; do
  pacman -Q "$orphan" >/dev/null 2>&1 || fail "pre-existing orphan $orphan was removed"
done

trap - ERR
printf '\nTARGET LIFECYCLE VALIDATION PASSED\n'
printf 'Log: %s\n' "$log"
