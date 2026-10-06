# The public CLI is relocatable with the plugin tree and may be invoked through
# the symlink created by `ress link`. Sourced modules are not separate command
# surfaces, must emit nothing while loading, and must fail before mutation when
# an installed tree is incomplete.

run_cli() {
  local executable="$1"; shift
  local stdout="$SANDBOX/module.stdout" stderr="$SANDBOX/module.stderr"
  "$executable" "$@" >"$stdout" 2>"$stderr"; STATUS=$?
  OUT=$(<"$stdout")
  MODULE_STDERR=$(<"$stderr")
}

# ---- direct and symlinked entrypoint --------------------------------------

run_cli "$RESS" --version
assert_ok "the repository entrypoint loads its modules"
assert_equals "$OUT" "1.2.0" "module loading adds no version stdout"
assert_equals "$MODULE_STDERR" "" "direct module loading is silent on stderr"

# Trace one lightweight process. Every tracked production module must be loaded
# exactly once by the entrypoint; nested, circular, or duplicate sourcing makes
# the total exceed the unique count.
trace="$SANDBOX/module.trace"
trace_stdout="$SANDBOX/trace.stdout"
exec 9>"$trace"
BASH_XTRACEFD=9 bash -x "$RESS" --version >"$trace_stdout" 2>/dev/null; STATUS=$?
exec 9>&-
expected_modules=$(find "$REPO_DIR/lib/ress" -type f -name '*.sh' -print | sort | wc -l)
loaded_modules=$(sed -n 's/^+* source \(.*\/lib\/ress\/.*\.sh\)$/\1/p' "$trace")
loaded_count=$(grep -c . <<<"$loaded_modules" || true)
unique_count=$(sort -u <<<"$loaded_modules" | grep -c . || true)
assert_ok "traced lightweight startup"
assert_equals "$loaded_count" "$expected_modules" "loads every production module exactly once"
assert_equals "$unique_count" "$expected_modules" "has no duplicate, circular, or nested module source"
assert_equals "$(<"$trace_stdout")" "1.2.0" "tracing does not change lightweight output"

mkdir -p "$SANDBOX/bin"
ln -s "$RESS" "$SANDBOX/bin/ress-linked"
run_cli "$SANDBOX/bin/ress-linked" status --json
assert_ok "a symlinked entrypoint resolves the real plugin tree"
assert_equals "$(jq -r 'type' <<<"$OUT")" "object" "symlinked status emits one JSON object"
assert_equals "$MODULE_STDERR" "" "symlinked module loading is silent"

# ---- relocated complete plugin tree --------------------------------------

relocated="$SANDBOX/relocated"
mkdir -p "$relocated"
rsync -a --exclude '.git/' "$REPO_DIR/" "$relocated/"

run_cli "$relocated/bin/ress" status --json
assert_ok "a relocated plugin loads its own module tree"
assert_equals "$(jq -r 'type' <<<"$OUT")" "object" "relocated status keeps JSON stdout clean"
assert_equals "$MODULE_STDERR" "" "relocated module loading is silent"

seed_machine
run_cli "$relocated/bin/ress" --porcelain backup -m module-loader
assert_ok "a relocated porcelain command runs through the public entrypoint"
bad=$(printf '%s\n' "$OUT" | grep -vE '^(BEGIN|STEP|PROGRESS|LOG|DONE)\|' | grep -c . || true)
assert_equals "$bad" "0" "module loading adds no prose to porcelain stdout"

# ---- incomplete plugin tree fails before mutation ------------------------

broken="$SANDBOX/broken"
mkdir -p "$broken"
rsync -a --exclude '.git/' "$REPO_DIR/" "$broken/"
rm -f "$broken/lib/ress/vault/common.sh"

broken_home="$SANDBOX/broken-home"
mkdir -p "$broken_home"
stdout="$SANDBOX/broken.stdout" stderr="$SANDBOX/broken.stderr"
env HOME="$broken_home" XDG_CONFIG_HOME="$broken_home/.config" \
  XDG_STATE_HOME="$broken_home/.local/state" XDG_DATA_HOME="$broken_home/.local/share" \
  OMARCHY_PATH="$OMARCHY_PATH" TERM=dumb \
  "$broken/bin/ress" --porcelain backup >"$stdout" 2>"$stderr"; STATUS=$?
OUT=$(<"$stdout")

assert_fails "a missing required module refuses startup"
assert_equals "$OUT" "" "missing-module failure leaves machine-readable stdout empty"
assert_file_contains "$stderr" "required module is missing or unreadable" \
  "stderr identifies the incomplete installation"
assert_no_file "$broken_home/.local/state/ress/running" "no operation marker is written"
assert_no_file "$broken_home/.local/share/ress/vault/.git/HEAD" "no vault is initialized"
