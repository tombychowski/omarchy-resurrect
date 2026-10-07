# ~/.config/autostart is not captured by default: every entry in it is a
# command that runs at the next login, wherever the vault is replayed.

seed_machine
mkdir -p "$HOME/.config/autostart"
cat >"$HOME/.config/autostart/mystery.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Mystery
Exec=/home/someone/.local/bin/mystery --daemon
DESKTOP

mntg init >/dev/null
VAULT="$XDG_DATA_HOME/montage/vault"

# ---- 1. off by default ----------------------------------------------------

mntg backup -m default
assert_ok "backup"
assert_no_file "$VAULT/home/.config/autostart/mystery.desktop" "autostart is not captured by default"
assert_no_output "autostart"

# ---- 2. opt in, and be told ------------------------------------------------

mntg set CAPTURE_AUTOSTART=1 >/dev/null
mntg backup -m "with autostart"
assert_ok "backup with autostart on"
assert_file "$VAULT/home/.config/autostart/mystery.desktop" "now it travels"
assert_output "1 autostart entry" "and the capture says so"
assert_output "runs at login"

# ---- 3. a restore counts it among the things the vault will run -----------

rm -rf "$HOME/.config/autostart"
mntg restore --dry-run --only config
assert_ok "dry run"
assert_output "1 autostart entry" "the restore names it too"
assert_output "started automatically when you log in"

mntg restore --yes --only config
assert_file "$HOME/.config/autostart/mystery.desktop" "and it is restored"

# ---- 4. back off again -----------------------------------------------------

mntg set CAPTURE_AUTOSTART=0 >/dev/null
mntg backup -m "off again"
assert_no_output "autostart entry" "nothing is said when it is off"
