#!/bin/bash
#
# Safe native-repository readers. Live controls are resolved as contained
# regular files; historical trees are reconstructed from Git objects into an
# isolated directory without checking out over the configured repository.
# Definitions only; sourcing this module performs no I/O.

REPOSITORY_HISTORY_TREE=""
REPOSITORY_HISTORY_COMMIT=""

repository_ref_valid() {
  local ref="${1:-}"
  (( ${#ref} >= 1 && ${#ref} <= 200 )) || return 1
  [[ $ref != -* && $ref != *$'\n'* && $ref != *$'\r'* && $ref != *$'\t'* ]] || return 1
  git check-ref-format --allow-onelevel "$ref" >/dev/null 2>&1
}

repository_resolve_commit() {
  local root="$1" ref="$2" commit
  repository_root_valid "$root" || return 1
  repository_ref_valid "$ref" || return 1
  commit=$(git -C "$root" rev-parse --verify "$ref^{commit}" 2>/dev/null) || return 1
  [[ $commit =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || return 1
  printf '%s\n' "$commit"
}

repository_loadout_profile_path() {
  local root="$1" id="$2"
  repository_id_valid "$id" || return 1
  repository_root_valid "$root" || return 1
  repository_envelope_validate_file "$root/$MONTAGE_REPOSITORY_MANIFEST" loadouts || return 1
  safe_control_file "$root" "loadouts/$id/profile.json"
}

repository_tree_path_valid() {
  local path="${1:-}" part
  local -a parts=()
  [[ -n $path && $path != /* && $path != */ &&
     $path != *$'\n'* && $path != *$'\r'* && $path != *$'\t'* ]] || return 1
  IFS='/' read -r -a parts <<<"$path"
  for part in "${parts[@]}"; do
    [[ -n $part && $part != . && $part != .. ]] || return 1
  done
}

repository_tree_links_contained() {
  local tree="$1" tree_real link link_target resolved
  [[ -d $tree && ! -L $tree ]] || return 1
  tree_real=$(realpath -e -- "$tree") || return 1
  while IFS= read -r -d '' link; do
    link_target=$(readlink -- "$link") || return 1
    [[ -n $link_target && $link_target != /* &&
       $link_target != *$'\n'* && $link_target != *$'\r'* ]] || return 1
    resolved=$(realpath -m -- "$(dirname "$link")/$link_target") || return 1
    [[ $resolved == "$tree_real"/* ]] || return 1
  done < <(find "$tree_real" -type l -print0)
}

# Reconstruct REF without changing the repository checkout, index, refs, or
# worktree metadata. Only ordinary blobs and symbolic links are accepted;
# submodules and unfamiliar modes fail closed. The caller reads the resulting
# path from REPOSITORY_HISTORY_TREE and may release it explicitly.
repository_materialize_git_tree() {
  local root="$1" ref="$2" commit temp tree listing canonical
  local record header path mode type object target link_target failed=0
  [[ $root == /* && -d $root && ! -L $root ]] || return 1
  canonical=$(realpath -e -- "$root") || return 1
  [[ $canonical == "$root" && -d $root/.git && ! -L $root/.git ]] || return 1
  repository_ref_valid "$ref" || return 1
  commit=$(git -C "$root" rev-parse --verify "$ref^{commit}" 2>/dev/null) || return 1
  [[ $commit =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || return 1
  private_dir "$STATE_DIR/repository-history"
  montage_make_temp_dir "$STATE_DIR/repository-history/read.XXXXXX" || return 1
  temp="$MONTAGE_TEMP_PATH"
  tree="$temp/tree"
  listing="$temp/tree.list"
  mkdir -- "$tree" || { rm -rf -- "$temp"; return 1; }
  git -C "$root" ls-tree -rz --full-tree -r "$commit" >"$listing" || {
    rm -rf -- "$temp"
    return 1
  }

  while IFS= read -r -d '' record; do
    [[ $record == *$'\t'* ]] || { failed=1; break; }
    header=${record%%$'\t'*}
    path=${record#*$'\t'}
    read -r mode type object <<<"$header"
    repository_tree_path_valid "$path" || { failed=1; break; }
    [[ $type == blob && $object =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || { failed=1; break; }
    target="$tree/$path"
    mkdir -p -- "$(dirname "$target")" || { failed=1; break; }
    case "$mode" in
      100644|100755)
        git -C "$root" cat-file blob "$object" >"$target" || { failed=1; break; }
        [[ $mode == 100755 ]] && chmod 755 "$target" || chmod 644 "$target"
        ;;
      120000)
        (( $(git -C "$root" cat-file -s "$object" 2>/dev/null) <= 4096 )) || { failed=1; break; }
        link_target=$(git -C "$root" cat-file blob "$object") || { failed=1; break; }
        [[ -n $link_target ]] || { failed=1; break; }
        ln -s -- "$link_target" "$target" || { failed=1; break; }
        ;;
      *) failed=1; break ;;
    esac
  done <"$listing"

  if (( failed )) || ! repository_tree_links_contained "$tree"; then
    rm -rf -- "$temp"
    return 1
  fi
  REPOSITORY_HISTORY_TREE="$tree"
  REPOSITORY_HISTORY_COMMIT="$commit"
}

# Reconstruct a native repository commit through the envelope-neutral object
# reader, then apply native identity validation to the isolated tree.
repository_materialize_history() {
  local root="$1" ref="$2" expected_type="${3:-}" manifest tree
  [[ -z $expected_type ]] || repository_type_valid "$expected_type" || return 1
  repository_root_valid "$root" || return 1
  repository_materialize_git_tree "$root" "$ref" || return 1
  tree="$REPOSITORY_HISTORY_TREE"
  manifest=$(safe_control_file "$tree" "$MONTAGE_REPOSITORY_MANIFEST") || {
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  }
  repository_envelope_validate_file "$manifest" "$expected_type" || {
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  }
}

repository_history_release() {
  local tree="${1:-$REPOSITORY_HISTORY_TREE}" history_root tree_real temp
  [[ -n $tree ]] || return 0
  history_root=$(realpath -m -- "$STATE_DIR/repository-history") || return 1
  tree_real=$(realpath -m -- "$tree") || return 1
  [[ $tree_real == "$history_root"/read.*/tree ]] || return 1
  temp=$(dirname "$tree_real")
  [[ -d $temp && ! -L $temp ]] || return 1
  rm -rf -- "$temp"
  if [[ $tree == "$REPOSITORY_HISTORY_TREE" ]]; then
    REPOSITORY_HISTORY_TREE=""
    REPOSITORY_HISTORY_COMMIT=""
  fi
}
