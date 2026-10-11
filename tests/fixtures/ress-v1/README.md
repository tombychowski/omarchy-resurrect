# Frozen Ress v1 compatibility fixtures

This file models the compatibility boundary implemented by Ress 1.2.0:

- `loadout/profile.json` is a schema-1 `omarchy-loadout` leaf.

It is input only. Migration tests validate it through the focused Ress v1
boundary. Refused non-loadout controls are constructed ephemerally by the tests
instead of retaining retired artifact families as checked-in fixtures.
