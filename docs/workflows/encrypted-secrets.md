# Transport encrypted secrets

Secrets are excluded from ordinary capture and disabled by default. Enable this workflow only for paths you deliberately choose. The vault stores one age-encrypted archive; the plaintext list and encryption configuration remain local.

The governing guarantees are in [Vault format](../contracts/vault-format.md) and the `credential-protection` OpenSpec capability.

## Install age and create the list

```bash
sudo pacman -S age
mntg secrets init
```

The generated `~/.config/montage/secrets` file contains example `$HOME`-relative paths and comments. Edit it to the smallest set you need, or add one path at a time:

```bash
mntg secrets add .ssh/id_example
mntg secrets list
```

Paths are relative to `$HOME`. The list is not copied into the vault.

Enable the category:

```bash
mntg secrets enable
```

Disable it later with `mntg secrets disable`. `mntg backup --secrets` forces the category for one run; `mntg backup --no-secrets` skips it for one run.

## Passphrase mode

Passphrase mode is the default:

```bash
mntg set SECRETS_MODE=passphrase
mntg backup
```

age prompts for the passphrase during backup and restore. Montage does not store it. Without a usable terminal, the secrets step is skipped rather than falling back to plaintext or persisting a passphrase.

Losing the passphrase makes the encrypted archive unrecoverable. Store it independently from the vault.

## Recipient mode for unattended backup

Generate an age identity and public recipient file:

```bash
age-keygen -o ~/.config/montage/secrets.key
age-keygen -y ~/.config/montage/secrets.key > ~/.config/montage/secrets.key.pub
chmod 600 ~/.config/montage/secrets.key
```

Configure the public-key path:

```bash
mntg set SECRETS_MODE=recipient
mntg set SECRETS_RECIPIENT=~/.config/montage/secrets.key.pub
```

Backup can now encrypt without a prompt. For this portable restore workflow, configure a path ending in `.pub`, not only a literal `age1…` recipient: restore finds the private identity by removing `.pub` from the configured path.

Move `secrets.key` to the destination through a separate secure channel. Do not put the private identity in the vault or add it to the secrets list whose recovery depends on that identity.

## Back up and inspect

```bash
mntg backup
mntg status
mntg scan
```

The vault should contain `secrets/secrets.tar.age`, not plaintext selected
files under `home/`. The ordinary secret scan checks every captured plaintext
subtree before commit while excluding Git metadata and that known ciphertext
bundle. It cannot inspect ciphertext and is not proof that an arbitrary
unrecognizable secret is absent.

## Restore

Passphrase mode requires an interactive terminal. Recipient mode requires the private identity at the path derived from `SECRETS_RECIPIENT`.

Restore the whole vault or only secrets:

```bash
mntg restore --only secrets
```

Montage decrypts into a private staging directory, rejects absolute or traversing archive members, drops symlinks, then copies into `$HOME` with replacement backups. It applies `0700` to `~/.ssh` and `0600` to files below it when that directory is not a symlink.

## Recovery checklist

- Confirm `age` is installed.
- In passphrase mode, run from a usable terminal.
- In recipient mode, bring the private identity separately and keep the configured `.pub` path beside it.
- If decryption fails, do not replace the vault blob with plaintext as a workaround.
- Verify restored secret permissions before using them.
