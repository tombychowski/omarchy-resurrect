# Panel settings

The **Repository settings** section registers existing native Montage
repositories. It collects a bounded name, absolute location, repository type
(`loadouts` or `vault`), and optional credential-free Git remote.

Saving opens the CLI flow:

```text
mntg repository configure NAME PATH TYPE --remote URL --replace
```

The panel does not edit the repository registry. `mntg` validates the native
envelope and stable id, strips URL credentials again, takes the dedicated
configuration lock, re-reads under the lock, and serializes the update. A
known-public vault remote retains its interactive warning and confirmation.

Ress paths are excluded from live Montage settings. **Port from Ress** accepts
a read-only source and a separate Montage destination, then calls **Preview
Ress port**. Only a compatible CLI report enables **Publish port in terminal**.
The source is never adopted as Montage configuration, and no shared-directory
mode is offered.

Capture category, schedule, AUR, and user-service settings continue through
`mntg set KEY=VALUE`; QML never rewrites the config file. AUR and service policy
remain three-state choices: asks first, proceeds without asking, or never.
