# Vision

## Fresh Omarchy to your machine

Omarchy can create a clean desktop quickly. The slower part is reconstructing the accumulated choices that made the previous machine useful: packages, selected configuration, themes, web apps, plugins, and a handful of deliberate permissions.

ress exists to make that reconstruction inspectable, repeatable, and owned by the user. A user should be able to capture the portable shape of a working machine, start from a clean Omarchy installation, preview what will happen, and restore that shape without turning a backup into an opaque installer.

## The intended outcome

A trustworthy reconstruction has four properties:

- The user can see what was captured, what was omitted, and what cannot be rebuilt elsewhere.
- Restoring is additive and resumable; interruption or disagreement does not force a restart from zero.
- Actions that execute fetched build instructions or arrange for code to run later require separate, informed consent.
- Machine-readable state is available through the CLI so the panel and automation do not invent a second truth.

ress is successful when a user can understand the boundary of the backup before needing it, reconstruct a machine when they do need it, and verify the result afterward.

## Two artifacts for two jobs

The private **vault** is a versioned Git repository for one user's reconstructible machine state. It can contain selected dotfiles and an explicitly enabled encrypted secrets bundle, so it belongs in storage the user controls.

A **loadout** is deliberately smaller and shareable. It names supported setup actions—packages, pinned plugins, reconstructible web apps, and a theme—but has no field for dotfiles, arbitrary files, secrets, or commands. It helps another person adopt a setup without accepting a disguised home-directory archive or script runner.

## Boundaries

ress is for Omarchy reconstruction, not general backup or fleet management.

It does not replace backups for documents, photos, repositories, databases, or other user data. It does not clone machine identity, network state, disks, or hardware configuration. It does not promise to reconstruct inputs it cannot represent safely, and it reports those gaps instead of calling the capture complete.

The project is local-first. A vault is an ordinary local Git repository; a remote is optional. ress does not require an account, hosted control plane, or ress-operated storage service.

## Direction

Future work should make reconstruction more trustworthy before making it broader: clearer evidence, better compatibility boundaries, more precise verification, and safer representations for genuinely portable state. New capture categories earn their place only when they can be previewed, restored, verified, and explained without weakening consent or user ownership.

This document describes direction and boundaries. For currently guaranteed behavior, consult [OpenSpec](../../openspec/) and the [contracts](../contracts/).
