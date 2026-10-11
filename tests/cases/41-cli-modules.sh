# The public CLI is relocatable with the plugin tree and may be invoked through
# the symlink created by `mntg link`. Sourced modules are not separate command
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

run_cli "$MNTG" --version
assert_ok "the repository entrypoint loads its modules"
assert_equals "$OUT" "1.0.0" "module loading adds no version stdout"
assert_equals "$MODULE_STDERR" "" "direct module loading is silent on stderr"

# Trace one lightweight process. Every tracked production module must be loaded
# exactly once by the entrypoint; nested, circular, or duplicate sourcing makes
# the total exceed the unique count.
trace="$SANDBOX/module.trace"
trace_stdout="$SANDBOX/trace.stdout"
exec 9>"$trace"
BASH_XTRACEFD=9 bash -x "$MNTG" --version >"$trace_stdout" 2>/dev/null; STATUS=$?
exec 9>&-
expected_modules=$(find "$REPO_DIR/lib/montage" -type f -name '*.sh' -print | sort | wc -l)
loaded_modules=$(sed -n 's/^+* source \(.*\/lib\/montage\/.*\.sh\)$/\1/p' "$trace")
loaded_count=$(grep -c . <<<"$loaded_modules" || true)
unique_count=$(sort -u <<<"$loaded_modules" | grep -c . || true)
assert_ok "traced lightweight startup"
assert_equals "$loaded_count" "$expected_modules" "loads every production module exactly once"
assert_equals "$unique_count" "$expected_modules" "has no duplicate, circular, or nested module source"
assert_equals "$(<"$trace_stdout")" "1.0.0" "tracing does not change lightweight output"

mkdir -p "$SANDBOX/bin"
ln -s "$MNTG" "$SANDBOX/bin/mntg-linked"
run_cli "$SANDBOX/bin/mntg-linked" status --json
assert_ok "a symlinked entrypoint resolves the real plugin tree"
assert_equals "$(jq -r 'type' <<<"$OUT")" "object" "symlinked status emits one JSON object"
assert_equals "$MODULE_STDERR" "" "symlinked module loading is silent"

# The public link owns only ~/.local/bin/mntg and only when it resolves to the
# active installation. Neighboring Ress and ImageMagick commands are never
# aliases or cleanup targets.
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\nprintf ress-existing\\n\n' >"$HOME/.local/bin/ress"
printf '#!/bin/sh\nprintf imagemagick-existing\\n\n' >"$HOME/.local/bin/montage"
chmod +x "$HOME/.local/bin/ress" "$HOME/.local/bin/montage"
ress_before=$(sha256sum "$HOME/.local/bin/ress")
imagemagick_before=$(sha256sum "$HOME/.local/bin/montage")

run_cli "$MNTG" link
assert_ok "link installs the active Montage command"
assert_equals "$(realpath "$HOME/.local/bin/mntg")" "$(realpath "$MNTG")" \
  "the managed link targets the active installation"
assert_equals "$(sha256sum "$HOME/.local/bin/ress")" "$ress_before" \
  "link leaves the Ress command untouched"
assert_equals "$(sha256sum "$HOME/.local/bin/montage")" "$imagemagick_before" \
  "link leaves ImageMagick montage untouched"
run_cli "$MNTG" link
assert_ok "link install is idempotent for its owned target"
run_cli "$MNTG" link --remove
assert_ok "link removal accepts the owned active link"
assert_no_file "$HOME/.local/bin/mntg" "owned link is removed"

printf 'unrelated-command\n' >"$HOME/.local/bin/mntg"
run_cli "$MNTG" link
assert_fails "link refuses an unrelated file"
assert_file_contains "$HOME/.local/bin/mntg" "unrelated-command" \
  "unrelated file is not replaced"
run_cli "$MNTG" link --remove
assert_fails "link removal refuses an unrelated file"
rm "$HOME/.local/bin/mntg"

ln -s "$HOME/.local/bin/montage" "$HOME/.local/bin/mntg"
unrelated_target=$(readlink "$HOME/.local/bin/mntg")
run_cli "$MNTG" link
assert_fails "link refuses an unrelated symlink"
assert_equals "$(readlink "$HOME/.local/bin/mntg")" "$unrelated_target" \
  "unrelated symlink is not retargeted"
run_cli "$MNTG" link --remove
assert_fails "link removal refuses an unrelated symlink"
rm "$HOME/.local/bin/mntg"

# ---- relocated complete plugin tree --------------------------------------

relocated="$SANDBOX/relocated"
mkdir -p "$relocated"
rsync -a --exclude '.git/' "$REPO_DIR/" "$relocated/"

run_cli "$relocated/bin/mntg" status --json
assert_ok "a relocated plugin loads its own module tree"
assert_equals "$(jq -r 'type' <<<"$OUT")" "object" "relocated status keeps JSON stdout clean"
assert_equals "$MODULE_STDERR" "" "relocated module loading is silent"

run_cli "$relocated/bin/mntg" --porcelain status
assert_ok "a relocated loadout-only porcelain command runs through the public entrypoint"
bad=$(printf '%s\n' "$OUT" | grep -vE '^(BEGIN|MIGRATION|STATUS|DONE)\|' | grep -c . || true)
assert_equals "$bad" "0" "module loading adds no prose to porcelain stdout"

run_cli "$relocated/bin/mntg" link
assert_ok "relocated installation can own the public link"
assert_equals "$(realpath "$HOME/.local/bin/mntg")" "$(realpath "$relocated/bin/mntg")" \
  "relocated link resolves to the relocated tree"
run_cli "$HOME/.local/bin/mntg" status --json
assert_ok "link-owned relocated invocation resolves its own modules"
assert_equals "$(jq -r 'type' <<<"$OUT")" "object" \
  "link-owned relocated status emits one JSON object"
run_cli "$relocated/bin/mntg" link --remove
assert_ok "relocated installation removes its own link"

# ---- incomplete plugin tree fails before mutation ------------------------

broken="$SANDBOX/broken"
mkdir -p "$broken"
rsync -a --exclude '.git/' "$REPO_DIR/" "$broken/"
rm -f "$broken/lib/montage/loadout/profile.sh"

broken_home="$SANDBOX/broken-home"
mkdir -p "$broken_home"
stdout="$SANDBOX/broken.stdout" stderr="$SANDBOX/broken.stderr"
env HOME="$broken_home" XDG_CONFIG_HOME="$broken_home/.config" \
  XDG_STATE_HOME="$broken_home/.local/state" XDG_DATA_HOME="$broken_home/.local/share" \
  OMARCHY_PATH="$OMARCHY_PATH" TERM=dumb \
  "$broken/bin/mntg" status --json >"$stdout" 2>"$stderr"; STATUS=$?
OUT=$(<"$stdout")

assert_fails "a missing required module refuses startup"
assert_equals "$OUT" "" "missing-module failure leaves machine-readable stdout empty"
assert_file_contains "$stderr" "required module is missing or unreadable" \
  "stderr identifies the incomplete installation"
assert_no_file "$broken_home/.local/state/montage/running" "no operation marker is written"
assert_no_file "$broken_home/.local/state/montage/loadouts.json" \
  "no applied-loadout registry is initialized"
