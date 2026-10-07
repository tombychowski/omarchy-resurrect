#!/bin/bash
#
# Conservative repository synchronization inspection. Fetch updates only a
# Montage-owned remote observation ref; classification never checks out,
# resets, merges, or changes repository content.

REPOSITORY_SYNC_RESULT=""
REPOSITORY_REMOTE_VISIBILITY="unknown"

repository_remote_visibility() {
  local remote="$1" public_url visibility
  REPOSITORY_REMOTE_VISIBILITY=unknown
  public_url=$(canonical_share_url "$remote" 2>/dev/null) || return 0
  [[ $public_url == https://github.com/* ]] || return 0
  have gh || return 0
  visibility=$(gh repo view "$public_url" --json visibility --jq .visibility 2>/dev/null) || return 0
  case "${visibility,,}" in
    public) REPOSITORY_REMOTE_VISIBILITY=public ;;
    private) REPOSITORY_REMOTE_VISIBILITY=private ;;
    internal) REPOSITORY_REMOTE_VISIBILITY=internal ;;
    *) REPOSITORY_REMOTE_VISIBILITY=unknown ;;
  esac
}

repository_sync_result_json() {
  local entry="$1" status="$2" local_commit="$3" remote_commit="$4"
  local ahead="$5" behind="$6" error_code="${7:-}" ok=true remote
  [[ -z $error_code ]] || ok=false
  remote=$(strip_credentials "$(jq -r '.remote' <<<"$entry")")
  jq -nc --arg repositoryId "$(jq -r '.id' <<<"$entry")" \
    --arg type "$(jq -r '.type' <<<"$entry")" \
    --arg path "$(jq -r '.path' <<<"$entry")" \
    --arg remote "$remote" \
    --arg status "$status" --arg localCommit "$local_commit" \
    --arg remoteCommit "$remote_commit" --arg errorCode "$error_code" \
    --argjson ahead "$ahead" --argjson behind "$behind" --argjson ok "$ok" '
      {schemaVersion:1,kind:"montage-repository-sync",repositoryId:$repositoryId,
       repositoryType:$type,path:$path,remote:$remote,status:$status,
       localCommit:$localCommit,remoteCommit:$remoteCommit,ahead:$ahead,behind:$behind,
       fetch:{ok:$ok,errorCode:(if $errorCode == "" then null else $errorCode end)}}'
}

repository_sync_classify() {
  local entry="$1" root remote id expected_id local_commit remote_commit tracking status ahead=0 behind=0
  root=$(jq -r '.path' <<<"$entry")
  remote=$(jq -r '.remote' <<<"$entry")
  expected_id=$(jq -r '.id' <<<"$entry")
  [[ -n $remote ]] && valid_git_remote "$remote" && ! url_has_credentials "$remote" || {
    REPOSITORY_SYNC_RESULT=$(repository_sync_result_json "$entry" invalid-remote "" "" 0 0 invalid-remote)
    return 2
  }
  repository_root_valid "$root" &&
    [[ $(jq -r '.id' "$root/$MONTAGE_REPOSITORY_MANIFEST") == "$expected_id" ]] || {
    REPOSITORY_SYNC_RESULT=$(repository_sync_result_json "$entry" invalid-repository "" "" 0 0 invalid-repository)
    return 2
  }
  local_commit=$(git -C "$root" rev-parse --verify HEAD^{commit} 2>/dev/null) || {
    REPOSITORY_SYNC_RESULT=$(repository_sync_result_json "$entry" no-local-history "" "" 0 0 no-local-history)
    return 2
  }
  id=$(jq -r '.id' <<<"$entry")
  tracking="refs/montage/remotes/$id"
  if ! git -C "$root" fetch -q --no-tags -- "$remote" "+HEAD:$tracking" 2>/dev/null; then
    REPOSITORY_SYNC_RESULT=$(repository_sync_result_json "$entry" fetch-failed "$local_commit" "" 0 0 fetch-failed)
    return 2
  fi
  remote_commit=$(git -C "$root" rev-parse --verify "$tracking^{commit}" 2>/dev/null) || {
    REPOSITORY_SYNC_RESULT=$(repository_sync_result_json "$entry" fetch-failed "$local_commit" "" 0 0 missing-remote-head)
    return 2
  }
  ahead=$(git -C "$root" rev-list --count "$remote_commit..$local_commit" 2>/dev/null || printf 0)
  behind=$(git -C "$root" rev-list --count "$local_commit..$remote_commit" 2>/dev/null || printf 0)
  if [[ $local_commit == "$remote_commit" ]]; then
    status=equal
  elif git -C "$root" merge-base --is-ancestor "$remote_commit" "$local_commit"; then
    status=local-ahead
  elif git -C "$root" merge-base --is-ancestor "$local_commit" "$remote_commit"; then
    status=remote-ahead
  else
    status=divergent
  fi
  REPOSITORY_SYNC_RESULT=$(repository_sync_result_json "$entry" "$status" \
    "$local_commit" "$remote_commit" "$ahead" "$behind")
}

repository_sync_print_human() {
  local result="$1"
  printf '%s  ahead %s  behind %s\n' \
    "$(jq -r '.status' <<<"$result")" \
    "$(jq -r '.ahead' <<<"$result")" "$(jq -r '.behind' <<<"$result")"
  printf '  local:  %s\n  remote: %s\n' \
    "$(jq -r '.localCommit // ""' <<<"$result")" \
    "$(jq -r '.remoteCommit // ""' <<<"$result")"
  if jq -e '.action' <<<"$result" >/dev/null 2>&1; then
    printf '  action:  %s (%s)' \
      "$(jq -r '.action.performed' <<<"$result")" \
      "$(jq -r 'if .action.ok then "ok" else "not completed" end' <<<"$result")"
    [[ $(jq -r '.action.reason // ""' <<<"$result") == "" ]] ||
      printf ' — %s' "$(jq -r '.action.reason' <<<"$result")"
    printf '\n'
  fi
}

repository_sync_with_action_json() {
  local result="$1" requested="$2" performed="$3" ok="$4" reason="${5:-}"
  jq -c --arg requested "$requested" --arg performed "$performed" \
    --arg reason "$reason" --argjson ok "$ok" '
      . + {action:{requested:$requested,performed:$performed,ok:$ok,
        reason:(if $reason == "" then null else $reason end)}}' <<<"$result"
}

# Fetch, classify, then perform only the explicitly requested history-preserving
# action. VALIDATOR checks the fetched exact commit using its domain contract.
repository_sync_apply() {
  local entry="$1" action="$2" validator="$3" rc=0 status root remote
  local local_commit remote_commit branch result
  repository_sync_classify "$entry" || rc=$?
  result="$REPOSITORY_SYNC_RESULT"
  (( rc == 0 )) || return "$rc"
  status=$(jq -r '.status' <<<"$result")
  root=$(jq -r '.path' <<<"$entry")
  remote=$(jq -r '.remote' <<<"$entry")
  local_commit=$(jq -r '.localCommit' <<<"$result")
  remote_commit=$(jq -r '.remoteCommit' <<<"$result")

  if [[ $status == divergent ]]; then
    REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" decision-required false divergent-history)
    return 3
  fi
  if [[ $status == equal ]]; then
    REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" no-op true)
    return 0
  fi

  case "$action:$status" in
    pull:remote-ahead)
      "$validator" "$root" "$remote_commit" "$(jq -r '.id' <<<"$entry")" || {
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" refused false invalid-remote-snapshot)
        return 2
      }
      repository_lock "$root" || {
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" refused false repository-busy)
        return 2
      }
      if ! repository_worktree_clean "$root"; then
        repository_unlock
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" refused false dirty-worktree)
        return 2
      fi
      if git -C "$root" merge -q --ff-only "$remote_commit" >/dev/null 2>&1; then
        repository_unlock
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" fast-forward-pull true)
        return 0
      fi
      repository_unlock
      REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" failed false pull-failed)
      return 2
      ;;
    push:local-ahead)
      branch=$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null) || {
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" refused false detached-head)
        return 2
      }
      repository_ref_valid "$branch" || {
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" refused false unsafe-branch)
        return 2
      }
      repository_lock "$root" || {
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" refused false repository-busy)
        return 2
      }
      if ! repository_worktree_clean "$root" ||
         [[ $(git -C "$root" rev-parse HEAD 2>/dev/null) != "$local_commit" ]]; then
        repository_unlock
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" refused false local-changed-after-preview)
        return 2
      fi
      if git -C "$root" push -q -- "$remote" "HEAD:refs/heads/$branch" >/dev/null 2>&1; then
        git -C "$root" update-ref "refs/montage/remotes/$(jq -r '.id' <<<"$entry")" "$local_commit" "$remote_commit" || true
        repository_unlock
        REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" push true)
        return 0
      fi
      repository_unlock
      REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" failed false push-failed)
      return 2
      ;;
    *)
      REPOSITORY_SYNC_RESULT=$(repository_sync_with_action_json "$result" "$action" decision-required false wrong-direction)
      return 3
      ;;
  esac
}
