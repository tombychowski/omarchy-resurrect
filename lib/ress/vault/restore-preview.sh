#!/bin/bash
#
# Restore-wide preview and consent reporting.
# Depends on core.sh, safety.sh, machine/packages.sh, vault/common.sh, and
# restore-state.sh. Owns no category replay or persistent state.
# Definitions only at source time.

# yes | no | ask — the flag wins, then the setting, and an unreadable setting
# falls back to asking rather than to doing.
units_decision_kind() {
  case "${UNITS_CHOICE:-}" in
    yes|no) printf '%s' "$UNITS_CHOICE"; return 0 ;;
  esac
  case "${CFG[ENABLE_UNITS]:-ask}" in
    yes|1|on|true) printf 'yes' ;;
    no|0|off|false) printf 'no' ;;
    *) printf 'ask' ;;
  esac
}


# Packages first (everything else may need a binary), plugins before `omarchy`
# so the restored shell.json is the last word on what is enabled.
# Restoring a machine means restoring the things that machine runs. Names and
# paths out of a vault are validated; file *contents* cannot be, so the honest
# move is to count what will run and say so before asking.
report_executable_content() {
  local hooks=0 menus=0 scripts=0 units=0 autostart=0 plugins=0 git_themes=0
  [[ -d $VAULT/omarchy/hooks ]] &&
    hooks=$(find "$VAULT/omarchy/hooks" -type f ! -name '*.sample' 2>/dev/null | wc -l)
  [[ -d $VAULT/omarchy/extensions ]] &&
    menus=$(find "$VAULT/omarchy/extensions" -type f 2>/dev/null | wc -l)
  [[ -d $VAULT/home/.local/bin ]] &&
    scripts=$(find "$VAULT/home/.local/bin" -type f 2>/dev/null | wc -l)
  [[ -d $VAULT/home/.config/systemd ]] &&
    units=$(find "$VAULT/home/.config/systemd" -type f -name '*.service' 2>/dev/null | wc -l)
  # Autostart is no longer captured by default, but a vault written before that
  # — or by someone who added it back — still carries it, and every entry is a
  # command that runs the next time you log in.
  [[ -d $VAULT/home/.config/autostart ]] &&
    autostart=$(find "$VAULT/home/.config/autostart" -type f -name '*.desktop' 2>/dev/null | wc -l)
  # Plugins and git themes are not files in the vault, they are checkouts the
  # restore fetches. The vault names them; the code arrives from upstream.
  [[ -f $VAULT/plugins/plugins.tsv ]] && plugins=$(count_lines "$VAULT/plugins/plugins.tsv")
  [[ -f $VAULT/omarchy/themes.tsv ]] &&
    git_themes=$(awk -F'\t' '$2 != "" { n++ } END { print n + 0 }' "$VAULT/omarchy/themes.tsv" 2>/dev/null || echo 0)

  (( hooks + menus + scripts + units + autostart + plugins + git_themes == 0 )) && return 0

  # Built as lines first because this has two audiences: a person, who gets a
  # block with a heading, and --porcelain, which is a protocol and must not have
  # prose written into it. Neither audience should be told less than the other.
  local lines=()
  (( hooks > 0 ))      && lines+=("$(plural "$hooks" "Omarchy hook") — run automatically on update, boot and theme change")
  (( menus > 0 ))      && lines+=("$(plural "$menus" "menu extension") — menu entries are shell commands")
  (( scripts > 0 ))    && lines+=("$(plural "$scripts" script) into ~/.local/bin")
  (( units > 0 ))      && lines+=("$(plural "$units" "systemd user unit")")
  (( autostart > 0 ))  && lines+=("$(plural "$autostart" "autostart entry" "autostart entries") — started automatically when you log in")
  (( plugins > 0 ))    && lines+=("$(plural "$plugins" "shell plugin") — cloned from git and loaded into the shell")
  (( git_themes > 0 )) && lines+=("$(plural "$git_themes" "git theme") — cloned from git, sourced on every theme change")

  local line
  if (( PORCELAIN )); then
    for line in "${lines[@]}"; do emit "LOG|will run: $line"; done
    return 0
  fi
  printf '\n%sThis vault installs things this machine will run:%s\n' "$c_bold" "$c_reset"
  for line in "${lines[@]}"; do printf '  %s\n' "$line"; done
  printf '%sRestore only a vault you trust as much as the machine it came from.%s\n' "$c_dim" "$c_reset"
  return 0
}

# `ress apply` shows the exact list before it asks. A restore asks the same
# question about a bigger change, so it shows the same kind of list: the package
# names this machine does not have, and the plugins that would be cloned. Read
# through the same validators the restore itself uses, so the preview cannot
# name anything the restore would go on to refuse.
report_restore_preview() {
  local names=() aur_names=() plugin_ids=() line
  if [[ -f $VAULT/packages/native.txt || -f $VAULT/packages/foreign.txt ]]; then
    local installed
    ress_make_temp_file || die "could not create restore preview workspace"
    installed="$RESS_TEMP_PATH"
    pacman -Qq 2>/dev/null | sort >"$installed" || true
    local want
    ress_make_temp_file || die "could not create restore preview workspace"
    want="$RESS_TEMP_PATH"
    # Only list files that exist — `sort` exits non-zero on a missing operand.
    [[ -f $VAULT/packages/native.txt ]] && sort -u -- "$VAULT/packages/native.txt" >"$want" || : >"$want"
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      valid_pkg "$line" && names+=("$line")
    done < <(comm -23 "$want" "$installed" || true)
    # Kept apart from the repo list all the way to the screen: one is a signed
    # download, the other is a build, and the difference is the whole reason
    # there is a second question later.
    if [[ -f $VAULT/packages/foreign.txt ]]; then
      sort -u -- "$VAULT/packages/foreign.txt" >"$want"
      while IFS= read -r line; do
        [[ -n $line ]] || continue
        valid_pkg "$line" && aur_names+=("$line")
      done < <(comm -23 "$want" "$installed" || true)
    fi
    rm -f "$installed" "$want"
  fi
  if [[ -f $VAULT/plugins/plugins.tsv ]]; then
    local id url sha
    while IFS=$'\037' read -r id url _ sha; do
      [[ -n $id && -n $url ]] || continue
      url=$(strip_credentials "$url")
      valid_id "$id" && valid_git_remote "$url" || continue
      [[ -d $HOME/.config/omarchy/plugins/$id ]] && continue
      # Mirror the pin rule, or the preview promises a plugin the restore skips.
      if [[ -n $sha ]]; then
        valid_sha "$sha" || continue
      elif (( ! ALLOW_UNPINNED )); then
        continue
      fi
      plugin_ids+=("$id")
    done < <(tr '\t' '\037' <"$VAULT/plugins/plugins.tsv")
  fi

  (( ${#names[@]} + ${#aur_names[@]} + ${#plugin_ids[@]} == 0 )) && return 0

  if (( PORCELAIN )); then
    (( ${#names[@]} > 0 ))      && emit "LOG|will install ${#names[@]} from the Arch repos: ${names[*]}"
    (( ${#aur_names[@]} > 0 ))  && emit "LOG|will build ${#aur_names[@]} from the AUR: ${aur_names[*]}"
    (( ${#plugin_ids[@]} > 0 )) && emit "LOG|will clone ${#plugin_ids[@]} shell plugins: ${plugin_ids[*]}"
    return 0
  fi

  printf '\n%sThis restore will install:%s\n' "$c_bold" "$c_reset"
  if (( ${#names[@]} > 0 )); then
    printf '  %s%s from the Arch repos%s\n' "$c_green" "$(plural "${#names[@]}" package)" "$c_reset"
    printf '%s\n' "${names[@]}" | fmt -w 72 | sed 's/^/      /'
  fi
  if (( ${#aur_names[@]} > 0 )); then
    printf '  %s%s built here from the AUR%s %s(asked about separately)%s\n' \
      "$c_yellow" "$(plural "${#aur_names[@]}" package)" "$c_reset" "$c_dim" "$c_reset"
    printf '%s\n' "${aur_names[@]}" | fmt -w 72 | sed 's/^/      /'
  fi
  if (( ${#plugin_ids[@]} > 0 )); then
    printf '  %s%s%s\n' "$c_green" "$(plural "${#plugin_ids[@]}" "shell plugin")" "$c_reset"
    printf '%s\n' "${plugin_ids[@]}" | fmt -w 72 | sed 's/^/      /'
  fi
  printf '\n'
  return 0
}


