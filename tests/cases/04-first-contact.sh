# A vault fetched from a URL this machine has not used before is not treated as
# less trustworthy — a fresh install replaying its owner's vault is always first
# contact — but nothing is assumed about it either.

seed_machine

# ---- 0. the public link is owned narrowly ---------------------------------

mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\nprintf ress-existing\\n\n' >"$HOME/.local/bin/ress"
printf '#!/bin/sh\nprintf imagemagick-existing\\n\n' >"$HOME/.local/bin/montage"
chmod +x "$HOME/.local/bin/ress" "$HOME/.local/bin/montage"
ress_before=$(sha256sum "$HOME/.local/bin/ress")
imagemagick_before=$(sha256sum "$HOME/.local/bin/montage")

mntg link
assert_ok "link installs the Montage command"
assert_equals "$(realpath "$HOME/.local/bin/mntg")" "$(realpath "$MNTG")" \
  "the link targets the active Montage installation"
assert_equals "$(sha256sum "$HOME/.local/bin/ress")" "$ress_before" \
  "link leaves the Ress command untouched"
assert_equals "$(sha256sum "$HOME/.local/bin/montage")" "$imagemagick_before" \
  "link leaves ImageMagick montage untouched"

mntg link
assert_ok "link is idempotent for its owned target"
mntg link --remove
assert_ok "link removal accepts the owned active link"
assert_no_file "$HOME/.local/bin/mntg" "owned link is removed"

printf 'unrelated-command\n' >"$HOME/.local/bin/mntg"
mntg link
assert_fails "link refuses an unrelated file"
assert_file_contains "$HOME/.local/bin/mntg" "unrelated-command" \
  "the unrelated file is not replaced"
mntg link --remove
assert_fails "link removal refuses an unrelated file"
rm "$HOME/.local/bin/mntg"

ln -s "$HOME/.local/bin/montage" "$HOME/.local/bin/mntg"
unrelated_target=$(readlink "$HOME/.local/bin/mntg")
mntg link
assert_fails "link refuses an unrelated symlink"
assert_equals "$(readlink "$HOME/.local/bin/mntg")" "$unrelated_target" \
  "the unrelated symlink is not retargeted"
rm "$HOME/.local/bin/mntg"

# Two vaults published as fake upstreams.
for name in mine theirs; do
  V=$(make_vault "$FAKE_STATE/remotes/$name")
  mkdir -p "$V/home"
  printf 'from %s\n' "$name" >"$V/home/.bashrc"
  printf 'somepkg\n' >"$V/packages/native.txt"
  printf 'plain.plugin\t\t1\t\n' >"$V/plugins/plugins.tsv"
  seal_vault "$V" "$name-box"
done
machine_publish repo somepkg

mntg init --remote "$(remote_url mine)" >/dev/null
assert_ok "init with a remote"

# ---- 1. a URL this machine already backs up to is not first contact -------

montage_answer "y" "y" -- restore --from "$(remote_url mine)" --only config
assert_ok "restore from the configured remote"
assert_no_output "has not restored from this vault before"
assert_file_contains "$HOME/.bashrc" "from mine"

# ---- 2. a different URL is ------------------------------------------------

montage_answer "y" "y" -- restore --from "$(remote_url theirs)" --restart --only config
assert_ok "restore from elsewhere"
assert_output "has not restored from this vault before"
assert_file_contains "$HOME/.bashrc" "from theirs"

# The prompt said the remote would move, and it did.
assert_output "back up there from now on"
assert_equals "$(sed -n 's/^REMOTE=//p' "$XDG_CONFIG_HOME/montage/config")" "$(remote_url theirs)" \
  "the vault remote follows the vault"

# ---- 3. .git URLs and trailing slashes are the same URL -------------------

mntg set REMOTE="$(remote_url theirs).git" >/dev/null
montage_answer "y" "y" -- restore --from "$(remote_url theirs)/" --restart --only config
assert_no_output "has not restored from this vault before" "a trailing slash is not a different repo"
mntg set REMOTE="$(remote_url theirs)" >/dev/null

# ---- 4. --allow-unpinned on first contact asks a second time -------------

montage_answer "y" "n" -- restore --from "$(remote_url mine)" --restart --only plugins --allow-unpinned
assert_fails "declining the unpinned question cancels the restore"
assert_output "allow-unpinned on a vault this machine has not used before"
assert_output "Take branch heads from this vault?"
assert_output "cancelled"

# Accepting it proceeds. (The plugin itself has no remote, so nothing is
# cloned — what is under test is the question, not the clone.)
montage_answer "y" "y" "y" -- restore --from "$(remote_url mine)" --restart --only plugins --allow-unpinned
assert_ok "accepting the unpinned question proceeds"

# ---- 5. no second question when the vault is one this machine uses -------

mntg set REMOTE="$(remote_url mine)" >/dev/null
montage_answer "y" "y" -- restore --from "$(remote_url mine)" --restart --only plugins --allow-unpinned
assert_ok "restore from the configured remote with --allow-unpinned"
assert_no_output "Take branch heads from this vault?"
