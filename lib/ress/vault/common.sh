#!/bin/bash
#
# Private-vault primitives: selected vault state, Git access, compatible
# manifest lookup/JSON rendering, and repository initialization.
#
# Depends on core.sh. Owns VAULT and is used by every vault command; loadout
# modules do not interpret the vault format. Definitions only: sourcing this
# module does not inspect, initialize, or mutate a vault.

VAULT=""
resolve_vault() { VAULT="${VAULT_OVERRIDE:-${CFG[VAULT]}}"; }
git_vault() { git -C "$VAULT" "$@"; }

# Where this vault keeps its manifest. New vaults use ress.json; one written
# before the rename is read where it lies, and moved on its next backup.
manifest_path() {
  local path
  if [[ -e $VAULT/$VAULT_MANIFEST || -L $VAULT/$VAULT_MANIFEST ]]; then
    path=$(safe_control_file "$VAULT" "$VAULT_MANIFEST") ||
      die "vault manifest must be a contained regular file"
    printf '%s' "$path"; return 0
  fi
  if [[ -e $VAULT/$VAULT_MANIFEST_LEGACY || -L $VAULT/$VAULT_MANIFEST_LEGACY ]]; then
    path=$(safe_control_file "$VAULT" "$VAULT_MANIFEST_LEGACY") ||
      die "vault manifest must be a contained regular file"
    printf '%s' "$path"; return 0
  fi
  printf '%s' "$VAULT/$VAULT_MANIFEST"
}

has_manifest() {
  [[ -e $VAULT/$VAULT_MANIFEST || -L $VAULT/$VAULT_MANIFEST ||
     -e $VAULT/$VAULT_MANIFEST_LEGACY || -L $VAULT/$VAULT_MANIFEST_LEGACY ]] || return 1
  manifest_path >/dev/null
}

validate_vault_artifact() {
  local relative path
  for relative in \
    packages/native.txt packages/foreign.txt plugins/plugins.tsv \
    services/user-units.txt omarchy/themes.tsv omarchy/theme.name \
    omarchy/background.name omarchy/shell.json omarchy/shell.toml \
    secrets/secrets.tar.age; do
    path="$VAULT/$relative"
    [[ -e $path || -L $path ]] || continue
    safe_control_file "$VAULT" "$relative" >/dev/null ||
      die "vault control file $relative must be a contained regular file"
  done

  local dir
  for relative in home omarchy webapps plugins packages services secrets; do
    dir="$VAULT/$relative"
    [[ -e $dir || -L $dir ]] || continue
    safe_artifact_dir "$VAULT" "$relative" >/dev/null ||
      die "vault directory $relative must be contained and must not be a symlink"
  done

  if [[ -d $VAULT/webapps/apps && ! -L $VAULT/webapps/apps ]]; then
    while IFS= read -r -d '' path; do
      relative="${path#"$VAULT/"}"
      safe_control_file "$VAULT" "$relative" >/dev/null ||
        die "vault launcher $relative must be a contained regular file"
    done < <(find -P "$VAULT/webapps/apps" -maxdepth 1 \( -type f -o -type l \) -print0)
  fi
}

# The vault's manifest as JSON, or null when its copy is not JSON at all. The
# rest of the answer is still true, and a status command that answers nothing is
# worse than one that answers with a hole in it.
manifest_json() {
  has_manifest || { printf 'null'; return 0; }
  local file; file=$(manifest_path)
  if jq -e . "$file" >/dev/null 2>&1; then jq -c . "$file"; else printf 'null'; fi
}

ensure_vault_repo() {
  private_dir "$VAULT"
  if [[ ! -d $VAULT/.git ]]; then
    git_vault init -q -b main
    git_vault config user.name "$(git config --global user.name 2>/dev/null || echo "$USER")"
    git_vault config user.email "$(git config --global user.email 2>/dev/null || echo "$USER@$(hostname)")"
    printf '%s\n' \
      "# ress vault" "" \
      "This directory is a snapshot of an Omarchy machine, written by" \
      "[ress](https://github.com/btsouth/omarchy-resurrect)." "" \
      "Replay it onto a fresh install with:" "" \
      '```bash' "ress restore --vault $VAULT" '```' >"$VAULT/README.md"
  fi
}
