#!/bin/bash
#
# Immutable vault-history inspection. Each result is reconstructed from Git
# objects into an isolated tree and validated without changing the configured
# checkout, index, or working tree.

VAULT_HISTORY_ITEM=""
VAULT_SELECTED_ROOT=""
VAULT_SELECTED_TREE=""
VAULT_SELECTED_REPOSITORY_ID=""
VAULT_SELECTED_COMMIT=""

vault_backup_selector_ref() {
  local root="$1" selector="$2" label_ref
  if repository_id_valid "$selector"; then
    label_ref="refs/montage/backups/$selector"
    if git -C "$root" show-ref --verify --quiet "$label_ref"; then
      printf '%s\n' "$label_ref"
      return
    fi
  fi
  printf '%s\n' "$selector"
}

vault_backup_labels_json() {
  local root="$1" commit="$2" ref label labels='[]'
  while IFS=$'\t' read -r ref label; do
    [[ -n $ref && -n $label ]] || continue
    [[ $(git -C "$root" rev-parse "$ref^{commit}" 2>/dev/null || true) == "$commit" ]] || continue
    repository_id_valid "$label" || continue
    labels=$(jq -nc --argjson labels "$labels" --arg label "$label" '$labels + [$label]') || return 1
  done < <(git -C "$root" for-each-ref --format='%(refname)%09%(refname:strip=3)' refs/montage/backups)
  jq -c 'sort' <<<"$labels"
}

vault_select_backup_tree() {
  local root="$1" ref="${2:-HEAD}" expected_id tree
  repository_envelope_validate_file "$root/$MONTAGE_REPOSITORY_MANIFEST" vault || return 1
  expected_id=$(jq -r '.id' "$root/$MONTAGE_REPOSITORY_MANIFEST")
  ref=$(vault_backup_selector_ref "$root" "$ref") || return 1
  repository_materialize_history "$root" "$ref" vault || return 1
  tree="$REPOSITORY_HISTORY_TREE"
  if ! vault_repository_validate_root "$tree" "$expected_id" 1 ||
     ! (VAULT="$tree"; validate_vault_artifact) >/dev/null 2>&1; then
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  fi
  VAULT_SELECTED_ROOT="$root"
  VAULT_SELECTED_TREE="$tree"
  VAULT_SELECTED_REPOSITORY_ID="$expected_id"
  VAULT_SELECTED_COMMIT="$REPOSITORY_HISTORY_COMMIT"
}

vault_repository_history_valid() {
  local root="$1" commit="$2" expected_id="$3" tree
  repository_materialize_history "$root" "$commit" vault || return 1
  tree="$REPOSITORY_HISTORY_TREE"
  if ! vault_repository_validate_root "$tree" "$expected_id" 1 ||
     ! (VAULT="$tree"; validate_vault_artifact) >/dev/null 2>&1; then
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  fi
  repository_history_release "$tree"
}

vault_backup_commit_json() {
  local root="$1" ref="$2" commit tree manifest subject item labels label
  vault_select_backup_tree "$root" "$ref" || return 1
  commit="$VAULT_SELECTED_COMMIT"
  tree="$VAULT_SELECTED_TREE"
  manifest="$tree/$VAULT_MANIFEST"
  subject=$(plain "$(git -C "$root" show -s --format=%s "$commit" 2>/dev/null || true)")
  subject="${subject:0:200}"
  labels=$(vault_backup_labels_json "$root" "$commit") || {
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  }
  label=$(jq -r 'first // empty' <<<"$labels")
  item=$(jq -nc --arg commit "$commit" --arg shortCommit "${commit:0:12}" \
    --arg subject "$subject" --arg label "$label" --argjson labels "$labels" \
    --argjson manifest "$(<"$manifest")" '
      {commit:$commit,shortCommit:$shortCommit,createdAt:$manifest.createdAt,
       montageVersion:$manifest.montageVersion,machineId:$manifest.machineId,
       sourceMachine:$manifest.machine,categories:$manifest.categories,
       counts:$manifest.counts,subject:$subject,
       label:(if $label == "" then null else $label end),labels:$labels}') || {
    repository_history_release "$tree" >/dev/null 2>&1 || true
    return 1
  }
  repository_history_release "$tree" || return 1
  VAULT_HISTORY_ITEM="$item"
  printf '%s\n' "$item"
}

vault_backup_catalog_json() {
  local root="$1" repository_id commit item backups='[]'
  vault_repository_validate_root "$root" "" 0 || return 1
  repository_id=$(jq -r '.id' "$root/$MONTAGE_REPOSITORY_MANIFEST")
  git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1 || return 1
  while IFS= read -r commit; do
    [[ -n $commit ]] || continue
    item=$(vault_backup_commit_json "$root" "$commit") || return 1
    backups=$(jq -nc --argjson values "$backups" --argjson item "$item" \
      '$values + [$item]') || return 1
  done < <(git -C "$root" rev-list --first-parent HEAD)
  jq -nc --arg repositoryId "$repository_id" --arg path "$root" \
    --argjson backups "$backups" \
    '{schemaVersion:1,kind:"montage-backup-list",repositoryId:$repositoryId,
      path:$path,backups:$backups}'
}

vault_backup_print_human() {
  local item="$1"
  printf '%s  %s  %s  %s\n' \
    "$(jq -r '.shortCommit' <<<"$item")" \
    "$(plain "$(jq -r '.createdAt' <<<"$item")")" \
    "$(plain "$(jq -r '.sourceMachine.hostname' <<<"$item")")" \
    "$(plain "$(jq -r '.subject' <<<"$item")")"
}

cmd_backup_list() {
  local as_json=0 catalog item
  while (( $# > 0 )); do
    case "$1" in
      --json) as_json=1 ;;
      *) die "usage: mntg backup list [--json]" ;;
    esac
    shift
  done
  resolve_vault
  catalog=$(vault_backup_catalog_json "$VAULT") ||
    die "vault history contains a malformed or unsupported backup"
  if (( as_json )); then printf '%s\n' "$catalog"; return; fi
  printf 'Backups for vault %s:\n' "$(jq -r '.repositoryId' <<<"$catalog")"
  while IFS= read -r item; do vault_backup_print_human "$item"; done \
    < <(jq -c '.backups[]' <<<"$catalog")
}

cmd_backup_show() {
  local ref="" as_json=0 item repository_id
  while (( $# > 0 )); do
    case "$1" in
      --json) as_json=1 ;;
      *) [[ -z $ref ]] || die "usage: mntg backup show COMMIT [--json]"; ref="$1" ;;
    esac
    shift
  done
  [[ -n $ref ]] || die "usage: mntg backup show COMMIT [--json]"
  resolve_vault
  item=$(vault_backup_commit_json "$VAULT" "$ref") ||
    die "selected commit is not a valid Montage backup"
  repository_id=$(jq -r '.id' "$VAULT/$MONTAGE_REPOSITORY_MANIFEST")
  if (( as_json )); then
    jq -nc --arg repositoryId "$repository_id" --arg path "$VAULT" \
      --argjson backup "$item" \
      '{schemaVersion:1,kind:"montage-backup-show",repositoryId:$repositoryId,
        path:$path,backup:$backup}'
    return
  fi
  vault_backup_print_human "$item"
  printf '  repository: %s\n  machine id: %s\n  categories: %s\n' \
    "$repository_id" "$(jq -r '.machineId' <<<"$item")" \
    "$(jq -r '.categories | join(", ")' <<<"$item")"
}

cmd_backup_label() {
  local label="${1:-}" selector="${2:-}" as_json=0 commit ref
  shift $(( $# >= 2 ? 2 : $# ))
  while (( $# > 0 )); do
    case "$1" in --json) as_json=1 ;; *) die "usage: mntg backup label LABEL COMMIT [--json]" ;; esac
    shift
  done
  repository_id_valid "$label" || die "backup label must be a bounded lowercase id"
  [[ -n $selector ]] || die "usage: mntg backup label LABEL COMMIT [--json]"
  resolve_vault
  vault_select_backup_tree "$VAULT" "$selector" || die "selected commit is not a valid Montage backup"
  commit="$VAULT_SELECTED_COMMIT"
  ref="refs/montage/backups/$label"
  git -C "$VAULT" show-ref --verify --quiet "$ref" && die "backup label already exists: $label"
  git -C "$VAULT" update-ref "$ref" "$commit" "" || die "could not create backup label"
  if (( as_json )); then
    jq -nc --arg label "$label" --arg commit "$commit" \
      '{schemaVersion:1,kind:"montage-backup-labeled",label:$label,commit:$commit}'
  else
    printf 'Labeled backup %s as %s.\n' "${commit:0:12}" "$label"
  fi
}

cmd_backup_unlabel() {
  local label="${1:-}" as_json=0 ref commit
  shift $(( $# >= 1 ? 1 : $# ))
  while (( $# > 0 )); do
    case "$1" in --json) as_json=1 ;; *) die "usage: mntg backup unlabel LABEL [--json]" ;; esac
    shift
  done
  repository_id_valid "$label" || die "backup label must be a bounded lowercase id"
  resolve_vault
  ref="refs/montage/backups/$label"
  commit=$(git -C "$VAULT" rev-parse --verify "$ref^{commit}" 2>/dev/null) ||
    die "backup label does not exist: $label"
  git -C "$VAULT" update-ref -d "$ref" "$commit" || die "could not remove backup label"
  if (( as_json )); then
    jq -nc --arg label "$label" --arg commit "$commit" \
      '{schemaVersion:1,kind:"montage-backup-unlabeled",label:$label,commit:$commit}'
  else
    printf 'Removed label %s from backup %s. Backup content was not changed.\n' "$label" "${commit:0:12}"
  fi
}

vault_retention_plan_json() {
  local root="$1" keep="$2" catalog total remove_count kept removed protected='[]'
  local item label remote_divergence=false repository_id
  catalog=$(vault_backup_catalog_json "$root") || return 1
  total=$(jq -r '.backups | length' <<<"$catalog")
  (( keep >= 1 && keep <= total )) || return 1
  remove_count=$((total - keep))
  kept=$(jq -c --argjson keep "$keep" '.backups[:$keep] | map(.commit)' <<<"$catalog")
  removed=$(jq -c --argjson keep "$keep" '.backups[$keep:] | map(.commit)' <<<"$catalog")
  while IFS= read -r item; do
    while IFS= read -r label; do
      [[ -n $label ]] || continue
      protected=$(jq -nc --argjson values "$protected" --arg label "$label" \
        --arg commit "$(jq -r '.commit' <<<"$item")" '$values + [{label:$label,commit:$commit}]')
    done < <(jq -r '.labels[]' <<<"$item")
  done < <(jq -c --argjson keep "$keep" '.backups[$keep:][]' <<<"$catalog")
  if (( remove_count > 0 )) && git -C "$root" rev-parse --verify '@{u}^{commit}' >/dev/null 2>&1; then
    remote_divergence=true
  fi
  repository_id=$(jq -r '.repositoryId' <<<"$catalog")
  jq -nc --arg repositoryId "$repository_id" --argjson keep "$keep" \
    --argjson changed "$([[ $remove_count -gt 0 ]] && printf true || printf false)" \
    --argjson kept "$kept" --argjson removed "$removed" \
    --argjson protectedLabels "$protected" --argjson remoteDivergence "$remote_divergence" '
      {schemaVersion:1,kind:"montage-backup-retention",repositoryId:$repositoryId,
       keep:$keep,changed:$changed,kept:$kept,removed:$removed,
       protectedLabels:$protectedLabels,blocked:($protectedLabels|length > 0),
       remoteDivergence:$remoteDivergence,rewritten:[]}'
}

vault_retention_apply() {
  local root="$1" plan="$2" old_head old parent="" commit tree subject new updates
  local mapping='[]' label ref label_old label_new
  local -a retained=()
  old_head=$(git -C "$root" rev-parse HEAD) || return 1
  while IFS= read -r commit; do retained+=("$commit"); done \
    < <(jq -r '.kept[]' <<<"$plan" | tac)
  for commit in "${retained[@]}"; do
    tree=$(git -C "$root" rev-parse "$commit^{tree}") || return 1
    subject=$(plain "$(git -C "$root" show -s --format=%s "$commit")")
    subject="${subject:0:200}"
    if [[ -n $parent ]]; then
      new=$(git -C "$root" commit-tree "$tree" -p "$parent" -m "$subject") || return 1
    else
      new=$(git -C "$root" commit-tree "$tree" -m "$subject") || return 1
    fi
    mapping=$(jq -nc --argjson values "$mapping" --arg from "$commit" --arg to "$new" \
      '$values + [{from:$from,to:$to}]') || return 1
    parent="$new"
  done
  [[ -n $parent ]] || return 1
  updates="update HEAD $parent $old_head"$'\n'
  while IFS=$'\t' read -r ref label; do
    [[ -n $ref && -n $label ]] || continue
    label_old=$(git -C "$root" rev-parse "$ref^{commit}") || return 1
    label_new=$(jq -r --arg old "$label_old" '.[] | select(.from == $old) | .to' <<<"$mapping")
    [[ -n $label_new ]] || return 1
    updates+="update $ref $label_new $label_old"$'\n'
  done < <(git -C "$root" for-each-ref --format='%(refname)%09%(refname:strip=3)' refs/montage/backups)
  printf '%s' "$updates" | git -C "$root" update-ref --stdin || return 1
  jq -c --argjson mapping "$mapping" '.rewritten = $mapping' <<<"$plan"
}

vault_retention_print_human() {
  local plan="$1" commit protected
  printf 'Keep newest %s backup(s); remove %s older backup(s).\n' \
    "$(jq -r '.keep' <<<"$plan")" "$(jq -r '.removed | length' <<<"$plan")"
  while IFS= read -r commit; do printf '  remove %s\n' "${commit:0:12}"; done \
    < <(jq -r '.removed[]' <<<"$plan")
  while IFS= read -r protected; do
    printf '  protected %s by label %s\n' \
      "$(jq -r '.commit[0:12]' <<<"$protected")" "$(jq -r '.label' <<<"$protected")"
  done < <(jq -c '.protectedLabels[]' <<<"$plan")
  if [[ $(jq -r '.remoteDivergence' <<<"$plan") == true ]]; then
    printf '  warning: retained local history will diverge from the published remote.\n'
  fi
}

cmd_backup_retain() {
  local keep="" as_json=0 plan result
  while (( $# > 0 )); do
    case "$1" in
      --keep) keep="${2:-}"; shift 2 ;;
      --json) as_json=1; shift ;;
      *) die "usage: mntg backup retain --keep COUNT [--dry-run] [--json]" ;;
    esac
  done
  [[ $keep =~ ^[1-9][0-9]{0,3}$ ]] || die "--keep requires a positive bounded integer"
  resolve_vault
  plan=$(vault_retention_plan_json "$VAULT" "$keep") || die "could not create retention plan"
  if [[ $(jq -r '.blocked' <<<"$plan") == true ]]; then
    if (( as_json )); then printf '%s\n' "$plan"; else vault_retention_print_human "$plan"; fi
    die "retention is blocked by labeled backups"
  fi
  if [[ $(jq -r '.changed' <<<"$plan") == false ]] || (( DRY_RUN )); then
    if (( as_json )); then printf '%s\n' "$plan"; else vault_retention_print_human "$plan"; fi
    return 0
  fi
  (( as_json )) || vault_retention_print_human "$plan"
  confirm "Rewrite local vault history exactly as previewed?" || die "cancelled"
  repository_lock "$VAULT" || die "vault repository is busy"
  repository_worktree_clean "$VAULT" || { repository_unlock; die "vault repository has uncommitted changes"; }
  result=$(vault_retention_apply "$VAULT" "$plan") || {
    repository_unlock
    die "retention rewrite failed"
  }
  repository_unlock
  if (( as_json )); then printf '%s\n' "$result"
  else
    printf 'Retained %s backup(s) in rewritten local history.\n' "$keep"
    [[ $(jq -r '.remoteDivergence' <<<"$result") == true ]] &&
      printf 'The local history now diverges from the published remote; Montage will not force-push it.\n'
  fi
}

cmd_backup_history() {
  local action="$1"; shift
  case "$action" in
    list) cmd_backup_list "$@" ;;
    show) cmd_backup_show "$@" ;;
    label) cmd_backup_label "$@" ;;
    unlabel) cmd_backup_unlabel "$@" ;;
    retain) cmd_backup_retain "$@" ;;
    *) die "unknown backup history command: $action" ;;
  esac
}
