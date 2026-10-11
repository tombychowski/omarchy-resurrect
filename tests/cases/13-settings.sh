# Loadout-only configuration has one ordered setting. Obsolete combined-product
# keys are ignored on read and omitted by the next serialized save.

CONFIG="$XDG_CONFIG_HOME/montage/config"

mntg status --json
assert_ok "status works before a config exists"
assert_equals "$(jq -r '.settings.aur' <<<"$OUT")" "ask" "AUR defaults to ask"
assert_no_file "$CONFIG" "reading status does not create configuration"

for value in ask yes no; do
  mntg set "AUR=$value"
  assert_ok "AUR=$value is accepted"
  assert_file_contains "$CONFIG" "AUR=$value" "AUR=$value is persisted"
done
assert_equals "$(stat -c '%a' "$CONFIG")" "600" "configuration is mode 0600"
assert_equals "$(sed -n 's/^\([A-Z_]*\)=.*/\1/p' "$CONFIG")" "AUR" \
  "the ordered schema serializes only AUR"

for bad in AUR=yse AUR=1 AUR=on NOT_A_SETTING=1 VAULT=/tmp/legacy \
  AUTO_BACKUP=on PROFILE_URL=https://example.invalid/loadout; do
  before=$(sha256sum "$CONFIG")
  mntg set "$bad"
  assert_fails "mntg set $bad is refused"
  assert_equals "$(sha256sum "$CONFIG")" "$before" \
    "a refused setting leaves configuration unchanged"
done

mntg set AUR
assert_fails "a setting without an equals sign is refused"
assert_output "expected KEY=VALUE"

# Hand-edited obsolete keys do not regain authority. A malformed retained value
# has the safe consumer fallback until an explicit valid save rewrites the file.
printf 'VAULT=/do/not/open\nAUTO_PUSH=1\nAUR=whatever\nINCLUDE_SECRETS=1\n' >"$CONFIG"
mntg status --json
assert_ok "status tolerates an obsolete and malformed hand-edited config"
assert_equals "$(jq -r '.settings.aur' <<<"$OUT")" "ask" \
  "a malformed AUR value safely falls back to ask"
assert_file_contains "$CONFIG" "VAULT=/do/not/open" \
  "ordinary reads do not rewrite hand-edited configuration"

mntg set AUR=yes
assert_ok "a valid update rewrites the loadout-owned schema"
assert_file_lacks "$CONFIG" "VAULT=" "obsolete vault configuration is omitted"
assert_file_lacks "$CONFIG" "AUTO_PUSH=" "obsolete scheduler configuration is omitted"
assert_file_lacks "$CONFIG" "INCLUDE_SECRETS=" "obsolete secret configuration is omitted"
assert_equals "$(sed -n 's/^\([A-Z_]*\)=.*/\1/p' "$CONFIG")" "AUR" \
  "rewritten configuration contains exactly the retained schema"

# Concurrent panel-style writes serialize into one complete valid document.
pids=()
for i in 1 2 3 4 5 6 7 8; do
  "$MNTG" set AUR=yes >/dev/null 2>&1 & pids+=("$!")
  "$MNTG" set AUR=no >/dev/null 2>&1 & pids+=("$!")
  "$MNTG" set AUR=ask >/dev/null 2>&1 & pids+=("$!")
done
concurrent_failures=0
for pid in "${pids[@]}"; do wait "$pid" || concurrent_failures=$((concurrent_failures + 1)); done
assert_equals "$concurrent_failures" "0" "all concurrent setting writes acquire the lock"
assert_equals "$(grep -c '^AUR=' "$CONFIG")" "1" "concurrent writes leave one untorn setting"
case "$(sed -n 's/^AUR=//p' "$CONFIG")" in
  ask|yes|no) STATUS=0 ;;
  *) STATUS=1 ;;
esac
assert_ok "the concurrent result is one valid policy"
mntg status --json
assert_ok "status reads the concurrently written configuration"
