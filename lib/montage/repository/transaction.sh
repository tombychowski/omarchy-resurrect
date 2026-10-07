#!/bin/bash
#
# Shared repository mutation primitives: identity-scoped locks, same-filesystem
# staging, recoverable path publication, clean-tree checks, and Git commits.
# Definitions only; sourcing this module performs no I/O.

REPOSITORY_LOCK_FD=""
REPOSITORY_STAGE=""
REPOSITORY_COMMIT_CHANGED=0
REPOSITORY_COMMIT_ID=""

repository_root_valid() {
  local root="$1" canonical
  [[ $root == /* && -d $root && ! -L $root ]] || return 1
  canonical=$(realpath -e -- "$root") || return 1
  [[ $canonical == "$root" ]] || return 1
  repository_envelope_validate_file "$root/$MONTAGE_REPOSITORY_MANIFEST"
}

repository_relative_path_valid() {
  local value="${1:-}" part
  local -a parts=()
  [[ -n $value && $value != /* && $value != */ && $value != *$'\n'* && $value != *$'\r'* ]] || return 1
  IFS='/' read -r -a parts <<<"$value"
  for part in "${parts[@]}"; do
    [[ $part =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ && $part != . && $part != .. ]] || return 1
  done
}

repository_lock_path() {
  local root="$1" id
  repository_root_valid "$root" || return 1
  id=$(jq -r '.id' "$root/$MONTAGE_REPOSITORY_MANIFEST")
  printf '%s/repository-locks/%s.lock' "$STATE_DIR" "$id"
}

repository_lock() {
  local root="$1" lock
  lock=$(repository_lock_path "$root") || return 1
  private_dir "$(dirname "$lock")"
  exec {REPOSITORY_LOCK_FD}>"$lock"
  flock -n "$REPOSITORY_LOCK_FD" || {
    exec {REPOSITORY_LOCK_FD}>&-
    REPOSITORY_LOCK_FD=""
    return 1
  }
}

repository_unlock() {
  [[ -n ${REPOSITORY_LOCK_FD:-} ]] || return 0
  flock -u "$REPOSITORY_LOCK_FD" 2>/dev/null || true
  exec {REPOSITORY_LOCK_FD}>&-
  REPOSITORY_LOCK_FD=""
}

repository_worktree_clean() {
  local root="$1"
  repository_root_valid "$root" || return 1
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  [[ -z $(git -C "$root" status --porcelain=v1 --untracked-files=all 2>/dev/null) ]]
}

repository_stage_dir() {
  local root="$1"
  repository_root_valid "$root" || return 1
  montage_make_temp_dir "$root/.montage-stage.XXXXXX" || return 1
  REPOSITORY_STAGE="$MONTAGE_TEMP_PATH"
}

repository_journal_path() {
  local root="$1" id
  repository_root_valid "$root" || return 1
  id=$(jq -r '.id' "$root/$MONTAGE_REPOSITORY_MANIFEST")
  printf '%s/repository-journals/%s.json' "$STATE_DIR" "$id"
}

repository_write_journal() {
  local root="$1" state="$2" target="$3" staged="$4" backup="$5" journal tmp
  journal=$(repository_journal_path "$root") || return 1
  private_dir "$(dirname "$journal")"
  montage_make_temp_file "$(dirname "$journal")/.journal.XXXXXX" || return 1
  tmp="$MONTAGE_TEMP_PATH"
  jq -nc --arg state "$state" --arg root "$root" --arg target "$target" \
    --arg staged "$staged" --arg backup "$backup" \
    '{schemaVersion:1,state:$state,root:$root,target:$target,staged:$staged,backup:$backup}' \
    >"$tmp" || return 1
  chmod 600 "$tmp" 2>/dev/null || true
  mv -- "$tmp" "$journal"
}

repository_recover_publication() {
  local root="$1" journal state recorded_root target staged backup root_real recovery_dir
  journal=$(repository_journal_path "$root") || return 1
  [[ -e $journal ]] || return 0
  [[ -f $journal && ! -L $journal ]] || return 1
  jq -e '
    type == "object" and keys == ["backup","root","schemaVersion","staged","state","target"] and
    .schemaVersion == 1 and
    (.state == "prepared" or .state == "old-moved" or .state == "published") and
    all(.root,.target,.staged,.backup; type == "string")
  ' "$journal" >/dev/null 2>&1 || return 1
  state=$(jq -r '.state' "$journal")
  recorded_root=$(jq -r '.root' "$journal")
  target=$(jq -r '.target' "$journal")
  staged=$(jq -r '.staged' "$journal")
  backup=$(jq -r '.backup' "$journal")
  root_real=$(realpath -e -- "$root") || return 1
  [[ $recorded_root == "$root_real" && $target == "$root_real"/* &&
     $staged == "$root_real"/.montage-stage.* ]] || return 1
  [[ -z $backup || $backup == "$root_real"/.montage-recovery.*/original ]] || return 1
  if [[ -n $backup ]]; then recovery_dir=$(dirname "$backup"); else recovery_dir=""; fi

  case "$state" in
    prepared)
      [[ -e $staged ]] && rm -rf -- "$staged"
      [[ -n $recovery_dir && -d $recovery_dir ]] && rmdir -- "$recovery_dir"
      ;;
    old-moved)
      [[ ! -e $target ]] || return 1
      if [[ -n $backup && -e $backup ]]; then
        mv -- "$backup" "$target"
        rmdir -- "$recovery_dir"
      fi
      [[ -e $staged ]] && rm -rf -- "$staged"
      ;;
    published)
      [[ -e $target ]] || return 1
      [[ -n $recovery_dir && -d $recovery_dir ]] && rm -rf -- "$recovery_dir"
      [[ -e $staged ]] && rm -rf -- "$staged"
      ;;
  esac
  rm -- "$journal"
}

# Publish one already-built staged file or directory into the repository.
# VALIDATOR is called with the staged path before a journal or destination
# mutation. A test-only interruption hook leaves a recoverable old-moved state.
repository_publish_path() {
  local root="$1" staged="$2" relative="$3" validator="${4:-}" root_real staged_real target backup="" journal recovery_dir=""
  repository_root_valid "$root" || return 1
  repository_relative_path_valid "$relative" || return 1
  root_real=$(realpath -e -- "$root") || return 1
  [[ -e $staged && ! -L $staged ]] || return 1
  staged_real=$(realpath -e -- "$staged") || return 1
  [[ $staged_real == "$root_real"/.montage-stage.* ]] || return 1
  [[ -z $validator ]] || "$validator" "$staged_real" || return 1
  target="$root_real/$relative"
  mkdir -p -- "$(dirname "$target")"
  if [[ -e $target || -L $target ]]; then
    recovery_dir=$(mktemp -d "$root_real/.montage-recovery.XXXXXX") || return 1
    backup="$recovery_dir/original"
  fi
  repository_write_journal "$root_real" prepared "$target" "$staged_real" "$backup" || {
    [[ -n $recovery_dir ]] && rmdir -- "$recovery_dir"
    return 1
  }
  journal=$(repository_journal_path "$root_real") || return 1
  if [[ -n $backup ]]; then mv -- "$target" "$backup" || return 1; fi
  repository_write_journal "$root_real" old-moved "$target" "$staged_real" "$backup" || return 1
  if [[ ${MONTAGE_TEST_INTERRUPT_AFTER_OLD_MOVE:-0} == 1 ]]; then return 75; fi
  mv -- "$staged_real" "$target" || return 1
  repository_write_journal "$root_real" published "$target" "$staged_real" "$backup" || return 1
  [[ -n $recovery_dir && -d $recovery_dir ]] && rm -rf -- "$recovery_dir"
  rm -- "$journal"
}

repository_commit_if_changed() {
  local root="$1" message="$2"
  repository_root_valid "$root" || return 1
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  git -C "$root" add -A || return 1
  REPOSITORY_COMMIT_CHANGED=0
  if git -C "$root" diff --cached --quiet --exit-code; then
    REPOSITORY_COMMIT_ID=$(git -C "$root" rev-parse HEAD 2>/dev/null || true)
    return 0
  fi
  git -C "$root" commit -q -m "$message" || return 1
  REPOSITORY_COMMIT_CHANGED=1
  REPOSITORY_COMMIT_ID=$(git -C "$root" rev-parse HEAD) || return 1
}
