#!/bin/bash
#
# Vault capture: category collection, credential scanning for backup, manifest
# writing, commit orchestration, and optional push.
# Depends on core.sh, safety.sh, and vault/common.sh. Owns secret-scan findings;
# used by backup and scan reporting. Definitions only at source time.

# ================================================================== CAPTURE

# One exclude list, used by every capture. It carries the credential patterns,
# so any capture that forgets it is a capture that can put a key in the vault.
build_excludes() {
  private_dir "$STATE_DIR"
  local out="$STATE_DIR/exclude.rsync" owned relative entry
  local -a owned_paths=(
    "$CONFIG_DIR"
    "$STATE_DIR"
    "${XDG_DATA_HOME:-$HOME/.local/share}/montage"
    "${VAULT_REPOSITORY_ROOT:-$VAULT}"
  )
  merged_list exclude >"$out"
  # Montage configuration, operational state, repositories, and its PATH link
  # are machine-local. Derive paths as well as shipping defaults so custom XDG
  # roots and a vault nested below a broad include cannot capture themselves.
  if [[ -e $MONTAGE_REPOSITORY_REGISTRY ]]; then
    repository_registry_load || return 1
    while IFS= read -r entry; do
      owned_paths+=("$(jq -r '.path' <<<"$entry")")
    done < <(jq -c '.repositories[]' <<<"$REPOSITORY_REGISTRY")
  fi
  for owned in "${owned_paths[@]}"; do
    [[ -n $owned && $owned == "$HOME"/* ]] || continue
    relative="${owned#"$HOME"/}"
    printf '%s/\n' "$relative" >>"$out"
  done
  printf '%s\n' '.local/bin/mntg' '**/*.montage-bak' >>"$out"
  printf '%s\n' "$out"
}

capture_path_is_montage_owned() {
  local path="$1" owned entry
  local -a owned_paths=(
    "$CONFIG_DIR"
    "$STATE_DIR"
    "${XDG_DATA_HOME:-$HOME/.local/share}/montage"
    "${VAULT_REPOSITORY_ROOT:-$VAULT}"
    "$HOME/.local/bin/mntg"
  )
  if [[ -e $MONTAGE_REPOSITORY_REGISTRY ]]; then
    repository_registry_load || return 2
    while IFS= read -r entry; do
      owned_paths+=("$(jq -r '.path' <<<"$entry")")
    done < <(jq -c '.repositories[]' <<<"$REPOSITORY_REGISTRY")
  fi
  for owned in "${owned_paths[@]}"; do
    [[ -n $owned ]] || continue
    [[ $path == "$owned" || $path == "$owned"/* ]] && return 0
  done
  [[ $path == *"$BAK_SUFFIX" ]]
}

capture_packages() {
  local out="$VAULT/packages"
  mkdir -p "$out"
  step_start packages "Reading the package database"
  pacman -Qqen >"$out/native.txt" 2>/dev/null || : >"$out/native.txt"
  pacman -Qqem >"$out/foreign.txt" 2>/dev/null || : >"$out/foreign.txt"
  local n f
  n=$(count_lines "$out/native.txt"); f=$(count_lines "$out/foreign.txt")
  step_ok packages "$(plural "$n" "explicit package"), $f from the AUR"
  CAPTURED_PACKAGES=$((n + f))
  return 0
}

# Everything the include list points at, minus the exclude patterns, mirrored
# into the vault at its $HOME-relative path. ~/.config/omarchy is deliberately
# absent — it is the `omarchy` category's job, which knows to leave the plugin
# checkouts behind.
capture_config() {
  local out="$VAULT/home"
  rm -rf "$out"; mkdir -p "$out"
  step_start config "Copying dotfiles"

  local excludes; excludes=$(build_excludes)
  printf '%s\n' ".config/omarchy/" >>"$excludes"

  local entries=() entry present=0 missing=0
  while IFS= read -r entry; do entries+=("$entry"); done < <(merged_list include)
  # Opt-in, and never silently: every entry under it is a command that runs at
  # the next login, on whatever machine this vault is replayed onto.
  if [[ ${CFG[CAPTURE_AUTOSTART]:-0} == 1 ]] && [[ -d $HOME/.config/autostart ]]; then
    entries+=(".config/autostart")
    local n_autostart; n_autostart=$(find "$HOME/.config/autostart" -type f -name '*.desktop' 2>/dev/null | wc -l)
    (( n_autostart > 0 )) &&
      step_warn config "capturing $(plural "$n_autostart" "autostart entry" "autostart entries") — each one runs at login wherever this vault is restored"
  fi

  local total=${#entries[@]} i=0
  for entry in "${entries[@]}"; do
    i=$((i + 1))
    progress config "$i" "$total"
    [[ -e $HOME/$entry ]] || { missing=$((missing + 1)); continue; }
    rsync -a --relative --safe-links --exclude-from="$excludes" \
      --max-size=20m "$HOME/./$entry" "$out/" 2>/dev/null || true
    present=$((present + 1))
  done

  # Name what we walked past. A backup tool that quietly captures 30% of your
  # config is worse than one that captures 30% and says so.
  # `systemctl --user enable` writes symlink farms under *.wants/. Those are
  # state, not configuration: copying them produces unit files that shadow the
  # real ones. Record what is enabled instead and re-enable it on the far side.
  mkdir -p "$VAULT/services"
  if have systemctl; then
    systemctl --user list-unit-files --state=enabled --no-legend --plain 2>/dev/null |
      awk '{print $1}' >"$VAULT/services/user-units.txt" || : >"$VAULT/services/user-units.txt"
  else
    : >"$VAULT/services/user-units.txt"
  fi
  CAPTURED_UNITS=$(count_lines "$VAULT/services/user-units.txt")

  local skipped="$VAULT/report"
  mkdir -p "$skipped"
  : >"$skipped/not-captured.txt"
  local dir base
  for dir in "$HOME"/.config/*/; do
    base=".config/$(basename "$dir")"
    capture_path_is_montage_owned "${dir%/}" && continue
    grep -qxF "$base" <(printf '%s\n' "${entries[@]}") && continue
    [[ $base == ".config/omarchy" ]] && continue
    printf '%s\n' "$base" >>"$skipped/not-captured.txt"
  done
  # --safe-links drops symlinks that point outside the captured tree. That is
  # what stops a link from smuggling an excluded file in under another name, but
  # it also means the target genuinely did not travel — so say which.
  : >"$skipped/symlinks-skipped.txt"
  local link target
  for entry in "${entries[@]}"; do
    [[ -e $HOME/$entry ]] || continue
    while IFS= read -r link; do
      # *.wants/ links are systemd enable-state, captured separately as unit
      # names; *$BAK_SUFFIX are Montage's own replacement leftovers. Neither is
      # lost, so neither belongs in a report about things that did not travel.
      [[ $link == */.wants/* || $link == *.wants/* ]] && continue
      [[ $link == *"$BAK_SUFFIX" ]] && continue
      capture_path_is_montage_owned "$link" && continue
      target=$(readlink -f "$link" 2>/dev/null || true)
      [[ -n $target && $target == "$HOME"/* ]] && continue
      printf '%s -> %s\n' "${link#"$HOME"/}" "${target:-<broken>}" >>"$skipped/symlinks-skipped.txt"
    done < <(find "$HOME/$entry" -type l 2>/dev/null)
  done
  local links; links=$(count_lines "$skipped/symlinks-skipped.txt")
  (( links == 0 )) || step_warn config "$links symlink(s) point outside your home and were not followed (see report/symlinks-skipped.txt)"

  local unknown; unknown=$(count_lines "$skipped/not-captured.txt")

  CAPTURED_CONFIG=$present
  CAPTURED_UNCAPTURED=$unknown
  step_ok config "$present paths captured, ${CAPTURED_UNITS:-0} user services enabled"
  # An entry on the capture list that does not exist here was being counted and
  # then thrown away, which is the one thing the surrounding comment says this
  # function does not do.
  (( missing > 0 )) && note "on the capture list but not on this machine: $missing"
  (( unknown > 0 )) && note "$unknown config directories were not on the list (see report/not-captured.txt)"
  return 0
}

capture_omarchy() {
  local out="$VAULT/omarchy"
  rm -rf "$out"; mkdir -p "$out"
  step_start omarchy "Capturing Omarchy state"

  local src="$HOME/.config/omarchy"
  local item
  for item in shell.json shell.toml; do
    [[ -f $src/$item ]] && cp "$src/$item" "$out/$item"
  done
  local excludes; excludes=$(build_excludes)
  for item in branding defaults extensions hooks themed; do
    [[ -d $src/$item ]] &&
      rsync -a --exclude-from="$excludes" --max-size=20m -- "$src/$item/" "$out/$item/" 2>/dev/null
  done

  # Themes: git-installed ones travel as a URL, hand-made ones as files.
  mkdir -p "$out/themes"
  : >"$out/themes.tsv"
  local theme name url
  for theme in "$src"/themes/*/; do
    [[ -d $theme ]] || continue
    name=$(basename "$theme")
    url=$(git -C "$theme" remote get-url origin 2>/dev/null || true)
    if [[ -n $url ]]; then
      url=$(strip_credentials "$url")
      printf '%s\t%s\t%s\n' "$name" "$url" "$(git -C "$theme" rev-parse HEAD 2>/dev/null || true)" >>"$out/themes.tsv"
      # Same rule the restore applies, said where it can still be acted on.
      valid_git_remote "$url" ||
        step_warn omarchy "theme $name has a remote a restore will not clone ($(plain "$url")) — it will travel as nothing at all"
    else
      printf '%s\t\t\n' "$name" >>"$out/themes.tsv"
      rsync -a --exclude '.git/' --exclude-from="$excludes" --max-size=20m -- "$theme" "$out/themes/$name/" 2>/dev/null
    fi
  done

  # Which theme is on, and which of its backgrounds.
  active_theme_name >"$out/theme.name" || rm -f "$out/theme.name"
  local bg
  bg=$(readlink "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)
  [[ -n $bg ]] && basename "$bg" >"$out/background.name"

  local themes; themes=$(count_lines "$out/themes.tsv")
  CAPTURED_THEMES=$themes
  step_ok omarchy "shell layout, $themes themes, $(cat "$out/theme.name" 2>/dev/null || echo "no") theme active"
  return 0
}

# Omarchy web apps are .desktop files whose Exec runs omarchy-launch-webapp.
# That signature is what separates the ones you made from the two hundred your
# package manager installed.
#
# Only the first Exec line is the launcher. A second one is a Desktop Action:
# another command the first line does not account for.
launcher_exec() { sed -n 's/^Exec=//p' "$1" | head -1; }

# Byte-identical to a launcher the package ships, so it is not this machine's
# state. Omarchy keeps its own in $OMARCHY_DIR/applications, a fresh install has
# them already, and capturing one puts a copy in ~/.local/share/applications on
# the far side that then shadows the package-owned file for good.
package_owned_launcher() {
  local path="$1" name="$2" shipped
  for shipped in "$OMARCHY_DIR/applications/$name" "/usr/share/applications/$name"; do
    [[ -f $shipped ]] && cmp -s -- "$path" "$shipped" && return 0
  done
  return 1
}

# Whether a launcher can come back at all: exactly one Exec line, and that line
# parses as a launcher URL with optional flags. A restore refuses anything else,
# so restore, verify and the loadout export ask this one question rather than
# three versions of it. They used to disagree: verify counted a launcher a
# restore would refuse, and the export published one.
launcher_travels() {
  [[ -f $1 ]] || return 1
  # A second Exec= line is a Desktop Action: a command the first line does not
  # account for, and one this cannot rebuild.
  [[ $(grep -c '^Exec=' "$1" 2>/dev/null || true) == 1 ]] || return 1
  webapp_parts "$(launcher_exec "$1")" >/dev/null
}

capture_webapps() {
  local out="$VAULT/webapps"
  rm -rf "$out"; mkdir -p "$out/apps" "$out/icons"
  step_start webapps "Finding web apps"

  local n=0 stock=0 desktop icon name
  local unrebuildable=() credentialed=()
  for desktop in "$HOME"/.local/share/applications/*.desktop; do
    [[ -f $desktop ]] || continue
    grep -q "omarchy-launch-webapp\|omarchy-launch-or-focus-webapp" "$desktop" || continue
    name=$(basename "$desktop")
    if package_owned_launcher "$desktop" "$name"; then stock=$((stock + 1)); continue; fi
    if webapp_url_has_credentials "$(launcher_exec "$desktop")"; then
      credentialed+=("${name%.desktop}")
      continue
    fi
    cp "$desktop" "$out/apps/"
    n=$((n + 1))
    # The launcher is recorded whatever its Exec line says: the vault is also a
    # record of what was here. Whether a restore can rebuild it is a separate
    # question, answered by the same rule the restore itself uses, and it is
    # worth answering now rather than on the machine that cannot fix it.
    launcher_travels "$desktop" || unrebuildable+=("${name%.desktop}")
    icon=$(sed -n 's/^Icon=//p' "$desktop" | head -1)
    [[ -n $icon ]] || continue
    local found
    for found in "$HOME"/.local/share/icons/hicolor/*/apps/"$icon".*; do
      [[ -f $found ]] && cp "$found" "$out/icons/" && break
    done
  done
  CAPTURED_WEBAPPS=$n
  step_ok webapps "$(plural "$n" "web app")"
  (( stock == 0 )) ||
    note "$stock launcher(s) Omarchy ships were left out — a fresh install has them already"
  (( ${#unrebuildable[@]} == 0 )) || step_warn webapps \
    "$(plural "${#unrebuildable[@]}" "launcher") a restore cannot re-create (not a launcher URL with optional flags): ${unrebuildable[*]}"
  (( ${#credentialed[@]} == 0 )) || step_warn webapps \
    "$(plural "${#credentialed[@]}" "launcher") left out because its URL contains credentials: ${credentialed[*]}"
  return 0
}

capture_plugins() {
  local out="$VAULT/plugins"
  mkdir -p "$out"
  : >"$out/plugins.tsv"
  step_start plugins "Listing shell plugins"

  local n=0 dir id url sha enabled shell_json="$HOME/.config/omarchy/shell.json"
  for dir in "$HOME"/.config/omarchy/plugins/*/; do
    [[ -f $dir/manifest.json ]] || continue
    id=$(jq -r '.id // empty' "$dir/manifest.json" 2>/dev/null) || continue
    [[ -n $id ]] || continue
    url=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
    url=$(strip_credentials "$url")
    sha=$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)
    enabled=0
    if [[ -f $shell_json ]] && grep -qF "\"$id\"" "$shell_json"; then enabled=1; fi
    printf '%s\t%s\t%s\t%s\n' "$id" "$url" "$enabled" "$sha" >>"$out/plugins.tsv"
    n=$((n + 1))
    # Both of these are said here rather than on the far side: a plugin that
    # cannot be re-cloned is a gap in the vault, and the machine that has the
    # checkout is the only one where it can be closed. A `file://` remote or a
    # bare local path is the usual way this happens — a plugin developed in a
    # working directory rather than installed from somewhere git can fetch.
    if [[ -z $url ]]; then
      step_warn plugins "$id has no git remote — it will not be restored"
    elif ! valid_git_remote "$url"; then
      step_warn plugins "$id's remote is not one a restore will clone ($(plain "$url")) — push it somewhere git can fetch, or it will not be restored"
    fi
  done
  CAPTURED_PLUGINS=$n
  step_ok plugins "$(plural "$n" plugin)"
  return 0
}

capture_secrets() {
  local out="$VAULT/secrets"
  mkdir -p "$out"
  local list="$CONFIG_DIR/secrets"

  if ! have age; then
    step_skip secrets "age is not installed — run: sudo pacman -S age"
    return 0
  fi
  if [[ ! -f $list ]]; then
    step_skip secrets "no secrets list — run: mntg secrets init"
    return 0
  fi

  local paths=() p
  while IFS= read -r p; do [[ -e $HOME/$p ]] && paths+=("$p"); done < <(merged_list_file "$list")
  if (( ${#paths[@]} == 0 )); then
    step_skip secrets "nothing on the secrets list exists here"
    return 0
  fi

  step_start secrets "Encrypting ${#paths[@]} paths"
  local args=()
  case "${CFG[SECRETS_MODE]}" in
    recipient)
      [[ -n ${CFG[SECRETS_RECIPIENT]} ]] || { step_fail secrets "SECRETS_MODE=recipient but SECRETS_RECIPIENT is empty"; return 0; }
      if [[ -f ${CFG[SECRETS_RECIPIENT]} ]]; then args=(-R "${CFG[SECRETS_RECIPIENT]}")
      else args=(-r "${CFG[SECRETS_RECIPIENT]}"); fi
      ;;
    *)
      if (( PORCELAIN )) || [[ ! -t 0 ]]; then
        step_skip secrets "passphrase mode needs a terminal — run: mntg backup"
        return 0
      fi
      args=(-p)
      ;;
  esac

  tar -C "$HOME" -cf - --numeric-owner "${paths[@]}" 2>/dev/null |
    age "${args[@]}" -o "$out/secrets.tar.age" ||
    { step_fail secrets "encryption failed"; return 0; }
  chmod 600 "$out/secrets.tar.age"
  CAPTURED_SECRETS=${#paths[@]}
  step_ok secrets "${#paths[@]} paths encrypted"
  return 0
}

merged_list_file() {
  sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$1"
}

# ============================================================== SECRET SCAN
#
# The capture list is an allowlist, and credentials are deliberately not on it.
# That is the design, and it is not the same as a guarantee: the risk that is
# left is a key inside a file that does belong in the vault. A token pasted into
# a script in ~/.local/bin, an Environment= line in a user unit, a helper that
# writes into ~/.config/git. Those travel with the config they live in.
#
# So the vault is read back before it is committed, looking for the shapes
# credentials actually have. Nothing here is clever: it is a list of the prefixes
# that vendors chose to make their tokens recognisable, plus assignments that
# name themselves. It will not find a secret with no shape to it, and it says so.

declare -A SECRET_RULES=(
  [github-token]='(^|[^A-Za-z0-9_])gh[pousr]_[A-Za-z0-9]{36}([^A-Za-z0-9_]|$)'
  [github-pat]='github_pat_[A-Za-z0-9_]{60,}'
  [gitlab-token]='glpat-[A-Za-z0-9_-]{20,}'
  [aws-access-key]='(^|[^A-Z0-9])(AKIA|ASIA)[0-9A-Z]{16}([^A-Z0-9]|$)'
  [slack-token]='xox[baprs]-[A-Za-z0-9-]{10,}'
  [openai-key]='(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9]{32,}'
  [anthropic-key]='sk-ant-[A-Za-z0-9_-]{20,}'
  [google-api-key]='(^|[^A-Za-z0-9_])AIza[0-9A-Za-z_-]{35}'
  [npm-token]='(^|[^A-Za-z0-9_])npm_[A-Za-z0-9]{36}'
  [digitalocean-token]='dop_v1_[a-f0-9]{64}'
  [huggingface-token]='(^|[^A-Za-z0-9_])hf_[A-Za-z0-9]{34}'
  [stripe-key]='(^|[^A-Za-z0-9_])sk_live_[A-Za-z0-9]{20,}'
  [pypi-token]='pypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{20,}'
  [private-key]='-----BEGIN [A-Z ]*PRIVATE KEY-----'
  [named-assignment]='^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*(TOKEN|SECRET|PASSWORD|PASSWD|APIKEY|API_KEY|ACCESS_KEY)[A-Za-z0-9_]*=[^[:space:]]{8,}'
  [systemd-environment]='^[[:space:]]*Environment=.*(TOKEN|SECRET|PASSWORD|PASSWD|APIKEY|API_KEY|ACCESS_KEY)[A-Za-z0-9_]*='
)

# The two rules above that match a *name* rather than a shape are the ones that
# find `GITHUB_TOKEN=` in a dotfile — and also every example, every indirection
# through another variable, and every empty default. Those are dropped, because
# a scanner that cries wolf is a scanner that gets turned off.
SECRET_RULES_LOOSE=" named-assignment systemd-environment "

looks_like_placeholder() {
  local line="$1"
  # An indirection is not a secret: $OTHER, $(cmd), `cmd`, ${x}.
  [[ $line =~ [=\"\'][[:space:]]*[\$\`] ]] && return 0
  [[ $line =~ =[[:space:]]*(\"\"|\'\'|$) ]] && return 0
  shopt -s nocasematch
  local placeholder=0
  [[ $line =~ (your[-_a-z]*|example|changeme|change-me|placeholder|redacted|dummy|todo|xxxx|\<[a-z_-]+\>|\.\.\.) ]] && placeholder=1
  shopt -u nocasematch
  return $(( placeholder ? 0 : 1 ))
}

# Fills SECRET_FINDINGS with "path<TAB>rule" lines, one per file per rule. The
# matched text is never captured, printed or written down: the point is to name
# the file, and a report that quotes the secret is a second copy of it.
SECRET_FINDINGS=""
secret_scan() {
  SECRET_FINDINGS=""
  # Success means "findings exist" — every caller reads it that way — so having
  # nothing to look at is a failure to find, not a success. Returning 0 here had
  # a backup with no dotfile categories report "possible credentials in 0 files",
  # and under SECRET_SCAN=block refuse to commit anything, ever again.
  local roots=() root
  for root in "$@"; do [[ -d $root ]] && roots+=("$root"); done
  (( ${#roots[@]} > 0 )) || return 1
  have grep || return 1

  # Every rule joined into one pattern for a single walk of the tree, because
  # seventeen walks of a home directory is seventeen walks of a home directory.
  # The per-rule pass then only reads the few files that matched anything.
  local rule pattern combined=""
  for rule in "${!SECRET_RULES[@]}"; do
    combined+="${SECRET_RULES[$rule]}|"
  done
  local candidates=()
  # -I skips binaries, so an encrypted blob or a font is never read as text.
  while IFS= read -r file; do
    [[ -n $file ]] && candidates+=("$file")
  done < <(grep -rIlE --binary-files=without-match --exclude-dir=.git --exclude=secrets.tar.age \
    -e "${combined%|}" -- "${roots[@]}" 2>/dev/null || true)
  (( ${#candidates[@]} > 0 )) || return 1

  local hits file line found=""
  for rule in "${!SECRET_RULES[@]}"; do
    pattern="${SECRET_RULES[$rule]}"
    # -H because grep leaves the filename off when it is given exactly one file,
    # and the parse below is all filename.
    hits=$(grep -HInE --binary-files=without-match -e "$pattern" -- "${candidates[@]}" 2>/dev/null || true)
    [[ -n $hits ]] || continue
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      file="${line%%:*}"
      if [[ $SECRET_RULES_LOOSE == *" $rule "* ]]; then
        # ${line#*:*:} is the matched text, read here and kept nowhere.
        looks_like_placeholder "${line#*:*:}" && continue
      fi
      # The path is printed later, and a vault chooses its own filenames — a
      # name carrying escape sequences would otherwise repaint the terminal the
      # findings are being read in.
      found+="$(plain "${file#"$VAULT/"}")"$'\t'"$rule"$'\n'
    done <<<"$hits"
  done
  SECRET_FINDINGS=$(printf '%s' "$found" | sort -u | grep -v '^$' || true)
  [[ -n $SECRET_FINDINGS ]]
}

secret_scan_mode() {
  case "${CFG[SECRET_SCAN]:-warn}" in
    off|no|0|false) printf 'off' ;;
    block|stop) printf 'block' ;;
    *) printf 'warn' ;;
  esac
}

# One place that renders findings, so `mntg backup` and `mntg scan` cannot drift
# into describing the same thing two ways.
report_secret_findings() {
  local count; count=$(printf '%s\n' "$SECRET_FINDINGS" | grep -c . || true)
  printf '\n%sPossible credentials in the vault (%s):%s\n\n' \
    "$c_yellow" "$(plural "$count" file)" "$c_reset"
  printf '%s\n' "$SECRET_FINDINGS" | awk -F'\t' 'NF { printf "    %-52s %s\n", $1, $2 }'
  printf '\n%sThe match is not shown, and is not written down anywhere.%s\n' "$c_dim" "$c_reset"
  printf '%sLeave one out of every future capture:%s\n' "$c_dim" "$c_reset"
  local first; first=$(printf '%s\n' "$SECRET_FINDINGS" | head -1 | cut -f1)
  printf '    echo %s >> %s/exclude\n' "${first#home/}" "$CONFIG_DIR"
  printf '%sOr, if it belongs in the vault, put it in the encrypted category:%s\n' "$c_dim" "$c_reset"
  printf '    mntg secrets add %s\n' "${first#home/}"
  return 0
}

# ================================================================== MANIFEST

write_manifest() {
  local omarchy_version="unknown" machine_id
  [[ -f $OMARCHY_DIR/version ]] && omarchy_version=$(<"$OMARCHY_DIR/version")
  machine_id=$(jq -r '.machineId' "$VAULT/$MONTAGE_REPOSITORY_MANIFEST") ||
    die "vault repository envelope is malformed"

  jq -n \
    --argjson schema "$SCHEMA" \
    --arg version "$VERSION" \
    --arg machineId "$machine_id" \
    --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg hostname "$(hostname)" \
    --arg user "$USER" \
    --arg omarchy "$omarchy_version" \
    --arg kernel "$(uname -r)" \
    --argjson categories "$(printf '%s\n' "${DONE_CATEGORIES[@]:-}" | jq -Rs 'split("\n") | map(select(length > 0))')" \
    --argjson counts "$(jq -n \
      --argjson packages "${CAPTURED_PACKAGES:-0}" \
      --argjson config "${CAPTURED_CONFIG:-0}" \
      --argjson themes "${CAPTURED_THEMES:-0}" \
      --argjson webapps "${CAPTURED_WEBAPPS:-0}" \
      --argjson plugins "${CAPTURED_PLUGINS:-0}" \
      --argjson secrets "${CAPTURED_SECRETS:-0}" \
      --argjson uncaptured "${CAPTURED_UNCAPTURED:-0}" \
      --argjson services "${CAPTURED_UNITS:-0}" \
      '$ARGS.named')" \
    '{schemaVersion: $schema, kind: "montage-backup", montageVersion: $version,
      createdAt: $createdAt, machineId: $machineId,
      machine: {hostname: $hostname, user: $user, omarchy: $omarchy, kernel: $kernel},
      categories: $categories, counts: $counts}' >"$VAULT/$VAULT_MANIFEST"
  vault_backup_manifest_validate_file "$VAULT/$VAULT_MANIFEST" "$machine_id" ||
    die "generated backup manifest failed validation"
}

# ==================================================================== BACKUP

cmd_backup() {
  local message="" push=0 force_secrets=0
  while (( $# > 0 )); do
    case "$1" in
      --message|-m) message="${2:-}"; shift 2 ;;
      --push) push=1; shift ;;
      --secrets) force_secrets=1; shift ;;
      --no-secrets) CFG[INCLUDE_SECRETS]=0; shift ;;
      *) die "unknown backup option: $1" ;;
    esac
  done
  (( force_secrets )) && CFG[INCLUDE_SECRETS]=1

  resolve_vault
  take_lock
  ensure_vault_repo
  repository_lock "$VAULT" || die "vault repository is busy"
  vault_publication_recover "$VAULT" || die "vault publication recovery failed"
  vault_repository_worktree_ready "$VAULT" || die "vault repository has uncommitted changes"
  local vault_root="$VAULT" repository_id stage
  repository_id=$(jq -r '.id' "$vault_root/$MONTAGE_REPOSITORY_MANIFEST")
  montage_make_temp_dir "$vault_root/.montage-stage.XXXXXX" ||
    die "could not create vault staging directory"
  stage="$MONTAGE_TEMP_PATH"
  cp -- "$vault_root/$MONTAGE_REPOSITORY_MANIFEST" "$stage/$MONTAGE_REPOSITORY_MANIFEST"
  [[ ! -f $vault_root/README.md ]] || cp -- "$vault_root/README.md" "$stage/README.md"
  VAULT_REPOSITORY_ROOT="$vault_root"
  VAULT="$stage"
  local backup_started=$SECONDS
  # Written before any work, so a run that dies partway still moves the next
  # deadline. Keyed off the attempt, not the success, or a failing backup
  # reschedules itself a minute later and never stops.
  date -u +%s >"$STATE_DIR/last-attempt"
  emit "BEGIN|backup|$VAULT"

  DONE_CATEGORIES=()
  local category
  for category in "${CATEGORIES[@]}"; do
    if ! cat_enabled "$category"; then
      step_skip "$category" "turned off"
      continue
    fi
    "capture_$category"
    DONE_CATEGORIES+=("$category")
  done

  write_manifest

  if [[ ${MONTAGE_TEST_INVALID_VAULT_STAGE:-} == loadouts ]]; then
    mkdir -p "$VAULT/loadouts/test"
    printf '{}\n' >"$VAULT/loadouts/test/profile.json"
  fi
  if ! (validate_vault_artifact); then
    VAULT="$vault_root"
    repository_unlock
    die "staged vault snapshot failed validation"
  fi

  # Before the commit, not after: a commit is the point at which a captured
  # credential becomes history, and history is what gets pushed.
  if [[ $(secret_scan_mode) != off ]]; then
    if secret_scan "$VAULT"; then
      private_dir "$STATE_DIR"
      printf '%s\n' "$SECRET_FINDINGS" >"$STATE_DIR/secrets-found.txt"
      chmod 600 "$STATE_DIR/secrets-found.txt" 2>/dev/null || true
      local found; found=$(printf '%s\n' "$SECRET_FINDINGS" | grep -c . || true)
      step_warn secrets "possible credentials in $(plural "$found" file)"
      (( PORCELAIN )) || report_secret_findings
      if [[ $(secret_scan_mode) == block ]]; then
        emit "DONE|fail|blocked by the secret scan"
        if (( ! PORCELAIN )); then
          printf '\n%sNothing was committed (SECRET_SCAN=block).%s\n' "$c_red" "$c_reset"
          printf 'The staged candidate was discarded; the vault working tree and history are unchanged.\n'
          printf 'Exclude them and run the backup again, or set SECRET_SCAN=warn to commit anyway.\n'
        fi
        rm -rf -- "$stage"
        VAULT="$vault_root"
        repository_unlock
        return 1
      fi
    else
      rm -f "$STATE_DIR/secrets-found.txt" 2>/dev/null || true
    fi
  fi

  VAULT="$vault_root"
  if ! vault_snapshot_content_changed "$vault_root" "$stage"; then
    rm -rf -- "$stage"
    step_skip commit "nothing changed since the last backup"
  else
    if vault_publish_stage "$vault_root" "$stage" "$repository_id"; then
      :
    else
      local publication_status=$?
      repository_unlock
      (( publication_status == 75 )) && die "vault publication was interrupted; rerun backup to recover"
      die "vault snapshot publication failed"
    fi
    local subject="${message:-Backup from $(hostname) at $(date '+%Y-%m-%d %H:%M')}"
    repository_commit_if_changed "$vault_root" "$subject" || {
      repository_unlock
      die "could not commit validated vault snapshot"
    }
    (( REPOSITORY_COMMIT_CHANGED == 1 )) || {
      repository_unlock
      die "published vault snapshot did not produce the expected content change"
    }
    step_ok commit "saved as ${REPOSITORY_COMMIT_ID:0:7}"
  fi

  if (( push )) || [[ ${CFG[AUTO_PUSH]} == 1 ]]; then
    push_vault
  fi

  private_dir "$STATE_DIR"
  date -u +%s >"$STATE_DIR/last-backup"
  repository_unlock
  emit "DONE|ok|backup complete"
  (( PORCELAIN )) || printf '\n%sBacked up to %s%s in %s\n' "$c_bold" "$VAULT" "$c_reset" "$(duration $((SECONDS - backup_started)))"
}

push_vault() {
  local remote="${CFG[REMOTE]}"
  if [[ -z $remote ]]; then
    step_skip push "no remote configured"
    return 0
  fi
  remote=$(strip_credentials "$remote")
  valid_git_remote "$remote" && ! url_has_credentials "$remote" || {
    step_fail push "configured remote is unsafe or malformed"
    return 1
  }
  git_vault remote get-url origin >/dev/null 2>&1 ||
    git_vault remote add origin "$remote"
  git_vault remote set-url origin "$remote"
  step_start push "Pushing to $remote"
  if git_vault push -q -u origin HEAD 2>/dev/null; then
    step_ok push "pushed"
  else
    step_fail push "push failed — check credentials or run: git -C $VAULT push"
  fi
}
