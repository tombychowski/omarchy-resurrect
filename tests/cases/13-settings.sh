# A setting whose value is a choice: a misspelled choice used to be accepted and
# then read as the default, so `AUR=yse` quietly meant "ask".

seed_machine

# A side-by-side Ress installation is inert input. Montage must not adopt its
# config, state, registry, or data roots during ordinary startup.
mkdir -p "$XDG_CONFIG_HOME/ress" "$XDG_STATE_HOME/ress" "$XDG_DATA_HOME/ress"
printf 'VAULT=%s\nAUTO_PUSH=1\n' "$XDG_DATA_HOME/ress/forbidden-vault" \
  >"$XDG_CONFIG_HOME/ress/config"
printf 'ress-state-sentinel\n' >"$XDG_STATE_HOME/ress/loadouts.json"
printf 'ress-data-sentinel\n' >"$XDG_DATA_HOME/ress/sentinel"
ress_config_before=$(sha256sum "$XDG_CONFIG_HOME/ress/config")
ress_state_before=$(sha256sum "$XDG_STATE_HOME/ress/loadouts.json")
ress_data_before=$(sha256sum "$XDG_DATA_HOME/ress/sentinel")

mntg init >/dev/null
assert_no_file "$XDG_DATA_HOME/ress/forbidden-vault/.git/HEAD" \
  "Montage does not read the Ress vault setting"
assert_equals "$(sha256sum "$XDG_CONFIG_HOME/ress/config")" "$ress_config_before" \
  "Montage does not write Ress configuration"
assert_equals "$(sha256sum "$XDG_STATE_HOME/ress/loadouts.json")" "$ress_state_before" \
  "Montage does not write Ress operational state"
assert_equals "$(sha256sum "$XDG_DATA_HOME/ress/sentinel")" "$ress_data_before" \
  "Montage does not write Ress data"
assert_file "$XDG_CONFIG_HOME/montage/config" "Montage writes its own configuration"

for bad in AUR=yse ENABLE_UNITS=1 SECRET_SCAN=warning AUTO_BACKUP=yes \
           CAPTURE_AUTOSTART=true SECRETS_MODE=gpg INCLUDE_PACKAGES=on; do
  mntg set "$bad"
  assert_fails "mntg set $bad is refused"
  assert_output "must be one of"
done

mntg set AUTO_INTERVAL_HOURS=soon
assert_fails "a non-numeric interval is refused"
assert_output "whole number of hours"

mntg set VAULT=
assert_fails "an empty vault path is refused"

mntg set NOT_A_SETTING=1
assert_fails "an unknown key is still refused"
assert_output "unknown setting"

# The valid values all still work, and land in the file.
mntg set AUR=yes ENABLE_UNITS=no SECRET_SCAN=block CAPTURE_AUTOSTART=1
assert_ok "valid values are accepted, several at once"
CONFIG="$XDG_CONFIG_HOME/montage/config"
assert_file_contains "$CONFIG" "AUR=yes"
assert_file_contains "$CONFIG" "ENABLE_UNITS=no"
assert_file_contains "$CONFIG" "SECRET_SCAN=block"
assert_file_contains "$CONFIG" "CAPTURE_AUTOSTART=1"

# A refused value leaves the previous one alone.
mntg set AUR=nope
assert_fails "refused"
assert_file_contains "$CONFIG" "AUR=yes" "the old value survives a refused write"

# The values the panel sends are all accepted, since it writes through the CLI.
for panel in AUTO_BACKUP=on AUTO_BACKUP=off AUR=ask AUR=yes AUR=no \
             ENABLE_UNITS=ask ENABLE_UNITS=yes ENABLE_UNITS=no \
             INCLUDE_SECRETS=1 INCLUDE_SECRETS=0; do
  mntg set "$panel"
  assert_ok "the panel's value $panel is accepted"
done

# A hand-edited config with a nonsense value still loads, and reads as the safe
# default rather than refusing to run at all.
printf 'AUR=whatever\nENABLE_UNITS=whatever\nSECRET_SCAN=whatever\n' >>"$CONFIG"
printf 'FUTURE_UNKNOWN_SETTING=must-not-survive\n' >>"$CONFIG"
mntg status
assert_ok "a config with a bad value still loads"
mntg status --json
assert_equals "$(jq -r '.settings.aur' <<<"$OUT")" "whatever" "status reports what is in the file"
mntg set AUTO_PUSH=1
assert_ok "a known update rewrites a hand-edited config"
assert_file_lacks "$CONFIG" "FUTURE_UNKNOWN_SETTING" "unknown hand-edited keys are ignored"

expected_order='VAULT REMOTE AUTO_BACKUP AUTO_INTERVAL_HOURS AUTO_PUSH INCLUDE_PACKAGES INCLUDE_CONFIG INCLUDE_OMARCHY INCLUDE_WEBAPPS INCLUDE_PLUGINS INCLUDE_SECRETS SECRETS_MODE SECRETS_RECIPIENT PROFILE_URL ENABLE_UNITS AUR SECRET_SCAN CAPTURE_AUTOSTART'
actual_order=$(sed -n 's/^\([A-Z_]*\)=.*/\1/p' "$CONFIG" | tr '\n' ' ' | sed 's/ $//')
assert_equals "$actual_order" "$expected_order" "the schema owns stable serialization order"

VAULT=$(make_vault)
printf 'somepkg\n' >"$VAULT/packages/foreign.txt"
seal_vault "$VAULT"
mntg --vault "$VAULT" restore --yes --only packages
assert_ok "and a nonsense AUR value reads as ask, not as yes"
assert_not_called "yay -S" "which is the safe direction to fail in"

# ---- concurrent writes ----------------------------------------------------

# The panel fires one `mntg set` per toggle through execDetached. Two landing at
# once used to be a read-modify-write race: both read the same file, the later
# write dropped the earlier change.
mntg set AUR=ask ENABLE_UNITS=ask SECRET_SCAN=warn >/dev/null
for i in 1 2 3 4 5 6 7 8; do
  "$MNTG" set "AUR=yes" >/dev/null 2>&1 &
  "$MNTG" set "ENABLE_UNITS=no" >/dev/null 2>&1 &
  "$MNTG" set "SECRET_SCAN=block" >/dev/null 2>&1 &
done
wait

assert_file_contains "$CONFIG" "AUR=yes" "a concurrent write is not lost"
assert_file_contains "$CONFIG" "ENABLE_UNITS=no" "nor is the second"
assert_file_contains "$CONFIG" "SECRET_SCAN=block" "nor the third"

# The file is still one valid config, not a torn write.
assert_equals "$(grep -c '^[A-Z_]*=' "$CONFIG")" "$(grep -c '^[A-Z_]*=' "$CONFIG")" "config parses"
mntg status --json
assert_ok "and status can still read it"
assert_equals "$(jq -r '.settings.aur' <<<"$OUT")" "yes"
