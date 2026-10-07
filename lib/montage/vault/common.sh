#!/bin/bash
#
# Private-vault primitives: selected vault state, native repository and backup
# validation, safe manifest lookup/JSON rendering, and initialization.
#
# Depends on core.sh. Owns VAULT and is used by every vault command; loadout
# modules do not interpret the vault format. Definitions only: sourcing this
# module does not inspect, initialize, or mutate a vault.

VAULT=""
VAULT_REPOSITORY_ROOT=""
resolve_vault() { VAULT="${VAULT_OVERRIDE:-${CFG[VAULT]}}"; }
git_vault() { git -C "$VAULT" "$@"; }

manifest_path() {
  local path
  path=$(safe_control_file "$VAULT" "$VAULT_MANIFEST") ||
    die "backup manifest must be a contained regular file"
  printf '%s' "$path"
}

has_manifest() {
  [[ -e $VAULT/$MONTAGE_REPOSITORY_MANIFEST || -L $VAULT/$MONTAGE_REPOSITORY_MANIFEST ]] || return 1
  [[ -e $VAULT/$VAULT_MANIFEST || -L $VAULT/$VAULT_MANIFEST ]] || return 1
  manifest_path >/dev/null
}

vault_backup_manifest_validate_file() {
  local file="$1" expected_machine_id="${2:-}" machine_id
  [[ -f $file && ! -L $file ]] || return 1
  jq -e --argjson schema "$SCHEMA" '
    def integer: type == "number" and floor == .;
    def bounded($min; $max): type == "string" and
      (length >= $min and length <= $max) and
      (explode | all(.[]; . >= 32 and . != 127));
    type == "object" and
    keys == ["categories","counts","createdAt","kind","machine","machineId","montageVersion","schemaVersion"] and
    .schemaVersion == $schema and (.schemaVersion | integer) and
    .kind == "montage-backup" and
    (.montageVersion | bounded(1; 64)) and
    (.createdAt | type == "string") and
    (.machineId | type == "string") and
    (.machine | type == "object" and
      keys == ["hostname","kernel","omarchy","user"] and
      (.hostname | bounded(1; 255)) and (.user | bounded(1; 255)) and
      (.omarchy | bounded(1; 255)) and (.kernel | bounded(1; 255))) and
    (.categories | type == "array" and
      all(.[]; . == "packages" or . == "config" or . == "omarchy" or
        . == "webapps" or . == "plugins" or . == "secrets") and
      length == (unique | length)) and
    (.counts | type == "object" and
      keys == ["config","packages","plugins","secrets","services","themes","uncaptured","webapps"] and
      all(.[]; integer and . >= 0))
  ' "$file" >/dev/null 2>&1 || return 1
  repository_timestamp_valid "$(jq -r '.createdAt' "$file")" || return 1
  machine_id=$(jq -r '.machineId' "$file")
  repository_id_valid "$machine_id" || return 1
  [[ -z $expected_machine_id || $machine_id == "$expected_machine_id" ]]
}

vault_repository_validate_root() {
  local root="$1" expected_id="${2:-}" require_backup="${3:-1}"
  local envelope id machine_id backup
  [[ $root == /* && -d $root && ! -L $root ]] || return 1
  envelope=$(safe_control_file "$root" "$MONTAGE_REPOSITORY_MANIFEST") || return 1
  repository_envelope_validate_file "$envelope" vault || return 1
  id=$(jq -r '.id' "$envelope")
  [[ -z $expected_id || $id == "$expected_id" ]] || return 1
  machine_id=$(jq -r '.machineId' "$envelope")

  # A native vault is one machine lineage, never a loadout collection.
  [[ ! -e $root/loadouts && ! -L $root/loadouts &&
     ! -e $root/profile.json && ! -L $root/profile.json ]] || return 1

  if [[ $require_backup == 1 ]]; then
    backup=$(safe_control_file "$root" "$VAULT_MANIFEST") || return 1
    vault_backup_manifest_validate_file "$backup" "$machine_id" || return 1
  elif [[ -e $root/$VAULT_MANIFEST || -L $root/$VAULT_MANIFEST ]]; then
    backup=$(safe_control_file "$root" "$VAULT_MANIFEST") || return 1
    vault_backup_manifest_validate_file "$backup" "$machine_id" || return 1
  fi
}

validate_vault_artifact() {
  local relative path
  vault_repository_validate_root "$VAULT" "" 1 ||
    die "vault repository or backup manifest is malformed or unsupported"
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

vault_publication_journal_path() {
  local root="$1" envelope id
  envelope=$(safe_control_file "$root" "$MONTAGE_REPOSITORY_MANIFEST") || return 1
  repository_envelope_validate_file "$envelope" vault || return 1
  id=$(jq -r '.id' "$envelope")
  printf '%s/vault-publications/%s.json' "$STATE_DIR" "$id"
}

vault_publication_write_journal() {
  local root="$1" stage="$2" recovery="$3" state="$4" journal tmp
  journal=$(vault_publication_journal_path "$root") || return 1
  private_dir "$(dirname "$journal")"
  montage_make_temp_file "$(dirname "$journal")/.journal.XXXXXX" || return 1
  tmp="$MONTAGE_TEMP_PATH"
  jq -nc --arg root "$root" --arg stage "$stage" --arg recovery "$recovery" \
    --arg state "$state" \
    '{schemaVersion:1,root:$root,stage:$stage,recovery:$recovery,state:$state}' >"$tmp" || return 1
  chmod 600 "$tmp" 2>/dev/null || true
  mv -- "$tmp" "$journal"
}

vault_snapshot_mutable_entry() {
  local path="$1" base
  base=$(basename "$path")
  [[ $base != .git && $base != "$MONTAGE_REPOSITORY_MANIFEST" && $base != README.md &&
     $base != .montage-stage.* && $base != .montage-recovery.* ]]
}

vault_move_mutable_entries() {
  local source="$1" destination="$2" path
  mkdir -p -- "$destination"
  while IFS= read -r -d '' path; do
    vault_snapshot_mutable_entry "$path" || continue
    mv -- "$path" "$destination/" || return 1
  done < <(find "$source" -mindepth 1 -maxdepth 1 -print0)
}

vault_remove_mutable_entries() {
  local root="$1" path
  while IFS= read -r -d '' path; do
    vault_snapshot_mutable_entry "$path" || continue
    rm -rf -- "$path" || return 1
  done < <(find "$root" -mindepth 1 -maxdepth 1 -print0)
}

vault_publication_recover() {
  local root="$1" journal state recorded_root stage recovery root_real
  journal=$(vault_publication_journal_path "$root") || return 1
  [[ -e $journal ]] || return 0
  [[ -f $journal && ! -L $journal ]] || return 1
  jq -e '
    type == "object" and
    keys == ["recovery","root","schemaVersion","stage","state"] and
    .schemaVersion == 1 and
    (.state == "prepared" or .state == "old-moved" or .state == "published") and
    all(.root,.stage,.recovery; type == "string")
  ' "$journal" >/dev/null 2>&1 || return 1
  recorded_root=$(jq -r '.root' "$journal")
  stage=$(jq -r '.stage' "$journal")
  recovery=$(jq -r '.recovery' "$journal")
  state=$(jq -r '.state' "$journal")
  root_real=$(realpath -e -- "$root") || return 1
  [[ $recorded_root == "$root_real" && $stage == "$root_real"/.montage-stage.* &&
     $recovery == "$root_real"/.montage-recovery.* ]] || return 1
  case "$state" in
    prepared)
      [[ ! -e $stage ]] || rm -rf -- "$stage"
      [[ ! -e $recovery ]] || rm -rf -- "$recovery"
      ;;
    old-moved)
      vault_remove_mutable_entries "$root_real" || return 1
      if [[ -d $recovery/original && ! -L $recovery/original ]]; then
        vault_move_mutable_entries "$recovery/original" "$root_real" || return 1
      fi
      [[ ! -e $stage ]] || rm -rf -- "$stage"
      rm -rf -- "$recovery"
      ;;
    published)
      [[ ! -e $stage ]] || rm -rf -- "$stage"
      [[ ! -e $recovery ]] || rm -rf -- "$recovery"
      ;;
  esac
  rm -- "$journal"
}

vault_publish_stage() {
  local root="$1" stage="$2" expected_id="$3" recovery journal
  vault_repository_validate_root "$stage" "$expected_id" 1 || return 1
  vault_repository_validate_root "$root" "$expected_id" 0 || return 1
  recovery=$(mktemp -d "$root/.montage-recovery.XXXXXX") || return 1
  mkdir -- "$recovery/original" || { rmdir -- "$recovery"; return 1; }
  vault_publication_write_journal "$root" "$stage" "$recovery" prepared || return 1
  journal=$(vault_publication_journal_path "$root") || return 1
  vault_move_mutable_entries "$root" "$recovery/original" || return 1
  vault_publication_write_journal "$root" "$stage" "$recovery" old-moved || return 1
  if [[ ${MONTAGE_TEST_INTERRUPT_AFTER_VAULT_OLD_MOVE:-0} == 1 ]]; then return 75; fi
  vault_move_mutable_entries "$stage" "$root" || return 1
  rm -rf -- "$stage"
  vault_publication_write_journal "$root" "$stage" "$recovery" published || return 1
  rm -rf -- "$recovery"
  rm -- "$journal"
  vault_repository_validate_root "$root" "$expected_id" 1
}

vault_snapshot_content_changed() {
  local root="$1" candidate="$2" current_normalized candidate_normalized
  [[ -f $root/$VAULT_MANIFEST ]] || return 0
  private_dir "$STATE_DIR/vault-compare"
  montage_make_temp_file "$STATE_DIR/vault-compare/current.XXXXXX" || return 0
  current_normalized="$MONTAGE_TEMP_PATH"
  montage_make_temp_file "$STATE_DIR/vault-compare/candidate.XXXXXX" || return 0
  candidate_normalized="$MONTAGE_TEMP_PATH"
  jq -S 'del(.createdAt)' "$root/$VAULT_MANIFEST" >"$current_normalized" || return 0
  jq -S 'del(.createdAt)' "$candidate/$VAULT_MANIFEST" >"$candidate_normalized" || return 0
  cmp -s -- "$current_normalized" "$candidate_normalized" || return 0
  diff -qr --exclude='.git' --exclude='.montage-stage.*' --exclude='.montage-recovery.*' \
    --exclude="$VAULT_MANIFEST" \
    "$root" "$candidate" >/dev/null 2>&1 || return 0
  return 1
}

vault_repository_worktree_ready() {
  local root="$1" line seen_envelope=0 seen_readme=0
  if git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then
    repository_worktree_clean "$root"
    return
  fi
  while IFS= read -r line; do
    case "$line" in
      '?? montage.json') seen_envelope=1 ;;
      '?? README.md') seen_readme=1 ;;
      *) return 1 ;;
    esac
  done < <(git -C "$root" status --porcelain=v1 --untracked-files=all)
  (( seen_envelope == 1 && seen_readme == 1 ))
}

ensure_vault_repo() {
  private_dir "$VAULT"
  if [[ -e $VAULT/$MONTAGE_REPOSITORY_MANIFEST || -L $VAULT/$MONTAGE_REPOSITORY_MANIFEST ]]; then
    vault_repository_validate_root "$VAULT" "" 0 ||
      die "existing vault repository is malformed or is not a Montage vault"
    [[ -d $VAULT/.git && ! -L $VAULT/.git ]] ||
      die "existing Montage vault is not a Git repository"
    return 0
  fi

  if [[ -n $(find "$VAULT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ]]; then
    die "refusing to initialize a native Montage vault over existing content"
  fi

  local repository_id machine_id created envelope
  repository_id=$(repository_generate_id vault) || die "could not generate vault identity"
  machine_id=$(repository_generate_id machine) || die "could not generate machine lineage identity"
  created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  envelope=$(repository_envelope_json vault "$repository_id" "$created" "$machine_id") ||
    die "could not create vault repository envelope"

  if [[ ! -d $VAULT/.git ]]; then
    git_vault init -q -b main
    git_vault config user.name "$(git config --global user.name 2>/dev/null || echo "$USER")"
    git_vault config user.email "$(git config --global user.email 2>/dev/null || echo "$USER@$(hostname)")"
    printf '%s\n' "$envelope" | jq -S . >"$VAULT/$MONTAGE_REPOSITORY_MANIFEST"
    printf '%s\n' \
      "# Montage vault" "" \
      "This directory is a snapshot of an Omarchy machine, written by" \
      "Montage." "" \
      "Replay it onto a fresh install with:" "" \
      '```bash' "mntg restore --vault $VAULT" '```' >"$VAULT/README.md"
  fi
  vault_repository_validate_root "$VAULT" "$repository_id" 0 ||
    die "new vault repository failed validation"
}
