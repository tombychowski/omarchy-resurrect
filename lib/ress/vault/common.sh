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
  [[ -f $VAULT/$VAULT_MANIFEST ]] && { printf '%s' "$VAULT/$VAULT_MANIFEST"; return 0; }
  [[ -f $VAULT/$VAULT_MANIFEST_LEGACY ]] && { printf '%s' "$VAULT/$VAULT_MANIFEST_LEGACY"; return 0; }
  printf '%s' "$VAULT/$VAULT_MANIFEST"
}

has_manifest() { [[ -f $VAULT/$VAULT_MANIFEST || -f $VAULT/$VAULT_MANIFEST_LEGACY ]]; }

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
