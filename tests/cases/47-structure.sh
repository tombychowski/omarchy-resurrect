"$REPO_DIR/tests/check-structure.sh" "$REPO_DIR" >"$SANDBOX/structure.out" 2>&1
STATUS=$?; OUT=$(<"$SANDBOX/structure.out")
assert_ok "the checked-in ownership and entrypoint structure passes"
assert_output "modules" "the structural check reports its scope"

FIXTURE="$SANDBOX/repo"
mkdir -p "$FIXTURE"
cp -a "$REPO_DIR/bin" "$REPO_DIR/lib" "$REPO_DIR/tests" "$FIXTURE/"
printf '\nunreachable_fixture() { :; }\n' >>"$FIXTURE/lib/ress/core.sh"
"$FIXTURE/tests/check-structure.sh" "$FIXTURE" >"$SANDBOX/dead.out" 2>&1
STATUS=$?; OUT=$(<"$SANDBOX/dead.out")
assert_fails "a deliberately unreachable fixture is rejected"
assert_output "unreachable function: unreachable_fixture"

cp "$REPO_DIR/lib/ress/machine/packages.sh" "$FIXTURE/lib/ress/machine/packages.sh"
printf '\nmachine_reverse_fixture() { registry_save "{}"; }\n' >>"$FIXTURE/lib/ress/machine/packages.sh"
printf 'machine_reverse_fixture\n' >>"$FIXTURE/tests/static-entrypoints.txt"
"$FIXTURE/tests/check-structure.sh" "$FIXTURE" >"$SANDBOX/reverse.out" 2>&1
STATUS=$?; OUT=$(<"$SANDBOX/reverse.out")
assert_fails "a representative reverse dependency is rejected"
assert_output "machine module has a reverse dependency"
