# Vision

## A deliberate Omarchy setup you can carry

The useful shape of an Omarchy machine is a set of choices: packages, pinned
plugins, reconstructible web apps, and a theme. Montage makes those choices
inspectable, shareable, and repeatable without turning a profile into a script
runner or a copy of somebody's home directory.

A person should be able to compose a constrained loadout, publish it as one
stable item in a library they own, inspect it, apply it additively, and later
check, repair, update, or remove only the state Montage can prove it owns.

## Intended outcome

A trustworthy loadout lifecycle is:

- declarative: a profile names supported resources and carries no commands or arbitrary files;
- explicit: source, library, item, and exact commit identities remain visible;
- additive: apply does not infer deletion from absence or take ownership of pre-existing resources;
- consentful: fetched AUR build instructions require a separate decision;
- observable: the CLI reports health, drift, pending work, updates, and library decisions for people and consumers;
- local-first: libraries and applied state remain user-owned files, while remotes are optional Git transport.

## Boundaries

Montage is not a general data-transfer, secret-management, fleet-management, or
arbitrary execution system. A portable loadout contains no dotfiles, personal
documents, credential material, services, shell fragments, or implied cleanup.
Use purpose-built tools for user data and private machine state.

Montage is independent from Ress. The only foreign boundary is a focused,
read-only inspection and import of one supported Ress v1 portable profile into
a separate Montage library item. It does not adopt Ress state, history, locks,
remotes, or ownership.

Future work should improve evidence, safety, and clarity before expanding the
artifact's authority. Current guarantees live in [OpenSpec](../../openspec/)
and the [contracts](../contracts/).
