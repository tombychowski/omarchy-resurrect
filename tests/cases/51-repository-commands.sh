# Repository commands are readable for humans and one-document JSON consumer
# surfaces for the panel.

make_repository() {
  local path="$1" type="$2" id="$3" machine="${4:-}"
  mkdir -p "$path"
  PLUGIN_DIR="$REPO_DIR"
  source "$REPO_DIR/lib/montage/core.sh"
  source "$REPO_DIR/lib/montage/safety.sh"
  source "$REPO_DIR/lib/montage/repository/common.sh"
  repository_envelope_json "$type" "$id" "2026-10-06T20:00:00Z" "$machine" >"$path/montage.json"
}

assert_one_json() {
  jq -se 'length == 1' <<<"$OUT" >/dev/null && _pass || _fail "$1" "$OUT"
}

loadouts="$SANDBOX/loadouts"
vault="$SANDBOX/vault"
make_repository "$loadouts" loadouts personal-loadouts
make_repository "$vault" vault personal-vault machine-one

mntg repository list --json
assert_ok "empty repository list JSON succeeds"
assert_one_json "empty list emits exactly one JSON result"
jq -e '.schemaVersion==1 and .kind=="montage-repository-list" and .repositories==[]' \
  <<<"$OUT" >/dev/null && _pass || _fail "empty list has the documented shape" "$OUT"

mntg repository configure personal "$loadouts" loadouts --json \
  --remote 'https://user:secret@github.com/example/loadouts.git'
assert_ok "repository configure JSON succeeds"
assert_one_json "configure emits exactly one JSON result"
jq -e '.kind=="montage-repository-configured" and .repository.valid and
  .repository.id=="personal-loadouts" and
  .repository.remote=="https://github.com/example/loadouts.git"' \
  <<<"$OUT" >/dev/null && _pass || _fail "configure reports sanitized healthy identity" "$OUT"
assert_no_output "secret" "configure JSON does not disclose URL credentials"

mntg repository configure backup "$vault" vault --json
assert_ok "second repository config succeeds"
assert_one_json "second configure emits one JSON result"

mntg repository list --json
assert_ok "repository list JSON succeeds"
assert_one_json "list emits exactly one JSON result"
jq -e '.revision==2 and (.repositories|length)==2 and
  all(.repositories[]; .valid and .status=="healthy")' \
  <<<"$OUT" >/dev/null && _pass || _fail "list reports both healthy repositories" "$OUT"

mntg repository show personal --json
assert_ok "repository show JSON succeeds"
assert_one_json "show emits exactly one JSON result"
jq -e '.kind=="montage-repository-show" and
  .repository.envelope.repositoryType=="loadouts"' \
  <<<"$OUT" >/dev/null && _pass || _fail "show includes the validated envelope" "$OUT"

mntg repository show personal
assert_ok "repository show human mode succeeds"
assert_output "personal  loadouts  healthy" "human show is readable"
assert_output "expected id: personal-loadouts" "human show explains expected identity"

mntg repository validate "$vault" --type vault --json
assert_ok "unconfigured path validation succeeds"
assert_one_json "path validation emits exactly one JSON result"
jq -e '.kind=="montage-repository-validation" and .repository.valid and
  .repository.currentId=="personal-vault"' \
  <<<"$OUT" >/dev/null && _pass || _fail "path validation reports current identity" "$OUT"

printf '{"schemaVersion":99}\n' >"$loadouts/montage.json"
mntg repository validate personal --json
assert_fails "invalid configured repository returns nonzero"
assert_one_json "invalid validation still emits exactly one JSON result"
jq -e '.repository.valid==false and .repository.status=="invalid-envelope"' \
  <<<"$OUT" >/dev/null && _pass || _fail "invalid envelope has a stable status" "$OUT"

make_repository "$loadouts" loadouts replacement-loadouts
mntg repository show personal --json
assert_fails "stale configured identity returns nonzero"
assert_one_json "stale show emits exactly one JSON result"
jq -e '.repository.valid==false and .repository.status=="identity-mismatch" and
  .repository.id=="personal-loadouts" and .repository.currentId=="replacement-loadouts"' \
  <<<"$OUT" >/dev/null && _pass || _fail "stale identity remains explicit" "$OUT"

mntg repository configure personal "$loadouts" loadouts --json
assert_fails "configuration refuses silent identity replacement"
assert_no_output '"kind"' "refused JSON configuration emits no partial document"
mntg repository configure personal "$loadouts" loadouts --replace --json
assert_ok "explicit identity replacement succeeds"
assert_one_json "replacement emits exactly one JSON result"

mntg repository remove backup --json
assert_ok "repository removal succeeds"
assert_one_json "removal emits exactly one JSON result"
jq -e '.kind=="montage-repository-removed" and .name=="backup"' \
  <<<"$OUT" >/dev/null && _pass || _fail "removal result identifies registry entry" "$OUT"
assert_file "$vault/montage.json" "removing configuration preserves repository content"
