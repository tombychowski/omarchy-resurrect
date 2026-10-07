# --porcelain is a protocol, not prose. The panel parses it line by line, and a
# consumer must not be told less than a person is.

seed_machine
machine_publish repo ripgrep
machine_publish aur brave-bin

VAULT=$(make_vault)
mkdir -p "$VAULT/home" "$VAULT/omarchy/hooks"
printf 'from the vault\n' >"$VAULT/home/.bashrc"
printf '#!/bin/sh\necho hi\n' >"$VAULT/omarchy/hooks/post-update"
printf 'ripgrep\n' >"$VAULT/packages/native.txt"
printf 'brave-bin\n' >"$VAULT/packages/foreign.txt"
seal_vault "$VAULT"

# Everything mntg itself writes is a record. (A subprocess mntg calls may print
# its own output — pacman does — so only mntg's own lines are checked, which is
# what the panel's parser sees as unparseable noise it must tolerate.)
only_protocol_candidate_lines() {
  printf '%s\n' "$OUT" | grep -vE '^(installed|built) ' || true
}
assert_protocol() {
  local bad
  bad=$(only_protocol_candidate_lines | grep -vE '^(BEGIN|STEP|PROGRESS|LOG|DONE|PORT|PORT_IDENTITY|PORT_REVISION|PORT_LOSS)\|' | grep -c . || true)
  assert_equals "$bad" "0" "${1:-every line is a protocol record}" 
  [[ $bad == 0 ]] || only_protocol_candidate_lines | grep -vE '^(BEGIN|STEP|PROGRESS|LOG|DONE)\|' >&2
}

# ---- restore ---------------------------------------------------------------

mntg --porcelain --vault "$VAULT" restore --yes
assert_ok "porcelain restore"
assert_protocol "restore emits only records"

# And still says everything the human version says.
assert_output "LOG|will run: 1 Omarchy hook"
assert_output "LOG|restoring otherbox"
assert_output "LOG|will install 1 from the Arch repos: ripgrep"
assert_output "LOG|will build 1 from the AUR: brave-bin"
assert_output "DONE|ok|restore complete"

# Deferred work reaches the protocol rather than only the terminal.
assert_output "LOG|left for later: 1 AUR package not built"

# ---- backup ----------------------------------------------------------------

mntg init >/dev/null
printf 'TOKEN=ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8\n' >"$HOME/.local/bin/deploy"
mntg --porcelain backup -m porcelain
assert_ok "porcelain backup"
assert_protocol "backup emits only records"
assert_output "STEP|secrets|warn|possible credentials in 1 file"
assert_no_output "Possible credentials in the vault" "the prose report stays out of the stream"
assert_no_output "ghp_A1b2" "and the match is never in it"

# ---- the blocked backup is a record, not a silent exit --------------------

mntg set SECRET_SCAN=block >/dev/null
mntg --porcelain backup -m blocked
assert_fails "porcelain backup blocked"
assert_output "DONE|fail|blocked by the secret scan"
assert_protocol "a blocked backup emits only records too"
assert_no_output "Nothing was committed" "the explanation is for a person, not for the protocol"

# ---- a blocked backup never pushes ---------------------------------------

REMOTE="$SANDBOX/remote.git"
git init -q --bare "$REMOTE"
mntg set REMOTE="$REMOTE" >/dev/null
mntg backup -m blocked --push
assert_fails "block fails the backup"
assert_output "Nothing was committed"
assert_equals "$(git -C "$REMOTE" rev-list --count --all 2>/dev/null || echo 0)" "0" \
  "a vault that failed the scan is never pushed"

# ---- Ress port preview ----------------------------------------------------

port_destination="$SANDBOX/ported-loadout"
mntg --porcelain port ress plan "$REPO_DIR/tests/fixtures/ress-v1/loadout" \
  --destination "$port_destination"
assert_ok "porcelain Ress port preview"
assert_protocol "port preview emits only versioned records"
assert_output "BEGIN|port|ress-v1|plan|loadout" "port protocol identifies format, operation and artifact"
assert_output "PORT|1|ress-v1|plan|loadout|true|false|" \
  "port protocol carries compatibility and publication state"
assert_output "PORT_REVISION|current|true|" "port protocol carries selected revision identity"
assert_output "DONE|ok|port operation complete" "port protocol terminates explicitly"
assert_no_file "$port_destination/profile.json" "port preview remains read-only"
