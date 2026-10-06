#!/bin/bash
#
# Supporting CLI commands for vault status, initialization, configuration,
# secrets setup, linking, diagnostics, and diffs.
# Depends on core.sh, safety.sh, and vault/common.sh. Used by status, init, set,
# secrets, link, doctor, and diff. Definitions only at source time.

# ==================================================================== STATUS

cmd_status() {
  local as_json=0
  [[ ${1:-} == --json ]] && as_json=1
  resolve_vault

  local last=0 commits=0 ahead=0 has_vault=0
  [[ -f $STATE_DIR/last-backup ]] && last=$(json_number "$(<"$STATE_DIR/last-backup")")
  if has_manifest; then
    has_vault=1
    commits=$(json_number "$(git_vault rev-list --count HEAD 2>/dev/null || echo 0)")
    ahead=$(json_number "$(git_vault rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)")
  fi

  local loadout_summary
  if [[ ! -f $LOADOUT_REGISTRY ]]; then
    loadout_summary='{"available":true,"count":0,"attention":0}'
  elif registry_validate "$LOADOUT_REGISTRY"; then
    loadout_summary=$(jq -c '{available:true,count:(.loadouts|length),
      attention:([.loadouts[] | select(.state != "healthy")]|length)}' "$LOADOUT_REGISTRY")
  else
    loadout_summary='{"available":false,"count":null,"attention":null}'
  fi

  if (( as_json )); then
    jq -n \
      --argjson hasVault "$has_vault" \
      --arg vault "$VAULT" \
      --arg remote "${CFG[REMOTE]}" \
      --argjson lastBackup "$last" \
      --argjson commits "$commits" \
      --argjson unpushed "$ahead" \
      --argjson autoBackup "$(config_status_onoff AUTO_BACKUP)" \
      --argjson intervalHours "$(config_status_number AUTO_INTERVAL_HOURS)" \
      --argjson categories "$(jq -n \
        --argjson packages "$(config_status_flag INCLUDE_PACKAGES)" \
        --argjson config "$(config_status_flag INCLUDE_CONFIG)" \
        --argjson omarchy "$(config_status_flag INCLUDE_OMARCHY)" \
        --argjson webapps "$(config_status_flag INCLUDE_WEBAPPS)" \
        --argjson plugins "$(config_status_flag INCLUDE_PLUGINS)" \
        --argjson secrets "$(config_status_flag INCLUDE_SECRETS)" \
        '$ARGS.named')" \
      --argjson settings "$(jq -n \
        --arg aur "${CFG[AUR]}" \
        --arg enableUnits "${CFG[ENABLE_UNITS]}" \
        --arg secretScan "${CFG[SECRET_SCAN]}" \
        --argjson captureAutostart "$(config_status_flag CAPTURE_AUTOSTART)" \
        '$ARGS.named')" \
      --argjson manifest "$(manifest_json)" \
      --argjson loadouts "$loadout_summary" \
      '$ARGS.named'
    return 0
  fi

  printf '%sress%s %s\n\n' "$c_bold" "$c_reset" "$VERSION"
  printf '  vault      %s\n' "$VAULT"
  printf '  remote     %s\n' "${CFG[REMOTE]:-${c_dim}none${c_reset}}"
  if (( has_vault )); then
    printf '  backups    %s\n' "$commits"
    printf '  last       %s\n' "$( (( last > 0 )) && date -d "@$last" '+%Y-%m-%d %H:%M' || echo never)"
    (( ahead > 0 )) && printf '  unpushed   %s%s commits%s\n' "$c_yellow" "$ahead" "$c_reset"
    printf '\n'
    jq -r 'def n(v; one): (v|tostring) + " " + (if v == 1 then one else one + "s" end);
      "  captured   " + n(.counts.packages; "package") + ", " + n(.counts.config; "config path")
      + ", " + n(.counts.themes; "theme") + ", " + n(.counts.webapps; "web app")
      + ", " + n(.counts.plugins; "plugin")' \
      "$(manifest_path)"
  else
    printf '  %sno backup yet — run: ress backup%s\n' "$c_dim" "$c_reset"
  fi

  if [[ $(jq -r '.available' <<<"$loadout_summary") == true ]]; then
    printf '  loadouts   %s tracked, %s need attention\n' \
      "$(jq -r '.count' <<<"$loadout_summary")" "$(jq -r '.attention' <<<"$loadout_summary")"
  else
    printf '  loadouts   %sunavailable (registry needs attention)%s\n' "$c_yellow" "$c_reset"
  fi
  printf '\n  categories '
  local category key
  for category in "${CATEGORIES[@]}"; do
    key="INCLUDE_$(printf '%s' "$category" | tr '[:lower:]' '[:upper:]')"
    if [[ ${CFG[$key]} == 1 ]]; then printf '%s%s%s ' "$c_green" "$category" "$c_reset"
    else printf '%s%s%s ' "$c_dim" "$category" "$c_reset"; fi
  done
  printf '\n'
}

# ================================================================== SETTINGS

cmd_init() {
  local remote=""
  while (( $# > 0 )); do
    case "$1" in
      --remote) remote="${2:-}"; shift 2 ;;
      *) die "unknown init option: $1" ;;
    esac
  done
  resolve_vault
  ensure_vault_repo
  CFG[VAULT]="$VAULT"
  [[ -n $remote ]] && CFG[REMOTE]="$(strip_credentials "$remote")"
  save_config
  private_dir "$CONFIG_DIR"
  [[ -f $CONFIG_DIR/include ]] || printf '%s\n' \
    "# Extra paths to capture, one per line, relative to \$HOME." \
    "# These are added to the list shipped with ress." >"$CONFIG_DIR/include"
  [[ -f $CONFIG_DIR/exclude ]] || printf '%s\n' \
    "# Extra rsync patterns to leave out of every capture." >"$CONFIG_DIR/exclude"
  printf 'Vault ready at %s\n' "$VAULT"
  [[ -n $remote ]] && printf 'Remote set to %s\n' "$(strip_credentials "$remote")"
  printf 'Run: ress backup\n'
}

cmd_set() {
  (( $# > 0 )) || die "usage: ress set KEY=VALUE [KEY=VALUE...]"
  # Validated in full before anything is written, so a run that is going to be
  # refused is refused without having changed half the settings first.
  local pair key value keys=() values=()
  for pair in "$@"; do
    [[ $pair == *=* ]] || die "expected KEY=VALUE, got: $pair"
    key="${pair%%=*}"; value="${pair#*=}"
    key=$(printf '%s' "$key" | tr '[:lower:]-' '[:upper:]_')
    [[ -v CONFIG_DEFAULTS[$key] ]] || die "unknown setting: $key"
    case "$key" in
      REMOTE|PROFILE_URL) value=$(strip_credentials "$value") ;;
    esac
    config_validate_value "$key" "$value"
    keys+=("$key"); values+=("$value")
  done

  # Re-read inside the lock: the config may have changed between this process
  # starting and reaching here, and writing a whole file from a stale read is
  # how one toggle undoes another.
  take_config_lock
  load_config
  local i
  for i in "${!keys[@]}"; do CFG[${keys[$i]}]="${values[$i]}"; done
  save_config
  printf 'Saved to %s\n' "$CONFIG_FILE"
}

cmd_secrets() {
  local action="${1:-list}"; shift || true
  case "$action" in
    init)
      private_dir "$CONFIG_DIR"
      if [[ -f $CONFIG_DIR/secrets ]]; then
        printf 'Already at %s\n' "$CONFIG_DIR/secrets"
      else
        cat >"$CONFIG_DIR/secrets" <<'LIST'
# Paths encrypted into the vault, one per line, relative to $HOME.
#
# Nothing here leaves the machine in the clear: the whole set is tarred and
# encrypted with age before it is written, and the vault only ever holds the
# ciphertext. Encryption is off until INCLUDE_SECRETS=1.
#
# In the default passphrase mode you will be asked for a passphrase at backup
# and at restore, and it is never stored anywhere. Lose it and this is noise.

.ssh
.config/gh/hosts.yml
.gnupg
LIST
        printf 'Wrote %s — edit it, then: ress set INCLUDE_SECRETS=1\n' "$CONFIG_DIR/secrets"
      fi
      have age || printf '\n%sage is not installed. Run: sudo pacman -S age%s\n' "$c_yellow" "$c_reset"
      ;;
    list)
      [[ -f $CONFIG_DIR/secrets ]] || die "no secrets list — run: ress secrets init"
      merged_list_file "$CONFIG_DIR/secrets"
      ;;
    add)
      [[ -n ${1:-} ]] || die "usage: ress secrets add <path-relative-to-home>"
      private_dir "$CONFIG_DIR"; touch "$CONFIG_DIR/secrets"
      printf '%s\n' "$1" >>"$CONFIG_DIR/secrets"
      printf 'Added %s\n' "$1"
      ;;
    enable)  CFG[INCLUDE_SECRETS]=1; save_config; printf 'Secrets will be captured on the next backup.\n' ;;
    disable) CFG[INCLUDE_SECRETS]=0; save_config; printf 'Secrets will not be captured.\n' ;;
    *) die "unknown secrets action: $action" ;;
  esac
}

cmd_link() {
  local target="$HOME/.local/bin/ress"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$SELF_DIR/ress" "$target"
  printf 'Linked %s -> %s\n' "$target" "$SELF_DIR/ress"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) printf 'Run: %sress doctor%s\n' "$c_green" "$c_reset" ;;
    *) printf '%s~/.local/bin is not on your PATH. Add it to ~/.bashrc:%s\n  export PATH="$HOME/.local/bin:$PATH"\n' "$c_yellow" "$c_reset" ;;
  esac
}

vault_is_initialised() { [[ -d "$VAULT/.git" ]]; }

cmd_doctor() {
  local problems=0
  printf '%sress doctor%s\n\n' "$c_bold" "$c_reset"
  # Takes a command, never a string to eval: an eval of an interpolated config
  # value is exactly the shape a scanner and a reviewer both stop on.
  check() {
    local label="$1" hint="$2"; shift 2
    if "$@" >/dev/null 2>&1; then
      printf '  %s✓%s %s\n' "$c_green" "$c_reset" "$label"
    else
      printf '  %s✗%s %s%s\n' "$c_red" "$c_reset" "$label" "${hint:+ — $hint}"
      problems=$((problems + 1))
    fi
  }
  check "git"            ""  have git
  check "rsync"          ""  have rsync
  check "jq"             ""  have jq
  check "curl"           ""  have curl
  check "pacman"         ""  have pacman
  check "yay (AUR)"      "AUR packages will be skipped on restore"          have yay
  check "age (secrets)"  "optional; needed only for the secrets category"   have age
  check "omarchy CLI"    ""  have omarchy
  check "shell running"  "the panel needs omarchy-shell; the CLI does not"  omarchy-shell shell ping
  resolve_vault
  check "vault"          "run: ress init"          vault_is_initialised
  check "git identity"   ""                        git config --global user.email
  check "ress on PATH"   "run: $SELF_DIR/ress link" command -v ress
  printf '\n'
  (( problems == 0 )) && printf '%sReady.%s\n' "$c_green" "$c_reset" ||
    printf '%s%s.%s\n' "$c_yellow" "$(plural "$problems" problem)" "$c_reset"
  return 0
}

# What a restore would actually cost on a *fresh Omarchy*, rather than on a bare
# Arch install. Omarchy ships its own package manifest, so the honest number is
# your explicit set minus what the ISO already lays down — and that difference,
# not the whole list, is everything a restore has to fetch.
STOCK_LISTS=("$OMARCHY_DIR/install/omarchy-base.packages" "$OMARCHY_DIR/install/omarchy-other.packages")

stock_packages() {
  # The existence check has to happen outside the pipeline: every stage of a
  # pipeline runs in its own subshell, so a flag set in the loop never makes it
  # back out here.
  local list present=()
  for list in "${STOCK_LISTS[@]}"; do
    [[ -f $list ]] && present+=("$list")
  done
  (( ${#present[@]} > 0 )) || return 1
  {
    sed -e 's/#.*//' -e 's/[[:space:]]//g' "${present[@]}"
    # The ISO pacstraps the base meta-packages too. They are not in the manifest
    # but they are certainly on a fresh install, and counting them would inflate
    # the estimate with things like sudo and mkinitcpio. `base` is a package
    # rather than a group on modern Arch, so ask for its dependencies.
    if have expac; then
      expac -S '%E' base base-devel 2>/dev/null | tr ' ' '\n' || true
    fi
    pacman -Sgq base base-devel 2>/dev/null || true
    # `omarchy` itself and what it pulls in are on every Omarchy machine, along
    # with the bootloader and initramfs pieces the installer lays down outside
    # the manifest.
    printf '%s\n' omarchy mkinitcpio efibootmgr
    if have expac; then
      expac -S '%E' omarchy 2>/dev/null | tr ' ' '\n' || true
    fi
  } | grep -v '^$' | sort -u
}

cmd_diff_stock() {
  resolve_vault
  # No RETURN trap here: it would fire after `stock` has left scope, and under
  # `set -u` that turns a clean run into an unbound-variable error.
  local stock
  ress_make_temp_file || die "could not create diff workspace"
  stock="$RESS_TEMP_PATH"
  if ! stock_packages >"$stock"; then
    rm -f "$stock"
    die "no Omarchy package manifest on this machine (expected ${STOCK_LISTS[0]})"
  fi

  local mine_raw
  if [[ -f $VAULT/packages/native.txt ]]; then
    mine_raw=$(sort -u "$VAULT/packages/native.txt" "$VAULT/packages/foreign.txt" 2>/dev/null)
  else
    mine_raw=$(pacman -Qqe | sort -u)
  fi

  # These names are read out of a vault and end up as argv for expac, so they go
  # through the same filter the restore path uses. `diff --stock` is read-only,
  # but a name that could be read as an option has no business being here.
  local mine
  keep_valid valid_pkg diff "package names" <<<"$mine_raw"
  mine=$(printf '%s\n' "${KEPT[@]:-}" | grep -v '^$' || true)

  local extra; extra=$(comm -23 <(printf '%s\n' "$mine") "$stock" || true)
  local n_mine n_stock n_extra
  n_mine=$(printf '%s' "$mine" | grep -c . || true)
  n_stock=$(count_lines "$stock")
  n_extra=$(printf '%s' "$extra" | grep -c . || true)

  printf '%sDistance from a stock Omarchy install%s\n\n' "$c_bold" "$c_reset"
  printf '  %-28s %s\n' "Omarchy ships" "$(plural "$n_stock" package)"
  printf '  %-28s %s\n' "you have explicitly" "$(plural "$n_mine" package)"
  printf '  %-28s %s%s%s\n' "a fresh Omarchy would fetch" "$c_green" "$(plural "$n_extra" package)" "$c_reset"

  # Distance-from-stock is a property of the vault, not of this machine, so on a
  # machine that already has these it read as though a restore still had work to
  # do. Say what is actually missing here as well.
  local here_missing=0 pkg
  while IFS= read -r pkg; do
    [[ -n $pkg ]] || continue
    pacman -Q "$pkg" >/dev/null 2>&1 || here_missing=$((here_missing + 1))
  done <<<"$extra"
  if (( n_extra > 0 )); then
    if (( here_missing == 0 )); then
      printf '  %-28s %sall of them are already installed%s\n\n' "on this machine" "$c_green" "$c_reset"
    else
      printf '  %-28s %s still missing\n\n' "on this machine" "$(plural "$here_missing" package)"
    fi
  else
    printf '\n'
  fi

  if (( n_extra > 0 )); then
    printf '%s\n' "$extra" | fmt -w 72 | sed 's/^/  /'
    printf '\n'
    if have expac; then
      local mb
      local priced=()
      while IFS= read -r pkg; do [[ -n $pkg ]] && priced+=("$pkg"); done <<<"$extra"
      mb=$(expac -S '%k' -- "${priced[@]:-}" 2>/dev/null | awk '{s+=$1} END {printf "%.0f", s/1024/1024}')
      [[ -n $mb ]] && printf '  %s≈ %s MB to download.%s\n' "$c_dim" "$mb" "$c_reset"
    fi
  fi
  printf '  %sAn estimate: anything already installed is skipped at restore time.\n  Everything else in the vault replays without the network.%s\n' "$c_dim" "$c_reset"
  rm -f "$stock"
}

cmd_diff() {
  if [[ ${1:-} == --stock ]]; then cmd_diff_stock; return $?; fi
  resolve_vault
  [[ -d $VAULT/.git ]] || die "no vault at $VAULT"

  local now added="" removed="" dirty
  ress_make_temp_file || die "could not create diff workspace"
  now="$RESS_TEMP_PATH"
  pacman -Qqen | sort >"$now"
  if [[ -f $VAULT/packages/native.txt ]]; then
    added=$(comm -23 "$now" <(sort -u "$VAULT/packages/native.txt") || true)
    removed=$(comm -13 "$now" <(sort -u "$VAULT/packages/native.txt") || true)
  fi
  rm -f "$now"

  [[ -n $added ]] && printf '%sInstalled since the last backup%s\n%s\n\n' \
    "$c_bold" "$c_reset" "$(fmt -w 72 <<<"$added" | sed 's/^/  + /')"
  [[ -n $removed ]] && printf '%sRemoved since the last backup%s\n%s\n\n' \
    "$c_bold" "$c_reset" "$(fmt -w 72 <<<"$removed" | sed 's/^/  - /')"

  dirty=$(git_vault status --short 2>/dev/null | head -40)
  [[ -n $dirty ]] && printf '%sUncommitted in the vault%s\n%s\n' "$c_bold" "$c_reset" "$(sed 's/^/  /' <<<"$dirty")"

  if [[ -z $added && -z $removed && -z $dirty ]]; then
    printf '%sNothing has changed since the last backup.%s\n' "$c_green" "$c_reset"
    printf '%sTry `ress diff --stock` to see how far this machine is from a fresh Omarchy.%s\n' "$c_dim" "$c_reset"
  fi
  return 0
}
