# Keyboard workflow

When the panel opens, arrow keys move among rows and left/right move among the
three surfaces. `Enter` activates the focused row and `Escape` closes the
panel. Shortcuts are `l` for Libraries, `c` or `s` for Compose/Share, and `a`
for Applied Loadouts.

Text fields take focus for library metadata, migration source/item identity,
and Share metadata/search. `Enter` or `Escape` returns focus to panel
navigation.

Compose offers eligible applied-loadout starting choices and additive preset
rows. Adding a preset unions resources with manual selections, retains the
selected theme, and explains skipped resources and theme conflicts. An absent
or unavailable current profile is disabled with an explanation.

Every visible action is also a keyboard row: library and item selection, sync
preview and terminal continuation, apply preview/apply, Compose handoff,
library configuration, Ress decisions/inspection/publication, Share selection
and acknowledgement, applied lifecycle actions, and AUR policy.

Rendered verification on a clean Omarchy installation must cover:

1. each surface and empty/unavailable states;
2. every attention color and active animation;
3. keyboard-only library, item, and applied selection;
4. text-focus return;
5. divergent synchronization and Ress publication terminal handoffs; and
6. scaling, scrolling, pointer parity, and malformed-result behavior.

These visual observations remain fresh-machine evidence unless an automated
renderer is available; they are not implied by syntax tests.
