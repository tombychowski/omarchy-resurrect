#!/bin/bash
#
# Shared safety and transport primitives: untrusted-input validators, terminal
# sanitization, source normalization, pinned Git retrieval, and web-app parsing.
#
# Depends on core.sh for output helpers and common flags. Reads HOME and
# OMARCHY_DIR; owns RESS_HOST and web-app parser limits. Used by vault capture,
# restore and verification plus loadout sharing, apply and lifecycle workflows.
# Definitions only: sourcing this module performs no network or machine work.



# A vault chooses the text we print about it. Escape sequences in that text can
# repaint the screen — including the confirmation prompt shown just before a
# sudo — so nothing from a vault reaches the terminal with control bytes in it.
plain() { printf '%s' "$1" | tr -d '\000-\037\177'; }
# ---------------------------------------------------- untrusted vault input
#
# A vault is not necessarily yours. `restore --from <git-url>` fetches one over
# the network, so every value read out of a vault or a loadout is attacker
# controlled until it matches one of these. A name that does not match is
# dropped, never quoted and passed along.
#
# The leading-character rules are load-bearing: they are what stops a vault
# entry like `-U` or `--overwrite=/etc/passwd` from arriving as an *option* on a
# root pacman command line, and what stops an id of `../../..` from becoming a
# path that gets removed.
valid_pkg()   { [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]{0,127}$ ]]; }
valid_id()    { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] && [[ $1 != *".."* ]]; }
valid_theme() { [[ $1 =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]] && [[ $1 != *".."* ]]; }
valid_icon()  { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; }
valid_sha()   { [[ $1 =~ ^[0-9a-f]{40}$ ]]; }
valid_label() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9\ ._+\&-]{0,63}$ ]]; }
valid_https() { [[ $1 =~ ^https://[A-Za-z0-9._~:/?\#@!\$\&\(\)*+,\;=%-]{3,512}$ ]]; }
valid_unit()  { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9@._-]{0,127}\.(service|socket|timer|target|path|slice)$ ]]; }

# Accept both active-theme state layouts. Current Omarchy writes theme.name;
# older or alternate layouts may point `theme` at the selected theme instead.
# Loadout drift and fallback must not report a false missing theme for either.
active_theme_name() {
  local state="$HOME/.local/state/omarchy/current" value="" target=""
  if [[ -f $state/theme.name ]]; then
    value=$(<"$state/theme.name")
  elif [[ -L $state/theme ]]; then
    target=$(readlink "$state/theme" 2>/dev/null || true)
    [[ -n $target ]] && value=${target%/} && value=${value##*/}
  fi
  value="${value//[[:space:]]/}"
  valid_theme "$value" && printf '%s\n' "$value"
}
# A schema version is compared with (( )), and bash arithmetic is not a numeric
# context — it evaluates the *contents* of a bare name, recursively, and performs
# command substitution inside an array subscript. A vault saying its
# schemaVersion is `CFG[$(...)]` therefore ran that command, before any prompt,
# on the `restore --from` path that fetches a stranger's vault. Nothing reaches
# arithmetic now without matching this first.
valid_int()   { [[ $1 =~ ^[0-9]{1,9}$ ]]; }

# Your own plugins and themes may legitimately be cloned over SSH, so restoring
# your own vault accepts the ssh forms too — but never `file://`, never a bare
# local path, and never anything that could start with `-` and be read as a git
# option. A shared loadout stays https-only: it came from a stranger.
valid_git_remote() {
  valid_https "$1" && return 0
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9._-]*:[A-Za-z0-9._~/-]{1,400}$ ]] && return 0
  [[ $1 =~ ^(ssh|git)://[A-Za-z0-9][A-Za-z0-9._~@:/-]{1,400}$ ]] && return 0
  return 1
}

# ------------------------------------------------------- web app launchers
#
# A web app launcher is an Exec line, and Omarchy has written that line three
# ways: a bare URL, a bare URL followed by browser flags, and a quoted URL
# (what `omarchy webapp install` writes today, quoting per the Desktop Entry
# spec). Reading it as "everything after the launcher name is the URL" refused
# two of the three, so a launcher made by the current installer, or one that
# carries a Chromium profile flag, was captured and then refused on the machine
# that needed it. The line is parsed as what it is — an argument list — and
# every piece is checked on its own.
#
# `%%` is how the Desktop Entry spec writes one literal percent, and it is how
# the installer writes a URL that contains one, so it is undone here and put
# back on the way out.

# One Exec argument per line, split the way the spec says: whitespace
# separates, double quotes group, and inside them a backslash escapes \\ \" \`
# and \$. Comparisons are literal string tests rather than `case` patterns:
# a pattern arm written `'\\'` is matched after quote removal, and a pattern
# backslash escapes the next character, so it never matched a lone backslash.
desktop_exec_words() {
  local s="$1" word="" in_quote=0 i=0 n=${#1} c next
  while (( i < n )); do
    c="${s:i:1}"
    next="${s:i+1:1}"
    # %% is one literal percent, in or out of quotes.
    if [[ $c == '%' && $next == '%' ]]; then
      word+='%'; i=$((i + 2)); continue
    fi
    if (( in_quote )); then
      if [[ $c == '"' ]]; then in_quote=0; i=$((i + 1)); continue; fi
      # Inside quotes these four take a backslash off; anything else keeps it.
      if [[ $c == '\' ]] &&
        [[ $next == '\' || $next == '"' || $next == '`' || $next == '$' ]]; then
        word+="$next"; i=$((i + 2)); continue
      fi
      word+="$c"; i=$((i + 1)); continue
    fi
    if [[ $c == '"' ]]; then in_quote=1; i=$((i + 1)); continue; fi
    if [[ $c == ' ' || $c == $'\t' ]]; then
      if [[ -n $word ]]; then printf '%s\n' "$word"; word=""; fi
      i=$((i + 1)); continue
    fi
    # A backslash outside quotes stays a character. The spec does not make it
    # special there, and a word it lands in still has to match a URL or a flag
    # to be used at all, so keeping it is the conservative reading.
    word+="$c"; i=$((i + 1))
  done
  if [[ -n $word ]]; then printf '%s\n' "$word"; fi
  return 0
}

# One browser flag, and nothing else: an option with an optional =value, no
# whitespace, no quote, no shell metacharacter. A launcher's second word that is
# not a flag — a second URL, a `;`, a command — fails this and the launcher is
# refused rather than rebuilt.
#
# Flags are installed as extra arguments to the browser, so a vault can hand it
# something like --user-data-dir=/path. That is the point of carrying them, and
# it is stated in the README; what the grammar rules out is a second word, a
# quote or a backslash, so no flag can become a second command or swallow the
# one after it.
WEBAPP_FLAG_RE='^--[A-Za-z0-9][A-Za-z0-9-]{0,31}(=[A-Za-z0-9._:/@,+-]{1,128})?$'

# Nothing a launcher needs is anywhere near this long, and the parse below walks
# the line a character at a time: a vault is a stranger's file, so a 40 KB Exec
# line would otherwise buy a 30-second stall in verify and in every restore. The
# cap is what makes that cost bounded instead of quadratic on someone else's
# input.
WEBAPP_MAX_EXEC=1024

# The one shape a launcher comes back from: omarchy-launch-webapp, one http(s)
# URL, then zero or more flags. Prints "<launcher>\t<url>\t<flags>"; returns 1 for
# anything else, which is a command, and commands do not travel.
webapp_parts() {
  local exec_line="$1"
  (( ${#exec_line} <= WEBAPP_MAX_EXEC )) || return 1

  local words=() word
  while IFS= read -r word; do
    [[ -n $word ]] && words+=("$word")
  done < <(desktop_exec_words "$exec_line")

  (( ${#words[@]} >= 2 )) || return 1
  case "${words[0]}" in
    omarchy-launch-webapp|omarchy-launch-or-focus-webapp) ;;
    *) return 1 ;;
  esac

  local url="${words[1]}" flags=() i
  valid_https "$url" || return 1
  for (( i = 2; i < ${#words[@]}; i++ )); do
    [[ ${words[i]} =~ $WEBAPP_FLAG_RE ]] || return 1
    flags+=("${words[i]}")
  done
  printf '%s\t%s\t%s' "${words[0]}" "$url" "${flags[*]:-}"
}

# The launcher line to hand the installer as its custom exec, rebuilt from the
# pieces webapp_parts validated. It keeps the launcher the vault used — asking
# for the plain form when the capture said or-focus would silently change what
# the launcher does — and writes a literal percent the way the spec wants it read
# back.
webapp_exec_line() {
  local launcher="$1" url="$2"; shift 2
  local flag
  printf '%s %s' "$launcher" "${url//%/%%}"
  for flag in "$@"; do printf ' %s' "$flag"; done
}

# Read a newline-separated list, keep only what `predicate` accepts, and report
# how much was thrown away so a tampered vault is loud rather than silent.
keep_valid() {
  local predicate="$1" category="$2" what="$3" line dropped=0
  KEPT=()
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    if "$predicate" "$line"; then KEPT+=("$line"); else dropped=$((dropped + 1)); fi
  done
  (( dropped == 0 )) || step_warn "$category" "refused $dropped unsafe $what from this vault"
}

# Clone `url` into `target` at exactly `sha`, detached. A branch head moves; the
# commit that was captured — or that a loadout's author published and a reviewer
# looked at — does not. Without this, restoring or applying installs whatever
# upstream happens to contain today, which is code nobody agreed to run.
clone_pinned() {
  local url="$1" target="$2" sha="$3"
  rm -rf "$target"
  if [[ -z $sha ]]; then
    git clone -q --depth 1 -- "$url" "$target" >/dev/null 2>&1
    return $?
  fi
  if git init -q "$target" >/dev/null 2>&1 &&
    git -C "$target" remote add origin "$url" >/dev/null 2>&1 &&
    git -C "$target" fetch -q --depth 1 origin "$sha" >/dev/null 2>&1 &&
    git -C "$target" checkout -q --detach FETCH_HEAD >/dev/null 2>&1; then
    return 0
  fi
  # Hosts that refuse fetch-by-sha: take the history and pin locally instead.
  rm -rf "$target"
  if git clone -q -- "$url" "$target" >/dev/null 2>&1 &&
    git -C "$target" checkout -q --detach "$sha" >/dev/null 2>&1; then
    return 0
  fi
  rm -rf "$target"
  return 1
}

RESS_HOST="ress.sh"

# ress.sh is a redirector and nothing else — no account, no upload, no copy of
# your profile. `ress.sh/gh/you/repo` means `github.com/you/repo` and is
# resolved here, on your machine, before anything touches the network. The
# short form exists so a loadout fits in a message; the long form always works.
normalize_source() {
  local src="$1"
  [[ -e $src ]] && { printf '%s' "$src"; return 0; }

  # A source that already names its transport reaches git as given. git
  # understands ssh://, git:// and the scp form git@host:path, and the https
  # prepend at the end of this function would otherwise turn any of them into
  # https://ssh://host/... (which is what `restore --from ssh://...` used to
  # hand the clone). valid_git_remote accepts those spellings for your own
  # vault, so they have to survive this far. A local path is handled above and
  # file:// is still refused, by valid_git_remote.
  case "$src" in
    http://*|https://*) ;;  # the https forms the shorthands below are written for
    *://*|*@*:*) printf '%s' "$src"; return 0 ;;
  esac

  src="${src#http://}"
  src="${src#https://}"
  src="${src#www.}"
  src="${src%/}"

  case "$src" in
    "$RESS_HOST"/gh/*) src="github.com/${src#"$RESS_HOST"/gh/}" ;;
    "$RESS_HOST"/*)    src="github.com/${src#"$RESS_HOST"/}" ;;
    gh/*)              src="github.com/${src#gh/}" ;;
    github.com/*|gitlab.com/*|codeberg.org/*|raw.githubusercontent.com/*) ;;
    */*/*) ;;
    */*)               src="github.com/$src" ;;
  esac
  printf 'https://%s' "$src"
}

# A URL may carry a token (https://TOKEN@host/...). That is fine to use once and
# wrong to write into a config file, so it is stripped before anything is saved
# and before anything is printed.
strip_credentials() {
  local url="$1"
  [[ $url =~ ^([a-z]+://)([^/@]*@)(.*)$ ]] && url="${BASH_REMATCH[1]}${BASH_REMATCH[3]}"
  printf '%s' "$url"
}

# Two spellings of the same repository. Compared after credentials, a trailing
# .git and a trailing slash are taken off, because none of the three changes
# where the URL points.
same_remote() {
  local a b
  a=$(strip_credentials "$1"); b=$(strip_credentials "$2")
  a="${a%.git}"; b="${b%.git}"
  a="${a%/}";    b="${b%/}"
  [[ -n $a && $a == "$b" ]]
}

# The paste-me form of a repo URL, for `ress share`.
ress_link() {
  local url="$1"
  url="${url%.git}"
  url="${url#git@github.com:}"
  url="${url#https://github.com/}"
  url="${url#http://github.com/}"
  [[ $url == "$1" ]] && { printf '%s' "$1"; return 0; }
  printf '%s/gh/%s' "$RESS_HOST" "$url"
}
