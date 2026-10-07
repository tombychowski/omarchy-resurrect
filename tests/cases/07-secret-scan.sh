# The capture list is an allowlist and credentials are not on it. The risk left
# is a key inside a file that does belong in the vault, so the vault is read
# back before it is committed.

seed_machine
mntg init >/dev/null
VAULT="$XDG_DATA_HOME/montage/vault"

# ---- 1. a clean machine is clean ------------------------------------------

mntg backup -m clean
assert_ok "backup"
assert_no_output "Possible credentials in the vault"

mntg scan
assert_ok "scan finds nothing"
assert_output "Nothing in this vault has the shape of a credential"
assert_output "not a proof" "and does not overclaim"

# ---- 2. a token pasted into a script in ~/.local/bin ----------------------

mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/deploy" <<'SCRIPT'
#!/bin/bash
curl -H "Authorization: token ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8" https://api.github.com/user
SCRIPT
chmod +x "$HOME/.local/bin/deploy"

mntg backup -m "with a token"
assert_ok "backup still succeeds in warn mode"
assert_output "Possible credentials in the vault"
assert_output "home/.local/bin/deploy"
assert_output "github-token"
assert_no_output "ghp_A1b2C3d4" "the match itself is never printed"

# The report is kept out of the vault: it is a list of where the secrets are.
assert_file "$XDG_STATE_HOME/montage/secrets-found.txt"
assert_no_file "$VAULT/report/secrets-found.txt" "the finding list never enters the vault"
assert_file_lacks "$XDG_STATE_HOME/montage/secrets-found.txt" "ghp_A1b2C3d4" "and holds no copy of the secret"

# warn means warn: the backup was still committed.
assert_equals "$(git -C "$VAULT" rev-list --count HEAD)" "2" "warn commits anyway"

mntg scan
assert_fails "scan exits non-zero when it finds something"
assert_output "github-token"

mntg scan --json
assert_fails "scan --json exits non-zero too"
assert_equals "$(jq -r '.count' <<<"$OUT")" "1" "one finding"
assert_equals "$(jq -r '.findings[0].rule' <<<"$OUT")" "github-token"

# ---- 3. block refuses the commit ------------------------------------------

mntg set SECRET_SCAN=block >/dev/null
mntg backup -m "should not commit"
assert_fails "block fails the backup"
assert_output "Nothing was committed"
assert_equals "$(git -C "$VAULT" rev-list --count HEAD)" "2" "and really did not commit"

# Excluding the file clears it.
printf '.local/bin/deploy\n' >>"$XDG_CONFIG_HOME/montage/exclude"
mntg backup -m "clean again"
assert_ok "backup succeeds once the file is excluded"
assert_no_output "Possible credentials in the vault"
assert_no_file "$VAULT/home/.local/bin/deploy" "and the file is not in the vault"
mntg set SECRET_SCAN=warn >/dev/null

# ---- 4. the shapes it knows ------------------------------------------------

rm -f "$XDG_CONFIG_HOME/montage/exclude"
mkdir -p "$HOME/.config/systemd/user"
cat >"$HOME/.config/systemd/user/worker.service" <<'UNIT'
[Service]
Environment=API_TOKEN=9f8e7d6c5b4a39281706abcdef123456
ExecStart=/usr/bin/worker
UNIT
printf 'export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE\n' >"$HOME/.bash_profile"

# A .key file is excluded from the capture outright, so the residual risk is a
# key pasted into a file that does travel. That is the one worth finding.
printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n' >"$HOME/.config/hypr/private.key"
printf -- '# for reference:\n# -----BEGIN OPENSSH PRIVATE KEY-----\n# b3BlbnNzaC1rZXktdjEAAAAA\n' >>"$HOME/.config/hypr/hyprland.conf"

mntg backup -m shapes
assert_no_file "$VAULT/home/.config/hypr/private.key" "a .key file never enters the vault at all"
assert_output "systemd-environment" "an Environment= line with a token in it"
assert_output "aws-access-key"
assert_output "private-key" "a key pasted into a file that does travel"
assert_output "worker.service"
assert_output "hyprland.conf"

# ---- 5. what it deliberately ignores --------------------------------------

rm -f "$HOME/.config/hypr/private.key" "$HOME/.config/systemd/user/worker.service" "$HOME/.local/bin/deploy"
printf 'bind = SUPER, Q, killactive\n' >"$HOME/.config/hypr/hyprland.conf"
cat >"$HOME/.bash_profile" <<'PROFILE'
# None of these is a secret and none of them should be reported.
export GITHUB_TOKEN="$(pass show github/token)"
export API_KEY=${API_KEY:-}
export SLACK_TOKEN=your-token-here
export DEPLOY_SECRET=changeme
export EXAMPLE_PASSWORD=<your-password>
export OTHER_TOKEN=""
PROFILE

mntg backup -m placeholders
assert_ok "backup"
assert_no_output "Possible credentials in the vault" "indirection, placeholders and empty values are not findings"

mntg scan
assert_ok "and the scan agrees"

# ---- 6. off means off ------------------------------------------------------

printf 'export REAL_TOKEN=ghp_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8\n' >>"$HOME/.bash_profile"
mntg set SECRET_SCAN=off >/dev/null
mntg backup -m "scanner off"
assert_ok "backup"
assert_no_output "Possible credentials in the vault" "off does not scan"
mntg set SECRET_SCAN=warn >/dev/null
mntg backup -m "scanner on"
assert_output "Possible credentials in the vault" "and on does"

# ---- 7. every plaintext vault subtree, with explicit exclusions -----------

# Clear the earlier source finding, then place one in a captured launcher:
# outside the historical home/ and omarchy/ scan roots.
grep -v 'REAL_TOKEN' "$HOME/.bash_profile" >"$SANDBOX/bash-profile.clean"
mv "$SANDBOX/bash-profile.clean" "$HOME/.bash_profile"
mkdir -p "$HOME/.local/share/applications"
cat >"$HOME/.local/share/applications/Scanned.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Scanned
Exec=omarchy-launch-webapp https://scan.example/
Icon=scanned
Type=Application
X-Token=ghp_Z1y2X3w4V5u6T7s8R9q0P1o2N3m4L5k6J7h8
DESKTOP

mntg backup -m "launcher finding"
assert_ok "warn mode scans captured plaintext outside home and omarchy"
assert_output "webapps/apps/Scanned.desktop" "whole-vault scan reports the launcher path"
assert_output "github-token" "whole-vault scan applies the same rule"
assert_no_output "ghp_Z1y2X3w4" "whole-vault finding does not reveal the value"

# Remove the plaintext finding and establish a clean working tree.
sed -i '/^X-Token=/d' "$HOME/.local/share/applications/Scanned.desktop"
mntg backup -m "clean launcher" >/dev/null

# Git objects, the known encrypted bundle, and binary content are outside the
# plaintext promise even when their bytes happen to resemble a token.
mkdir -p "$VAULT/secrets" "$VAULT/report"
printf 'ghp_Z1y2X3w4V5u6T7s8R9q0P1o2N3m4L5k6J7h8\n' >"$VAULT/secrets/secrets.tar.age"
printf 'ghp_Z1y2X3w4V5u6T7s8R9q0P1o2N3m4L5k6J7h8\n' >"$VAULT/.git/scanner-probe"
printf '\0ghp_Z1y2X3w4V5u6T7s8R9q0P1o2N3m4L5k6J7h8\n' >"$VAULT/report/binary.dat"
mntg scan
assert_ok "scan excludes Git metadata, encrypted ciphertext, and binary files"
assert_output "Nothing in this vault" "excluded content creates no finding"
rm -f "$VAULT/secrets/secrets.tar.age" "$VAULT/.git/scanner-probe" "$VAULT/report/binary.dat"
rmdir "$VAULT/secrets" 2>/dev/null || true

# Blocking applies to the same expanded scope.
printf 'X-Token=ghp_Z1y2X3w4V5u6T7s8R9q0P1o2N3m4L5k6J7h8\n' \
  >>"$HOME/.local/share/applications/Scanned.desktop"
mntg set SECRET_SCAN=block >/dev/null
before_block=$(git -C "$VAULT" rev-list --count HEAD)
mntg backup -m "blocked launcher"
assert_fails "block mode rejects a finding outside historical scan roots"
assert_output "webapps/apps/Scanned.desktop"
assert_equals "$(git -C "$VAULT" rev-list --count HEAD)" "$before_block" "whole-vault block creates no commit"
