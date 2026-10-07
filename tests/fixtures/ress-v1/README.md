# Frozen Ress v1 compatibility fixtures

These files model the compatibility boundary implemented by Ress 1.2.0:

- `loadout/profile.json` is a schema-1 `omarchy-loadout` leaf;
- `vault/ress.json` is the canonical schema-1 vault manifest;
- `legacy-vault/resurrect.json` is the supported legacy manifest spelling;
- `vault/home/.config/example/settings.ress-bak` models the current replacement suffix;
- `legacy-vault/home/.config/example/settings.resurrect-bak` models the legacy suffix;
- `vault/plugins/plugins.tsv` contains ordinary, Ress-self, and Montage-self plugin entries;
- `history/01-ress.json`, `02-ress.json`, and `03-future.json` are chronological
  manifest controls used to construct isolated Git-history fixtures.

They are input only. Port tests validate them through the bounded Ress v1
adapter and must not call native Montage repository or vault readers directly.

