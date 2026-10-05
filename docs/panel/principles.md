# Panel principles

The ress panel is a compact native Omarchy surface over the CLI. It makes backup freshness, capture choices, and common actions visible without becoming an independent backup engine or a second interpretation of the vault.

## One glance, one decision

The bar icon answers whether a backup exists, is current, is stale, or an operation is running. Opening the panel adds the last-backup age, captured summary, category choices, and the actions most likely to matter now.

The panel should not present a dashboard merely because more data is available. Details belong only when they help the user decide whether to back up, restore, share, apply, or change a safety-relevant setting.

## The CLI is the authority

The panel obtains durable state from `ress status --json` and `ress loadout list --json --contents`, live resource health from `ress loadout check --json`, and operation state from the porcelain protocol. It invokes CLI commands for mutations. It does not inspect vault or registry files, recreate validation rules, or infer success from animation or elapsed time.

If status cannot be parsed, the panel discards it. It must not fill missing vault facts from guesses. Process stderr, terminal records, and exit status determine operation errors.

See the [CLI protocol contract](../contracts/cli-protocol.md).

## Progressive disclosure follows risk

Low-risk, familiar actions stay close:

- back up now;
- export a loadout;
- toggle capture categories;
- change scheduled-backup and consent policies; and
- copy or open the generated share location.

Actions needing longer review or interaction move to a terminal:

- restore, because it can write many files, install packages, need `sudo`, and ask separate consent questions;
- loadout preview, because the exact package and integration list should have room to be read; and
- loadout apply, update, and repair, because they confirm and can install software; and
- loadout removal, because it can delete exclusively owned resources and needs a complete retention/cleanup review.

Opening a terminal is part of the trust model, not a fallback presentation failure. Privilege and prompts remain visible and answerable.

## Show policy in words

The panel does not reduce three-state consent choices to an ambiguous toggle. AUR and service policies read as:

- asks first;
- proceeds without asking; or
- never performs the action.

Secrets are visibly identified as encrypted and off by default. Loadout copy explains that profiles have no dotfiles or attachments.

## Progress comes from real work

During in-panel backup or share operations, labels, categories, progress, logs, and terminal state come from protocol records. Unknown lines are ignored instead of partially interpreted. Indeterminate progress is acceptable when the CLI has reported a running step but no meaningful total.

The panel never estimates completion from time. A stale successful backup remains a freshness condition, not a failed current operation.

## Compact, keyboard-first interaction

The same actions remain available to pointer and keyboard users. Cursor movement, tab switching, activation, direct `b`/`r`/`s`/`a`/`l` shortcuts, and closing are first-class paths. Focus entering the profile URL field must also have a keyboard path back to panel navigation.

The panel keeps a predictable three-tab structure—Backup, Share, Loadouts—and preserves selection language across pointer and keyboard interaction. The Loadouts tab first gives count and attention, then rows, then selected metadata and corrective actions.

## Honest outcomes

Success, partial completion, failure, deferred work, and missing status are different conditions. The panel should retain those distinctions even when it summarizes them into short language. It must not present a stale backup as a failure, a parse failure as empty truth, or a completed process as success solely because it exited the progress view.

The exact current wording is defined in [Status language](status-language.md); data flow and process boundaries are defined in [CLI integration](cli-integration.md).
