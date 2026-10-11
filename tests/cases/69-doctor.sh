# Doctor checks only the tools, writable roots, configuration, libraries, and
# machine capabilities needed by the loadout product.

export PATH="$HOME/.local/bin:$PATH"
mntg link >/dev/null
machine_shell_running

mntg doctor
assert_ok "loadout doctor completes"
for expected in git jq curl pacman 'yay (AUR)' 'omarchy CLI' 'shell running' \
  configuration 'configuration path' 'state path' 'loadout libraries' 'git identity' \
  'mntg on PATH'; do
  assert_output "$expected" "doctor reports $expected"
done
for retired in rsync age vault backup restore scheduler secrets; do
  assert_no_output "$retired" "doctor has no retired $retired check"
done
assert_output "Ready." "a prepared loadout machine is ready"

source "$TESTS_DIR/lib/loadout.sh"
machine_publish repo alpha
write_package_loadout "$SANDBOX/doctor-loadout" Doctor alpha
mntg apply --yes "$SANDBOX/doctor-loadout"
assert_ok "doctor fixture creates applied state"
mntg doctor
assert_output "✓ state path" "existing writable state directory passes doctor"
assert_output "Ready." "doctor remains ready after apply"

mkdir -p "$XDG_CONFIG_HOME/montage"
printf 'AUR=invalid\n' >"$XDG_CONFIG_HOME/montage/config"
mntg doctor
assert_ok "doctor reports malformed optional configuration without crashing"
assert_output "✗ configuration" "doctor identifies malformed AUR policy"
assert_output "1 problem." "doctor counts the malformed setting"

printf 'AUR=ask\n' >"$XDG_CONFIG_HOME/montage/config"
printf '{"schemaVersion":2,"revision":0,"repositories":[{"name":"bad","path":"/tmp/bad","type":"vault","id":"bad","remote":""}]}\n' \
  >"$XDG_CONFIG_HOME/montage/repositories.json"
mntg doctor
assert_ok "doctor reports invalid repository configuration without crashing"
assert_output "✗ loadout libraries" "doctor identifies unsupported repository state"
