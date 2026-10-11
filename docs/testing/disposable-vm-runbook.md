# Montage disposable VM verification runbook

Prepared 2026-10-10 from Tom's Proxmox setup notes, the current manual scripts,
the testing strategy, the fresh-machine checklist, and the active corrective
change. This is an operator procedure; it does not claim these preparations or
tests have been executed on your Proxmox installation.

Jump to [one-time template setup](#2-build-the-recovery-template-once),
[template Notes](#25-add-proxmox-notes-to-the-base-template),
[one-time guest preparation](#3-prepare-the-reusable-target-and-peer-once),
[prepared guest Notes](#37-add-proxmox-notes-to-the-prepared-guests),
[before each handoff](#4-immediately-before-each-handoff),
[code staging](#5-stage-the-exact-code-and-reachable-plugin-fixture),
[coverage arrangements](#6-coverage-arrangements-that-prevent-another-partial-run),
[handoff prompt](#7-exact-handoff-prompt), or
[after testing](#8-after-testing-completes).

## Recommended arrangement

**Keep two reusable VMs and reset both to powered-off, test-ready snapshots for
each run. Keep one clean Omarchy template for recovery and baseline upgrades.**
This avoids repeating installation, account setup, machine identity changes,
host-key acceptance, networking, and sudo preparation each time.

| Resource | Example ID | Purpose |
| --- | ---: | --- |
| `montage-omarchy-base-v1` | 9000 | Frozen recovery template; no Montage, test privileges, or guest private keys |
| `montage-test-desktop` | 9102 | Native/AUR packages, plugins, themes, web apps, migrations, and rendered panel |
| `montage-git-peer` (the **peer**) | 9101 | Disposable bare Git remotes and independent Git histories |
| Target snapshot `montage-desktop-ready-v1` | — | Clean product state plus reusable test infrastructure |
| Peer snapshot `montage-git-peer-ready-v1` | — | Empty remote directory plus reusable SSH access |

The test desktop is the **target** named by the existing manual scripts; the
Git peer provides remote repositories. These role labels do not mean a source
and destination for machine capture/restore.

The earlier “customize/capture on source, restore on target” description is
obsolete for Montage's current loadout-only workflow. The peer is a Git host;
the target is the real Omarchy desktop under test. Both can use the same base
template. A real Ress installation must coexist **on the target** to prove
side-by-side isolation; an installation only on the peer cannot prove that.

Use full clones for this pair. Proxmox describes full clones as independent
copies; linked clones retain a dependency on their template. Linked clones are
an alternative for frequent replacement, but introduce storage/template
dependencies. [Proxmox VM documentation](https://github.com/proxmox/pve-docs/blob/master/qm.adoc#copies-and-clones)

Do not designate a previously tested VM as clean merely because Montage's
cleanup passed. Reuse an existing VM only by restoring a known, documented
baseline. If there is no such snapshot or backup, rebuild it once.

### The recurring operator work

After completing the one-time sections below, each run is:

1. Restore both ready snapshots and start both VMs.
2. Log into the target's desktop; leave a terminal open and verify the display.
3. Load the dedicated workstation SSH key and run the readiness checks.
4. Export/publish the revision under test and stage it using section 5. This
   includes uncommitted changes when needed.
5. Paste the handoff prompt in section 7, with the recorded values substituted.
6. After Codex finishes, retain evidence outside the guests, revoke any external
   test credentials, restore both snapshots, and leave the VMs powered off.

Codex creates the run's remotes, libraries, migration fixtures, AUR profiles,
and preservation canaries. You do not rebuild those by hand each time.

## 1. Record your installation values once

All IDs and addresses below are examples. The IP addresses are historical
addresses from your notes, not a statement that those machines exist today.
Reserve the selected IPs in DHCP against each **final clone's** MAC address.

Keep this table in the Proxmox VM Notes and with your test evidence:

| Value | Example / what to record |
| --- | --- |
| Proxmox node, version, pool | Your node; pool `montage-tests` |
| VM storage | Snapshot-capable storage covering every VM disk, including EFI |
| Bridge | `vmbr0`, or your selected bridge |
| Target ID / hostname / IP / MAC | `9102` / `montage-test-desktop` / `192.168.68.160` / actual MAC |
| Peer ID / hostname / IP / MAC | `9101` / `montage-git-peer` / `192.168.68.154` / actual MAC |
| Account | `montagetest` on both |
| Workstation key | `/home/tom/.ssh/montage_vm_test` |
| ISO filename, hash, version, installation date | Actual values |
| Baseline Omarchy/kernel/package versions | Actual values after final setup |
| Snapshot names and dates | `montage-desktop-ready-v1`, `montage-git-peer-ready-v1` |
| Public plugin fixture | A dedicated HTTPS Git repository you control |
| Evidence destination | `/home/tom/montage-validation-results/<run-id>` |

Use an expendable LAN or test VLAN reachable from the workstation, with outbound
DNS/HTTPS and package-repository access. Allow workstation → both guests TCP
22, and target → peer TCP 22. If peer-initiated synchronization is needed, allow
peer → target TCP 22 too; the default workflow only needs target → peer.
Do not grant guest access to Proxmox administration credentials.

Check that **Take Snapshot** works on the actual VM storage before investing
in the baseline. If snapshots are unsupported, use powered-off Proxmox backups
of each fully prepared guest and restore those between runs. Re-cloning the
generic template requires repeating section 3; restoring a role-specific backup
retains that preparation. Snapshots are reset points, not an off-host backup.

## 2. Build the recovery template once

### 2.1 Create and install the base VM

Create a resource pool `montage-tests`, upload the chosen Omarchy ISO, and create
the base VM. Retain the ISO and its hash for later rebuilds.

| Setting | Recommended starting value |
| --- | --- |
| Machine / firmware | `q35` / OVMF (UEFI) |
| EFI disk | Selected VM storage; pre-enrolled Secure Boot keys unchecked |
| Disk controller / disk | VirtIO SCSI single / 60 GB SCSI |
| Discard / IO thread | Enable where supported |
| CPU / RAM | `host`, 4 cores / 8 GB |
| Display / network | VirtIO-GPU / VirtIO NIC on selected bridge |
| Guest agent | Enable in Proxmox Options |
| Start at boot | Disabled |

These are starting settings based on the [Omarchy Proxmox installation
example](https://omarchy.org/manual/unattended-installs/). Preserve a display
configuration that actually works on your node rather than changing GPUs on
every run. The target needs both 1280×800 and 1920×1080 usable display modes.
The peer can later use 2 cores / 4 GB; retaining its inherited 60 GB disk is fine.

Install through the Proxmox console with:

- User `montagetest`, full name `Montage Test`.
- Email `montage-test@example.invalid`, hostname `montage-base`.
- Timezone `America/Denver` and a guest-only password.
- No disk encryption, for this disposable environment.

The current installer documents **Ctrl+C at the disk-formatting confirmation**
to select an unencrypted install. Ctrl+C at the first keyboard screen instead
selects preparation for another owner; these are different steps.
[Omarchy installation manual](https://omarchy.org/manual/getting-started/)

After installation, shut down, eject the ISO, put the installed disk first in
Boot Order, and boot again. Complete first-login setup and verify a functioning
Hyprland/Quickshell desktop and terminal before proceeding.

### 2.2 Install access and test tools in the base

**Base VM, terminal with interactive sudo:**

```bash
sudo pacman -Syu --needed qemu-guest-agent openssh rsync jq git curl wtype
sudo systemctl enable --now sshd
sudo systemctl start qemu-guest-agent
sudo reboot
```

The guest-agent unit can be static/device-activated on some installations;
`enable` is not necessary if the unit has no install section. After reboot,
verify both services actually start and Proxmox reports guest-agent information:

```bash
systemctl is-active sshd qemu-guest-agent
id montagetest
sudo -v
```

`montagetest` should be in `wheel` and have ordinary interactive sudo. If the
installer did not add it, use `sudo usermod -aG wheel montagetest`, then log out
and back in; verify the distribution's wheel sudo policy with `sudo visudo`.
Do not enable blanket passwordless sudo.

Record these extra packages as testing infrastructure. Verify that `yay`,
`makepkg`, `hyprctl`, and `quickshell` are available. If AUR build tools are
missing, install `base-devel` during baseline preparation. Use the installed
Omarchy version's supported procedure for its AUR helper; do not substitute a
random installation script.

### 2.3 Establish workstation SSH access

**Workstation:** reuse the existing dedicated key if present. Otherwise create
it with a passphrase. Do not overwrite an existing key.

```bash
install -d -m 700 /home/tom/.ssh
test -f /home/tom/.ssh/montage_vm_test || \
  ssh-keygen -t ed25519 -f /home/tom/.ssh/montage_vm_test \
    -C montage-vm-testing
ssh-add /home/tom/.ssh/montage_vm_test
cat /home/tom/.ssh/montage_vm_test.pub
```

If the `.pub` file is missing, derive it with
`ssh-keygen -y -f /home/tom/.ssh/montage_vm_test > /home/tom/.ssh/montage_vm_test.pub`.
Only the public line goes into the guest.

**Base VM:** paste that line into `~/.ssh/authorized_keys`, then set directory
mode 0700 and file mode 0600. Check UFW and Proxmox firewalls. If UFW is active,
allow TCP 22 from the workstation's actual IP or selected test subnet. For
example, substitute the real address in:

```bash
sudo ufw allow from WORKSTATION_IP to any port 22 proto tcp
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Compare that console fingerprint with the workstation SSH prompt before
accepting the base host key. Test an SSH login and interactive sudo.

### 2.4 Freeze the recovery template

The base must contain no Montage/Ress installation, test remotes, personal
service login, GitHub token, private guest SSH key, or temporary sudo rule.
Use test Git identity rather than personal credentials. Record hardware,
package versions, additions, and “unencrypted disposable test baseline” in Notes.
Shut down, wait for **Stopped**, then **Convert to template**.

Do not update this template in place. For a new Omarchy baseline, create a new
version and retain the old version until the new pair passes readiness checks.

### 2.5 Add Proxmox Notes to the base template

In the Proxmox web interface, select `montage-omarchy-base-v1`, open **Summary**,
and use the **Notes** panel's edit control. Paste the Markdown below and save.
You can also add the Notes to the base VM before converting it to a template;
confirm they remain attached afterward.

The original date, version, setup IP, firewall scope, and update method below
come from your supplied v1 Notes. Preserve them when documenting that original
template. For a rebuilt template, replace them with the actual new values and
change the version/name. Fill every `<...>` field from the completed setup;
record a missing check as **pending**, not verified. Do not paste passwords,
private keys, tokens, or Proxmox credentials into Notes.

**Paste-ready base template Notes:**

```markdown
# Montage Omarchy Base Template v1

Purpose: Clean recovery and provisioning template for disposable Montage
verification guests. The test desktop runs Montage and UI checks; the Git
peer hosts disposable remote repositories. This template is not a test guest.

## Installation and provenance

- Resource type: Proxmox VM template.
- VM ID: 9000.
- Name: montage-omarchy-base-v1.
- Setup date: 2026-10-02.
- OS: Omarchy Linux (Arch Linux / Hyprland / Wayland).
- Omarchy version: 4.0.4-1.
- Kernel: <recorded kernel version>.
- ISO filename / SHA-256: <filename> / <hash>.
- Proxmox node / version: <node> / <version>.
- Pool / storage / bridge: montage-tests / <storage> / <bridge>.
- Guest hostname / username: montage-base / montagetest.
- Disk encryption: disabled; disposable environment only.
- Hardware: <CPU type and cores>; <RAM>; <disk size/controller>; <GPU>;
  <machine/firmware>; <EFI/Secure Boot configuration>.
- Start at boot: disabled. Installation ISO ejected; installed disk boots first.

## Guest preparation

- Original v1 system updates performed through: omarchy update.
- Last update / reboot date: <date>.
- Original access packages: qemu-guest-agent, openssh, rsync, jq, nano.
- nano added for convenient configuration editing over SSH.
- Current runbook tools verified: git, curl, wtype, hyprctl, quickshell,
  yay, makepkg; <record any additions, including base-devel if installed>.
- qemu-guest-agent and sshd verified active after reboot: <date / result>.
- QEMU Guest Agent enabled in Proxmox and guest information verified: <result>.
- montagetest wheel membership and interactive sudo verified: <result>.
- Montage and Ress are not installed; Montage config/state/link absent.
- No test remotes, captured user state, user SSH private keys, external account
  credentials, or montage-vm-test sudoers rule.

## SSH access

- Original template IP during setup: 192.168.68.154; setup address only, may change.
- Original UFW policy: active; TCP 22 allowed from 192.168.68.0/24.
- Current UFW / Proxmox firewall policy: <verified rule scope>.
- Dedicated workstation key: /home/tom/.ssh/montage_vm_test.
- Public key installed in montagetest's ~/.ssh/authorized_keys.
- Key authentication verified: <date / result>.
- Workstation private key remains on the workstation, not in the VM.
- Base SSH host-key fingerprint: <ED25519 SHA256 fingerprint>.

## Template use

- Shut down and wait for Stopped before converting to a template.
- Create montage-test-desktop and montage-git-peer as full clones.
- Before networking a new clone, initialize a unique hostname, machine ID,
  and SSH host keys; verify a unique MAC and record its IP separately.
- Never run Montage tests or add the pacman-only test rule in this template.
- Prepared guest snapshots, not this template, are the routine reset points.
- Create a new version for baseline changes; retain original provenance.
- Procedure: /home/tom/Work/omarchy-resurrect/docs/testing/disposable-vm-runbook.md.

## Console and maintenance

- Proxmox console available for recovery.
- Original v1 SPICE clipboard sharing: not configured.
- Current console / clipboard method: <actual method; note any later change>.
- Use SSH for routine administration and copy/paste.
- Baseline readiness status / verification date: <PENDING or PASSED> / <date>.
- Change history: <date, change, verification, and replacement baseline name>.
```

For a future `v2` or later template, copy these Notes, update all identity and
provenance fields, and record the parent template/ISO plus the baseline changes.
Do not carry forward a v1 verification result as proof of the new version.

## 3. Prepare the reusable target and peer once

### 3.1 Clone and give each guest a unique identity

Full-clone the template into the two selected VM IDs. Before booting a clone,
disconnect its virtual NIC in Proxmox. Use the console to initialize identity.
Run the following **only in a new disposable clone**, with the appropriate name:

```bash
sudo hostnamectl set-hostname montage-test-desktop
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
sudo rm -f /etc/ssh/ssh_host_*key*
sudo ssh-keygen -A
sudo poweroff
```

Use `montage-git-peer` for the peer. If `/etc/hosts` contains `montage-base`,
replace that hostname too. Reconnect the NIC, confirm different MAC addresses,
set DHCP reservations, and boot both. This initialization is **not repeated
after snapshot rollback**. Reused guests keep their individual identities.

Verify hostname, machine ID, IP, SSH fingerprint, and services on each console.
The two machine IDs and SSH fingerprints must differ. Accept the new SSH host
keys from the workstation only after comparing console fingerprints.
If a replacement guest reuses an IP, remove that IP's old `known_hosts` entry
only after verifying the new fingerprint. Do not disable host-key checking.

For the commands below, define these values in each workstation shell:

```bash
export TARGET_IP=192.168.68.160
export PEER_IP=192.168.68.154
export VM_KEY=/home/tom/.ssh/montage_vm_test
```

### 3.2 Make noninteractive Omarchy sessions predictable

SSH does not inherit the graphical session's environment. On **both guests**,
create a small explicit environment file:

```bash
install -d -m 700 "$HOME/.config/montage-validation"
cat > "$HOME/.config/montage-validation/env.sh" <<'EOF'
export OMARCHY_PATH=/usr/share/omarchy
export PATH="$HOME/.local/bin:$OMARCHY_PATH/bin:$PATH"
EOF
chmod 600 "$HOME/.config/montage-validation/env.sh"
. "$HOME/.config/montage-validation/env.sh"
test -d "$OMARCHY_PATH"
omarchy version
git config --global user.name 'Montage VM Test'
git config --global user.email 'montage-test@example.invalid'
```

If this Omarchy version has a different installation path, discover and record
the actual path and adjust the file. Never edit `/usr/share/omarchy`.
Codex must source this file in each SSH command/session; shell startup files
alone are not a reliable noninteractive environment contract.

For real UI work, execute from a terminal in the target's actual desktop, or
discover the active user's runtime directory, Wayland socket, D-Bus address,
and Hyprland instance before invoking desktop commands from SSH. Do not guess
`wayland-0` or treat a running process as proof that SSH has desktop access.
The script's headless theme mode is not evidence of a visible theme change.

### 3.3 Prepare the target desktop and clean product state

**Target, graphical terminal:**

```bash
. "$HOME/.config/montage-validation/env.sh"
omarchy theme set tokyo-night
cat "$HOME/.local/state/omarchy/current/theme.name"
pgrep -af Hyprland
pgrep -af quickshell
hyprctl monitors
```

Verify `tokyo-night`, a live desktop, working pointer/wheel input, and both
1280×800 and 1920×1080 at scale 1. If the console cannot resize to those modes,
inspect `hyprctl monitors all` and the installed Hyprland display help/config;
configure supported modes once and record how to switch them. Browser zoom or
resizing the console's HTML canvas is not a change to the guest resolution.

The target baseline must have:

- No `tree`, `figlet`, or `sl` package.
- No `~/.config/omarchy/plugins/tombychowski.montage`.
- No Montage config/state or `~/.local/bin/mntg`, including broken symlinks.
- No user themes `sunset-drive` or `hermarchy`.
- No `Montage VM A.desktop` or `Montage VM B.desktop` launcher.
- No previous run evidence, validation checkout, bare remotes, or fixture canary.

Stock Omarchy plugins/themes/web apps are allowed; “clean” does not mean deleting
stock user configuration. If fixture packages are already installed, investigate
why before removing them. Do not remove stock dependencies to satisfy a test.

Check fixture package absence:

```bash
for package in tree figlet sl; do
  if pacman -Q "$package" >/dev/null 2>&1; then
    printf 'NOT READY: %s is installed\n' "$package"
  else
    printf 'absent: %s\n' "$package"
  fi
done
```

### 3.4 Add the disposable target's pacman-only privilege

**Target, console or graphical terminal with interactive sudo:**

```bash
sudo visudo -f /etc/sudoers.d/montage-vm-test
```

Insert exactly:

```text
montagetest ALL=(root) NOPASSWD: /usr/bin/pacman
```

Validate and test:

```bash
sudo chmod 0440 /etc/sudoers.d/montage-vm-test
sudo visudo -cf /etc/sudoers.d/montage-vm-test
sudo visudo -c
sudo -k
sudo -n /usr/bin/pacman -Q bash
sudo -k
sudo -n /usr/bin/id
```

The pacman query must succeed; `id` must fail. Investigate broader sudo policy
if `id` succeeds. The peer needs no extra sudo authorization.

**Pacman authorization is effectively root-equivalent:** package installation
scripts can run as root. This ready baseline is suitable only for this trusted,
expendable VM pool. Saving the rule in the target ready snapshot deliberately
avoids recreating it each run. The recovery template has no such rule.

`loadout-vm-preflight.sh` checks `sudo -n true`, so
`SUDO_NONINTERACTIVE=no` is correct for this policy. Verify pacman separately;
do not broaden sudo merely to turn that preflight field into `yes`.

### 3.5 Establish target-to-peer access without a personal forwarded agent

Use a separate **guest test key**, valid only for this peer. This is intentionally
different from the workstation key. It prevents tests from depending on the
operator's particular forwarded SSH connection.

**Target:**

```bash
install -d -m 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -N '' -f "$HOME/.ssh/montage_peer_test" \
  -C montage-disposable-peer-only
cat "$HOME/.ssh/montage_peer_test.pub"
```

**Peer:** append that public line to `~/.ssh/authorized_keys` and set mode 0600.
Authorize only that public key, never copy the private key to the peer or base
template. Where supported, prefix its line with `restrict` to disable forwarding
and PTY allocation while retaining Git/command access. If UFW is active, allow
TCP 22 from the target's IP too.

**Target:** compare the peer's SSH fingerprint with its console fingerprint
and accept it once. Replace the sample IP if needed:

```bash
ssh -i "$HOME/.ssh/montage_peer_test" -o IdentitiesOnly=yes \
  montagetest@192.168.68.154 'hostname; git --version'
```

For tests, Codex starts a dedicated guest `ssh-agent`, adds only this key, and
records real agent-authenticated Git transport. Agent forwarding from your
workstation is unnecessary. The test private key is saved in the target's
ready snapshot; its public authorization is saved in the peer's snapshot.
It grants access only to expendable peer data and is replaced if the pair is
rebuilt or retired.

**Peer:** reserve an empty remote parent directory:

```bash
install -d -m 700 "$HOME/.local/share/montage-validation/remotes"
```

Do not create a fixed `loadouts.git` in the baseline. Codex creates new bare
repositories beneath a run-specific directory and uses real ordinary commits,
fetches, pulls, and pushes to exercise synchronization.

### 3.6 Freeze and prove the ready snapshots

Record both package inventories, version information, machine IDs, MACs, SSH
fingerprints, and target resolution capability in Notes. Confirm there are no
GitHub logins, tokens, credential stores, personal data, Montage resources, or
run-specific Git fixtures. Only the dedicated guest key and test policy persist.
Use the guest Notes blocks in section 3.7 **before taking the ready snapshots**,
so their recorded VM configuration contains the correct role-specific Notes.

Shut down both guests cleanly and wait for **Stopped**. In **Snapshots → Take
Snapshot**, create `montage-desktop-ready-v1` on the target and
`montage-git-peer-ready-v1` on the peer, **without RAM**. Optionally make a
powered-off Proxmox backup of each prepared guest for recovery.

Perform a rehearsal: start both, create an expendable marker on each, shut down,
roll back both snapshots, boot, and confirm both markers are absent, networking
works, and the target desktop can be logged into. A verified rollback is the
foundation of the repeatable workflow.

Do not store a running desktop, SSH agent, build, or package transaction in a
memory snapshot. Log into a fresh desktop after every reset.

### 3.7 Add Proxmox Notes to the prepared guests

The recommended arrangement has **one base template and two reusable guest
VMs with ready snapshots**. The guest Notes below belong on those VMs; they
do not require creating two more templates. Cloning may carry forward base
Notes, so replace inherited base-template Notes with the correct guest block.

Select each guest's **Summary → Notes → Edit**, paste its block, fill the
verified values, and save **before taking the ready snapshots in section 3.6**.
Use your actual IDs and reservations if they differ from the examples. Record
the rollback rehearsal result after it has actually completed. Proxmox
Notes are the resource record; also put the short descriptions below on the
snapshots themselves so the correct reset point is identifiable.

**Paste-ready test desktop Notes:**

```markdown
# Montage Test Desktop — Ready Baseline v1

Purpose: Disposable Omarchy desktop for Montage package, plugin, theme,
web-app, lifecycle, migration, preservation, and rendered-panel verification.
This is the target in the manual scripts; it is not a capture/restore destination.

## Identity and baseline

- Resource type: Reusable Proxmox VM, not a template.
- VM ID / name: 9102 / montage-test-desktop.
- Parent template: montage-omarchy-base-v1 (VM ID 9000).
- Preparation date / Omarchy / kernel: <date> / <version> / <kernel>.
- Proxmox node / pool / storage: <node> / montage-tests / <storage>.
- Guest hostname / username: montage-test-desktop / montagetest.
- Reserved IP / MAC: 192.168.68.160 / <actual MAC>.
- Machine ID / ED25519 host fingerprint: <machine ID> / <SHA256 fingerprint>.
- Hardware: <CPU/cores>; <RAM>; <disk>; <GPU/firmware>.
- Ready snapshot / creation date: montage-desktop-ready-v1 / <date>.
- Snapshot taken powered off, without RAM; rollback rehearsal: <date / result>.
- Recovery backup: <backup identifier/location, or none>.

## Ready state

- Baseline theme: tokyo-night.
- Fixture packages tree, figlet, sl: absent.
- Montage and Ress: not installed; Montage config/state/mntg link absent.
- Fixture themes sunset-drive and hermarchy and Montage VM A/B launchers: absent.
- No staged test revision, previous-run evidence, libraries, or external tokens.
- SSH and guest agent active after reboot; interactive sudo available.
- ~/.config/montage-validation/env.sh sets OMARCHY_PATH=/usr/share/omarchy
  and adds the Omarchy and local-user bin directories to PATH.
- Git test identity: Montage VM Test / montage-test@example.invalid.
- Required tools and package/AUR/HTTPS network access: <verification date/result>.

## Test authorization and SSH

- Workstation public test key authorized; workstation private key is not in VM.
- /etc/sudoers.d/montage-vm-test permits only:
  montagetest ALL=(root) NOPASSWD: /usr/bin/pacman
- This is effectively root-equivalent test privilege, saved only in this
  disposable ready baseline. sudo -n pacman -Q bash succeeds; sudo -n id fails.
- Guest private key: ~/.ssh/montage_peer_test; authorized only on montage-git-peer.
- Peer IP / verified fingerprint: 192.168.68.154 / <SHA256 fingerprint>.
- No personal SSH agent forwarding or personal GitHub login required.
- Firewall scope: <workstation SSH source and any other authorized test rules>.

## Desktop and run/reset procedure

- Proxmox console / pointer method: <actual method>.
- Verified guest modes: 1280x800 and 1920x1080 at scale 1; <date/result>.
- Resolution switching method / clipboard support: <actual methods>.
- After every boot/reset, log into Hyprland/Quickshell as montagetest and
  leave an ordinary application window open for focus-return verification.
- Stage exact code and pin the reachable HTTPS plugin fixture before handoff.
- Install Ress only in the later coexistence phase, after clean lifecycle checks.
- Secure evidence outside both guests before any reset.
- Restore this snapshot AND montage-git-peer-ready-v1 between runs.
- Leave powered off between runs; do not turn tested state into a new baseline.
- Evidence root on workstation: /home/tom/montage-validation-results/<run-id>.
- Procedure: /home/tom/Work/omarchy-resurrect/docs/testing/disposable-vm-runbook.md.
- Baseline readiness status: <PENDING or PASSED>; verification record: <saved path>.
```

**Paste-ready Git peer Notes:**

```markdown
# Montage Git Peer — Ready Baseline v1

Purpose: Disposable SSH Git host for independent Montage library histories
and real fetch/pull/push synchronization checks. Not a source-machine capture VM.

## Identity and baseline

- Resource type: Reusable Proxmox VM, not a template.
- VM ID / name: 9101 / montage-git-peer.
- Parent template: montage-omarchy-base-v1 (VM ID 9000).
- Preparation date / Omarchy / kernel: <date> / <version> / <kernel>.
- Proxmox node / pool / storage: <node> / montage-tests / <storage>.
- Guest hostname / username: montage-git-peer / montagetest.
- Reserved IP / MAC: 192.168.68.154 / <actual MAC>.
- Machine ID / ED25519 host fingerprint: <machine ID> / <SHA256 fingerprint>.
- Hardware: <CPU/cores>; <RAM>; <disk>.
- Ready snapshot / creation date: montage-git-peer-ready-v1 / <date>.
- Snapshot taken powered off, without RAM; rollback rehearsal: <date / result>.
- Recovery backup: <backup identifier/location, or none>.

## Guest preparation and access

- SSH and qemu-guest-agent verified active after reboot: <date/result>.
- Workstation public test key authorized; workstation private key is not in VM.
- Test desktop's montage_peer_test PUBLIC key authorized for SSH Git access.
- Authorized key restriction: <restrict, or actual applied restrictions>.
- No test desktop private key or personal credentials stored here.
- Firewall allows TCP 22 from workstation and test desktop: <verified scope>.
- No montage-vm-test sudoers rule; Git tests require no extra sudo privilege.
- ~/.config/montage-validation/env.sh sets OMARCHY_PATH and test PATH.
- Git test identity: Montage VM Test / montage-test@example.invalid.
- Bare remote parent: ~/.local/share/montage-validation/remotes, mode 0700.
- Remote parent is empty in the ready snapshot; create per-run remotes beneath it.
- Montage/Ress, run artifacts, external tokens, and personal state absent.

## Run/reset procedure

- Codex creates independent per-run bare remotes and test histories here.
- Real Ress coexistence is tested on montage-test-desktop, not on this peer.
- Secure evidence outside both guests before reset; revoke external credentials
  separately because rollback cannot revoke server-side access.
- Restore this snapshot AND montage-desktop-ready-v1 between runs.
- Leave powered off between runs; preserve the ready baseline.
- Console / clipboard method: <actual method>; SSH is routine administration.
- Evidence root on workstation: /home/tom/montage-validation-results/<run-id>.
- Procedure: /home/tom/Work/omarchy-resurrect/docs/testing/disposable-vm-runbook.md.
- Baseline readiness status: <PENDING or PASSED>; verification record: <saved path>.
```

**Snapshot descriptions:** paste these into the corresponding snapshot's
description when creating it. Append the actual creation date, Omarchy version,
and successful rehearsal date afterward.

```text
montage-desktop-ready-v1: Powered-off clean Montage product state; tokyo-night;
no Montage/Ress or lifecycle fixtures. Includes test tools, workstation SSH
authorization, peer-only guest key, and disposable pacman-only sudo rule.
Reset together with montage-git-peer-ready-v1. Export evidence first.
```

```text
montage-git-peer-ready-v1: Powered-off clean Git peer; empty mode-0700 remote
parent; workstation and test-desktop public keys authorized; no extra test
sudo rule, personal credentials, or run histories. Reset together with
montage-desktop-ready-v1. Export evidence first.
```

Save a copy of each completed Notes block with the external baseline records.
Snapshot rollback can restore older VM configuration, including its Notes;
if it restores an older description, reapply the saved Notes. Keep per-run
results and reset records in the workstation run directory; you do not need to
rewrite baseline Notes for every run. Keep baseline facts separate from results.
If a version, privilege, key, firewall, or console method changes, record it as
a baseline revision and reverify it before creating a replacement ready snapshot.

## 4. Immediately before each handoff

### 4.1 Reset, boot, and log in

In Proxmox, shut down both guests if needed. Restore **both** ready snapshots
and start both VMs. Wait for boot, guest-agent reporting, DHCP, and clock sync.
Do not reset just the target and retain yesterday's peer histories.

Log in as `montagetest` on the target through the console. Leave an ordinary
terminal open for focus-return checks. Start at 1280×800, scale 1; confirm that
you can switch to 1920×1080 during the run. Keep pointer/console access available.

Do not install Montage or Ress before the clean lifecycle script: Montage is
one of that script's fixture resources and must initially be absent. Codex
installs Ress later in the separate coexistence phase.

### 4.2 Verify SSH, tools, privileges, and baseline

**Workstation:** define the values from section 3.1, then:

```bash
ssh-add /home/tom/.ssh/montage_vm_test
ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$VM_KEY" \
  "montagetest@$TARGET_IP" \
  '. "$HOME/.config/montage-validation/env.sh"; hostname; cat /etc/machine-id; systemctl is-active sshd qemu-guest-agent; omarchy version; sudo -n /usr/bin/pacman -Q bash'
ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$VM_KEY" \
  "montagetest@$PEER_IP" \
  '. "$HOME/.config/montage-validation/env.sh"; hostname; cat /etc/machine-id; systemctl is-active sshd qemu-guest-agent; git --version'
```

`BatchMode` failures usually mean the key is not available to the calling
process, the service/firewall is wrong, or a host-key change needs verification.
Codex must be able to use the same agent socket; a key loaded in an unrelated
terminal's private agent is not necessarily available to Codex. Have Codex run
these checks first. If necessary, start/restart Codex from the environment
with the agent, or arrange a dedicated test-key agent accessible to it; do not
send your passphrase in chat or copy the workstation private key into a guest.

**Target, graphical terminal:**

```bash
. "$HOME/.config/montage-validation/env.sh"
for tool in git jq curl ssh rsync pacman omarchy yay makepkg hyprctl wtype quickshell; do
  command -v "$tool" || printf 'MISSING: %s\n' "$tool"
done
omarchy version
quickshell --version
uname -r
timedatectl show -p NTPSynchronized --value
getent ahosts github.com
curl -fsSI https://github.com/ >/dev/null
df -h /
hyprctl monitors
cat "$HOME/.local/state/omarchy/current/theme.name"
```

Check Arch repository, AUR, both profile theme remotes, and the plugin fixture
from the **target**, not just the workstation. Section 5 checks exact HTTPS Git
commits. Leave roughly 15–20 GB free on the target, more for large AUR builds.

If an old Arch baseline cannot complete real package transactions, refresh
the whole baseline coherently, reboot, and version the ready snapshots. Do not
use `pacman -Sy` followed by package installation as a partial-upgrade shortcut.
Record any update rather than silently testing a different baseline.

## 5. Stage the exact code and reachable plugin fixture

### 5.1 Create the fixture repository once

Create a dedicated, initially empty **public** Git repository, for example
`https://github.com/YOUR_ACCOUNT/montage-vm-fixture`. Keep it separate from
production release repositories. Publication is intentional: only export code
and fixtures you are comfortable making public. Authenticate for pushes on the
workstation using your existing Git setup; guests clone anonymously.

Do not log either guest into your personal GitHub account. `gh auth login` in
the original notes is unnecessary for a public plugin fixture and SSH peer
remotes. Private credential-helper testing is a separate phase in section 6.

Portable plugin/theme resource URLs must be credential-free HTTPS and work
after a trailing `.git` is normalized away. SSH is appropriate for a **library
remote**, but not a portable **plugin definition**. Do not globally disable
TLS verification. The previous loopback/self-signed fixture was a workaround,
not the default repeatable setup.

### 5.2 Export the working tree and publish a reproducible fixture commit

If you are rerunning the **same exact exported revision**, reuse its retained
archive, public URL, and fixture commit instead of exporting/publishing again.
Create a new run directory and `run-values.txt` with a new run ID, copy the
retained archive and checksum into it, then continue at section 5.3. Do not
reuse an old artifact to claim coverage of newly edited development files.

**Workstation, Bash:** replace the fixture URL. Run this block once per run.
It leaves the development repository's index, branch, and commits untouched.
It exports Git-tracked and non-ignored untracked files, omits deleted files,
and records the working-tree status. Review the listed files before publication.

```bash
export REPO=/home/tom/Work/omarchy-resurrect
export PLUGIN_URL=https://github.com/YOUR_ACCOUNT/montage-vm-fixture
export RUN_ID="$(date +%Y%m%d-%H%M%S)"
export RUN_ROOT="/home/tom/montage-validation-results/$RUN_ID"
install -d -m 700 "$RUN_ROOT"
cd "$REPO"
git rev-parse HEAD > "$RUN_ROOT/development-head.txt"
git status --short > "$RUN_ROOT/development-status.txt"
git diff --binary HEAD > "$RUN_ROOT/development-tracked.patch"
git ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' path; do
    if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
  done > "$RUN_ROOT/files.nul"
tr '\0' '\n' < "$RUN_ROOT/files.nul"
```

Review that output, including untracked files. Ignored files, `.git`, tokens,
and personal evidence must not be part of the export. If ignored source files
are required to reproduce the implementation, resolve that explicitly rather
than silently claiming the export includes them. Avoid editing the development
tree while the export is being made.

After review, continue **in the same workstation shell**:

```bash
set -euo pipefail
tar --create --gzip --file="$RUN_ROOT/source.tar.gz" \
  --null --verbatim-files-from --files-from="$RUN_ROOT/files.nul"
install -d -m 700 "$RUN_ROOT/fixture"
tar -xzf "$RUN_ROOT/source.tar.gz" -C "$RUN_ROOT/fixture"
git -C "$RUN_ROOT/fixture" init -q
git -C "$RUN_ROOT/fixture" add --force --all
git -C "$RUN_ROOT/fixture" -c user.name='Montage VM Fixture' \
  -c user.email='montage-test@example.invalid' \
  commit -qm "Montage validation $RUN_ID"
export PLUGIN_COMMIT="$(git -C "$RUN_ROOT/fixture" rev-parse HEAD)"
git -C "$RUN_ROOT/fixture" remote add origin "$PLUGIN_URL"
git -C "$RUN_ROOT/fixture" push origin "HEAD:refs/heads/run-$RUN_ID"
git -C "$RUN_ROOT/fixture" archive --format=tar.gz \
  --output="$RUN_ROOT/montage-under-test.tar.gz" "$PLUGIN_COMMIT"
sha256sum "$RUN_ROOT/montage-under-test.tar.gz" > "$RUN_ROOT/archive.sha256"
printf 'RUN_ID=%s\nPLUGIN_URL=%s\nPLUGIN_COMMIT=%s\nRUN_ROOT=%s\n' \
  "$RUN_ID" "$PLUGIN_URL" "$PLUGIN_COMMIT" "$RUN_ROOT" |
  tee "$RUN_ROOT/run-values.txt"
```

This snapshot commit has a **new** SHA, even if the code came from a clean
development commit. Record both identities. Its archived tree is the code sent
to the guests. The working-tree patch plus full export also records uncommitted
work; `git archive HEAD` from the development tree would miss that work.
The forced add preserves exported files that were tracked in the development
repository even if its ignore rules would hide them in a new repository.

For an empty public fixture repository, select the pushed branch as its default
branch in the hosting UI, once. Keep each run branch available for the entire
test and evidence review. The exact commit is the resource pin.

### 5.3 Upload without installing Montage

**Workstation, same shell, with `TARGET_IP`, `PEER_IP`, and `VM_KEY` set:**

```bash
for host in "$TARGET_IP" "$PEER_IP"; do
  ssh -o IdentitiesOnly=yes -i "$VM_KEY" "montagetest@$host" \
    'install -d -m 700 "$HOME/.local/share/mntg-validation"'
  scp -o IdentitiesOnly=yes -i "$VM_KEY" \
    "$RUN_ROOT/montage-under-test.tar.gz" \
    "$RUN_ROOT/run-values.txt" \
    "montagetest@$host:.local/share/mntg-validation/"
done
ssh -o IdentitiesOnly=yes -i "$VM_KEY" "montagetest@$TARGET_IP" \
  'set -eu; root="$HOME/.local/share/mntg-validation"; test ! -e "$root/current"; install -d -m 700 "$root/current" "$root/profiles"; tar -xzf "$root/montage-under-test.tar.gz" -C "$root/current"; cp "$root/current/tests/manual/vm-loadout-a.json" "$root/current/tests/manual/vm-loadout-b.json" "$root/profiles/"'
```

The peer retains the same archive for independent history/fixture work. The
target's `current/bin/mntg` is staged code, not an installed plugin or PATH link.

**Target, graphical terminal:** read the recorded URL and commit from
`~/.local/share/mntg-validation/run-values.txt`, then substitute them below.
Only change staged profile copies:

```bash
set -euo pipefail
. "$HOME/.config/montage-validation/env.sh"
PLUGIN_URL=https://github.com/YOUR_ACCOUNT/montage-vm-fixture
PLUGIN_COMMIT=REPLACE_WITH_THE_RECORDED_40_CHARACTER_SHA
root="$HOME/.local/share/mntg-validation"
for profile in "$root/profiles/vm-loadout-a.json" "$root/profiles/vm-loadout-b.json"; do
  jq --arg url "$PLUGIN_URL" --arg commit "$PLUGIN_COMMIT" \
    '(.plugins[] | select(.id == "tombychowski.montage")) |= (.url = $url | .commit = $commit)' \
    "$profile" > "$profile.updated"
  mv "$profile.updated" "$profile"
done
check_dir=$(mktemp -d)
GIT_TERMINAL_PROMPT=0 git -c credential.helper= clone --no-checkout \
  "$PLUGIN_URL" "$check_dir/plugin"
git -C "$check_dir/plugin" checkout --detach "$PLUGIN_COMMIT"
test "$(git -C "$check_dir/plugin" rev-parse HEAD)" = "$PLUGIN_COMMIT"
test "$(jq -r '.id' "$check_dir/plugin/manifest.json")" = tombychowski.montage
rm -rf -- "$check_dir"
for profile in "$root/profiles/vm-loadout-a.json" "$root/profiles/vm-loadout-b.json"; do
  url=$(jq -r '.theme.url' "$profile")
  commit=$(jq -r '.theme.commit' "$profile")
  theme_dir=$(mktemp -d)
  GIT_TERMINAL_PROMPT=0 git -c credential.helper= clone --no-checkout "$url" "$theme_dir/theme"
  git -C "$theme_dir/theme" checkout --detach "$commit"
  rm -rf -- "$theme_dir"
done
cd "$root/current"
./tests/manual/loadout-vm-preflight.sh | tee "$root/preflight.log"
sudo -n /usr/bin/pacman -Q bash
```

Expect `REGISTRY=absent`, `MONTAGE_PLUGIN=absent`, `CURRENT_THEME=tokyo-night`,
and `SUDO_NONINTERACTIVE=no`. The public fixture must work anonymously and
the pinned theme commits must actually fetch. If any check fails, fix it before
starting the destructive lifecycle. Codex can perform this target block as the
first staging check, using the handed-off URL and SHA, to save operator typing.

## 6. Coverage arrangements that prevent another partial run

The lifecycle script is valuable but does not cover the entire fresh-machine
checklist. Its profiles have no AUR packages; it uses headless theme flags and
a shell shim for one removal path. Those results must stay distinguished from
real visible UI, AUR review, and live shell unload evidence.

| Coverage | Preparation / responsibility |
| --- | --- |
| Native lifecycle | Target initially clean; staged profiles pinned to working HTTPS Git commits; pacman-only sudo ready |
| Real SSH-agent Git | Guest test key and verified peer host key; Codex starts an agent and creates per-run bare remotes |
| Credential-helper Git | Separate private HTTPS library remote and narrowly scoped disposable read/write credential; configure helper externally |
| AUR `ask` / `yes` / `no` | Working `yay`, `makepkg`, build tools/network; Codex chooses a small disposable fixture and presents fetched PKGBUILD for separate consent |
| Ress coexistence | Confirm a reachable supported Ress source/revision; install on target after clean lifecycle; retain before/after bytes and metadata |
| Installed upgrade | Codex provides a real earlier fixture commit and later fast-forward commit on a separate disposable branch; one pinned fresh install cannot prove update |
| Pre-existing preservation | Codex installs a small unrelated resource before a separate apply, records baseline, then verifies release preserves it |
| Repair/update commands | Codex creates drift/new library revision and runs explicit check, repair, update preview/update; not inferred from apply/remove |
| Rendered interaction | Logged-in target desktop, ordinary window open, verified two resolutions, pointer/wheel input, and accessible visible terminal handoffs |
| Registry/Ress migrations | Codex creates disposable copies on separate non-overlapping paths, records source bytes/modes, and compares after each operation |
| Current corrective change | Rendered field entry/focus, preset union/theme feedback, unhealthy Applied view, Ress result parsing/handoff, package preservation, migration reporting, and read-only preview provenance |

### Private credential-helper preparation

If you want this coverage in this run, create an expendable private **loadout
library** repository on your Git host. Issue a short-lived credential restricted
to that repository's required read/write access. In a target interactive terminal,
configure your host's supported credential helper and enter the credential
through its private prompt. Prefer a memory/cache helper over plaintext storage.
Record only the credential-free HTTPS remote and helper type for Codex.

Never put the token in this runbook, chat, shell command arguments, repository
URL, profile, or evidence. Test authentication with
`GIT_TERMINAL_PROMPT=0 git ls-remote HTTPS_REMOTE` and later a real non-forced
push. An empty remote is allowed. Codex must record this as **credential-helper**
evidence separately from **SSH-agent** evidence. Expire/revoke the credential
after testing; snapshot rollback cannot revoke server-side credentials.

Without that remote/helper, this row is deferred even if SSH tests pass. This
is the one optional preparation requiring external authentication; public
plugin fixtures and peer Git tests need no GitHub guest login.

### Human participation during testing

Arrange an operator window for AUR review and pointer checks. A command-line
SSH connection alone gives Codex no Proxmox pointer access. If Codex has no
browser/console control, perform the requested clicks, wheel movement, display
switches, and terminal decisions while Codex records observations. Do not
count keyboard-only `wtype`, Page Down, or screenshots as pointer evidence.

General test authorization does not approve unseen AUR build instructions.
For the build/review paths, require the fetched PKGBUILD and relevant build
files to be shown and obtain the separate execution decision. Decline paths
remain part of the test. Do not silently add blanket AUR execution permission
to make the run unattended.

If a second clean phase is needed, Codex first exports evidence and asks you
to restore the pair, then restages the same archived revision. This uses the
same two VMs. Never restore a snapshot while a test or evidence copy is active.

## 7. Exact handoff prompt

Copy the following into the Codex chat for this repository. Replace every
`<...>` field. If an optional fixture is unavailable, write **unavailable —
defer that row**. Use the URL/SHA from `run-values.txt`, not the historical
checked-in plugin URL or the development `HEAD` in a dirty workspace.

```text
Run Montage's manual verification on my two disposable Omarchy VMs using
docs/testing/disposable-vm-runbook.md, docs/testing/fresh-machine-validation.md,
docs/testing/strategy.md, tests/manual/, the current main OpenSpec requirements,
and any active corrective change. This run is authorized now.

Run ID: <run-id>
Development repository: /home/tom/Work/omarchy-resurrect
Development base HEAD: <development-head.txt value>
Exported fixture commit under test: <PLUGIN_COMMIT, exact 40-character SHA>
Public plugin fixture URL: <credential-free HTTPS PLUGIN_URL>
Workstation evidence directory: /home/tom/montage-validation-results/<run-id>
Archive SHA-256: <archive.sha256 value>

Target: montagetest@<target-IP>, Proxmox VM <target-ID>, montage-test-desktop
Peer: montagetest@<peer-IP>, Proxmox VM <peer-ID>, montage-git-peer
Workstation SSH key: /home/tom/.ssh/montage_vm_test
Target-to-peer key: /home/montagetest/.ssh/montage_peer_test
Verified SSH host keys: <target fingerprint>; <peer fingerprint>
Ready snapshots: <target snapshot>; <peer snapshot>
Recorded baseline: <Omarchy/kernel versions and snapshot dates>

Both VMs have been restored to those ready snapshots. The target desktop is
logged in as montagetest, with Hyprland/Quickshell running and an ordinary
terminal open. The target supports 1280x800 and 1920x1080 at scale 1.
Pointer/console access: <available control method, or operator-assisted>
I am available for pointer/display checks and AUR build review during <window>.
The temporary test rule authorizes only /usr/bin/pacman on the target; the
peer has no additional sudo rule. sudo -n true is expected to fail.
Source ~/.config/montage-validation/env.sh in every remote session/command.

The same montage-under-test.tar.gz and run-values.txt are staged beneath
~/.local/share/mntg-validation on both guests. On the target, current/ contains
the exported source and profiles/ contains copies of the two lifecycle profiles.
<Profile status: already patched/verified, or patch them now using the URL/SHA above.>
Montage is not installed and its packages/themes/web-app fixtures are absent.
Baseline theme is tokyo-night. Verify these facts before any mutation.

Private HTTPS library remote / credential helper: <URL and helper type, or unavailable — defer>
Supported Ress fixture source / revision: <URL and revision, or unavailable — defer>

You may create and mutate test libraries, bare remotes, fixture histories,
packages, pinned integrations, web apps, themes, and copied migration fixtures
only inside these disposable guests and the dedicated fixture repository's
run-specific branches. You may push ordinary non-forced fixture updates needed
to prove installed update and remote synchronization. Do not publish the
development working tree or push/commit/stage changes in my development repo.
Use the exported fixture commit as the implementation under test. Test fixes
as a new explicitly recorded revision rather than mixing revisions in results.
Do not touch other VMs, Proxmox configuration, personal libraries, or release repos.

First confirm BatchMode SSH access, identities, environment, exact code archive,
clean fixture state, pacman-only sudo, anonymous HTTPS plugin pin, theme pins,
and target-to-peer transport. If these fail, explain the specific blocker.
Run loadout-real-scratch.sh, then run-vm-loadout-lifecycle.sh with the documented
staging layout before separately installing Montage for the live panel and
Ress coexistence phases. Use real SSH-agent Git plus the separate credential
helper fixture when available. Include explicit repair/update, pre-existing
resource preservation, installed upgrade/removal, and all current correction
checks. Keep real desktop evidence separate from headless/shim script checks.
Present fetched AUR build instructions and obtain the separate execution
decision for AUR review/build paths. Do not infer it from this general authorization.

For every fresh-machine checklist section and correction, report pass, fail,
or deferred with expected/actual observations, exact revision, baseline/tool
versions, commands, and artifact paths. Collect panel evidence at both sizes,
real mouse and wheel behavior, field entry, focus return, and terminal handoffs.
If console control is unavailable, coordinate operator actions with me.
Do not convert old results or unexecuted checks into current passes.

Keep evidence under ~/.local/share/mntg-validation/evidence on both guests;
include preflight.log and target-lifecycle.log in the final collection. Export
all selected evidence and a coverage report to the workstation run directory,
verify that the local copies open and match checksums, and complete product
cleanup/preservation assertions before asking for reset. Leave both VMs intact
until evidence is secured. If an intermediate reset is needed, export first
and tell me exactly when to restore both snapshots and restage the same archive.

Finish with results, unresolved blockers, cleanup observations, retained
evidence paths, and an explicit statement that evidence is safe and the VMs
can be reset. Do not reset/delete VMs, rotate their keys, remove reusable test
infrastructure, or revoke my external credentials yourself. Leave project
changes unstaged and do not merge or archive an OpenSpec change.
```

## 8. After testing completes

### 8.1 Secure evidence before reset

Require the coverage report, exact code/archive identity, Omarchy/tool versions,
commands with expected/actual observations, selected screenshots, and cleanup
assertions. A pass in one evidence class does not close a deferred row in another.

Codex should already have copied these off the guests. If you need to copy
them yourself, use the same workstation variables and existing `RUN_ROOT`:

```bash
install -d -m 700 "$RUN_ROOT/target" "$RUN_ROOT/peer"
rsync -av -e "ssh -i $VM_KEY -o IdentitiesOnly=yes" \
  "montagetest@$TARGET_IP:.local/share/mntg-validation/" "$RUN_ROOT/target/"
rsync -av -e "ssh -i $VM_KEY -o IdentitiesOnly=yes" \
  "montagetest@$PEER_IP:.local/share/mntg-validation/" "$RUN_ROOT/peer/"
```

Copy any additional evidence paths listed by Codex too. Verify transfer exit
status, open the report/screenshots locally, and compare guest and local
SHA-256 inventories for retained artifacts. Do not keep evidence only in `/tmp`
or inside either resettable VM. Back up the retained workstation directory to
your usual storage if desired, after checking it contains no credentials.

Product cleanup must be tested **before** infrastructure reset: for example,
confirm Montage removal preserves an unrelated Ress installation, foreign PATH
target, pre-existing resources, and private source bytes. Snapshot rollback
cleans the VM but cannot prove Montage's own cleanup behaved correctly.

### 8.2 Revoke external access and reset both VMs

1. End builds/transactions and close disposable guest SSH agents/tunnels.
2. Revoke/expire any private-remote credential issued for this run. Remove
   server-side temporary remotes if no longer needed. Rollback does not erase
   remote-host Git history or revoke tokens.
3. Retain public fixture commits while evidence is under review. Later remove
   expired run branches if desired; keep the dedicated fixture repository for
   the next run. Never delete a production repository as test cleanup.
4. Shut down both guests cleanly and wait for **Stopped**.
5. Roll back target to `montage-desktop-ready-v1` and peer to
   `montage-git-peer-ready-v1`. Leave both stopped until the next run.
6. Unload the dedicated workstation key if no longer needed:

   ```bash
   ssh-add -d /home/tom/.ssh/montage_vm_test
   ```

The ready target deliberately still contains its test-only pacman rule and
peer-only key after rollback. Keep it powered off between runs. Do not remove
those and then overwrite the ready snapshot unless changing the baseline;
doing so defeats the saved preparation.

If you leave the tested target running instead of resetting it, remove the
temporary rule through the console with interactive sudo:

```bash
sudo rm -f /etc/sudoers.d/montage-vm-test
sudo visudo -c
sudo -k
sudo -n /usr/bin/pacman -Q bash
```

The last query must fail. This is temporary containment, not a substitute for
restoring a clean baseline before the next run. Neither the pacman-only rule
nor Codex's SSH authorization includes arbitrary root cleanup commands.

### 8.3 Refresh or retire the baseline

Refresh when the chosen Omarchy/tool version changes, Arch transactions stop
working, or you change test infrastructure. Build from the clean template or a
new ISO; perform coherent updates, reboot, redo role preparation, prove reset,
then record new `v2` snapshots. Do not snapshot yesterday's tested state as the
new baseline. Re-run coverage on the changed baseline and retain old evidence
with its original versions.

For retirement, remove the guest key's public authorization from any retained
peer, revoke external credentials, and destroy the expendable guests and their
privileged snapshots/backups when no longer needed. The workstation test key
can remain for a replacement pair or be deleted when testing ends entirely.

## 9. Sources and boundaries

- Operator notes reviewed: `/home/tom/Nextcloud/Documents/Set Up Disposable Omarchy VM on Proxmox.md`.
- [Testing strategy](strategy.md) owns evidence classes and recording rules.
- [Fresh-machine validation](fresh-machine-validation.md) owns the full manual checklist and historical observations.
- [Manual preflight](../../tests/manual/loadout-vm-preflight.sh),
  [real-tool scratch check](../../tests/manual/loadout-real-scratch.sh), and
  [native lifecycle script](../../tests/manual/run-vm-loadout-lifecycle.sh) own their actual requirements and staging layout.
- [Current corrective evidence](../../openspec/changes/fix-loadout-only-regressions/evidence.md)
  identifies pending rendered/real-machine verification as of 2026-10-10.
  Inspect active changes again for each later run.
- [Application identity](../architecture/application-identity.md) owns Montage paths and coexistence.
- [Omarchy skill](/home/tom/.codex/skills/omarchy/SKILL.md) informed guest command and privilege guidance.
- [Proxmox documentation](https://github.com/proxmox/pve-docs/blob/master/qm.adoc)
  and [Omarchy installation documentation](https://omarchy.org/manual/getting-started/)
  were reviewed on 2026-10-10. Installation UI and storage support should be
  checked against the versions actually deployed.

The ready snapshots are clean **Montage product state**, with documented SSH,
tools, guest key, and test privilege additions. Evidence from them is qualified
accordingly; it is not an untouched stock Omarchy installation. This runbook
introduces no new Montage behavior and weakens none of its preservation,
credential, compatibility, or execution-consent requirements.
