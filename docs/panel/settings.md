# Panel settings

The only persistent product setting is `AUR=ask|yes|no`. The Applied Loadouts
surface cycles it through `mntg set`, whose locked read-modify-write preserves
the ordered configuration and omits obsolete keys on the next save.

Library form fields are operation inputs, not a second settings store. The
panel opens `mntg repository configure NAME PATH [--remote URL]` in a terminal.
The CLI validates canonical path, fixed loadout-library envelope, stable
identity, and credential-free remote before replacing registry state.

Ress source and decision fields are in-memory migration inputs. They are never
stored as library settings or adopted as native ownership. Inspection is
read-only; confirmed publication targets the selected configured library and a
new stable item id.
