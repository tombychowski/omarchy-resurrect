# Back up and restore

This workflow captures one Omarchy machine lineage into a private Montage
vault, inspects immutable backups, previews one exact snapshot, restores it,
and verifies the result. Read [Vault format](../contracts/vault-format.md) for
the repository contract and [Restore safety](../contracts/restore-safety.md)
for consent and preservation rules.

## Initialize the private vault

```bash
mntg doctor
mntg init
mntg status
```

Initialization creates a Git repository with stable vault and machine-lineage
ids in `montage.json`. It does not pretend an empty repository is a backup.
Keep a vault remote private: configuration, package inventory, host evidence,
and encrypted-secret ciphertext are personal data.

The ordinary categories default on except secrets. Review or change settings
through the CLI:

```bash
mntg set CAPTURE_AUTOSTART=1
mntg set SECRET_SCAN=block
```

Autostart capture is explicit because those launchers run at login. Blocking
scan mode refuses a candidate containing credential-shaped plaintext.

## Capture a backup commit

```bash
mntg backup -m "Before replacing this machine"
```

Montage stages and validates the complete snapshot before publishing it. A
failed capture or blocking credential scan leaves the current snapshot and Git
history unchanged. An unchanged capture reports the existing commit instead
of adding timestamp-only history.

Inspect the immutable results:

```bash
mntg backup list
mntg backup list --json
mntg backup show 0123456789abcdef0123456789abcdef01234567
```

Each list or show operation reconstructs and validates the named commit without
changing the vault checkout. Resolve warnings about omissions, unsafe links,
local-only code, unsupported launchers, or credential-bearing URLs on the
source machine.

## Give an important backup a label

Use a bounded lowercase label as a stable human selector:

```bash
mntg backup label before-reinstall 0123456789abcdef0123456789abcdef01234567
mntg backup show before-reinstall
```

Labels are unique. A labeled backup is protected from retention until the
label is explicitly removed:

```bash
mntg backup unlabel before-reinstall
```

## Preview one exact backup

Select the commit or Montage-managed label explicitly:

```bash
mntg restore --backup before-reinstall --dry-run
mntg restore --backup 0123456789abcdef0123456789abcdef01234567 \
  --only packages,config --dry-run
```

The preview prints the vault repository id and resolved commit. That isolated
commit remains the source even if a branch moves afterward. Supported
categories are `packages`, `config`, `omarchy`, `webapps`, `plugins`, and
`secrets`; an unknown category fails before mutation.

For first contact with a private remote, preview in temporary storage:

```bash
mntg restore --from https://github.com/you/private-montage-vault.git \
  --backup 0123456789abcdef0123456789abcdef01234567 --dry-run
```

Use the exact commit currently published by the remote. Git credentials should
come from an SSH agent or credential helper, not an embedded URL.

## Restore and resume

```bash
mntg restore --backup before-reinstall
```

The confirmation names the same vault id and resolved commit shown in preview.
General `--yes` does not grant AUR-build or service-enablement consent. For an
unattended run, make all decisions explicit:

```bash
mntg restore --backup before-reinstall \
  --yes --aur --enable-units
```

Or explicitly defer the higher-power actions:

```bash
mntg restore --backup before-reinstall \
  --yes --no-aur --no-enable-units
```

If a live restore stops or remains partial, rerun the same command with the
same label or commit. Progress is keyed by repository id plus resolved commit;
another vault or backup never inherits completed categories. Use `--restart`
to discard progress deliberately.

Deferred services remain separately inspectable:

```bash
mntg enable-units --list
mntg enable-units syncthing.service
```

## Verify the same immutable backup

```bash
mntg verify --backup before-reinstall
mntg verify --backup before-reinstall --json
```

Verification reports the repository id and exact commit and exits nonzero when
restorable entries are missing or differ. Use the same selector as restore so
the comparison cannot silently move to a newer backup.

## Preview local retention

Always preview before shortening local branch history:

```bash
mntg backup retain --keep 10 --dry-run
```

The plan names every affected backup. Labels on removable backups block the
operation. A live run repeats the plan and requires confirmation:

```bash
mntg backup retain --keep 10
```

Retention reconstructs the retained linear chain, so equivalent retained
snapshots may receive new commit ids and retained labels are remapped. If the
old history was published, Montage reports that local history now diverges
from the remote. It will not force-push or silently erase the remote history;
keep the remote history, choose a new private remote, or perform deliberate
external Git administration.

## If something remains

- Rerun restore with the same exact commit or label to continue.
- Use `--only <category>` for failed or deferred work.
- Use `mntg enable-units` for services deliberately left disabled.
- Fix capture omissions on the source machine and create a new backup commit.
- Follow [Fresh-machine validation](../testing/fresh-machine-validation.md)
  before a release or destructive machine replacement.
