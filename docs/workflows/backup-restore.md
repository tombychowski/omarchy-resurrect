# Back up and restore

This workflow captures a working Omarchy machine into a private Git vault, previews it on another machine, restores selected state, and verifies the result.

The exact vault layout is defined in [Vault format](../contracts/vault-format.md). Consent, checkpointing, and preservation rules are defined in [Restore safety](../contracts/restore-safety.md).

## Prepare the source machine

Check that expected tools and configuration are available:

```bash
ress doctor
ress status
```

Create the default local vault, optionally with a private remote:

```bash
ress init
# or
ress init --remote https://github.com/you/private-omarchy-vault.git
```

If an immediate HTTPS operation is supplied a credential-bearing URL, ress uses
it only for that transport. Config, status, vault Git origins, warnings, and
generated instructions retain only the credential-free repository identity.
Prefer Git credential helpers or SSH rather than embedding credentials.

Review capture choices in `ress status` or `~/.config/ress/config`. The ordinary categories default on except secrets. Change a supported setting with `ress set`, for example:

```bash
ress set CAPTURE_AUTOSTART=1
ress set SECRET_SCAN=block
```

Autostart capture is an explicit choice because those launchers run at login. Blocking scan mode refuses a commit when captured plaintext resembles a credential.

## Capture

Run a local backup:

```bash
ress backup -m "Before replacing this machine"
```

Push in the same operation when a remote is configured:

```bash
ress backup --push
```

Afterward, inspect the summary and scan independently:

```bash
ress status
ress scan
```

Read warnings about unlisted configuration, unsafe symlinks, local-only
plugins/themes, unsupported launchers, and credential-bearing web-app URLs on
the source machine; it is the machine best able to resolve those omissions.

## Preview on the destination

On a fresh Omarchy installation, install the plugin using Omarchy's plugin flow, then preview without changing the configured local vault or machine:

```bash
~/.config/omarchy/plugins/tsouth89.resurrect/bin/ress \
  restore --from https://github.com/you/private-omarchy-vault.git --dry-run
```

The preview names selected category work and content that can execute or persist. A private remote may require credentials supplied through Git's normal mechanisms.

Preview only selected categories when useful:

```bash
ress restore --from https://github.com/you/private-omarchy-vault.git \
  --only packages,config --dry-run
```

Supported categories are `packages`, `config`, `omarchy`, `webapps`, `plugins`, and `secrets`. A typo is rejected before mutation.

## Restore

Start the live interactive restore:

```bash
ress restore --from https://github.com/you/private-omarchy-vault.git
```

The general confirmation permits ordinary selected writes. AUR builds and user-service enablement remain separate choices. For a deliberately unattended run, make all three decisions explicit:

```bash
ress restore --from https://github.com/you/private-omarchy-vault.git \
  --yes --aur --enable-units
```

To decline the higher-power actions explicitly:

```bash
ress restore --from https://github.com/you/private-omarchy-vault.git \
  --yes --no-aur --no-enable-units
```

Use `--review-aur` instead of `--aur` when the AUR helper should retain its own package-review questions.

Restore is resumable. If it stops or reports a partial result, rerun the same command against the same vault snapshot. Completed categories are skipped; failed or deferred work remains available.

Use `--skip LIST` or `--only LIST` for focused recovery. Deferred services can be reviewed later:

```bash
ress enable-units --list
ress enable-units syncthing.service
# or, after reviewing all candidates
ress enable-units --all
```

## Verify

After restore and any deliberate deferred work:

```bash
ress verify
```

Verification exits non-zero when restorable vault entries are missing or differ, so it can close a provisioning script:

```bash
ress restore --from https://github.com/you/private-omarchy-vault.git \
  --yes --aur --enable-units
ress verify || exit 1
```

`ress verify --json` provides structured category counts and item arrays for automation. Non-restorable inventory is reported separately from missing work.

## If something remains

- Rerun restore to continue the same snapshot.
- Use `ress restore --only <category>` to focus on a failed or deferred category.
- Use `ress enable-units` for services deliberately left disabled.
- Resolve capture omissions on the source machine and create a new backup.
- Follow [Fresh-machine validation](../testing/fresh-machine-validation.md) before a release or a destructive machine replacement.
