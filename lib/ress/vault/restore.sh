#!/bin/bash
#
# Vault restore: progress, preview, AUR and unit consent, category replay, and
# resumable restore orchestration.
# Depends on core.sh, safety.sh, and vault/common.sh. Owns restore/AUR/unit run
# state; used by restore. Definitions only at source time.

# =================================================================== RESTORE

RESTORE_STATE=""
RESTORE_FAILED=0
FAILED_STEPS=()

# Set by cmd_restore. "" leaves the decision to ENABLE_UNITS; --enable-units and
# --no-enable-units override it for this run.
UNITS_CHOICE=""
# A vault fetched from a URL this machine has not used before. It is not less
# trustworthy for being new — a fresh install restoring its owner's vault is
# always first contact — but it is the case where nothing has been agreed to
# yet, so nothing is assumed.
FIRST_CONTACT=0

step_done()      { grep -qxF "$1" "$RESTORE_STATE" 2>/dev/null; }
mark_done()      { printf '%s\n' "$1" >>"$RESTORE_STATE"; }

# A category can end without failing and without being finished: you were asked
# whether to build seven AUR packages and said no. Marking that done would have
# the next run skip the very step you deferred; marking it failed would call a
# decision a fault. So it is neither — it is recorded here, reported at the end,
# and left for the next run to offer again.
PARTIAL_STEPS=()
mark_partial() {
  local category="$1" reason="$2" existing
  for existing in "${PARTIAL_STEPS[@]:-}"; do
    [[ $existing == "$category|"* ]] && return 0
  done
  PARTIAL_STEPS+=("$category|$reason")
}
was_partial() {
  local entry
  for entry in "${PARTIAL_STEPS[@]:-}"; do
    [[ $entry == "$1|"* ]] && return 0
  done
  return 1
}

# Never clobber in silence. Anything restore overwrites is moved aside first,
# so a restore onto a machine you actually use is reversible.
# --safe-links drops any symlink in the vault that points outside the tree, so
# a crafted vault cannot plant `.config/foo -> /etc` and have later writes
# follow it out of $HOME.
RSYNC_SAFE=(-a --safe-links --backup --suffix="$BAK_SUFFIX")

# ==================================================================== AUR
#
# Every other package a restore installs is a signed binary from the Arch
# repositories. An AUR package is a PKGBUILD: a shell script fetched from
# aur.archlinux.org and run on this machine while it builds. That is the one
# point where a list of names in a vault becomes somebody else's code running
# here, so it is the one point that asks first.

# Names that never get built, whoever asks. Checked before the question, since
# refusing is not a question.
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

restore_packages() {
  local dir="$VAULT/packages"
  [[ -d $dir ]] || { step_skip packages "not in this vault"; return 0; }
  step_start packages "Working out what is missing"

  local installed="$STATE_DIR/installed.txt"
  pacman -Qq | sort >"$installed"

  local missing_native missing_foreign
  missing_native=$(comm -23 <(sort -u "$dir/native.txt") "$installed" || true)
  missing_foreign=$(comm -23 <(sort -u "$dir/foreign.txt") "$installed" || true)

  # Everything below goes onto a command line that runs as root, so it is
  # filtered to real package names first. `--` closes the option list as well,
  # because two independent guards on a root invocation is the right number.
  local safe_native=() safe_foreign=()
  keep_valid valid_pkg packages "package names" <<<"$missing_native"; safe_native=("${KEPT[@]}")
  keep_valid valid_pkg packages "package names" <<<"$missing_foreign"; safe_foreign=("${KEPT[@]}")

  local n_count=${#safe_native[@]} f_count=${#safe_foreign[@]}

  if (( n_count == 0 && f_count == 0 )); then
    step_ok packages "already complete — nothing to install"
    return 0
  fi
  step_ok packages "$n_count from the repos, $f_count from the AUR"

  if (( DRY_RUN )); then
    # Two different things happen to these two lists, so they are never shown
    # as one list.
    if (( n_count > 0 )); then
      printf '  %sfrom the Arch repos%s\n' "$c_dim" "$c_reset"
      printf '%s\n' "${safe_native[@]}" | fmt -w 68 | sed 's/^/      /'
    fi
    if (( f_count > 0 )); then
      printf '  %sbuilt from the AUR%s\n' "$c_yellow" "$c_reset"
      local pkg
      for pkg in "${safe_foreign[@]}"; do
        if aur_denied "$pkg"; then printf '      %-32s %son your deny list%s\n' "$pkg" "$c_dim" "$c_reset"
        else printf '      %s\n' "$pkg"; fi
      done
    fi
    return 0
  fi

  if (( n_count > 0 )); then
    step_start packages "Installing $n_count packages"
    if sudo pacman -S --needed --noconfirm -- "${safe_native[@]}"; then
      step_ok packages "repo packages installed"
    else
      # A freshly installed Omarchy carries the ISO's offline.db and none of the
      # online databases, so the first install on a new machine fails with
      # "target not found" until they are fetched. Checking for a database file
      # is not enough — offline.db is one — so refresh and retry rather than
      # trying to guess the state.
      step_warn packages "install failed — refreshing package databases and retrying"
      if sudo pacman -Sy --noconfirm >/dev/null 2>&1 &&
        sudo pacman -S --needed --noconfirm -- "${safe_native[@]}"; then
        step_ok packages "repo packages installed after a database refresh"
      else
        local still_missing=()
        local pkg
        for pkg in "${safe_native[@]}"; do
          pacman -Q "$pkg" >/dev/null 2>&1 || still_missing+=("$pkg")
        done
        if (( ${#still_missing[@]} == 0 )); then
          step_ok packages "repo packages installed after a database refresh"
        else
          step_fail packages "${#still_missing[@]} did not install: ${still_missing[*]}"
          RESTORE_FAILED=1
        fi
      fi
    fi
  fi

  if (( f_count > 0 )); then
    if ! have yay; then
      step_fail packages "yay is not installed; skipped $f_count AUR packages — run: sudo pacman -S yay, then rerun"
      RESTORE_FAILED=1
      return 0
    fi
    aur_gate packages "${safe_foreign[@]}"
    if [[ $AUR_MODE == skip ]]; then
      # Not a failure: you were asked and said no. Not done either, so the next
      # run asks again rather than walking past it.
      (( ${#AUR_KEPT[@]} > 0 )) &&
        mark_partial packages "$(plural "${#AUR_KEPT[@]}" "AUR package") not built — ress restore --only packages --aur"
    elif aur_install packages "${AUR_KEPT[@]}"; then
      step_ok packages "AUR packages installed"
    else
      # A failed build is worth retrying, so this is a failure and not a
      # warning: a warning would let the category be marked done and the
      # rerun would skip the very step that did not finish.
      step_fail packages "some AUR packages failed — see packages/foreign.txt"
      RESTORE_FAILED=1
    fi
  fi
  return 0
}

restore_config() {
  local dir="$VAULT/home"
  if [[ -d $dir ]]; then
    local n; n=$(find "$dir" -type f | wc -l)
    step_start config "Restoring $n files into \$HOME"
    if (( DRY_RUN )); then
      rsync -an --out-format='    %n' "${RSYNC_SAFE[@]}" -- "$dir/" "$HOME/"
    else
      rsync "${RSYNC_SAFE[@]}" -- "$dir/" "$HOME/"
      step_ok config "$n files restored (replaced files kept as *$BAK_SUFFIX)"
    fi
  else
    step_skip config "no dotfiles in this vault"
  fi
  # Runs even when the vault carried no dotfiles: enable-state is recorded
  # separately from the unit files, and a vault can hold one without the other.
  restore_user_units
  return 0
}

# ------------------------------------------------------------------- units
#
# Everything else a restore does is a write: a file lands somewhere and sits
# there until something reads it. Enabling a unit is different in kind — it is
# the one step that arranges for code to run later, without anyone asking for
# it again. So it is the one step that is never silent, and never implied by
# --yes: turning it on takes ENABLE_UNITS=yes or --enable-units.

# The units this vault says were enabled, minus the ones already enabled here.
# Names come out of a vault, so they go through valid_unit before they reach a
# systemctl command line.
pending_units() {
  local file="$VAULT/services/user-units.txt"
  [[ -s $file ]] || return 0
  have systemctl || return 0
  local unit
  while IFS= read -r unit; do
    [[ -n $unit ]] || continue
    valid_unit "$unit" || continue
    systemctl --user is-enabled -- "$unit" >/dev/null 2>&1 && continue
    printf '%s\n' "$unit"
  done <"$file"
}

# A unit ress can enable is one that exists here: either restored into
# ~/.config/systemd/user or shipped by a package.
unit_installed() {
  [[ -f $HOME/.config/systemd/user/$1 ]] && return 0
  systemctl --user cat -- "$1" >/dev/null 2>&1
}

# What the unit will actually run. This is the line that makes the prompt worth
# reading — and it comes out of a file the vault chose, so it is stripped of
# anything that could repaint the terminal and clipped to one line.
unit_exec() {
  local unit="$1" line=""
  # The vault's copy first: during a dry run it is the only one there is, and
  # after a restore it is the one that landed. Then whatever is installed, for
  # a unit that came from a package rather than from the vault.
  local from_vault="$VAULT/home/.config/systemd/user/$unit"
  local installed="$HOME/.config/systemd/user/$unit"
  local file=""
  [[ -f $from_vault ]] && file="$from_vault"
  [[ -z $file && -f $installed ]] && file="$installed"
  [[ -n $file ]] && line=$(sed -n 's/^ExecStart=//p' "$file" | head -1)
  [[ -n $line ]] || line=$(systemctl --user show -p ExecStart --value -- "$unit" 2>/dev/null | head -1)
  line=$(plain "$line")
  [[ ${#line} -gt 64 ]] && line="${line:0:61}..."
  printf '%s' "$line"
}

list_units() {
  local unit exec_line
  for unit in "$@"; do
    exec_line=$(unit_exec "$unit")
    printf '    %-34s %s%s%s\n' "$unit" "$c_dim" "${exec_line:-—}" "$c_reset"
  done
}

# Turn on the named units, reporting each one that could not be turned on.
# Returns the number enabled through ENABLED_UNITS.
ENABLED_UNITS=0
enable_units() {
  local unit
  ENABLED_UNITS=0
  for unit in "$@"; do
    if ! unit_installed "$unit"; then
      step_warn units "$unit is not installed here — skipped"
      continue
    fi
    if systemctl --user enable -- "$unit" >/dev/null 2>&1; then
      ENABLED_UNITS=$((ENABLED_UNITS + 1))
    else
      step_warn units "could not enable $unit"
    fi
  done
  return 0
}

restore_user_units() {
  local units=() unit
  while IFS= read -r unit; do [[ -n $unit ]] && units+=("$unit"); done < <(pending_units)
  (( ${#units[@]} > 0 )) || return 0

  if (( DRY_RUN )); then
    step_start units "$(plural "${#units[@]}" "user service") enabled in this vault, not here"
    list_units "${units[@]}"
    case "$(units_decision_kind)" in
      yes)  note "they would be enabled" ;;
      no)   note "they would be left disabled (ENABLE_UNITS=no)" ;;
      ask)  note "you would be asked before any of them is enabled" ;;
    esac
    return 0
  fi

  case "$(units_decision_kind)" in
    no)
      local why="--no-enable-units"
      [[ ${UNITS_CHOICE:-} == no ]] || why="ENABLE_UNITS=no"
      step_skip units "$(plural "${#units[@]}" "user service") left disabled ($why) — run: ress enable-units"
      return 0
      ;;
    yes)
      step_start units "Enabling $(plural "${#units[@]}" "user service")"
      list_units "${units[@]}"
      enable_units "${units[@]}"
      step_ok units "$(plural "$ENABLED_UNITS" "user service") enabled"
      return 0
      ;;
  esac

  # ask. Without a terminal there is nobody to ask, and --yes deliberately does
  # not answer this one: it is the prompt for ress overwriting your files, not
  # a standing agreement to start services from a vault.
  if (( PORCELAIN )) || [[ ! -t 0 ]]; then
    step_skip units "$(plural "${#units[@]}" "user service") left disabled (no terminal) — run: ress enable-units"
    return 0
  fi

  printf '\n%s%s from this vault, enabled there and not here:%s\n\n' \
    "$c_bold" "$(plural "${#units[@]}" "user service")" "$c_reset"
  list_units "${units[@]}"
  printf '\n%sEnabling them starts them with your session from now on.%s\n' "$c_dim" "$c_reset"
  local reply=""
  read -r -p "Enable $(plural "${#units[@]}" "user service")? [y/N] " reply || reply=""
  if [[ $reply == [yY]* ]]; then
    enable_units "${units[@]}"
    step_ok units "$(plural "$ENABLED_UNITS" "user service") enabled"
  else
    step_skip units "left disabled — run: ress enable-units to change your mind"
  fi
  return 0
}

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

# What a restore would do with one row of themes.tsv, as an action word and a
# reason. Both the dry run and the restore itself decide through this, so a
# plan cannot promise something the restore then refuses — the rule that keeps
# the two honest is that there is only one copy of it.
#
#   clone <url> at <pin>   fetch it, pinned or at the branch head
#   copy                   the theme travelled as files in the vault
#   present                already on this machine; left alone
#   skip <why>             a decision: unpinned, and --allow-unpinned was not given
#   refuse <why>           the vault said something that will not be repeated
#   missing                named, but neither a remote nor files to install from
theme_action() {
  local name="$1" url="$2" sha="$3"
  local dest="$HOME/.config/omarchy/themes"
  if ! valid_theme "$name"; then printf 'refuse\tunsafe theme name\n'; return 0; fi
  if [[ -n $url ]] && ! valid_git_remote "$url"; then printf 'refuse\tunsafe remote\n'; return 0; fi
  if [[ -d $dest/$name ]]; then printf 'present\talready here\n'; return 0; fi
  if [[ -n $url ]]; then
    if [[ -n $sha ]] && ! valid_sha "$sha"; then printf 'refuse\tmalformed commit\n'; return 0; fi
    # A theme is a git checkout the shell sources on every reload, so it gets
    # the same rule a plugin gets: without a recorded commit the clone is
    # whatever upstream contains now, not what was captured.
    if [[ -z $sha ]]; then
      (( ALLOW_UNPINNED )) || { printf 'skip\tno recorded commit — pass --allow-unpinned to take the branch head\n'; return 0; }
      printf 'clone\t%s at branch head\n' "$url"; return 0
    fi
    printf 'clone\t%s pinned to %s\n' "$url" "${sha:0:12}"
    return 0
  fi
  [[ -d $VAULT/omarchy/themes/$name ]] && { printf 'copy\tfrom files in the vault\n'; return 0; }
  printf 'missing\tno remote and no files in the vault\n'
}

# The dry run for this category used to be the word "dry run". Everything below
# is what a plan has to say to be worth reading: which themes arrive and from
# where, that the bar layout is replaced and by what, and which theme ends up
# active.
preview_omarchy() {
  local dir="$VAULT/omarchy" dest="$HOME/.config/omarchy"

  local item n
  for item in branding defaults extensions hooks themed; do
    [[ -d $dir/$item ]] || continue
    n=$(find "$dir/$item" -type f 2>/dev/null | wc -l)
    (( n > 0 )) || continue
    case "$item" in
      hooks)      printf '    %-12s %s %s(run on update, boot and theme change)%s\n' "$item" "$(plural "$n" file)" "$c_yellow" "$c_reset" ;;
      extensions) printf '    %-12s %s %s(menu entries are shell commands)%s\n' "$item" "$(plural "$n" file)" "$c_yellow" "$c_reset" ;;
      *)          printf '    %-12s %s\n' "$item" "$(plural "$n" file)" ;;
    esac
  done

  if [[ -f $dir/themes.tsv ]]; then
    local name url tsha action detail
    while IFS=$'\037' read -r name url tsha; do
      [[ -n $name ]] || continue
      IFS=$'\t' read -r action detail < <(theme_action "$name" "$url" "$tsha")
      case "$action" in
        clone|copy) printf '    %-12s %-22s %s%s%s\n' theme "$(plain "$name")" "$c_dim" "$(plain "$detail")" "$c_reset" ;;
        present)    printf '    %-12s %-22s %s%s%s\n' theme "$(plain "$name")" "$c_dim" "$detail" "$c_reset" ;;
        *)          printf '    %-12s %-22s %s%s%s\n' theme "$(plain "$name")" "$c_yellow" "$detail" "$c_reset" ;;
      esac
    done < <(tr '\t' '\037' <"$dir/themes.tsv")
  fi

  if [[ -f $dir/shell.json ]]; then
    local widgets=""
    widgets=$(jq -r '[.bar.layout // {} | .[]? | .[]? | .id] | join(", ")' "$dir/shell.json" 2>/dev/null || true)
    if [[ -n $widgets ]]; then
      printf '    %-12s %s\n' "bar layout" "$(plain "$widgets")"
    else
      printf '    %-12s %s\n' "bar layout" "replaced"
    fi
    [[ -f $dest/shell.json ]] &&
      printf '    %-12s %syours is kept as shell.json%s%s\n' "" "$c_dim" "$BAK_SUFFIX" "$c_reset"
  fi

  if [[ -f $dir/theme.name ]]; then
    local want current=""
    want=$(<"$dir/theme.name"); want="${want//[[:space:]]/}"
    current=$(active_theme_name || true)
    if ! valid_theme "$want"; then
      printf '    %-12s %sunsafe theme name — refused%s\n' "active theme" "$c_yellow" "$c_reset"
    elif [[ $want == "$current" ]]; then
      printf '    %-12s %s %s(already active)%s\n' "active theme" "$(plain "$want")" "$c_dim" "$c_reset"
    else
      printf '    %-12s %s → %s\n' "active theme" "${current:-none}" "$(plain "$want")"
    fi
  fi
  return 0
}

restore_omarchy() {
  local dir="$VAULT/omarchy"
  [[ -d $dir ]] || { step_skip omarchy "not in this vault"; return 0; }
  local dest="$HOME/.config/omarchy"
  if (( DRY_RUN )); then
    step_start omarchy "Omarchy state"
    preview_omarchy
    return 0
  fi
  mkdir -p "$dest/themes"
  step_start omarchy "Restoring Omarchy state"

  local item
  for item in branding defaults extensions hooks themed; do
    [[ -d $dir/$item ]] && rsync "${RSYNC_SAFE[@]}" -- "$dir/$item/" "$dest/$item/"
  done
  [[ -f $dir/shell.toml ]] && cp -n "$dir/shell.toml" "$dest/shell.toml" 2>/dev/null || true

  # Themes before shell.json: the shell reads the active theme on reload, and
  # pointing it at a theme that is not on disk yet gives you a grey desktop.
  local name url tsha action detail installed=0
  if [[ -f $dir/themes.tsv ]]; then
    while IFS=$'\037' read -r name url tsha; do
      [[ -n $name ]] || continue
      IFS=$'\t' read -r action detail < <(theme_action "$name" "$url" "$tsha")
      case "$action" in
        present) continue ;;
        refuse)  step_warn omarchy "theme $(plain "$name"): $detail — refused"; continue ;;
        skip)    step_warn omarchy "theme $(plain "$name"): $detail"; continue ;;
        missing) step_warn omarchy "theme $(plain "$name"): $detail"; continue ;;
        clone)
          if clone_pinned "$url" "$dest/themes/$name" "$tsha"; then
            installed=$((installed + 1))
          else
            step_warn omarchy "could not clone theme $(plain "$name") from $url"
          fi
          ;;
        copy)
          rsync -a --safe-links -- "$dir/themes/$name/" "$dest/themes/$name/"
          installed=$((installed + 1))
          ;;
      esac
    done < <(tr '\t' '\037' <"$dir/themes.tsv")
  fi
  (( installed > 0 )) && step_ok omarchy "$installed themes installed"

  if [[ -f $dir/shell.json ]]; then
    [[ -f $dest/shell.json ]] && cp -p "$dest/shell.json" "$dest/shell.json$BAK_SUFFIX"
    cp "$dir/shell.json" "$dest/shell.json"
    step_ok omarchy "shell layout restored"
  fi

  if [[ -f $dir/theme.name ]] && have omarchy-theme-set; then
    local theme; theme=$(<"$dir/theme.name")
    theme="${theme//[[:space:]]/}"
    valid_theme "$theme" || { step_warn omarchy "refused unsafe theme name"; return 0; }
    omarchy-theme-set "$theme" >/dev/null 2>&1 &&
      step_ok omarchy "theme set to $theme" ||
      step_warn omarchy "could not apply theme $theme"
  fi
  return 0
}

restore_webapps() {
  local dir="$VAULT/webapps"
  [[ -d $dir/apps ]] || { step_skip webapps "not in this vault"; return 0; }
  local n; n=$(find "$dir/apps" -name '*.desktop' | wc -l)
  step_start webapps "Restoring $n web apps"

  # A .desktop file *is* an Exec line, so none of them are copied. Each launcher
  # is read for a name, a URL, an icon and any browser flags, and rebuilt by the
  # real installer — the same path `ress apply` takes for a stranger's loadout,
  # and for the same reason: a vault fetched over the network chose this file's
  # contents. The launcher line handed back is assembled from the pieces that
  # passed validation, never from the captured text.
  local rows=() desktop exec_line name url icon parts launcher flags
  local refused=()
  for desktop in "$dir"/apps/*.desktop; do
    [[ -f $desktop ]] || continue
    name=$(sed -n 's/^Name=//p' "$desktop" | head -1)
    [[ -n $name ]] || name=$(basename "$desktop" .desktop)
    if ! launcher_travels "$desktop"; then refused+=("$(plain "$name")"); continue; fi
    exec_line=$(launcher_exec "$desktop")
    parts=$(webapp_parts "$exec_line") || { refused+=("$(plain "$name")"); continue; }
    IFS=$'\t' read -r launcher url flags <<<"$parts"
    # The URL, the flags and the launcher form were just checked; the label
    # decides a filename, and the installer refuses a name with a slash in it.
    if ! valid_label "$name"; then refused+=("$(plain "$name")"); continue; fi
    icon=$(sed -n 's/^Icon=//p' "$desktop" | head -1)
    valid_icon "$icon" || icon=""
    rows+=("$launcher"$'\t'"$name"$'\t'"$url"$'\t'"$icon"$'\t'"$flags")
  done
  (( ${#refused[@]} == 0 )) || step_warn webapps \
    "$(plural "${#refused[@]}" "launcher") refused — not a launcher URL with optional flags: ${refused[*]}"

  if (( DRY_RUN )); then
    if (( ${#rows[@]} == 0 )); then
      note "nothing here can be rebuilt"
      return 0
    fi
    local row launcher rname shown
    for row in "${rows[@]}"; do
      IFS=$'\t' read -r launcher rname url icon flags <<<"$row"
      shown="$url${flags:+ $flags}"
      [[ $launcher == omarchy-launch-webapp ]] || shown="$shown (via ${launcher#omarchy-})"
      if [[ -f $HOME/.local/share/applications/$rname.desktop ]]; then
        printf '    %-32s %s %s(replaces yours, kept as *%s)%s\n' "$rname" "$shown" "$c_dim" "$BAK_SUFFIX" "$c_reset"
      else
        printf '    %-32s %s\n' "$rname" "$shown"
      fi
    done
    note "each one is rebuilt by \`omarchy webapp install\` from a name, a URL and an icon — never by copying its .desktop file"
    return 0
  fi
  if (( ${#rows[@]} > 0 )) && ! have omarchy; then
    # Retryable: once `omarchy` is on PATH a rerun should pick this up, so it
    # must not be marked done the way a warning would allow.
    step_fail webapps "the omarchy CLI is not here — run: ress restore --only webapps once it is"
    RESTORE_FAILED=1
    return 0
  fi

  mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/256x256/apps"
  # Icons first: an icon *name* only resolves to a file that is already on disk,
  # and without one the installer goes to the network for a favicon.
  [[ -d $dir/icons ]] && rsync -a --safe-links --backup --suffix="$BAK_SUFFIX" -- "$dir/icons/" "$HOME/.local/share/icons/hicolor/256x256/apps/"

  local row ok=0 target flag_words=()
  for row in "${rows[@]:-}"; do
    [[ -n $row ]] || continue
    IFS=$'\t' read -r launcher name url icon flags <<<"$row"
    target="$HOME/.local/share/applications/$name.desktop"
    [[ -f $target ]] && cp -p "$target" "$target$BAK_SUFFIX"
    local -a install_args=("$name" "$url" "${icon:-$url}")
    # The installer takes the whole Exec line for exactly this, and what is
    # handed over is assembled here from the URL, the flags and the launcher form
    # that were all checked above. Without flags the plain launcher is the one
    # the installer writes itself, and passing the line then would only restate
    # it — but an or-focus launcher has to be passed, or it comes back as the
    # plain form and opens a second window instead of focusing the first.
    if [[ -n $flags ]]; then
      read -r -a flag_words <<<"$flags"
      install_args+=("$(webapp_exec_line "$launcher" "$url" "${flag_words[@]}")")
    elif [[ $launcher != omarchy-launch-webapp ]]; then
      install_args+=("$(webapp_exec_line "$launcher" "$url")")
    fi
    if omarchy webapp install "${install_args[@]}" >/dev/null 2>&1; then
      ok=$((ok + 1))
    else
      step_warn webapps "could not add web app $name"
    fi
  done
  have gtk-update-icon-cache && gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" &>/dev/null || true
  have update-desktop-database && update-desktop-database "$HOME/.local/share/applications" &>/dev/null || true
  step_ok webapps "$ok of $n web apps rebuilt (replaced launchers kept as *$BAK_SUFFIX)"
  return 0
}

restore_plugins() {
  local file="$VAULT/plugins/plugins.tsv"
  [[ -f $file ]] || { step_skip plugins "not in this vault"; return 0; }
  local total; total=$(count_lines "$file")
  (( total > 0 )) || { step_skip plugins "none in this vault"; return 0; }
  step_start plugins "Reinstalling $total plugins"

  local id url enabled sha i=0 ok=0
  # Tab is IFS whitespace, so `read` treats a\t\tb as two fields, not three, and
  # an entry with no url silently shifted every later column left. \037 is not
  # whitespace, so empty fields survive.
  while IFS=$'\037' read -r id url enabled sha; do
    i=$((i + 1))
    progress plugins "$i" "$total"
    [[ -n $id ]] || continue
    # `$id` is used as a directory name that is cloned into and, on failure,
    # removed. An id of `../../..` would take the removal with it.
    if ! valid_id "$id"; then
      step_warn plugins "refused unsafe plugin id from this vault"
      continue
    fi
    if [[ -n $url ]] && ! valid_git_remote "$url"; then
      step_warn plugins "$id has an unsafe remote — refused"
      continue
    fi
    if [[ -z $url ]]; then
      step_warn plugins "$id has no git remote — install it by hand"
      continue
    fi
    if [[ -n $sha ]] && ! valid_sha "$sha"; then
      step_warn plugins "$id has a malformed commit — refused"
      continue
    fi
    local target="$HOME/.config/omarchy/plugins/$id"
    if [[ -d $target ]]; then
      ok=$((ok + 1)); continue
    fi
    if (( DRY_RUN )); then
      # Say which of these the real run would actually take, rather than listing
      # an unpinned entry the pin rule below is going to skip.
      local pin
      if [[ -n $sha ]]; then pin="${sha:0:12} (pinned)"
      elif (( ALLOW_UNPINNED )); then pin="branch head"
      else pin="no commit — would be skipped"
      fi
      printf '    %s  %s  %s\n' "$id" "$url" "$pin"
      continue
    fi
    # An unpinned plugin is whatever upstream contains right now, which is not
    # what was captured. That code runs inside the shell, so it is refused
    # unless you say otherwise.
    if [[ -z $sha ]] && (( ! ALLOW_UNPINNED )); then
      step_warn plugins "$id has no recorded commit — skipped (pass --allow-unpinned to take the branch head)"
      continue
    fi
    if clone_pinned "$url" "$target" "$sha" &&
      omarchy plugin validate "$target" >/dev/null 2>&1; then
      ok=$((ok + 1))
      if [[ $enabled == 1 ]] && omarchy-shell shell ping >/dev/null 2>&1; then
        omarchy plugin enable "$id" >/dev/null 2>&1 || true
      fi
    else
      rm -rf "$target"
      # A clone that was attempted and failed is retryable, unlike the skips
      # above, which are decisions rather than failures.
      step_fail plugins "could not install $id from $url"
      RESTORE_FAILED=1
    fi
  done < <(tr '\t' '\037' <"$file")
  step_ok plugins "$ok of $total plugins in place"
  return 0
}

restore_secrets() {
  local blob="$VAULT/secrets/secrets.tar.age"
  [[ -f $blob ]] || { step_skip secrets "not in this vault"; return 0; }
  if ! have age; then
    step_warn secrets "age is not installed — run: sudo pacman -S age, then: ress restore --only secrets"
    return 0
  fi
  if (( DRY_RUN )); then
    # There is nothing honest to list here: the archive is encrypted, and what
    # is in it is not knowable without the passphrase. Say that, and say where
    # it lands.
    local size; size=$(du -h "$blob" 2>/dev/null | cut -f1)
    step_skip secrets "an encrypted archive (${size:-?}) — its contents are only readable after you decrypt it, into \$HOME with 0600 permissions"
    return 0
  fi
  # Only passphrase mode has anything to ask. Recipient mode is the unattended
  # one — refusing it for want of a terminal defeated the point of having it.
  if [[ ${CFG[SECRETS_MODE]} != recipient ]] && [[ ! -t 0 ]]; then
    step_skip secrets "passphrase mode needs a terminal — run: ress restore --only secrets"
    return 0
  fi

  step_start secrets "Decrypting"
  local args=()
  if [[ ${CFG[SECRETS_MODE]} == recipient ]]; then
    # The private half is found by taking .pub off the public half, so
    # SECRETS_RECIPIENT has to be a path to a key file rather than a bare
    # `age1…` recipient. A backup accepts either — `age -r` is happy with a
    # literal recipient — which means the mistake is only discovered here, on
    # the machine that needs the data. Say which mistake it was.
    local recipient="${CFG[SECRETS_RECIPIENT]}"
    if [[ $recipient == age1* && ! -e $recipient ]]; then
      step_fail secrets "SECRETS_RECIPIENT is a recipient string, so there is no private key to find here — point it at the .pub file sitting next to its identity, then: ress restore --only secrets"
      RESTORE_FAILED=1
      return 0
    fi
    local identity="${recipient%.pub}"
    [[ -f $identity ]] || {
      step_fail secrets "no identity at $identity — bring that file here, or point SECRETS_RECIPIENT at a .pub file next to it"
      RESTORE_FAILED=1
      return 0
    }
    args=(-i "$identity")
  fi

  # The archive inside the blob is as untrusted as the vault around it: whoever
  # wrote it chose the member list. Unpack into a staging directory first so
  # nothing lands in $HOME until it has been looked at.
  local work; work=$(mktemp -d)
  chmod 700 "$work" 2>/dev/null || true
  ( umask 077; : >"$work/blob.tar" )
  if ! age -d "${args[@]}" "$blob" >"$work/blob.tar" 2>/dev/null; then
    rm -rf "$work"; step_fail secrets "decryption failed"; RESTORE_FAILED=1; return 0
  fi
  if tar -tf "$work/blob.tar" 2>/dev/null | grep -qE '^/|(^|/)\.\.(/|$)'; then
    rm -rf "$work"; step_fail secrets "refused: the archive contains absolute or traversing paths"
    RESTORE_FAILED=1; return 0
  fi
  mkdir -p "$work/tree"
  if ! tar -C "$work/tree" -xf "$work/blob.tar" 2>/dev/null; then
    rm -rf "$work"; step_fail secrets "could not unpack the archive"; RESTORE_FAILED=1; return 0
  fi
  # A symlink member is how an archive aims a later write, or a chmod, at a path
  # of its choosing. None of them travel.
  local links; links=$(find "$work/tree" -type l 2>/dev/null | wc -l)
  (( links == 0 )) || step_warn secrets "dropped $links symlink(s) from the archive"
  find "$work/tree" -type l -delete 2>/dev/null || true

  # Landing through rsync gives secrets the same *$BAK_SUFFIX protection
  # every other restored file gets; tar would have overwritten silently.
  rsync "${RSYNC_SAFE[@]}" -- "$work/tree/" "$HOME/"
  rm -rf "$work"

  # Never follow a symlink at ~/.ssh: chmod would apply to its target.
  if [[ -d $HOME/.ssh && ! -L $HOME/.ssh ]]; then
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    find -P "$HOME/.ssh" -type f -exec chmod 600 {} + 2>/dev/null || true
  fi
  step_ok secrets "secrets restored with 0600 permissions"
  return 0
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
    local installed; installed=$(mktemp)
    pacman -Qq 2>/dev/null | sort >"$installed" || true
    local want; want=$(mktemp)
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

RESTORE_ORDER=(packages config plugins omarchy webapps secrets)

cmd_restore() {
  local from="" only="" skip="" restart=0 pending_remote=""
  while (( $# > 0 )); do
    case "$1" in
      --from) from="${2:-}"; shift 2 ;;
      --only) only="${2:-}"; shift 2 ;;
      --skip) skip="${2:-}"; shift 2 ;;
      --restart) restart=1; shift ;;
      --enable-units) UNITS_CHOICE="yes"; shift ;;
      --no-enable-units) UNITS_CHOICE="no"; shift ;;
      *) die "unknown restore option: $1" ;;
    esac
  done

  # A category name that is not a category selects nothing, and a restore that
  # selects nothing used to finish with "this machine is yours again" having
  # done exactly nothing. A typo is not a selection.
  # Split on commas without letting the shell expand `*` against $PWD, which
  # made `--only '*'` complain about whatever file it happened to find.
  local requested name known
  set -f
  for requested in ${only//,/ } ${skip//,/ }; do
    [[ -n $requested ]] || continue
    known=0
    for name in "${CATEGORIES[@]}"; do [[ $name == "$requested" ]] && known=1; done
    (( known )) || { set +f; die "no such category: $(plain "$requested") (choose from: ${CATEGORIES[*]})"; }
  done
  set +f

  resolve_vault
  if [[ -n $from ]]; then
    from=$(normalize_source "$from")
    # Not "is this vault safe" — a fresh install replaying its owner's vault is
    # always first contact. It is "has this machine agreed to anything about
    # this vault yet", which is what decides how much is assumed below.
    same_remote "$from" "$(normalize_source "${CFG[REMOTE]:-}")" || FIRST_CONTACT=1
  fi
  # A dry run must not touch anything, and fetching a vault over the top of the
  # configured one is very much touching something: it discards local commits
  # and repoints the remote. Preview against a throwaway clone instead.
  if [[ -n $from ]] && (( DRY_RUN )); then
    DRYRUN_VAULT=$(mktemp -d)
    step_start clone "Cloning $(strip_credentials "$from") for preview"
    if git clone -q --depth 1 -- "$from" "$DRYRUN_VAULT/vault" 2>/dev/null; then
      VAULT="$DRYRUN_VAULT/vault"
      step_ok clone "previewing against a temporary copy; your vault is untouched"
    else
      rm -rf "$DRYRUN_VAULT"; die "could not clone $(strip_credentials "$from")"
    fi
    from=""
  fi

  if [[ -n $from ]] && [[ -d $VAULT/.git || -e $VAULT ]]; then
    # Fetching replaces whatever vault is already here, which is a change in its
    # own right and used to happen before any prompt. Where it also moves the
    # remote this machine backs up to, that is part of the same question rather
    # than a second one asked later — declining half of it would leave the vault
    # holding one machine's history and pointing at another's.
    local replace="Replace the vault at $VAULT with the one at $(plain "$(strip_credentials "$from")")?"
    if (( FIRST_CONTACT )) && [[ -n ${CFG[REMOTE]:-} ]] && [[ -z ${VAULT_OVERRIDE:-} ]]; then
      replace="Replace the vault at $VAULT with the one at $(plain "$(strip_credentials "$from")"), and back up there from now on?"
    fi
    confirm "$replace" || die "cancelled"
  fi
  if [[ -n $from ]]; then
    if [[ -d $VAULT/.git ]]; then
      step_start clone "Updating vault from $(strip_credentials "$from")"
      git_vault remote set-url origin "$from" 2>/dev/null || git_vault remote add origin "$from"
      git_vault fetch -q --depth 1 origin && git_vault reset -q --hard FETCH_HEAD
      step_ok clone "vault updated"
    else
      step_start clone "Cloning $(strip_credentials "$from")"
      rm -rf "$VAULT"; mkdir -p "$(dirname "$VAULT")"
      git clone -q --depth 1 -- "$from" "$VAULT" || die "could not clone $from"
      step_ok clone "cloned to $VAULT"
    fi
    # Remembered only after the restore itself is agreed to, below — answering
    # "no" should not leave the machine pointed somewhere new.
    pending_remote="$from"
  fi

  # Fail on the missing tool now, with its package name, rather than halfway
  # through a restore on a machine you cannot yet use.
  local tool missing=()
  for tool in git rsync jq pacman; do have "$tool" || missing+=("$tool"); done
  (( ${#missing[@]} == 0 )) ||
    die "missing: ${missing[*]} — run: sudo pacman -S --needed ${missing[*]}"

  take_lock
  has_manifest || die "no vault at $VAULT — pass --from <git-url> or --vault <dir>"
  local manifest; manifest=$(manifest_path)
  local schema; schema=$(jq -r '.schemaVersion // 0' "$manifest")
  valid_int "$schema" ||
    die "this vault does not declare a schema version as a number — refusing to read it"
  (( schema == SCHEMA )) ||
    die "vault schema $(plain "$schema") is not readable by ress $VERSION"

  private_dir "$STATE_DIR"
  RESTORE_STATE="$STATE_DIR/restore.state"
  if (( ! DRY_RUN )); then
    (( restart )) && rm -f "$RESTORE_STATE"
    # Progress belongs to one snapshot of one vault. Without that line, a
    # restore of a *different* vault read the previous one's progress and
    # skipped every category as "already done" — silently doing nothing, which
    # is the worst way for a restore to fail. A newer backup of the same vault
    # starts over too: what was done was done from the old snapshot.
    local identity="# $VAULT $(jq -r '.createdAt // "?"' "$manifest" 2>/dev/null || echo "?")"
    if [[ ! -f $RESTORE_STATE ]] || [[ $(head -1 "$RESTORE_STATE" 2>/dev/null) != "$identity" ]]; then
      printf '%s\n' "$identity" >"$RESTORE_STATE"
    fi
  fi

  local origin; origin=$(plain "$(jq -r '.machine.hostname // "?"' "$manifest")")
  local created; created=$(plain "$(jq -r '.createdAt // "?"' "$manifest")")

  report_executable_content

  if (( ! DRY_RUN )); then
    if (( PORCELAIN )); then
      emit "LOG|restoring $origin (backed up $created) onto $(hostname)"
      (( FIRST_CONTACT )) && emit "LOG|this machine has not restored from this vault before"
    else
      printf '%sRestoring %s%s (backed up %s) onto %s.%s\n' \
        "$c_bold" "$origin" "$c_reset$c_dim" "$created" "$(hostname)" "$c_reset"
      (( FIRST_CONTACT )) && printf '%sThis machine has not restored from this vault before.%s\n' \
        "$c_dim" "$c_reset"
    fi
    report_restore_preview
    # An unpinned clone is whatever upstream contains at the moment it runs. On
    # a vault this machine already backs up to, that is your own repository
    # moving on. On one it has never seen, it is a second decision, so it is
    # asked as one.
    if (( ALLOW_UNPINNED && FIRST_CONTACT )); then
      printf '\n%s--allow-unpinned on a vault this machine has not used before.%s\n' "$c_yellow" "$c_reset"
      printf '  Plugins and themes with no recorded commit will be cloned at whatever\n'
      printf '  their branch head holds when this runs — not at what was captured.\n'
      confirm "Take branch heads from this vault?" || die "cancelled"
    fi
    confirm "This overwrites configuration in your home directory. Continue?" ||
      die "cancelled"
    # A one-off `--vault` is a scratch restore, not a change of allegiance.
    if [[ -n ${pending_remote:-} && -z ${VAULT_OVERRIDE:-} ]]; then
      CFG[REMOTE]=$(strip_credentials "$pending_remote")
      save_config
    fi
  fi

  emit "BEGIN|restore|$VAULT"
  local started=$SECONDS
  local category
  for category in "${RESTORE_ORDER[@]}"; do
    [[ -n $only ]] && [[ ",$only," != *",$category,"* ]] && continue
    [[ -n $skip ]] && [[ ",$skip," == *",$category,"* ]] && { step_skip "$category" "skipped"; continue; }
    if (( ! DRY_RUN )) && step_done "$category"; then
      step_skip "$category" "already done — pass --restart to redo"
      continue
    fi
    local failures_before=${#FAILED_STEPS[@]}
    "restore_$category"
    # Only a category that actually succeeded is recorded as done. Marking a
    # failed one made "rerun to pick up where it stopped" untrue: the rerun
    # skipped precisely the step that had failed. A category left deliberately
    # incomplete is not done either, for the same reason.
    if (( ! DRY_RUN )) && (( ${#FAILED_STEPS[@]} == failures_before )) && ! was_partial "$category"; then
      mark_done "$category"
    fi
  done

  if (( ! DRY_RUN )) && (( ! PORCELAIN )); then
    local elapsed=$((SECONDS - started))
    printf '\n'
    if (( RESTORE_FAILED )); then
      printf '%sFinished with problems:%s\n' "$c_yellow" "$c_reset"
      local failure
      for failure in "${FAILED_STEPS[@]:-}"; do [[ -n $failure ]] && printf '  x %s\n' "$failure"; done
      printf 'Rerun the same command to pick up where it stopped.\n'
    else
      printf '%sThis machine is yours again%s — in %s. Log out and back in to pick up\nshell and session changes.\n' \
        "$c_bold" "$c_reset" "$(duration "$elapsed")"
    fi
    # Said after either ending: what you declined is not a problem, but it is
    # also not finished, and the next run will offer it again.
    if (( ${#PARTIAL_STEPS[@]} > 0 )); then
      printf '\n%sLeft for later:%s\n' "$c_bold" "$c_reset"
      local entry
      for entry in "${PARTIAL_STEPS[@]:-}"; do
        [[ -n $entry ]] && printf '  · %s\n' "${entry#*|}"
      done
    fi
  fi
  if (( ! DRY_RUN )); then
    have omarchy-restart-shell && omarchy-restart-shell >/dev/null 2>&1 &
    # Deferred work is reported through the protocol too: it is the difference
    # between "finished" and "finished, and here is what you still owe".
    local entry
    for entry in "${PARTIAL_STEPS[@]:-}"; do
      [[ -n $entry ]] && emit "LOG|left for later: ${entry#*|}"
    done
  fi
  emit "DONE|$( (( RESTORE_FAILED )) && echo partial || echo ok)|restore complete"
  return $RESTORE_FAILED
}
