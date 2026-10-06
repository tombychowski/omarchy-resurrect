#!/bin/bash
#
# Vault verification and deferred actions: machine comparison, explicit
# credential scanning, and captured-unit enablement.
# Depends on core.sh, safety.sh, vault/common.sh, and vault backup/restore
# primitives. Used by verify, scan, and enable-units. Definitions only until
# implementation is loaded without source-time work.

# ==================================================================== VERIFY
#
# A restore reports what it did. This reports what is true now: the vault as a
# specification, the machine as the thing being checked against it. They are
# different questions — a restore can finish cleanly and still leave a package
# uninstalled because you said no to the AUR, and a machine can drift months
# later without any restore having run at all.
#
# Exits non-zero when the machine does not match, so it can be the last line of
# a provisioning script.

# Names out of the vault, filtered and sorted, one per line.
verify_list() {
  local file="$1" predicate="$2" line
  [[ -f $file ]] || return 0
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    "$predicate" "$line" && printf '%s\n' "$line"
  done <"$file" | sort -u
}

# Each category reports a list of names, and a name can contain a space: a web
# app label is two words as often as not. So the lists are joined with the unit
# separator the vault's own tables use, and turned into spaces only where they
# are printed or counted. Splitting them on spaces put "Microsoft Teams" in the
# JSON as two entries, so a caller counting them got a number that was not a
# count.
list_join() { local IFS=$'\037'; printf '%s' "$*"; }
list_display() { printf '%s' "${1//$'\037'/ }"; }
# How many names a list holds. Counting words would call "Microsoft Teams" two
# names, which is how the refused line came to say "2 entries" about one.
list_count() {
  [[ -n ${1:-} ]] || { printf '0'; return 0; }
  printf '%s' "$1" | tr $'\037' '\n' | grep -c . || true
  return 0
}

cmd_verify() {
  local as_json=0
  while (( $# > 0 )); do
    case "$1" in
      --json) as_json=1; shift ;;
      *) die "unknown verify option: $1" ;;
    esac
  done
  resolve_vault
  has_manifest || die "no vault at $VAULT — run: ress backup"
  validate_vault_artifact
  local manifest; manifest=$(manifest_path)

  # Each category reports three things: how many the vault names, how many are
  # here, and which ones are not. A fourth list holds what a restore would refuse
  # outright: those are not missing, they are not restorable, and counting them
  # as want/have is what made verify report a match where a restore had work.
  local -A want=() have=() missing=() refused=()

  # ---- packages
  local installed
  ress_make_temp_file || die "could not create verification workspace"
  installed="$RESS_TEMP_PATH"
  pacman -Qq 2>/dev/null | sort -u >"$installed" || true
  local wanted_pkgs
  ress_make_temp_file || die "could not create verification workspace"
  wanted_pkgs="$RESS_TEMP_PATH"
  { verify_list "$VAULT/packages/native.txt" valid_pkg
    verify_list "$VAULT/packages/foreign.txt" valid_pkg
  } | sort -u >"$wanted_pkgs"
  want[packages]=$(count_lines "$wanted_pkgs")
  missing[packages]=$(comm -23 "$wanted_pkgs" "$installed" | tr '\n' $'\037' | sed 's/\037$//')
  have[packages]=$(( ${want[packages]} - $(list_count "${missing[packages]}") ))
  rm -f "$installed" "$wanted_pkgs"

  # ---- dotfiles: what a restore would still have to write
  want[config]=0; have[config]=0; missing[config]=""
  if [[ -d $VAULT/home ]]; then
    want[config]=$(find "$VAULT/home" -type f 2>/dev/null | wc -l)
    local differing
    # -i itemises; a line starting >f is a file whose contents or metadata
    # differ from the vault's copy, which is exactly "not restored".
    differing=$(rsync -ain --safe-links -- "$VAULT/home/" "$HOME/" 2>/dev/null |
      grep -c '^>f' || true)
    have[config]=$(( ${want[config]} - differing ))
    (( differing > 0 )) && missing[config]="$differing differ from the vault"
  fi

  # ---- themes
  local themes=0 themes_here=0 missing_themes=() name url tsha
  if [[ -f $VAULT/omarchy/themes.tsv ]]; then
    while IFS=$'\037' read -r name url tsha; do
      url=$(strip_credentials "$url")
      [[ -n $name ]] || continue
      valid_theme "$name" || continue
      themes=$((themes + 1))
      if [[ -d $HOME/.config/omarchy/themes/$name || -d $OMARCHY_DIR/themes/$name ]]; then
        themes_here=$((themes_here + 1))
      else
        missing_themes+=("$name")
      fi
    done < <(tr '\t' '\037' <"$VAULT/omarchy/themes.tsv")
  fi
  want[themes]=$themes; have[themes]=$themes_here; missing[themes]="$(list_join "${missing_themes[@]:-}")"

  # ---- web apps
  # A launcher a restore would refuse is not a launcher this can count. The rule
  # for what a restore can rebuild lives in launcher_travels, and this is the
  # same call: verify used to answer "11 of 11" for a vault where a restore would
  # have rebuilt nine, which is a machine reported as matching when it was not.
  #
  # The name this looks for is the one in the file, because that is the name a
  # restore rebuilds under. Matching on the vault's file name instead meant a
  # vault whose launcher file is not named after its Name= field had verify
  # report missing a launcher the restore had just created.
  local webapps=0 webapps_here=0 missing_webapps=() refused_webapps=() desktop app label
  if [[ -d $VAULT/webapps/apps ]]; then
    for desktop in "$VAULT"/webapps/apps/*.desktop; do
      [[ -f $desktop ]] || continue
      app=$(basename "$desktop" .desktop)
      label=$(sed -n 's/^Name=//p' "$desktop" | head -1)
      [[ -n $label ]] || label="$app"
      if ! launcher_travels "$desktop" || ! valid_label "$label"; then
        refused_webapps+=("$(plain "$label")"); continue
      fi
      webapps=$((webapps + 1))
      if [[ -f $HOME/.local/share/applications/$label.desktop ]]; then
        webapps_here=$((webapps_here + 1))
      else
        missing_webapps+=("$label")
      fi
    done
  fi
  want[webapps]=$webapps; have[webapps]=$webapps_here; missing[webapps]="$(list_join "${missing_webapps[@]:-}")"
  refused[webapps]="$(list_join "${refused_webapps[@]:-}")"

  # ---- plugins
  # A plugin a restore cannot clone is not a plugin this can count. It is in the
  # vault and it will never be on the far side, so counting it as missing left a
  # machine that could not be brought into line being told to restore, for good.
  # The rule is the restore's own: a remote it will not take, or a commit that is
  # not a commit, is a refusal rather than a gap.
  local plugins=0 plugins_here=0 missing_plugins=() refused_plugins=() id purl psha
  if [[ -f $VAULT/plugins/plugins.tsv ]]; then
    while IFS=$'\037' read -r id purl _ psha; do
      purl=$(strip_credentials "$purl")
      [[ -n $id ]] || continue
      if ! valid_id "$id"; then refused_plugins+=("$(plain "$id")"); continue; fi
      if [[ -z $purl ]] || ! valid_git_remote "$purl"; then
        refused_plugins+=("$(plain "$id")"); continue
      fi
      if [[ -n $psha ]] && ! valid_sha "$psha"; then
        refused_plugins+=("$(plain "$id")"); continue
      fi
      plugins=$((plugins + 1))
      if [[ -f $HOME/.config/omarchy/plugins/$id/manifest.json ]]; then
        plugins_here=$((plugins_here + 1))
      else
        missing_plugins+=("$id")
      fi
    done < <(tr '\t' '\037' <"$VAULT/plugins/plugins.tsv")
  fi
  want[plugins]=$plugins; have[plugins]=$plugins_here; missing[plugins]="$(list_join "${missing_plugins[@]:-}")"
  refused[plugins]="$(list_join "${refused_plugins[@]:-}")"

  # ---- services
  local units=0 units_here=0 missing_units=() unit
  if [[ -s $VAULT/services/user-units.txt ]] && have systemctl; then
    while IFS= read -r unit; do
      [[ -n $unit ]] || continue
      valid_unit "$unit" || continue
      units=$((units + 1))
      if systemctl --user is-enabled -- "$unit" >/dev/null 2>&1; then
        units_here=$((units_here + 1))
      else
        missing_units+=("$unit")
      fi
    done <"$VAULT/services/user-units.txt"
  fi
  want[services]=$units; have[services]=$units_here; missing[services]="$(list_join "${missing_units[@]:-}")"

  local order=(packages config themes webapps plugins services)
  local category complete=1
  for category in "${order[@]}"; do
    (( ${have[$category]} < ${want[$category]} )) && complete=0
  done

  if (( as_json )); then
    local rows=""
    for category in "${order[@]}"; do
      rows+=$(jq -nc --arg k "$category" \
        --argjson want "${want[$category]}" \
        --argjson have "${have[$category]}" \
        --arg missing "${missing[$category]}" \
        --arg refused "${refused[$category]:-}" \
        '{key: $k, want: $want, have: $have,
          missing: ($missing | split("\u001f") | map(select(length > 0))),
          refused: ($refused | split("\u001f") | map(select(length > 0)))}')
      rows+=$'\n'
    done
    printf '%s' "$rows" | jq -s \
      --arg vault "$VAULT" \
      --argjson complete "$complete" \
      --argjson manifest "$(cat "$manifest")" \
      '{vault: $vault, complete: ($complete == 1),
        takenAt: $manifest.createdAt, takenFrom: $manifest.machine.hostname,
        categories: (map({key: .key, value: {want: .want, have: .have, missing: .missing, refused: .refused}}) | from_entries)}'
    (( complete )) || return 1
    return 0
  fi

  printf '%sress verify%s — this machine against %s taken from %s\n\n' \
    "$c_bold" "$c_reset" \
    "$(plain "$(jq -r '.createdAt // "?"' "$manifest")")" \
    "$(plain "$(jq -r '.machine.hostname // "?"' "$manifest")")"

  local detail refused_n
  for category in "${order[@]}"; do
    refused_n=$(list_count "${refused[$category]:-}")
    if (( ${want[$category]} == 0 )); then
      # A category whose only entries are ones a restore would refuse is not
      # "not in this vault": there is something here, and it will not travel.
      (( refused_n > 0 )) ||
        printf '  %-11s %snot in this vault%s\n' "$category" "$c_dim" "$c_reset"
    else
      detail="$(list_display "${missing[$category]}")"
      if (( ${have[$category]} >= ${want[$category]} )); then
        printf '  %-11s %s✓%s %s of %s\n' "$category" "$c_green" "$c_reset" \
          "${have[$category]}" "${want[$category]}"
      else
        printf '  %-11s %s✗%s %s of %s   %s%s%s\n' "$category" "$c_yellow" "$c_reset" \
          "${have[$category]}" "${want[$category]}" "$c_dim" "$(plain "${detail:0:80}")" "$c_reset"
      fi
    fi
    (( refused_n == 0 )) || printf '  %-11s %s%s a restore cannot rebuild: %s%s\n' \
      "$category" "$c_dim" "$(plural "$refused_n" "entry" "entries")" "$(list_display "${refused[$category]}")" "$c_reset"
  done
  printf '\n'
  if (( complete )); then
    printf '%sThis machine matches the vault.%s\n' "$c_green" "$c_reset"
    return 0
  fi

  # A dotfile that differs is not the same as a package that is missing. One
  # means a restore did not finish; the other usually means you have been using
  # the machine, which is what it is for.
  local absent=0 other
  for other in packages themes webapps plugins services; do
    (( ${have[$other]} < ${want[$other]} )) && absent=1
  done
  if (( absent )); then
    printf '%sSome of the vault is not on this machine.%s Run: ress restore\n' "$c_yellow" "$c_reset"
    (( ${want[services]} > ${have[services]} )) &&
      printf '%sServices are only ever enabled on purpose: ress enable-units%s\n' "$c_dim" "$c_reset"
  fi
  if (( ${have[config]} < ${want[config]} )); then
    printf '%sDotfiles here differ from the vault%s — usually because you have edited them\nsince the backup. `ress diff` shows what changed; `ress backup` records it.\n' \
      "$c_dim" "$c_reset"
  fi
  return 1
}

# The scan the backup runs, on demand — before a push, or after adding something
# to the capture list and wondering what came with it.
cmd_scan() {
  local as_json=0
  while (( $# > 0 )); do
    case "$1" in
      --json) as_json=1; shift ;;
      *) die "unknown scan option: $1" ;;
    esac
  done
  resolve_vault
  has_manifest || die "no vault at $VAULT — run: ress backup"
  validate_vault_artifact

  secret_scan "$VAULT" || true

  if (( as_json )); then
    printf '%s\n' "$SECRET_FINDINGS" | jq -Rs '
      split("\n") | map(select(length > 0) | split("\t") | {file: .[0], rule: .[1]})
      | {findings: ., count: length}'
    [[ -n $SECRET_FINDINGS ]] && return 1
    return 0
  fi

  if [[ -z $SECRET_FINDINGS ]]; then
    printf '%sNothing in this vault has the shape of a credential.%s\n' "$c_green" "$c_reset"
    printf '%sThat is a check against known token formats and self-naming assignments,\nnot a proof: a secret with no shape to it looks like any other string.%s\n' \
      "$c_dim" "$c_reset"
    return 0
  fi
  report_secret_findings
  return 1
}

# The other half of "restore never turns anything on by itself": a way to turn
# them on afterwards, on purpose, having read what they run.
cmd_enable_units() {
  local all=0 wanted=()
  while (( $# > 0 )); do
    case "$1" in
      --all|-a) all=1; shift ;;
      --list|-l) all=2; shift ;;
      -*) die "unknown enable-units option: $1" ;;
      *) wanted+=("$1"); shift ;;
    esac
  done

  resolve_vault
  has_manifest || die "no vault at $VAULT — run: ress backup"
  have systemctl || die "systemctl is not here, so there is nothing to enable"

  local units=() unit
  while IFS= read -r unit; do [[ -n $unit ]] && units+=("$unit"); done < <(pending_units)

  # Nothing pending at all is a different answer from "none of the ones you
  # named are pending", and saying the first when the second is true told you
  # the machine was in a state it was not in — with exit 0, so a script could
  # not tell either.
  local pending_total=${#units[@]}
  local unmatched=0
  if (( ${#wanted[@]} > 0 )); then
    local chosen=() name found
    for name in "${wanted[@]}"; do
      found=0
      for unit in "${units[@]:-}"; do [[ $unit == "$name" ]] && { chosen+=("$name"); found=1; break; }; done
      if (( ! found )); then
        unmatched=$((unmatched + 1))
        printf '%s%s is not a service this vault has enabled, or it is already enabled here.%s\n' \
          "$c_yellow" "$(plain "$name")" "$c_reset" >&2
      fi
    done
    units=()
    (( ${#chosen[@]} > 0 )) && units=("${chosen[@]}")
  fi

  if (( ${#units[@]} == 0 )); then
    if (( unmatched > 0 )); then
      # The vault does have work outstanding; you just did not name any of it.
      (( pending_total > 0 )) &&
        printf '%s%s in this vault, still not enabled here. Run without a name to see them.%s\n' \
          "$c_dim" "$(plural "$pending_total" "user service")" "$c_reset"
      return 1
    fi
    printf '%sEvery user service in this vault is already enabled here.%s\n' "$c_green" "$c_reset"
    return 0
  fi

  printf '%s%s from this vault, not enabled here:%s\n\n' \
    "$c_bold" "$(plural "${#units[@]}" "user service")" "$c_reset"
  list_units "${units[@]}"
  printf '\n'

  if (( all == 2 )); then return 0; fi
  if (( ! all )); then
    confirm "Enable $(plural "${#units[@]}" "user service")?" || { printf 'Nothing was enabled.\n'; return 0; }
  fi

  enable_units "${units[@]}"
  printf '%s%s enabled.%s\n' "$c_green" "$(plural "$ENABLED_UNITS" "user service")" "$c_reset"
  (( ENABLED_UNITS > 0 )) &&
    printf '%sEnabled means "starts with your next session". `systemctl --user start <unit>` starts one now.%s\n' \
      "$c_dim" "$c_reset"
  return 0
}

# The plugin lives under ~/.config/omarchy/plugins, which is not on anyone's
# PATH. One symlink into ~/.local/bin makes `ress` a real command; the plugin
# folder itself stays symlink-free, which the manifest validator requires.
